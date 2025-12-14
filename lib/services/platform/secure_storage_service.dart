import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-aware secure storage service
/// Uses flutter_secure_storage on mobile and SharedPreferences on web
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  FlutterSecureStorage? _secureStorage;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
    } else {
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
    }
  }

  Future<void> write({required String key, required String value}) async {
    if (kIsWeb) {
      await _prefs?.setString(key, value);
    } else {
      await _secureStorage?.write(key: key, value: value);
    }
  }

  Future<String?> read({required String key}) async {
    if (kIsWeb) {
      return _prefs?.getString(key);
    } else {
      return await _secureStorage?.read(key: key);
    }
  }

  Future<void> delete({required String key}) async {
    if (kIsWeb) {
      await _prefs?.remove(key);
    } else {
      await _secureStorage?.delete(key: key);
    }
  }

  Future<void> deleteAll() async {
    if (kIsWeb) {
      await _prefs?.clear();
    } else {
      await _secureStorage?.deleteAll();
    }
  }

  Future<Map<String, String>> readAll() async {
    if (kIsWeb) {
      final keys = _prefs?.getKeys() ?? {};
      final Map<String, String> result = {};
      for (final key in keys) {
        final value = _prefs?.getString(key);
        if (value != null) {
          result[key] = value;
        }
      }
      return result;
    } else {
      return await _secureStorage?.readAll() ?? {};
    }
  }

  Future<bool> containsKey({required String key}) async {
    if (kIsWeb) {
      return _prefs?.containsKey(key) ?? false;
    } else {
      return await _secureStorage?.containsKey(key: key) ?? false;
    }
  }
}
