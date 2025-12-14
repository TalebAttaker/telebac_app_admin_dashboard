/// Wilaya Model
/// Represents a Mauritanian state/region

class Wilaya {
  final String id;
  final String nameAr;
  final String nameFr;
  final String code;
  final int displayOrder;
  final DateTime createdAt;

  Wilaya({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.code,
    required this.displayOrder,
    required this.createdAt,
  });

  factory Wilaya.fromJson(Map<String, dynamic> json) {
    return Wilaya(
      id: json['id'],
      nameAr: json['name_ar'],
      nameFr: json['name_fr'],
      code: json['code'],
      displayOrder: json['display_order'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'code': code,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Display name based on current locale
  String getDisplayName(String locale) {
    return locale == 'ar' ? nameAr : nameFr;
  }
}
