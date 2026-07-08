import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LocalImageStorage {
  /// Save an image byte array to the application's document directory.
  /// [fileName] should be the unique identifier or name of the file (e.g. 'item_burger.png').
  static Future<String> saveImage(String fileName, Uint8List bytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('Error saving image to local storage: $e');
      return '';
    }
  }

  /// Load an image as a Uint8List from the local application document directory.
  static Future<Uint8List?> loadImageBytes(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      print('Error loading image from local storage: $e');
    }
    return null;
  }
  
  /// Delete an image from the local application document directory.
  static Future<bool> deleteImage(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      print('Error deleting image from local storage: $e');
    }
    return false;
  }
}
