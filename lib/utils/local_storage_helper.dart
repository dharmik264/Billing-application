import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
      debugPrint('Error saving image to local storage: $e');
      return '';
    }
  }

  /// Load an image as a Uint8List from the local application document directory.
  static Future<Uint8List?> loadImageBytes(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading image from local storage: $e');
    }
    return null;
  }
  
  /// Delete an image from the local application document directory.
  static Future<bool> deleteImage(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting image from local storage: $e');
    }
    return false;
  }
}
