/// Subscription Plan Model
/// Represents a subscription plan with pricing and features

class SubscriptionPlan {
  final String id;
  final String nameAr;
  final String nameFr;
  final String? descriptionAr;
  final String? descriptionFr;
  final double price;
  final String durationType; // 'monthly' or 'annual'
  final int durationMonths;
  final String? gradeId;
  final String? specializationId; // التخصص المرتبط (مثل Bac O أو Bac A)
  final String? curriculumId; // المنهج الدراسي المرتبط
  final Map<String, dynamic>? curricula; // بيانات المنهج المتداخلة من Supabase
  final List<String> features;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;

  SubscriptionPlan({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    this.descriptionAr,
    this.descriptionFr,
    required this.price,
    required this.durationType,
    required this.durationMonths,
    this.gradeId,
    this.specializationId,
    this.curriculumId,
    this.curricula,
    required this.features,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      nameAr: json['name_ar'],
      nameFr: json['name_fr'],
      descriptionAr: json['description_ar'],
      descriptionFr: json['description_fr'],
      price: (json['price_ouguiya'] != null)
          ? double.parse(json['price_ouguiya'].toString())
          : (json['price'] as num).toDouble(),
      durationType: json['duration_type'],
      durationMonths: json['duration_months'] ??
          (json['duration_type'] == 'monthly' ? 1 : 12),
      gradeId: json['grade_id'],
      specializationId: json['specialization_id'],
      curriculumId: json['curriculum_id'],
      curricula: json['curricula'] as Map<String, dynamic>?,
      features: List<String>.from(json['features'] ?? []),
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// Get curriculum name based on locale
  String getCurriculumName({String locale = 'ar'}) {
    if (curricula == null) return 'غير محدد';
    if (locale == 'ar' && curricula!['name_ar'] != null) {
      return curricula!['name_ar'];
    } else if (locale == 'fr' && curricula!['name_fr'] != null) {
      return curricula!['name_fr'];
    }
    return curricula!['name'] ?? 'غير محدد';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'description_ar': descriptionAr,
      'description_fr': descriptionFr,
      'price': price,
      'duration_type': durationType,
      'duration_months': durationMonths,
      'grade_id': gradeId,
      'specialization_id': specializationId,
      'curriculum_id': curriculumId,
      'features': features,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Display name based on current locale
  String getDisplayName(String locale) {
    return locale == 'ar' ? nameAr : nameFr;
  }

  // Display description based on current locale
  String? getDisplayDescription(String locale) {
    return locale == 'ar' ? descriptionAr : descriptionFr;
  }

  // Calculate monthly price
  double get monthlyPrice => price / durationMonths;

  // Get savings percentage compared to monthly
  double getSavingsPercentage(double monthlyPrice) {
    if (durationMonths == 1) return 0;
    final totalMonthlyPrice = monthlyPrice * durationMonths;
    return ((totalMonthlyPrice - price) / totalMonthlyPrice * 100);
  }
}
