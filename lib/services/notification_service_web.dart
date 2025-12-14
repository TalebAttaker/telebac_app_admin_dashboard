import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web-compatible notification service (stub for now)
/// For full web notifications, implement Web Push API
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;

  String? _webToken;
  bool _isInitialized = false;

  // Settings keys (must match SettingsProvider)
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyLiveSessionReminders = 'live_session_reminders';
  static const String _keyNewContentNotifications = 'new_content_notifications';

  String? get fcmToken => _webToken;
  bool get isInitialized => _isInitialized;

  /// Check if notifications are enabled in settings
  Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyNotificationsEnabled) ?? true;
    } catch (e) {
      debugPrint('Error checking notifications setting: $e');
      return true;
    }
  }

  /// Initialize notification service (stub for web)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('NotificationService (Web): Initializing...');

      // TODO: Implement Web Push API here if needed
      // For now, just mark as initialized
      _isInitialized = true;
      debugPrint('NotificationService (Web): Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService (Web): Initialization error: $e');
    }
  }

  /// Request notification permission (Web API)
  Future<void> requestPermission() async {
    debugPrint('NotificationService (Web): Permission request - Web Push API not yet implemented');
    // TODO: Implement Notification.requestPermission() from Web API
  }

  /// Subscribe to a topic (not applicable for web)
  Future<void> subscribeToTopic(String topic) async {
    debugPrint('NotificationService (Web): Topic subscription not available on web');
  }

  /// Unsubscribe from a topic (not applicable for web)
  Future<void> unsubscribeFromTopic(String topic) async {
    debugPrint('NotificationService (Web): Topic unsubscription not available on web');
  }

  /// Show local notification (stub)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('NotificationService (Web): Local notification - $title: $body');
    // TODO: Use Web Notifications API
  }

  /// Schedule a notification (stub)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    debugPrint('NotificationService (Web): Scheduled notification not yet implemented');
  }

  /// Cancel a scheduled notification (stub)
  Future<void> cancelNotification(int id) async {
    debugPrint('NotificationService (Web): Cancel notification $id');
  }

  /// Cancel all notifications (stub)
  Future<void> cancelAllNotifications() async {
    debugPrint('NotificationService (Web): Cancel all notifications');
  }

  /// Handle notification settings changes
  void onNotificationsEnabledChanged(bool enabled) {
    notifyListeners();
  }

  void onLiveSessionRemindersChanged(bool enabled) {
    notifyListeners();
  }

  void onNewContentNotificationsChanged(bool enabled) {
    notifyListeners();
  }
}
