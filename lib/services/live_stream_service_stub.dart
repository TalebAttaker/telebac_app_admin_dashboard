import 'package:flutter/material.dart';

/// Stub for LiveStream service on web
/// Web should use Edge Functions for Cloudflare Stream operations
class LiveStreamService extends ChangeNotifier {
  Future<void> initialize() async {
    debugPrint('LiveStreamService (Web Stub): Using Edge Functions for live streams');
  }

  // Add other methods as needed with stub implementations
}
