import 'package:flutter/material.dart';

/// App Colors - Light Theme (Clean & Professional)
/// نظام الألوان الجديد: أبيض طاغي + أزرق + برتقالي
///
/// Color Distribution:
/// - 60% White/Light Gray (Backgrounds, Cards)
/// - 30% Blue (Primary actions, Headers)
/// - 10% Orange (Accent, CTAs)

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════
  // الخلفيات والأسطح (60% - الأبيض والرمادي الفاتح)
  // ═══════════════════════════════════════════════════════

  /// خلفية التطبيق الرئيسية - أبيض مائل للرمادي
  static const Color background = Color(0xFFF8FAFC);

  /// خلفية بديلة أفتح
  static const Color backgroundLight = Color(0xFFFFFFFF);

  /// خلفية البطاقات - أبيض نقي
  static const Color cardBackground = Color(0xFFFFFFFF);

  /// سطح للتباين الخفيف
  static const Color surface = Color(0xFFF1F5F9);

  /// سطح داكن قليلاً للفصل البصري
  static const Color surfaceVariant = Color(0xFFE2E8F0);

  // ═══════════════════════════════════════════════════════
  // الأزرق الأساسي (30%)
  // ═══════════════════════════════════════════════════════

  /// الأزرق الأساسي - للأزرار والعناصر الرئيسية
  static const Color primary = Color(0xFF2563EB);

  /// الأزرق الداكن - للـ AppBar والتركيز
  static const Color primaryDark = Color(0xFF1D4ED8);

  /// الأزرق الفاتح - للـ hover والخلفيات الخفيفة
  static const Color primaryLight = Color(0xFF3B82F6);

  /// الأزرق الفاتح جداً - للخلفيات
  static const Color primarySurface = Color(0xFFEFF6FF);

  /// الأزرق الشفاف - للتحديد
  static const Color primaryOverlay = Color(0x1A2563EB);

  // ═══════════════════════════════════════════════════════
  // البرتقالي للتمييز (10%)
  // ═══════════════════════════════════════════════════════

  /// البرتقالي الأساسي - للـ CTAs والتنبيهات المهمة
  static const Color accent = Color(0xFFF97316);

  /// البرتقالي الفاتح
  static const Color accentLight = Color(0xFFFB923C);

  /// البرتقالي الداكن
  static const Color accentDark = Color(0xFFEA580C);

  /// البرتقالي الفاتح جداً - للخلفيات
  static const Color accentSurface = Color(0xFFFFF7ED);

  // ═══════════════════════════════════════════════════════
  // ألوان النصوص
  // ═══════════════════════════════════════════════════════

  /// النص الأساسي - رمادي داكن جداً (ليس أسود نقي)
  static const Color textPrimary = Color(0xFF1F2937);

  /// النص الثانوي - رمادي متوسط
  static const Color textSecondary = Color(0xFF6B7280);

  /// النص الخافت - رمادي فاتح
  static const Color textMuted = Color(0xFF9CA3AF);

  /// النص على الخلفيات الملونة
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// النص على الخلفيات الداكنة
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ═══════════════════════════════════════════════════════
  // الحدود والفواصل
  // ═══════════════════════════════════════════════════════

  /// حدود خفيفة للبطاقات
  static const Color border = Color(0xFFE5E7EB);

  /// حدود أغمق للتركيز
  static const Color borderDark = Color(0xFFD1D5DB);

  /// فواصل خفيفة
  static const Color divider = Color(0xFFF3F4F6);

  // ═══════════════════════════════════════════════════════
  // ألوان الحالة
  // ═══════════════════════════════════════════════════════

  /// أخضر للنجاح
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);
  static const Color successSurface = Color(0xFFECFDF5);

  /// أحمر للخطأ
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEF2F2);

  /// أصفر للتحذير
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFFFBEB);

  /// أزرق للمعلومات
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ═══════════════════════════════════════════════════════
  // ظلال
  // ═══════════════════════════════════════════════════════

  /// لون الظل الأساسي
  static const Color shadowColor = Color(0x1A000000);

  /// ظل خفيف
  static const Color shadowLight = Color(0x0D000000);

  /// ظل متوسط
  static const Color shadowMedium = Color(0x26000000);

  // ═══════════════════════════════════════════════════════
  // ألوان خاصة بالمواد الدراسية
  // ═══════════════════════════════════════════════════════

  static const Color subjectMath = Color(0xFF3B82F6);      // أزرق
  static const Color subjectPhysics = Color(0xFF8B5CF6);   // بنفسجي
  static const Color subjectChemistry = Color(0xFF10B981); // أخضر
  static const Color subjectBiology = Color(0xFF22C55E);   // أخضر فاتح
  static const Color subjectArabic = Color(0xFFF59E0B);    // أصفر
  static const Color subjectFrench = Color(0xFF06B6D4);    // سماوي
  static const Color subjectEnglish = Color(0xFFEC4899);   // وردي
  static const Color subjectHistory = Color(0xFFF97316);   // برتقالي
  static const Color subjectGeography = Color(0xFF14B8A6); // تركوازي
  static const Color subjectPhilosophy = Color(0xFF6366F1);// نيلي
  static const Color subjectIslamic = Color(0xFF059669);   // أخضر داكن

  // ═══════════════════════════════════════════════════════
  // ألوان السنوات الدراسية
  // ═══════════════════════════════════════════════════════

  static const List<Color> gradeColors = [
    Color(0xFF3B82F6), // السنة الأولى - أزرق
    Color(0xFF8B5CF6), // السنة الثانية - بنفسجي
    Color(0xFF10B981), // السنة الثالثة - أخضر
    Color(0xFFF59E0B), // السنة الرابعة - أصفر
    Color(0xFFEC4899), // السنة الخامسة - وردي
    Color(0xFF06B6D4), // السنة السادسة - سماوي
  ];

  // ═══════════════════════════════════════════════════════
  // Gradients
  // ═══════════════════════════════════════════════════════

  /// تدرج أزرق للـ AppBar
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// تدرج برتقالي للأزرار المميزة
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// تدرج خفيف للخلفيات
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ═══════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════

  /// الحصول على لون المادة الدراسية
  static Color getSubjectColor(String subjectName) {
    final name = subjectName.toLowerCase();
    if (name.contains('رياض') || name.contains('math')) return subjectMath;
    if (name.contains('فيزي') || name.contains('phys')) return subjectPhysics;
    if (name.contains('كيمي') || name.contains('chim')) return subjectChemistry;
    if (name.contains('أحيا') || name.contains('bio')) return subjectBiology;
    if (name.contains('عرب') || name.contains('arab')) return subjectArabic;
    if (name.contains('فرن') || name.contains('fran')) return subjectFrench;
    if (name.contains('انج') || name.contains('eng')) return subjectEnglish;
    if (name.contains('تاري') || name.contains('hist')) return subjectHistory;
    if (name.contains('جغرا') || name.contains('geo')) return subjectGeography;
    if (name.contains('فلس') || name.contains('phil')) return subjectPhilosophy;
    if (name.contains('إسلا') || name.contains('islam')) return subjectIslamic;
    return primary;
  }

  /// الحصول على لون السنة الدراسية
  static Color getGradeColor(int index) {
    return gradeColors[index % gradeColors.length];
  }
}
