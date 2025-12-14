import 'package:flutter/material.dart';

/// نموذج الشعبة/التخصص
/// Specialization model for different study streams
class Specialization {
  final String id;
  final String gradeId;
  final String name;
  final String nameAr;
  final String? nameFr;
  final String iconName;
  final String colorHex;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;

  Specialization({
    required this.id,
    required this.gradeId,
    required this.name,
    required this.nameAr,
    this.nameFr,
    this.iconName = 'school',
    this.colorHex = '#3B82F6',
    required this.displayOrder,
    this.isActive = true,
    required this.createdAt,
  });

  factory Specialization.fromJson(Map<String, dynamic> json) {
    return Specialization(
      id: json['id'],
      gradeId: json['grade_id'],
      name: json['name'],
      nameAr: json['name_ar'],
      nameFr: json['name_fr'],
      iconName: json['icon_name'] ?? 'school',
      colorHex: json['color_hex'] ?? '#3B82F6',
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade_id': gradeId,
      'name': name,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'icon_name': iconName,
      'color_hex': colorHex,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// الحصول على اللون من الـ hex
  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  /// الحصول على الأيقونة المناسبة
  IconData get icon {
    switch (iconName) {
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'biotech':
        return Icons.biotech_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'history_edu':
        return Icons.history_edu_rounded;
      case 'architecture':
        return Icons.architecture_rounded;
      case 'engineering':
        return Icons.engineering_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  /// الحصول على الاسم المعروض (عربي أولاً)
  String get displayName => nameAr.isNotEmpty ? nameAr : name;
}
