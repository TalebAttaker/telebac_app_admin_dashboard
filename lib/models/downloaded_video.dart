/// Model for downloaded videos stored locally with encryption
/// نموذج الفيديوهات المحملة والمشفرة محلياً
class DownloadedVideo {
  final String id; // video_id from Supabase
  final String lessonId;
  final String lessonTitle;
  final String bunnyVideoId;
  final String quality; // 360p, 480p, 720p, 1080p
  final String localPath; // Encrypted video file path
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final int durationSeconds;

  // Hierarchy for organization
  final String gradeId;
  final String subjectId;
  final String chapterId;
  final String topicId;
  final String gradeName;
  final String subjectName;
  final String chapterName;
  final String topicName;

  // معلومات الاشتراك وقت التحميل (للتوافق مع الإصدارات القديمة - اختيارية)
  // Subscription info at download time (optional for backward compatibility)
  final DateTime? subscriptionEndDateAtDownload;
  final String? subscriptionPlanId;
  final String? userId;

  DownloadedVideo({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.bunnyVideoId,
    required this.quality,
    required this.localPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.durationSeconds,
    required this.gradeId,
    required this.subjectId,
    required this.chapterId,
    required this.topicId,
    required this.gradeName,
    required this.subjectName,
    required this.chapterName,
    required this.topicName,
    // حقول جديدة اختيارية
    this.subscriptionEndDateAtDownload,
    this.subscriptionPlanId,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'lesson_title': lessonTitle,
      'bunny_video_id': bunnyVideoId,
      'quality': quality,
      'local_path': localPath,
      'file_size_bytes': fileSizeBytes,
      'downloaded_at': downloadedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'chapter_id': chapterId,
      'topic_id': topicId,
      'grade_name': gradeName,
      'subject_name': subjectName,
      'chapter_name': chapterName,
      'topic_name': topicName,
      // حقول جديدة
      'subscription_end_date_at_download':
          subscriptionEndDateAtDownload?.toIso8601String(),
      'subscription_plan_id': subscriptionPlanId,
      'user_id': userId,
    };
  }

  factory DownloadedVideo.fromJson(Map<String, dynamic> json) {
    return DownloadedVideo(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      lessonTitle: json['lesson_title'] as String,
      bunnyVideoId: json['bunny_video_id'] as String,
      quality: json['quality'] as String,
      localPath: json['local_path'] as String,
      fileSizeBytes: json['file_size_bytes'] as int,
      downloadedAt: DateTime.parse(json['downloaded_at'] as String),
      durationSeconds: json['duration_seconds'] as int,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      chapterId: json['chapter_id'] as String,
      topicId: json['topic_id'] as String,
      gradeName: json['grade_name'] as String,
      subjectName: json['subject_name'] as String,
      chapterName: json['chapter_name'] as String,
      topicName: json['topic_name'] as String,
      // حقول جديدة (اختيارية للتوافق مع البيانات القديمة)
      subscriptionEndDateAtDownload:
          json['subscription_end_date_at_download'] != null
              ? DateTime.parse(json['subscription_end_date_at_download'])
              : null,
      subscriptionPlanId: json['subscription_plan_id'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  /// نسخ مع تعديل (لتحديث الحقول)
  DownloadedVideo copyWith({
    String? id,
    String? lessonId,
    String? lessonTitle,
    String? bunnyVideoId,
    String? quality,
    String? localPath,
    int? fileSizeBytes,
    DateTime? downloadedAt,
    int? durationSeconds,
    String? gradeId,
    String? subjectId,
    String? chapterId,
    String? topicId,
    String? gradeName,
    String? subjectName,
    String? chapterName,
    String? topicName,
    DateTime? subscriptionEndDateAtDownload,
    String? subscriptionPlanId,
    String? userId,
  }) {
    return DownloadedVideo(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      bunnyVideoId: bunnyVideoId ?? this.bunnyVideoId,
      quality: quality ?? this.quality,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      gradeId: gradeId ?? this.gradeId,
      subjectId: subjectId ?? this.subjectId,
      chapterId: chapterId ?? this.chapterId,
      topicId: topicId ?? this.topicId,
      gradeName: gradeName ?? this.gradeName,
      subjectName: subjectName ?? this.subjectName,
      chapterName: chapterName ?? this.chapterName,
      topicName: topicName ?? this.topicName,
      subscriptionEndDateAtDownload:
          subscriptionEndDateAtDownload ?? this.subscriptionEndDateAtDownload,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      userId: userId ?? this.userId,
    );
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Get thumbnail URL from BunnyCDN
  String get thumbnailUrl {
    const pullZoneUrl = 'https://vz-538dcb17-d29.b-cdn.net';
    return '$pullZoneUrl/$bunnyVideoId/thumbnail.jpg';
  }
}
