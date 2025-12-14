import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Progress Service
/// Tracks user learning progress

class ProgressService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  Map<String, double> _lessonProgress = {};

  Map<String, double> get lessonProgress => _lessonProgress;

  /// Update progress (alias for trackProgress)
  Future<void> updateProgress({
    required String lessonId,
    String? videoId,
    required int watchedDurationSeconds,
    required int lastWatchedPositionSeconds,
    required int totalDurationSeconds,
  }) async {
    return trackProgress(
      lessonId: lessonId,
      videoId: videoId,
      watchedDurationSeconds: watchedDurationSeconds,
      lastWatchedPositionSeconds: lastWatchedPositionSeconds,
      totalDurationSeconds: totalDurationSeconds,
    );
  }

  /// Track progress via Edge Function
  Future<void> trackProgress({
    required String lessonId,
    String? videoId,
    required int watchedDurationSeconds,
    required int lastWatchedPositionSeconds,
    required int totalDurationSeconds,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      await _dio.post(
        SupabaseConfig.trackProgressEndpoint,
        data: {
          'lesson_id': lessonId,
          if (videoId != null) 'video_id': videoId,
          'watched_duration_seconds': watchedDurationSeconds,
          'last_watched_position_seconds': lastWatchedPositionSeconds,
          'total_duration_seconds': totalDurationSeconds,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Update local cache
      final percentage = (watchedDurationSeconds / totalDurationSeconds) * 100;
      _lessonProgress[lessonId] = percentage;
      notifyListeners();
    } catch (e) {
      debugPrint('Error tracking progress: $e');
    }
  }

  /// Fetch user progress
  Future<void> fetchProgress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_progress')
          .select('lesson_id, completion_percentage')
          .eq('user_id', userId);

      _lessonProgress = {};
      for (var item in response as List) {
        _lessonProgress[item['lesson_id']] =
            (item['completion_percentage'] as num).toDouble();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching progress: $e');
    }
  }

  /// Get progress for a specific lesson
  double getLessonProgress(String lessonId) {
    return _lessonProgress[lessonId] ?? 0.0;
  }

  /// Check if lesson is completed
  bool isLessonCompleted(String lessonId) {
    return getLessonProgress(lessonId) >= 90.0;
  }
}
