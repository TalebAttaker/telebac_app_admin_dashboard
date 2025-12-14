class Subject {
  final String id;
  final String gradeId;
  final String name;
  final String? nameAr;
  final String? nameFr;
  final String? description;
  final String? iconUrl;
  final String? coverImageUrl;
  final int displayOrder;
  final bool isActive;

  Subject({
    required this.id,
    required this.gradeId,
    required this.name,
    this.nameAr,
    this.nameFr,
    this.description,
    this.iconUrl,
    this.coverImageUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'],
      gradeId: json['grade_id'],
      name: json['name'],
      nameAr: json['name_ar'],
      nameFr: json['name_fr'],
      description: json['description'],
      iconUrl: json['icon_url'],
      coverImageUrl: json['cover_image_url'],
      displayOrder: json['display_order'],
      isActive: json['is_active'] ?? true,
    );
  }
}
