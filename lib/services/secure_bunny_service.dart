import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'web_upload_service.dart' if (dart.library.io) 'web_upload_helper_stub.dart';

/// Secure BunnyCDN Service
/// Uses Edge Function to handle all BunnyCDN operations
/// API keys are stored securely in Edge Function, NOT in the app
class SecureBunnyService extends ChangeNotifier {
  static const String _edgeFunctionUrl = '${SupabaseConfig.functionsUrl}/bunny-admin';

  // Pull Zone URL is public and safe to expose
  static const String _pullZoneUrl = 'https://vz-538dcb17-d29.b-cdn.net';

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if service is configured (always true for Edge Function-based service)
  static bool get isConfigured => true;

  /// Get authorization header from current session
  Map<String, String> _getAuthHeaders() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('User not authenticated');
    }
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  /// Create a new video entry in BunnyCDN (Admin only)
  Future<String?> createVideo({
    required String title,
    String? collectionId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'create_video',
          'title': title,
          if (collectionId != null) 'collectionId': collectionId,
        }),
      );

      debugPrint('[BUNNY] Create video response status: ${response.statusCode}');
      debugPrint('[BUNNY] Create video response body: ${response.body}');

      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        _error = data['error'] ?? 'Failed to create video (${response.statusCode})';
        debugPrint('[BUNNY] Error creating video: $_error');
        return null;
      }

      final data = json.decode(response.body);
      if (data['success'] == true && data['videoId'] != null) {
        debugPrint('[BUNNY] Video created successfully: ${data['videoId']}');
        return data['videoId'] as String;
      } else {
        _error = data['error'] ?? 'Failed to create video - no videoId returned';
        debugPrint('[BUNNY] Error: $_error');
        return null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating video: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get upload URL and auth key for video upload (Admin only)
  Future<Map<String, dynamic>?> getUploadCredentials(String videoId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'get_upload_url',
          'videoId': videoId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'uploadUrl': data['uploadUrl'],
          'authKey': data['authKey'],
          'libraryId': data['libraryId'],
        };
      } else {
        _error = data['error'] ?? 'Failed to get upload credentials';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error getting upload credentials: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a video from BunnyCDN (Admin only)
  Future<bool> deleteVideo(String videoId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'delete_video',
          'videoId': videoId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        _error = data['error'] ?? 'Failed to delete video';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting video: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get video information from BunnyCDN (Admin only)
  Future<Map<String, dynamic>?> getVideoInfo(String videoId) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'get_video_info',
          'videoId': videoId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>?;
      } else {
        _error = data['error'] ?? 'Failed to get video info';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error getting video info: $e');
      return null;
    }
  }

  /// List all collections (Admin only)
  Future<List<Map<String, dynamic>>> listCollections() async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'list_collections',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['collections'] ?? []);
      } else {
        _error = data['error'] ?? 'Failed to list collections';
        return [];
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error listing collections: $e');
      return [];
    }
  }

  /// Create a new collection (Admin only)
  Future<String?> createCollection(String name) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: _getAuthHeaders(),
        body: json.encode({
          'action': 'create_collection',
          'name': name,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['collectionId'] as String?;
      } else {
        _error = data['error'] ?? 'Failed to create collection';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating collection: $e');
      return null;
    }
  }

  /// Get or create collection with hierarchical name (Admin only)
  Future<String?> getOrCreateCollection({
    required String gradeName,
    required String subjectName,
    required String topicName,
  }) async {
    final collectionName = '$gradeName › $subjectName › $topicName';

    // First check existing collections
    final collections = await listCollections();
    for (var collection in collections) {
      if (collection['name'] == collectionName) {
        return collection['guid'] as String?;
      }
    }

    // Create new collection if not found
    return await createCollection(collectionName);
  }

  // ============================================================================
  // Public URLs (safe to use without Edge Function)
  // ============================================================================

  /// Get video playback URL (public - no API key needed)
  String getVideoPlaybackUrl(String videoId) {
    return '$_pullZoneUrl/$videoId/playlist.m3u8';
  }

  /// Get video thumbnail URL (public - no API key needed)
  String getVideoThumbnailUrl(String videoId) {
    return '$_pullZoneUrl/$videoId/thumbnail.jpg';
  }

  /// Get video stream URL for specific quality (public - no API key needed)
  String getVideoStreamUrl(String videoId, String quality) {
    return '$_pullZoneUrl/$videoId/$quality/video.m3u8';
  }

  /// Get direct MP4 URL for specific quality (public - for downloads)
  String getVideoMp4Url(String videoId, String quality) {
    return '$_pullZoneUrl/$videoId/$quality.mp4';
  }

  /// Upload video from bytes (Admin only)
  /// This method handles the complete upload flow:
  /// 1. Creates video entry
  /// 2. Gets upload credentials
  /// 3. Uploads the file
  Future<String?> uploadVideoFromBytes({
    required List<int> videoBytes,
    required String fileName,
    required String title,
    String? curriculumName,
    String? gradeName,
    String? subjectName,
    String? topicName,
    Function(double)? onProgress,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Step 1: Get or create collection if hierarchy provided
      String? collectionId;
      if (curriculumName != null && gradeName != null && subjectName != null && topicName != null) {
        collectionId = await getOrCreateCollection(
          gradeName: gradeName,
          subjectName: subjectName,
          topicName: topicName,
        );
      }

      // Step 2: Create video entry
      debugPrint('[BUNNY] Creating video entry...');
      final videoId = await createVideo(
        title: title,
        collectionId: collectionId,
      );

      if (videoId == null || videoId.isEmpty) {
        final errorMsg = _error ?? 'Failed to create video entry - no ID returned';
        debugPrint('[BUNNY] $errorMsg');
        throw Exception(errorMsg);
      }

      debugPrint('[BUNNY] Video entry created with ID: $videoId');

      // Step 3: Get upload credentials
      debugPrint('[BUNNY] Getting upload credentials...');
      final credentials = await getUploadCredentials(videoId);
      if (credentials == null) {
        final errorMsg = _error ?? 'Failed to get upload credentials';
        debugPrint('[BUNNY] $errorMsg');
        await deleteVideo(videoId); // Clean up
        throw Exception(errorMsg);
      }

      // Step 4: Upload the file
      final uploadUrl = credentials['uploadUrl'] as String;
      final authKey = credentials['authKey'] as String;

      debugPrint('[BUNNY] Uploading video to BunnyCDN...');
      debugPrint('[BUNNY] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      debugPrint('[BUNNY] File size: ${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

      if (kIsWeb && videoBytes.length > 10 * 1024 * 1024) {
        // Web platform with large files (>10MB): Use WebUploadService with HTML File object
        debugPrint('[BUNNY] Large file detected on web - attempting HTML File upload');

        try {
          // Try to get HTML File from file picker
          final htmlFile = WebUploadService.getHtmlFileFromPicker();

          if (htmlFile != null) {
            debugPrint('[BUNNY] Using WebUploadService for large file upload');
            await WebUploadService.uploadLargeFile(
              file: htmlFile,
              uploadUrl: uploadUrl,
              headers: {
                'AccessKey': authKey,
                'Content-Type': 'application/octet-stream',
              },
              onProgress: onProgress,
            );
            debugPrint('[BUNNY] Web upload completed successfully');
          } else {
            debugPrint('[BUNNY] HTML File not found, falling back to standard upload');
            throw Exception('Cannot upload large files without HTML File object');
          }
        } catch (e) {
          debugPrint('[BUNNY] Web upload error: $e');
          _error = e.toString();
          await deleteVideo(videoId); // Clean up
          throw Exception('Large file upload failed: $e');
        }
      } else {
        // Standard upload for mobile or small web files
        debugPrint('[BUNNY] Using standard http.put upload');
        final response = await http.put(
          Uri.parse(uploadUrl),
          headers: {
            'AccessKey': authKey,
            'Content-Type': 'application/octet-stream',
          },
          body: videoBytes,
        );

        debugPrint('[BUNNY] Upload response status: ${response.statusCode}');

        if (response.statusCode != 200 && response.statusCode != 201) {
          final errorMsg = 'Upload failed with status ${response.statusCode}: ${response.body}';
          debugPrint('[BUNNY] $errorMsg');
          _error = errorMsg;
          await deleteVideo(videoId); // Clean up
          throw Exception(errorMsg);
        }
      }

      debugPrint('[BUNNY] Video uploaded successfully: $videoId');
      return videoId;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error uploading video: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload video from file (Admin only - Mobile/Desktop)
  /// This is a convenience wrapper around uploadVideoFromBytes for File objects
  Future<String?> uploadVideo({
    required File videoFile,
    required String title,
    String? curriculumName,
    String? gradeName,
    String? subjectName,
    String? topicName,
    Function(double)? onProgress,
  }) async {
    try {
      // Read file bytes
      final bytes = await videoFile.readAsBytes();
      final fileName = videoFile.path.split('/').last;

      // Use uploadVideoFromBytes
      return await uploadVideoFromBytes(
        videoBytes: bytes,
        fileName: fileName,
        title: title,
        curriculumName: curriculumName,
        gradeName: gradeName,
        subjectName: subjectName,
        topicName: topicName,
        onProgress: onProgress,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('Error uploading video from file: $e');
      return null;
    }
  }
}
