import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';

/// Platform-aware device info service
/// Provides device/browser information based on platform
class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get device identifier
  /// On web, returns browser fingerprint-like string
  /// On mobile, returns actual device ID
  Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        // Create a fingerprint from browser info
        return '${webInfo.browserName}_${webInfo.platform}_${webInfo.userAgent?.hashCode}';
      } else {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique device ID
      }
    } catch (e) {
      return 'unknown_device';
    }
  }

  /// Get device name
  Future<String> getDeviceName() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return '${webInfo.browserName ?? 'Browser'} on ${webInfo.platform ?? 'Web'}';
      } else {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      }
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Get platform type
  String getPlatformType() {
    return kIsWeb ? 'web' : 'mobile';
  }

  /// Check if running on web
  bool get isWeb => kIsWeb;

  /// Get detailed device/browser info for debugging
  Future<Map<String, dynamic>> getDetailedInfo() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return {
          'platform': 'web',
          'browserName': webInfo.browserName?.name,
          'appVersion': webInfo.appVersion,
          'userAgent': webInfo.userAgent,
          'vendor': webInfo.vendor,
          'language': webInfo.language,
        };
      } else {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'id': androidInfo.id,
        };
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
