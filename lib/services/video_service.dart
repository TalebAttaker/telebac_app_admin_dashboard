import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Video Service
/// Handles video token generation and video playback

class VideoService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  String? _currentVideoUrl;
  String? _currentVideoToken;
  DateTime? _tokenExpiry;

  String? get currentVideoUrl => _currentVideoUrl;
  bool get hasValidToken => _tokenExpiry != null && _tokenExpiry!.isAfter(DateTime.now());

  /// Generate secure video token from Edge Function
  Future<Map<String, dynamic>> generateVideoToken({
    required String videoId,
    String resolution = '720p',
    int expiryHours = 24,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final response = await _dio.post(
        SupabaseConfig.generateVideoTokenEndpoint,
        data: {
          'video_id': videoId,
          'resolution': resolution,
          'expiry_hours': expiryHours,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        _currentVideoUrl = response.data['video_url'];
        _currentVideoToken = response.data['video_url']; // Contains token in URL
        _tokenExpiry = DateTime.parse(response.data['expires_at']);

        notifyListeners();
        return response.data;
      }

      throw Exception('Failed to generate video token');
    } catch (e) {
      debugPrint('Error generating video token: $e');
      rethrow;
    }
  }

  /// Check if user has access to video
  Future<bool> checkVideoAccess({
    String? lessonId,
    String? subjectId,
    String? gradeId,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      final response = await _dio.post(
        SupabaseConfig.checkAccessEndpoint,
        data: {
          if (lessonId != null) 'lesson_id': lessonId,
          if (subjectId != null) 'subject_id': subjectId,
          if (gradeId != null) 'grade_id': gradeId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['has_access'] == true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking access: $e');
      return false;
    }
  }

  /// Clear video cache
  void clearVideoCache() {
    _currentVideoUrl = null;
    _currentVideoToken = null;
    _tokenExpiry = null;
    notifyListeners();
  }
}
