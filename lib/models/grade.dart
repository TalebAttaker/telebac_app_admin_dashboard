class Grade {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameFr;
  final int displayOrder;
  final String? iconUrl;
  final bool isActive;
  final DateTime createdAt;

  Grade({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameFr,
    required this.displayOrder,
    this.iconUrl,
    required this.isActive,
    required this.createdAt,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'],
      name: json['name'],
      nameAr: json['name_ar'],
      nameFr: json['name_fr'],
      displayOrder: json['display_order'],
      iconUrl: json['icon_url'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'display_order': displayOrder,
      'icon_url': iconUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
