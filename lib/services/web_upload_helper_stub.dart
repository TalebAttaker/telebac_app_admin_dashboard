// Stub implementation for web upload helper
// This file is used when NOT running on web platform

class WebUploadHelper {
  // Stub implementation - does nothing on non-web platforms
  static Future<void> uploadFile(dynamic file) async {
    throw UnsupportedError('Web upload is only supported on web platform');
  }
}
