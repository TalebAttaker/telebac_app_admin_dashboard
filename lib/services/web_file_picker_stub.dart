// Stub implementation for web file picker
// This file is used when NOT running on web platform

/// Web File Picker Result (stub)
class WebFilePickerResult {
  final dynamic htmlFile = null;
  final String name = '';
  final int size = 0;
  final String type = '';
}

/// Web File Picker (stub for non-web platforms)
class WebFilePicker {
  static Future<WebFilePickerResult?> pickVideoFile() async {
    throw UnsupportedError('Web file picker is only supported on web platform');
  }

  static bool validateFileSize(int sizeInBytes, {int maxSizeMB = 500}) {
    return true;
  }

  static bool validateVideoFile(String fileName, String mimeType) {
    return true;
  }
}
