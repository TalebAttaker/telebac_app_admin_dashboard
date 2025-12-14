class Lesson {
  final String id;
  final String topicId;
  final String title;
  final String? titleAr;
  final String? titleFr;
  final String? description;
  final String lessonType;
  final int displayOrder;
  final int? durationMinutes;
  final bool isFree;
  final bool isActive;
  final int viewsCount;
  final List<Video>? videos;
  final String? pdfUrl; // رابط ملف PDF المرفق (اختياري)

  Lesson({
    required this.id,
    required this.topicId,
    required this.title,
    this.titleAr,
    this.titleFr,
    this.description,
    required this.lessonType,
    required this.displayOrder,
    this.durationMinutes,
    required this.isFree,
    required this.isActive,
    required this.viewsCount,
    this.videos,
    this.pdfUrl,
  });

  // Getter for the primary video (first video in the list)
  Video? get video => videos != null && videos!.isNotEmpty ? videos!.first : null;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      topicId: json['topic_id'],
      title: json['title'],
      titleAr: json['title_ar'],
      titleFr: json['title_fr'],
      description: json['description'],
      lessonType: json['lesson_type'],
      displayOrder: json['display_order'],
      durationMinutes: json['duration_minutes'],
      isFree: json['is_free'] ?? false,
      isActive: json['is_active'] ?? true,
      viewsCount: json['views_count'] ?? 0,
      videos: json['videos'] != null
          ? (json['videos'] as List).map((v) => Video.fromJson(v)).toList()
          : null,
      pdfUrl: json['pdf_url'],
    );
  }
}

class Video {
  final String id;
  final String lessonId;
  final String bunnyVideoId;
  final int durationSeconds;
  final String? thumbnailUrl;
  final String? url360p;
  final String? url480p;
  final String? url720p;
  final String? url1080p;

  Video({
    required this.id,
    required this.lessonId,
    required this.bunnyVideoId,
    required this.durationSeconds,
    this.thumbnailUrl,
    this.url360p,
    this.url480p,
    this.url720p,
    this.url1080p,
  });

  // Getter for duration (returns formatted string)
  String get duration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      lessonId: json['lesson_id'],
      bunnyVideoId: json['bunny_video_id'],
      durationSeconds: json['duration_seconds'],
      thumbnailUrl: json['thumbnail_url'],
      url360p: json['url_360p'],
      url480p: json['url_480p'],
      url720p: json['url_720p'],
      url1080p: json['url_1080p'],
    );
  }
}
