import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

/// Device Binding Service
/// يدير ربط الحساب بجهاز واحد فقط
/// يمنع مشاركة الحساب بين عدة أشخاص
class DeviceBindingService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  String? _currentDeviceId;
  Map<String, dynamic>? _deviceDetails;
  bool _isDeviceBound = false;
  bool _isCheckingDevice = false;
  bool _isInitialized = false;

  // Getters
  String? get currentDeviceId => _currentDeviceId;
  bool get isDeviceBound => _isDeviceBound;
  bool get isCheckingDevice => _isCheckingDevice;

  /// تهيئة الخدمة وجلب معرف الجهاز
  /// يتم تخزين المعرف مؤقتاً لتجنب إعادة التوليد في كل مرة
  Future<void> initialize() async {
    if (_isInitialized && _currentDeviceId != null) {
      debugPrint('[DEVICE] Already initialized, using cached device ID');
      return;
    }
    await _generateDeviceId();
    _isInitialized = true;
  }

  /// توليد معرف فريد للجهاز
  Future<String> _generateDeviceId() async {
    if (_currentDeviceId != null) return _currentDeviceId!;

    try {
      String deviceIdentifier = '';

      // Check if running on web first to avoid Platform errors
      if (kIsWeb) {
        // Web platform - don't use device binding
        deviceIdentifier = 'web_${DateTime.now().millisecondsSinceEpoch}';
        _deviceDetails = {
          'device_name': 'Web Browser',
          'device_model': 'Web',
          'platform': 'web',
          'os_version': 'Web',
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // استخدام مزيج من المعلومات لتوليد معرف فريد
        deviceIdentifier = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
        _deviceDetails = {
          'device_name': androidInfo.model,
          'device_model': '${androidInfo.brand} ${androidInfo.model}',
          'platform': 'android',
          'os_version': 'Android ${androidInfo.version.release}',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceIdentifier = '${iosInfo.identifierForVendor}_${iosInfo.model}';
        _deviceDetails = {
          'device_name': iosInfo.name,
          'device_model': iosInfo.model,
          'platform': 'ios',
          'os_version': '${iosInfo.systemName} ${iosInfo.systemVersion}',
        };
      } else {
        // Other platforms
        deviceIdentifier = 'other_${DateTime.now().millisecondsSinceEpoch}';
        _deviceDetails = {
          'device_name': 'Unknown Device',
          'device_model': 'Unknown',
          'platform': 'other',
          'os_version': 'Unknown',
        };
      }

      // تشفير المعرف لجعله أكثر أماناً
      final bytes = utf8.encode(deviceIdentifier);
      final hash = sha256.convert(bytes);
      _currentDeviceId = hash.toString();

      // إضافة إصدار التطبيق
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        _deviceDetails?['app_version'] = packageInfo.version;
      } catch (e) {
        _deviceDetails?['app_version'] = 'unknown';
      }

      return _currentDeviceId!;
    } catch (e) {
      debugPrint('Error generating device ID: $e');
      // استخدام معرف احتياطي
      _currentDeviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      return _currentDeviceId!;
    }
  }

  /// التحقق من ربط الجهاز عند تسجيل الدخول
  /// يرجع:
  /// - DeviceBindingResult.success: الجهاز مرتبط أو تم ربطه بنجاح
  /// - DeviceBindingResult.deviceMismatch: الجهاز مختلف عن المرتبط
  /// - DeviceBindingResult.error: حدث خطأ
  Future<DeviceBindingResult> checkAndBindDevice() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return DeviceBindingResult.error('المستخدم غير مسجل الدخول');
    }

    // Skip device binding on web (admin dashboard and PWA in browser mode)
    if (kIsWeb) {
      debugPrint('[DEVICE] Running on web - skipping device binding');
      _isDeviceBound = true;
      return DeviceBindingResult.success();
    }

    _isCheckingDevice = true;
    notifyListeners();

    try {
      await _generateDeviceId();

      // البحث عن جهاز نشط مرتبط بالمستخدم
      final existingDevice = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (existingDevice == null) {
        // لا يوجد جهاز مرتبط - ربط هذا الجهاز
        await _bindCurrentDevice(userId);
        _isDeviceBound = true;
        _isCheckingDevice = false;
        notifyListeners();
        return DeviceBindingResult.success();
      }

      // التحقق من أن هذا هو نفس الجهاز
      if (existingDevice['device_id'] == _currentDeviceId) {
        // نفس الجهاز - تحديث آخر ظهور
        await _updateLastSeen(existingDevice['id']);
        _isDeviceBound = true;
        _isCheckingDevice = false;
        notifyListeners();
        return DeviceBindingResult.success();
      }

      // جهاز مختلف - رفض الدخول
      _isDeviceBound = false;
      _isCheckingDevice = false;
      notifyListeners();

      final boundDeviceName = existingDevice['device_name'] ?? 'جهاز غير معروف';
      final boundDate = existingDevice['bound_at'] != null
          ? DateTime.parse(existingDevice['bound_at']).toLocal().toString().split('.')[0]
          : 'تاريخ غير معروف';

      return DeviceBindingResult.deviceMismatch(
        'هذا الحساب مرتبط بجهاز آخر ($boundDeviceName) منذ $boundDate. '
        'يرجى التواصل مع الدعم الفني لفك الارتباط.',
      );
    } catch (e) {
      debugPrint('Error checking device binding: $e');
      _isCheckingDevice = false;
      notifyListeners();
      return DeviceBindingResult.error('حدث خطأ أثناء التحقق من الجهاز: $e');
    }
  }

  /// ربط الجهاز الحالي بالمستخدم
  Future<void> _bindCurrentDevice(String userId) async {
    await _supabase.from('user_devices').insert({
      'user_id': userId,
      'device_id': _currentDeviceId,
      'device_name': _deviceDetails?['device_name'],
      'device_model': _deviceDetails?['device_model'],
      'platform': _deviceDetails?['platform'],
      'os_version': _deviceDetails?['os_version'],
      'app_version': _deviceDetails?['app_version'],
      'is_active': true,
      'bound_at': DateTime.now().toIso8601String(),
      'last_seen_at': DateTime.now().toIso8601String(),
    });
  }

  /// تحديث آخر ظهور للجهاز
  Future<void> _updateLastSeen(String deviceRecordId) async {
    await _supabase.from('user_devices').update({
      'last_seen_at': DateTime.now().toIso8601String(),
      'app_version': _deviceDetails?['app_version'],
    }).eq('id', deviceRecordId);
  }

  /// الحصول على معلومات الجهاز المرتبط (للعرض في الإعدادات)
  Future<Map<String, dynamic>?> getBoundDeviceInfo() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final device = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      return device;
    } catch (e) {
      debugPrint('Error getting bound device info: $e');
      return null;
    }
  }

  /// فك ربط الجهاز (للمشرف فقط)
  /// يستخدم من لوحة التحكم
  Future<bool> unbindDevice({
    required String userId,
    required String reason,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) return false;

    try {
      // التحقق من أن المستخدم الحالي مشرف
      final adminProfile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', adminId)
          .single();

      if (adminProfile['role'] != 'admin') {
        debugPrint('Unauthorized: Only admins can unbind devices');
        return false;
      }

      // فك ربط الجهاز
      await _supabase.from('user_devices').update({
        'is_active': false,
        'unbound_at': DateTime.now().toIso8601String(),
        'unbound_by': adminId,
        'unbound_reason': reason,
      }).eq('user_id', userId).eq('is_active', true);

      return true;
    } catch (e) {
      debugPrint('Error unbinding device: $e');
      return false;
    }
  }

  /// الحصول على قائمة جميع الأجهزة للمستخدم (للمشرف)
  Future<List<Map<String, dynamic>>> getUserDeviceHistory(String userId) async {
    try {
      final devices = await _supabase
          .from('user_devices')
          .select('*, unbound_by_profile:profiles!user_devices_unbound_by_fkey(full_name)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(devices);
    } catch (e) {
      debugPrint('Error getting user device history: $e');
      return [];
    }
  }

  /// تسجيل الخروج وتنظيف البيانات المحلية
  void onLogout() {
    _isDeviceBound = false;
    notifyListeners();
  }
}

/// نتيجة التحقق من ربط الجهاز
class DeviceBindingResult {
  final DeviceBindingStatus status;
  final String? message;

  DeviceBindingResult._({required this.status, this.message});

  factory DeviceBindingResult.success() => DeviceBindingResult._(
    status: DeviceBindingStatus.success,
  );

  factory DeviceBindingResult.deviceMismatch(String message) => DeviceBindingResult._(
    status: DeviceBindingStatus.deviceMismatch,
    message: message,
  );

  factory DeviceBindingResult.error(String message) => DeviceBindingResult._(
    status: DeviceBindingStatus.error,
    message: message,
  );

  bool get isSuccess => status == DeviceBindingStatus.success;
  bool get isDeviceMismatch => status == DeviceBindingStatus.deviceMismatch;
  bool get isError => status == DeviceBindingStatus.error;
}

enum DeviceBindingStatus {
  success,
  deviceMismatch,
  error,
}
