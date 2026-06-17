import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> downloadCsv(String csvData, String fileName) async {
  try {
    String path = '';

    if (Platform.isAndroid) {
      // Best-effort Android download folder without packages
      path = '/storage/emulated/0/Download/$fileName';
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      path = '$userProfile\\Downloads\\$fileName';
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      path = '$home/Downloads/$fileName';
    } else if (Platform.isIOS) {
      // iOS sandboxing prevents simple absolute paths without path_provider.
      // Use application documents directory so the file is actually saved.
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$fileName';
    } else {
      path = fileName;
    }

    final file = File(path);
    // Add BOM for UTF-8 compatibility
    final bytes = [0xEF, 0xBB, 0xBF, ...csvData.codeUnits];
    file.writeAsBytesSync(bytes);
    debugPrint('File exported successfully to: $path');
  } catch (e) {
    debugPrint('Failed to export file: $e');
  }
}

Future<void> downloadPdf(Uint8List bytes, String fileName) async {
  Directory output;
  if (Platform.isAndroid) {
    output = Directory('/storage/emulated/0/Download');
    if (!output.existsSync()) {
      output = await getApplicationDocumentsDirectory();
    }
  } else {
    output = await getApplicationDocumentsDirectory();
  }

  final file = File('${output.path}/$fileName');
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}
