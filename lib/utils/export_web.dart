// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

void downloadCsv(String csvData, String fileName) {
  final bytes = utf8.encode(csvData);
  // Add BOM for Excel UTF-8 compatibility
  final bom = [0xEF, 0xBB, 0xBF];
  final blob = html.Blob([bom + bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<void> downloadPdf(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
