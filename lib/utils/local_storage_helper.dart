import 'dart:io';
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

  /// Generate a unique file name for an item image based on id, code, or name.
  static String getItemImageFileName({String? id, String? code, String? name}) {
    final cleanId = id?.trim() ?? '';
    final cleanCode = code?.trim() ?? '';
    final cleanName = (name ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();

    if (cleanId.isNotEmpty) {
      return 'item_image_id_$cleanId.png';
    } else if (cleanCode.isNotEmpty) {
      return 'item_image_code_$cleanCode.png';
    } else if (cleanName.isNotEmpty) {
      return 'item_image_name_$cleanName.png';
    } else {
      return 'item_image_default.png';
    }
  }

  /// Save an item image bytes with proper fallback identifiers.
  static Future<String> saveItemImage({
    String? id,
    String? code,
    String? name,
    required Uint8List bytes,
  }) async {
    final primaryFileName = getItemImageFileName(id: id, code: code, name: name);
    final savedPath = await saveImage(primaryFileName, bytes);

    final cleanCode = code?.trim() ?? '';
    if (cleanCode.isNotEmpty) {
      await saveImage('item_image_$cleanCode.png', bytes);
      await saveImage('item_image_code_$cleanCode.png', bytes);
    }
    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      await saveImage('item_image_id_$cleanId.png', bytes);
    }
    final cleanName = (name ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    if (cleanName.isNotEmpty) {
      await saveImage('item_image_name_$cleanName.png', bytes);
    }

    return savedPath;
  }

  /// Load item image bytes checking primary unique key as well as legacy fallbacks.
  static Future<Uint8List?> loadItemImageBytes({
    String? id,
    String? code,
    String? name,
  }) async {
    final primary = getItemImageFileName(id: id, code: code, name: name);
    final bytes = await loadImageBytes(primary);
    if (bytes != null) return bytes;

    final cleanCode = code?.trim() ?? '';
    if (cleanCode.isNotEmpty) {
      final codeBytes = await loadImageBytes('item_image_code_$cleanCode.png');
      if (codeBytes != null) return codeBytes;
      final codeBytesRaw = await loadImageBytes('item_image_$cleanCode.png');
      if (codeBytesRaw != null) return codeBytesRaw;
    }

    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      final idBytes = await loadImageBytes('item_image_id_$cleanId.png');
      if (idBytes != null) return idBytes;
    }

    final cleanName = (name ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    if (cleanName.isNotEmpty) {
      final nameBytes = await loadImageBytes('item_image_name_$cleanName.png');
      if (nameBytes != null) return nameBytes;
    }

    return null;
  }

  /// Delete item image for all identifier variations.
  static Future<void> deleteItemImage({
    String? id,
    String? code,
    String? name,
  }) async {
    final primary = getItemImageFileName(id: id, code: code, name: name);
    await deleteImage(primary);

    final cleanCode = code?.trim() ?? '';
    if (cleanCode.isNotEmpty) {
      await deleteImage('item_image_$cleanCode.png');
      await deleteImage('item_image_code_$cleanCode.png');
    }
    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      await deleteImage('item_image_id_$cleanId.png');
    }
    final cleanName = (name ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    if (cleanName.isNotEmpty) {
      await deleteImage('item_image_name_$cleanName.png');
    }
  }
}
