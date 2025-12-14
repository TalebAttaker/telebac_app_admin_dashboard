// Web-specific file picker implementation
// This file is only compiled when running on web platform
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Web File Picker Result
/// Holds both the HTML File object and metadata
class WebFilePickerResult {
  final html.File htmlFile;
  final String name;
  final int size;
  final String type;

  WebFilePickerResult({
    required this.htmlFile,
    required this.name,
    required this.size,
    required this.type,
  });
}

/// Web-specific file picker helper
/// Captures HTML File object for efficient large file uploads
class WebFilePicker {
  /// Pick a video file and return HTML File object
  /// This avoids loading the entire file into memory
  static Future<WebFilePickerResult?> pickVideoFile() async {
    try {
      // Create a hidden file input element
      final input = html.FileUploadInputElement();
      input.accept = 'video/*';
      input.multiple = false;

      // Create a completer to wait for file selection
      final completer = Completer<WebFilePickerResult?>();

      // Listen for file selection
      input.onChange.listen((event) {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final file = files.first;
          debugPrint('📁 Web file selected:');
          debugPrint('  - Name: ${file.name}');
          debugPrint('  - Size: ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB');
          debugPrint('  - Type: ${file.type}');

          completer.complete(WebFilePickerResult(
            htmlFile: file,
            name: file.name,
            size: file.size,
            type: file.type,
          ));
        } else {
          // No files selected (cancelled)
          if (!completer.isCompleted) {
            debugPrint('File selection cancelled');
            completer.complete(null);
          }
        }
      });

      // Trigger the file picker
      input.click();

      return await completer.future;
    } catch (e) {
      debugPrint('Error in web file picker: $e');
      return null;
    }
  }

  /// Validate file size (max 500MB for safety)
  static bool validateFileSize(int sizeInBytes, {int maxSizeMB = 500}) {
    final sizeMB = sizeInBytes / 1024 / 1024;
    return sizeMB <= maxSizeMB;
  }

  /// Validate file type (video only)
  static bool validateVideoFile(String fileName, String mimeType) {
    final validExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.wmv', '.m4v'];
    final validMimeTypes = [
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo',
      'video/x-matroska',
      'video/webm',
      'video/x-flv',
      'video/x-ms-wmv',
    ];

    // Check extension
    final lowerName = fileName.toLowerCase();
    final hasValidExtension = validExtensions.any((ext) => lowerName.endsWith(ext));

    // Check MIME type
    final hasValidMimeType = validMimeTypes.any((mime) => mimeType.startsWith(mime));

    return hasValidExtension || hasValidMimeType;
  }
}
