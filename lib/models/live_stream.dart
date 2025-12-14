/// Live Stream Model
/// Represents a live streaming session

class LiveStream {
  final String id;
  final String titleAr;
  final String titleFr;
  final String? descriptionAr;
  final String? descriptionFr;
  final String? thumbnailUrl;

  // Technical details
  final String? streamKey;
  final String? videoId;
  final String? rtmpUrl;
  final String? hlsUrl;
  final String? whipUrl;

  // Status
  final String status; // scheduled, live, ended, archived

  // Timing
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  // Statistics
  final int viewerCount;
  final int peakViewers;
  final int totalViews;
  final int durationSeconds;

  // Creator
  final String? createdBy;

  // Curriculum - لربط البث بمنهج معين
  final String? curriculumId;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  LiveStream({
    required this.id,
    required this.titleAr,
    required this.titleFr,
    this.descriptionAr,
    this.descriptionFr,
    this.thumbnailUrl,
    this.streamKey,
    this.videoId,
    this.rtmpUrl,
    this.hlsUrl,
    this.whipUrl,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.viewerCount = 0,
    this.peakViewers = 0,
    this.totalViews = 0,
    this.durationSeconds = 0,
    this.createdBy,
    this.curriculumId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      id: json['id'] as String,
      titleAr: (json['title_ar'] as String?) ?? '',
      titleFr: (json['title_fr'] as String?) ?? '',
      descriptionAr: json['description_ar'] as String?,
      descriptionFr: json['description_fr'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      streamKey: json['stream_key'] as String?,
      videoId: json['video_id'] as String?,
      rtmpUrl: json['rtmp_url'] as String?,
      hlsUrl: json['hls_url'] as String?,
      whipUrl: json['whip_url'] as String?,
      status: json['status'] as String,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      viewerCount: json['viewer_count'] as int? ?? 0,
      peakViewers: json['peak_viewers'] as int? ?? 0,
      totalViews: json['total_views'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      createdBy: json['created_by'] as String?,
      curriculumId: json['curriculum_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title_ar': titleAr,
      'title_fr': titleFr,
      'description_ar': descriptionAr,
      'description_fr': descriptionFr,
      'thumbnail_url': thumbnailUrl,
      'stream_key': streamKey,
      'video_id': videoId,
      'rtmp_url': rtmpUrl,
      'hls_url': hlsUrl,
      'whip_url': whipUrl,
      'status': status,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'viewer_count': viewerCount,
      'peak_viewers': peakViewers,
      'total_views': totalViews,
      'duration_seconds': durationSeconds,
      'created_by': createdBy,
      'curriculum_id': curriculumId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  bool get isScheduled => status == 'scheduled';
  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get isArchived => status == 'archived';

  String getTitle(String locale) {
    return locale == 'ar' ? titleAr : titleFr;
  }

  String? getDescription(String locale) {
    return locale == 'ar' ? descriptionAr : descriptionFr;
  }

  String getStatusText(String locale) {
    if (locale == 'ar') {
      switch (status) {
        case 'scheduled':
          return 'مجدول';
        case 'live':
          return 'مباشر الآن';
        case 'ended':
          return 'انتهى';
        case 'archived':
          return 'مؤرشف';
        default:
          return status;
      }
    } else {
      switch (status) {
        case 'scheduled':
          return 'Programmé';
        case 'live':
          return 'En direct';
        case 'ended':
          return 'Terminé';
        case 'archived':
          return 'Archivé';
        default:
          return status;
      }
    }
  }

  String? getDurationFormatted() {
    if (durationSeconds == 0) return null;
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
