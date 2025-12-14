import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Platform-aware file storage service
/// Handles file operations differently for web vs mobile
class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();

  /// Get application documents directory
  /// Returns null on web as file system access is limited
  Future<Directory?> getApplicationDocumentsDirectory() async {
    if (kIsWeb) {
      return null; // Web uses browser storage (IndexedDB, localStorage)
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Get temporary directory
  /// Returns null on web
  Future<Directory?> getTemporaryDirectory() async {
    if (kIsWeb) {
      return null;
    } else {
      return await getTemporaryDirectory();
    }
  }

  /// Check if file operations are supported
  bool get supportsFileSystem => !kIsWeb;

  /// Get storage path for encrypted videos
  /// On web, this should be handled via IndexedDB instead
  Future<String?> getVideoStoragePath() async {
    if (kIsWeb) {
      // Web: Use IndexedDB or Cache API for video storage
      return null; // Indicates to use browser storage APIs
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/encrypted_videos';
    }
  }

  /// Check if a file exists
  /// Only works on mobile
  Future<bool> fileExists(String path) async {
    if (kIsWeb || path.isEmpty) {
      return false;
    }
    return File(path).exists();
  }

  /// Delete a file
  /// Only works on mobile
  Future<void> deleteFile(String path) async {
    if (!kIsWeb && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
