import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  // The notification will be shown automatically by the system
  // We just need to ensure Firebase is initialized
}

/// Service for handling push notifications via Firebase Cloud Messaging
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _supabase = Supabase.instance.client;

  String? _fcmToken;
  bool _isInitialized = false;

  // Settings keys (must match SettingsProvider)
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyLiveSessionReminders = 'live_session_reminders';
  static const String _keyNewContentNotifications = 'new_content_notifications';

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Check if notifications are enabled in settings
  Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyNotificationsEnabled) ?? true;
    } catch (e) {
      return true; // Default to enabled
    }
  }

  /// Check if live session reminders are enabled
  Future<bool> areLiveRemindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mainEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
      final liveEnabled = prefs.getBool(_keyLiveSessionReminders) ?? true;
      return mainEnabled && liveEnabled;
    } catch (e) {
      return true;
    }
  }

  /// Check if new content notifications are enabled
  Future<bool> areNewContentNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mainEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
      final newContentEnabled = prefs.getBool(_keyNewContentNotifications) ?? true;
      return mainEnabled && newContentEnabled;
    } catch (e) {
      return true;
    }
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz_data.initializeTimeZones();

      // Request permission
      final settings = await _requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('Notification permission not granted');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get FCM token
      await _getFcmToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_handleTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from notification)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
      notifyListeners();

      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Request notification permission
  Future<NotificationSettings> _requestPermission() async {
    return await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  /// Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // High importance channel for general notifications
      const highImportanceChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin?.createNotificationChannel(highImportanceChannel);

      // Live session reminders channel
      const liveRemindersChannel = AndroidNotificationChannel(
        'live_reminders_channel',
        'Live Session Reminders',
        description: 'Reminders for upcoming live sessions',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin?.createNotificationChannel(liveRemindersChannel);
    }
  }

  /// Get FCM token and save to Supabase
  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveTokenToSupabase(_fcmToken!);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Handle token refresh
  Future<void> _handleTokenRefresh(String newToken) async {
    debugPrint('FCM Token refreshed: $newToken');

    // Remove old token
    if (_fcmToken != null) {
      await _removeTokenFromSupabase(_fcmToken!);
    }

    // Save new token
    _fcmToken = newToken;
    await _saveTokenToSupabase(newToken);
  }

  /// Save FCM token to Supabase
  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Cannot save FCM token: User not logged in');
      return;
    }

    try {
      // Upsert token (update if exists, insert if not)
      await _supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': _getDeviceType(),
        'device_name': await _getDeviceName(),
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');

      debugPrint('FCM token saved to Supabase');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token from Supabase
  Future<void> _removeTokenFromSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('fcm_tokens')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('token', token);

      debugPrint('FCM token deactivated in Supabase');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  /// Handle foreground message
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Check if notifications are enabled
    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      debugPrint('Notifications disabled in settings, skipping display');
      // Still save to database but don't show
      await _saveNotificationToDatabase(message);
      return;
    }

    // Check notification type and corresponding setting
    final notificationType = message.data['type'] as String?;
    if (notificationType == 'live_session' || notificationType == 'live_reminder') {
      final liveEnabled = await areLiveRemindersEnabled();
      if (!liveEnabled) {
        debugPrint('Live reminders disabled in settings, skipping display');
        await _saveNotificationToDatabase(message);
        return;
      }
    } else if (notificationType == 'new_content' || notificationType == 'new_lesson') {
      final newContentEnabled = await areNewContentNotificationsEnabled();
      if (!newContentEnabled) {
        debugPrint('New content notifications disabled in settings, skipping display');
        await _saveNotificationToDatabase(message);
        return;
      }
    }

    // Show local notification
    await _showLocalNotification(
      title: notification.title ?? 'El-Mouein',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );

    // Save to notifications table
    await _saveNotificationToDatabase(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap when app is in background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    _navigateBasedOnData(message.data);
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateBasedOnData(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate based on notification data
  void _navigateBasedOnData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final targetId = data['target_id'] as String?;

    // You'll need to implement navigation logic based on your app's routes
    // This is a placeholder - the actual navigation should be handled by the app
    debugPrint('Navigate to: type=$type, targetId=$targetId');

    // Notify listeners so the app can handle navigation
    _lastNotificationData = data;
    notifyListeners();
  }

  Map<String, dynamic>? _lastNotificationData;
  Map<String, dynamic>? get lastNotificationData => _lastNotificationData;

  void clearLastNotificationData() {
    _lastNotificationData = null;
  }

  /// Save notification to database
  Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': message.notification?.title,
        'title_ar': message.data['title_ar'],
        'title_fr': message.data['title_fr'],
        'message': message.notification?.body,
        'body_ar': message.data['body_ar'],
        'body_fr': message.data['body_fr'],
        'notification_type': message.data['type'] ?? 'info',
        'data': message.data,
        'is_read': false,
        'fcm_sent': true,
        'fcm_sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving notification to database: $e');
    }
  }

  /// Get device type
  String _getDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Get device name
  Future<String> _getDeviceName() async {
    // For simplicity, return platform name
    // You can enhance this with device_info_plus package
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    return 'Unknown Device';
  }

  /// Fetch unread notifications from Supabase
  Future<List<Map<String, dynamic>>> fetchUnreadNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Fetch all notifications from Supabase
  Future<List<Map<String, dynamic>>> fetchAllNotifications({int limit = 50}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Subscribe to topic for broadcast notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Clean up on logout
  Future<void> cleanup() async {
    if (_fcmToken != null) {
      await _removeTokenFromSupabase(_fcmToken!);
    }
    _fcmToken = null;
    _lastNotificationData = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  // Live Session Reminders
  // ═══════════════════════════════════════════════════════

  /// Schedule a reminder for a live session
  /// Schedules notifications 15 minutes and 5 minutes before the session
  Future<void> scheduleLiveSessionReminder({
    required String sessionId,
    required String sessionTitle,
    required DateTime scheduledTime,
    String? teacherName,
  }) async {
    // Check if live reminders are enabled
    final enabled = await areLiveRemindersEnabled();
    if (!enabled) {
      debugPrint('Live reminders disabled, skipping scheduling');
      return;
    }

    try {
      // Schedule 15-minute reminder
      final reminder15Min = scheduledTime.subtract(const Duration(minutes: 15));
      if (reminder15Min.isAfter(DateTime.now())) {
        await _scheduleLocalNotification(
          id: _generateNotificationId(sessionId, 15),
          title: 'البث المباشر يبدأ قريباً!',
          body: teacherName != null
              ? '$sessionTitle - مع $teacherName - خلال 15 دقيقة'
              : '$sessionTitle - خلال 15 دقيقة',
          scheduledTime: reminder15Min,
          payload: jsonEncode({
            'type': 'live_reminder',
            'session_id': sessionId,
            'minutes_before': 15,
          }),
        );
        debugPrint('Scheduled 15-min reminder for session: $sessionId');
      }

      // Schedule 5-minute reminder
      final reminder5Min = scheduledTime.subtract(const Duration(minutes: 5));
      if (reminder5Min.isAfter(DateTime.now())) {
        await _scheduleLocalNotification(
          id: _generateNotificationId(sessionId, 5),
          title: 'البث المباشر يبدأ الآن!',
          body: teacherName != null
              ? '$sessionTitle - مع $teacherName - خلال 5 دقائق'
              : '$sessionTitle - خلال 5 دقائق',
          scheduledTime: reminder5Min,
          payload: jsonEncode({
            'type': 'live_reminder',
            'session_id': sessionId,
            'minutes_before': 5,
          }),
        );
        debugPrint('Scheduled 5-min reminder for session: $sessionId');
      }

      // Save scheduled reminders to preferences for tracking
      await _saveScheduledReminder(sessionId, scheduledTime);
    } catch (e) {
      debugPrint('Error scheduling live session reminder: $e');
    }
  }

  /// Cancel scheduled reminders for a live session
  Future<void> cancelLiveSessionReminder(String sessionId) async {
    try {
      await _localNotifications.cancel(_generateNotificationId(sessionId, 15));
      await _localNotifications.cancel(_generateNotificationId(sessionId, 5));
      await _removeScheduledReminder(sessionId);
      debugPrint('Cancelled reminders for session: $sessionId');
    } catch (e) {
      debugPrint('Error cancelling live session reminder: $e');
    }
  }

  /// Schedule a local notification at a specific time
  Future<void> _scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'live_reminders_channel',
      'Live Session Reminders',
      channelDescription: 'Reminders for upcoming live sessions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use zonedSchedule for time-based notifications
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledTime),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Convert DateTime to TZDateTime for scheduling
  /// Note: This uses UTC, you may want to use timezone package for proper local time handling
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Generate a unique notification ID based on session ID and minutes before
  int _generateNotificationId(String sessionId, int minutesBefore) {
    return (sessionId.hashCode + minutesBefore).abs() % 2147483647;
  }

  /// Save scheduled reminder to preferences
  Future<void> _saveScheduledReminder(String sessionId, DateTime scheduledTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = prefs.getStringList('scheduled_live_reminders') ?? [];
      final reminderData = jsonEncode({
        'session_id': sessionId,
        'scheduled_time': scheduledTime.toIso8601String(),
      });
      if (!reminders.contains(reminderData)) {
        reminders.add(reminderData);
        await prefs.setStringList('scheduled_live_reminders', reminders);
      }
    } catch (e) {
      debugPrint('Error saving scheduled reminder: $e');
    }
  }

  /// Remove scheduled reminder from preferences
  Future<void> _removeScheduledReminder(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = prefs.getStringList('scheduled_live_reminders') ?? [];
      reminders.removeWhere((r) {
        try {
          final data = jsonDecode(r) as Map<String, dynamic>;
          return data['session_id'] == sessionId;
        } catch (e) {
          return false;
        }
      });
      await prefs.setStringList('scheduled_live_reminders', reminders);
    } catch (e) {
      debugPrint('Error removing scheduled reminder: $e');
    }
  }

  /// Get all scheduled live session reminders
  Future<List<Map<String, dynamic>>> getScheduledReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = prefs.getStringList('scheduled_live_reminders') ?? [];
      return reminders.map((r) {
        try {
          return jsonDecode(r) as Map<String, dynamic>;
        } catch (e) {
          return <String, dynamic>{};
        }
      }).where((r) => r.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error getting scheduled reminders: $e');
      return [];
    }
  }

  /// Clean up expired reminders
  Future<void> cleanupExpiredReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders = prefs.getStringList('scheduled_live_reminders') ?? [];
      final now = DateTime.now();
      final validReminders = reminders.where((r) {
        try {
          final data = jsonDecode(r) as Map<String, dynamic>;
          final scheduledTime = DateTime.parse(data['scheduled_time'] as String);
          return scheduledTime.isAfter(now);
        } catch (e) {
          return false;
        }
      }).toList();
      await prefs.setStringList('scheduled_live_reminders', validReminders);
    } catch (e) {
      debugPrint('Error cleaning up expired reminders: $e');
    }
  }
}
