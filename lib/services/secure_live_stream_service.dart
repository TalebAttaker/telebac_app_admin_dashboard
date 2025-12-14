import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/live_stream.dart';
import '../models/live_comment.dart';
import '../models/live_reaction.dart';

/// Secure Live Stream Service
/// Uses Edge Function for Cloudflare Stream operations
/// API keys stored securely in Edge Function, NOT in the app
class SecureLiveStreamService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _edgeFunctionUrl = '${SupabaseConfig.functionsUrl}/cloudflare-stream';
  static const String _cloudflareCustomerSubdomain = 'customer-vegvgpl31x9ap217.cloudflarestream.com';

  // Default Live Input (shared with telebac_live app)
  static const String _defaultLiveInputId = '01019c46179a6ff6e20df3b348b9e7b8';
  static const String _defaultStreamKey = '004099ad93f953061ccdd3b756e8e1cek01019c46179a6ff6e20df3b348b9e7b8';
  static const String _defaultWhipUrl = 'https://customer-vegvgpl31x9ap217.cloudflarestream.com/1e397b056a6cb2776c5dd41886f70299k01019c46179a6ff6e20df3b348b9e7b8/webRTC/publish';

  // Realtime subscriptions
  RealtimeChannel? _commentsChannel;
  RealtimeChannel? _reactionsChannel;
  RealtimeChannel? _viewerCountChannel;

  String? _lastError;
  String? get lastError => _lastError;

  /// Check if service is configured (always true for Edge Function-based service)
  static bool get isConfigured => true;

  /// Get authorization header from current session
  Map<String, String> _getAuthHeaders() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('User not authenticated');
    }
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  /// Create a new live stream (Admin only)
  Future<LiveStream?> createStream({
    required String titleAr,
    required String titleFr,
    String? descriptionAr,
    String? descriptionFr,
    String? thumbnailUrl,
    DateTime? scheduledAt,
  }) async {
    try {
      _lastError = null;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _lastError = 'المستخدم غير مصرح له. قم بتسجيل الدخول مرة أخرى.';
        throw Exception('User not authenticated');
      }

      // Use the shared Live Input (same as telebac_live)
      debugPrint('Using shared Cloudflare Live Input: $_defaultLiveInputId');

      // Create stream record in Supabase
      final streamData = {
        'title_ar': titleAr,
        'title_fr': titleFr,
        'description_ar': descriptionAr,
        'description_fr': descriptionFr,
        'thumbnail_url': thumbnailUrl,
        'stream_key': _defaultStreamKey,
        'video_id': _defaultLiveInputId,
        'rtmp_url': 'rtmps://live.cloudflare.com:443/live/',
        'hls_url': 'https://$_cloudflareCustomerSubdomain/$_defaultLiveInputId/manifest/video.m3u8',
        'whip_url': _defaultWhipUrl,
        'status': scheduledAt != null ? 'scheduled' : 'scheduled',
        'scheduled_at': scheduledAt?.toIso8601String(),
        'created_by': userId,
      };

      final response = await _supabase
          .from('live_streams')
          .insert(streamData)
          .select()
          .single();

      debugPrint('Stream created successfully in database');
      notifyListeners();
      return LiveStream.fromJson(response);
    } catch (e) {
      debugPrint('Error creating stream: $e');
      if (_lastError == null) {
        _lastError = 'حدث خطأ غير متوقع: ${e.toString()}';
      }
      return null;
    }
  }

  /// Create Live Input on Cloudflare (Admin only) - via Edge Function
  Future<Map<String, dynamic>?> createCloudflareLiveInput(String title) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'create_live_input',
          'title': title,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['liveInput'] as Map<String, dynamic>;
      } else {
        debugPrint('Cloudflare API error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating Cloudflare live input: $e');
      return null;
    }
  }

  /// Get Cloudflare Live Input status - via Edge Function
  Future<Map<String, dynamic>?> getCloudflareStreamStatus(String uid) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'get_live_input_status',
          'uid': uid,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['status'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting Cloudflare stream status: $e');
      return null;
    }
  }

  /// Get recordings from a Live Input - via Edge Function
  Future<List<Map<String, dynamic>>> getCloudflareRecordings(String liveInputUid) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'get_recordings',
          'liveInputUid': liveInputUid,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['recordings'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting Cloudflare recordings: $e');
      return [];
    }
  }

  /// Delete Live Input from Cloudflare (Admin only) - via Edge Function
  Future<bool> deleteCloudflareLiveInput(String uid) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'delete_live_input',
          'uid': uid,
        }),
      );

      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      debugPrint('Error deleting Cloudflare live input: $e');
      return false;
    }
  }

  // ============================================================================
  // Stream Management (using Supabase - already secure with RLS)
  // ============================================================================

  Future<bool> startStream(String streamId) async {
    try {
      await _supabase.from('live_streams').update({
        'status': 'live',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('id', streamId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting stream: $e');
      return false;
    }
  }

  Future<bool> endStream(String streamId) async {
    try {
      final stream = await getStream(streamId);
      if (stream == null) return false;

      final duration = stream.startedAt != null
          ? DateTime.now().difference(stream.startedAt!).inSeconds
          : 0;

      await _supabase.from('live_streams').update({
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
        'duration_seconds': duration,
      }).eq('id', streamId);

      // Try to get recording
      if (stream.videoId != null) {
        await Future.delayed(const Duration(seconds: 3));
        final recordings = await getCloudflareRecordings(stream.videoId!);
        if (recordings.isNotEmpty) {
          final recordingUid = recordings.first['uid'] as String?;
          if (recordingUid != null) {
            await _supabase.from('live_streams').update({
              'hls_url': 'https://$_cloudflareCustomerSubdomain/$recordingUid/manifest/video.m3u8',
              'video_id': recordingUid,
            }).eq('id', streamId);
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error ending stream: $e');
      return false;
    }
  }

  Future<bool> archiveStream(String streamId) async {
    try {
      final stream = await getStream(streamId);
      if (stream == null) return false;

      if (stream.videoId != null) {
        final recordings = await getCloudflareRecordings(stream.videoId!);
        if (recordings.isNotEmpty) {
          final recordingUid = recordings.first['uid'] as String?;
          if (recordingUid != null) {
            await _supabase.from('live_streams').update({
              'status': 'archived',
              'hls_url': 'https://$_cloudflareCustomerSubdomain/$recordingUid/manifest/video.m3u8',
            }).eq('id', streamId);
            notifyListeners();
            return true;
          }
        }
      }

      await _supabase.from('live_streams').update({
        'status': 'archived',
      }).eq('id', streamId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error archiving stream: $e');
      return false;
    }
  }

  Future<LiveStream?> getStream(String streamId) async {
    try {
      final response = await _supabase
          .from('live_streams')
          .select()
          .eq('id', streamId)
          .single();
      return LiveStream.fromJson(response);
    } catch (e) {
      debugPrint('Error getting stream: $e');
      return null;
    }
  }

  Future<List<LiveStream>> getStreams({String? status, String? curriculumId}) async {
    try {
      var query = _supabase.from('live_streams').select();
      if (status != null) query = query.eq('status', status);
      if (curriculumId != null) query = query.eq('curriculum_id', curriculumId);
      final response = await query.order('created_at', ascending: false);
      return (response as List).map((json) => LiveStream.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting streams: $e');
      return [];
    }
  }

  Future<List<LiveStream>> getLiveStreams({String? curriculumId}) async {
    return getStreams(status: 'live', curriculumId: curriculumId);
  }

  Future<List<LiveStream>> getScheduledStreams({String? curriculumId}) async {
    return getStreams(status: 'scheduled', curriculumId: curriculumId);
  }

  Future<List<LiveStream>> getArchivedStreams({String? curriculumId}) async {
    try {
      var query = _supabase
          .from('live_streams')
          .select()
          .or('status.eq.archived,status.eq.ended');
      if (curriculumId != null) query = query.eq('curriculum_id', curriculumId);
      final response = await query.order('created_at', ascending: false);
      return (response as List).map((json) => LiveStream.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting archived streams: $e');
      return [];
    }
  }

  Future<void> updateViewerCount(String streamId, int count) async {
    try {
      final stream = await getStream(streamId);
      if (stream == null) return;
      final peakViewers = count > stream.peakViewers ? count : stream.peakViewers;
      await _supabase.from('live_streams').update({
        'viewer_count': count,
        'peak_viewers': peakViewers,
      }).eq('id', streamId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating viewer count: $e');
    }
  }

  Future<void> incrementTotalViews(String streamId) async {
    try {
      await _supabase.rpc('increment_stream_views', params: {'stream_id': streamId});
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<bool> deleteStream(String streamId) async {
    try {
      final stream = await getStream(streamId);
      if (stream == null) return false;

      if (stream.videoId != null) {
        await deleteCloudflareLiveInput(stream.videoId!);
      }

      await _supabase.from('live_streams').delete().eq('id', streamId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting stream: $e');
      return false;
    }
  }

  // ============================================================================
  // Comments, Reactions, Viewer Count - All use Supabase (already secure)
  // Same implementation as LiveStreamService
  // ============================================================================

  Future<LiveComment?> sendComment({
    required String streamId,
    required String message,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('live_comments')
          .insert({'stream_id': streamId, 'user_id': userId, 'message': message})
          .select()
          .single();

      final profileResponse = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      return LiveComment.fromJson({...response, 'profiles': profileResponse});
    } catch (e) {
      debugPrint('Error sending comment: $e');
      return null;
    }
  }

  Future<List<LiveComment>> getComments(String streamId, {int limit = 50}) async {
    try {
      final commentsResponse = await _supabase
          .from('live_comments')
          .select('*')
          .eq('stream_id', streamId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(limit);

      final comments = commentsResponse as List;
      if (comments.isEmpty) return [];

      final userIds = comments
          .map((c) => c['user_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', userIds);

        for (final profile in profilesResponse as List) {
          profilesMap[profile['id']] = profile;
        }
      }

      return comments.map((json) {
        final userId = json['user_id'] as String?;
        final profile = userId != null ? profilesMap[userId] : null;
        return LiveComment.fromJson({...json, 'profiles': profile});
      }).toList();
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  Future<bool> pinComment(String commentId) async {
    try {
      await _supabase.from('live_comments').update({'is_pinned': true}).eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('Error pinning comment: $e');
      return false;
    }
  }

  Future<bool> unpinComment(String commentId) async {
    try {
      await _supabase.from('live_comments').update({'is_pinned': false}).eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('Error unpinning comment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _supabase.from('live_comments').update({'is_deleted': true}).eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  void subscribeToComments(String streamId, Function(LiveComment) onComment) {
    _commentsChannel?.unsubscribe();
    _commentsChannel = _supabase
        .channel('live_comments:$streamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: streamId,
          ),
          callback: (payload) async {
            try {
              final newRecord = payload.newRecord;
              final userId = newRecord['user_id'] as String?;

              Map<String, dynamic>? userProfile;
              if (userId != null) {
                try {
                  final profileResponse = await _supabase
                      .from('profiles')
                      .select('id, full_name, avatar_url')
                      .eq('id', userId)
                      .maybeSingle();
                  userProfile = profileResponse;
                } catch (e) {
                  debugPrint('Error fetching user profile: $e');
                }
              }

              final comment = LiveComment.fromJson({...newRecord, 'profiles': userProfile});
              onComment(comment);
            } catch (e) {
              debugPrint('Error parsing comment: $e');
            }
          },
        )
        .subscribe();
  }

  void unsubscribeFromComments() {
    _commentsChannel?.unsubscribe();
    _commentsChannel = null;
  }

  Future<LiveReaction?> sendReaction({
    required String streamId,
    required String reactionType,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('live_reactions')
          .upsert({'stream_id': streamId, 'user_id': userId, 'reaction_type': reactionType})
          .select()
          .single();

      return LiveReaction.fromJson(response);
    } catch (e) {
      debugPrint('Error sending reaction: $e');
      return null;
    }
  }

  Future<LiveReactionStats> getReactionStats(String streamId) async {
    try {
      final response = await _supabase.rpc('get_stream_reaction_stats', params: {'stream_id': streamId});
      return LiveReactionStats.fromJson(response);
    } catch (e) {
      debugPrint('Error getting reaction stats: $e');
      return LiveReactionStats(counts: {});
    }
  }

  void subscribeToReactions(String streamId, Function(LiveReactionStats) onReactionUpdate) {
    _reactionsChannel?.unsubscribe();
    _reactionsChannel = _supabase
        .channel('live_reactions:$streamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: streamId,
          ),
          callback: (payload) async {
            final stats = await getReactionStats(streamId);
            onReactionUpdate(stats);
          },
        )
        .subscribe();
  }

  void unsubscribeFromReactions() {
    _reactionsChannel?.unsubscribe();
    _reactionsChannel = null;
  }

  void subscribeToViewerCount(String streamId, Function(int) onViewerCountUpdate) {
    _viewerCountChannel?.unsubscribe();
    _viewerCountChannel = _supabase
        .channel('live_streams:$streamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_streams',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: streamId,
          ),
          callback: (payload) {
            try {
              final viewerCount = payload.newRecord['viewer_count'] as int? ?? 0;
              onViewerCountUpdate(viewerCount);
            } catch (e) {
              debugPrint('Error parsing viewer count: $e');
            }
          },
        )
        .subscribe();
  }

  void unsubscribeFromViewerCount() {
    _viewerCountChannel?.unsubscribe();
    _viewerCountChannel = null;
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  String getRTMPUrl() => 'rtmps://live.cloudflare.com:443/live/';

  String? getStreamKey(LiveStream stream) => stream.streamKey;

  String? getHLSUrl(LiveStream stream) {
    if (stream.hlsUrl != null && stream.hlsUrl!.isNotEmpty) {
      return stream.hlsUrl;
    }
    if (stream.isLive || stream.isScheduled) {
      final videoId = stream.videoId ?? _defaultLiveInputId;
      return 'https://$_cloudflareCustomerSubdomain/$videoId/manifest/video.m3u8';
    }
    if (stream.videoId != null) {
      return 'https://$_cloudflareCustomerSubdomain/${stream.videoId}/manifest/video.m3u8';
    }
    return 'https://$_cloudflareCustomerSubdomain/$_defaultLiveInputId/manifest/video.m3u8';
  }

  String? getThumbnailUrl(LiveStream stream) {
    final videoId = stream.videoId ?? _defaultLiveInputId;
    return 'https://$_cloudflareCustomerSubdomain/$videoId/thumbnails/thumbnail.jpg';
  }

  String? getWhipUrl(LiveStream stream) {
    if (stream.whipUrl != null && stream.whipUrl!.isNotEmpty) {
      return stream.whipUrl;
    }
    return _defaultWhipUrl;
  }

  Future<bool> isStreamLiveOnCloudflare() async {
    try {
      final status = await getCloudflareStreamStatus(_defaultLiveInputId);
      if (status != null) {
        final currentState = status['status']?['current']?['state'];
        return currentState == 'connected';
      }
      return false;
    } catch (e) {
      debugPrint('Error checking live status: $e');
      return false;
    }
  }

  @override
  void dispose() {
    unsubscribeFromComments();
    unsubscribeFromReactions();
    unsubscribeFromViewerCount();
    super.dispose();
  }
}
