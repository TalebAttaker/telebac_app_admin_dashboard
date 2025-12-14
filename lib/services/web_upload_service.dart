import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

/// Web-specific upload service for large files
class WebUploadService {
  /// Upload a large file from web using HTML5 File API
  /// This avoids loading the entire file into memory
  static Future<void> uploadLargeFile({
    required html.File file,
    required String uploadUrl,
    required Map<String, String> headers,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('🌐 Web Upload Starting...');
      debugPrint('  - File: ${file.name}');
      debugPrint('  - Size: ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('  - URL: $uploadUrl');

      final xhr = html.HttpRequest();

      // Setup progress tracking
      xhr.upload.onProgress.listen((event) {
        if (event.lengthComputable) {
          final progress = event.loaded! / event.total!;
          debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          onProgress?.call(progress);
        }
      });

      // Setup completion handler
      final completer = Completer<void>();
      xhr.onLoad.listen((event) {
        if (xhr.status == 200 || xhr.status == 201) {
          debugPrint('✅ Upload completed successfully!');
          completer.complete();
        } else {
          debugPrint('❌ Upload failed with status: ${xhr.status}');
          debugPrint('Response: ${xhr.responseText}');
          completer.completeError(
            Exception('Upload failed with status ${xhr.status}: ${xhr.responseText}'),
          );
        }
      });

      xhr.onError.listen((event) {
        debugPrint('❌ Upload error occurred');
        completer.completeError(Exception('Upload network error'));
      });

      // Open connection and set headers
      xhr.open('PUT', uploadUrl);
      headers.forEach((key, value) {
        xhr.setRequestHeader(key, value);
      });

      // Send the file
      xhr.send(file);

      await completer.future;
    } catch (e) {
      debugPrint('Error in web upload: $e');
      rethrow;
    }
  }

  /// Get HTML File object from FilePicker result
  /// This is a workaround to access the underlying HTML File without loading bytes
  static html.File? getHtmlFileFromPicker() {
    try {
      // Access the hidden file input element created by FilePicker
      final fileInput = html.document.querySelector('input[type="file"]') as html.FileUploadInputElement?;
      if (fileInput != null && fileInput.files != null && fileInput.files!.isNotEmpty) {
        return fileInput.files!.first;
      }
    } catch (e) {
      debugPrint('Error getting HTML file: $e');
    }
    return null;
  }
}
