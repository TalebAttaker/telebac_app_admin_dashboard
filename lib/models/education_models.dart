import 'package:flutter/material.dart';

/// Represents an academic year/grade level
class AcademicYear {
  final String id;
  final String nameAr;
  final String nameFr;
  final IconData icon;
  final int order;
  final bool hasBaccalaureate;

  AcademicYear({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.icon,
    required this.order,
    this.hasBaccalaureate = false,
  });
}

/// Represents a Baccalaureate specialization (D, C, A)
class Specialization {
  final String id;
  final String nameAr;
  final String nameFr;
  final String code; // D, C, or A
  final Color color;
  final IconData icon;
  final String descriptionAr;

  Specialization({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.code,
    required this.color,
    required this.icon,
    required this.descriptionAr,
  });
}

/// Represents a subject/course
class Subject {
  final String id;
  final String nameAr;
  final String nameFr;
  final IconData icon;
  final Color color;
  final String descriptionAr;
  final List<String> applicableToYears; // Which years this subject applies to
  final List<String> applicableToSpecs; // Which specializations (empty = all)

  Subject({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.icon,
    required this.color,
    required this.descriptionAr,
    required this.applicableToYears,
    this.applicableToSpecs = const [],
  });
}

/// Represents a topic/chapter within a subject
class Topic {
  final String id;
  final String subjectId;
  final String nameAr;
  final String nameFr;
  final String descriptionAr;
  final int order;
  final IconData icon;

  Topic({
    required this.id,
    required this.subjectId,
    required this.nameAr,
    required this.nameFr,
    required this.descriptionAr,
    required this.order,
    required this.icon,
  });
}

/// Represents content type (video lessons, exercises, etc.)
/// Note: writtenLessons removed - PDF is now attached directly to video lessons
enum ContentType {
  videoLessons,
  solvedExercises,
  solvedBaccalaureate,
  summaries,
}

extension ContentTypeExtension on ContentType {
  String get nameAr {
    switch (this) {
      case ContentType.videoLessons:
        return 'دروس مرئية';
      case ContentType.solvedExercises:
        return 'تمارين محلولة';
      case ContentType.solvedBaccalaureate:
        return 'باكالوريا محلولة';
      case ContentType.summaries:
        return 'ملخصات';
    }
  }

  String get nameFr {
    switch (this) {
      case ContentType.videoLessons:
        return 'Cours vidéo';
      case ContentType.solvedExercises:
        return 'Exercices résolus';
      case ContentType.solvedBaccalaureate:
        return 'Bac résolu';
      case ContentType.summaries:
        return 'Résumés';
    }
  }

  IconData get icon {
    switch (this) {
      case ContentType.videoLessons:
        return Icons.play_circle_filled;
      case ContentType.solvedExercises:
        return Icons.assignment_turned_in;
      case ContentType.solvedBaccalaureate:
        return Icons.school;
      case ContentType.summaries:
        return Icons.summarize;
    }
  }

  Color get color {
    switch (this) {
      case ContentType.videoLessons:
        return const Color(0xFF3D7AB8); // Lighter Professional Blue
      case ContentType.solvedExercises:
        return const Color(0xFF1E3A5F); // Deep Navy Blue
      case ContentType.solvedBaccalaureate:
        return const Color(0xFFFFA726); // Orange accent (minimal usage)
      case ContentType.summaries:
        return const Color(0xFF5A8BC4); // Sky Blue
    }
  }

  String get descriptionAr {
    switch (this) {
      case ContentType.videoLessons:
        return 'شاهد الدروس بالفيديو مع شرح تفصيلي';
      case ContentType.solvedExercises:
        return 'تمارين محلولة خطوة بخطوة';
      case ContentType.solvedBaccalaureate:
        return 'امتحانات الباكالوريا السابقة مع الحلول';
      case ContentType.summaries:
        return 'ملخصات شاملة للمراجعة السريعة';
    }
  }
}

/// Content item (video, document, etc.)
class ContentItem {
  final String id;
  final String topicId;
  final ContentType type;
  final String titleAr;
  final String titleFr;
  final String? descriptionAr;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? documentUrl;
  final int durationMinutes;
  final bool isPremium;

  ContentItem({
    required this.id,
    required this.topicId,
    required this.type,
    required this.titleAr,
    required this.titleFr,
    this.descriptionAr,
    this.thumbnailUrl,
    this.videoUrl,
    this.documentUrl,
    this.durationMinutes = 0,
    this.isPremium = false,
  });
}
