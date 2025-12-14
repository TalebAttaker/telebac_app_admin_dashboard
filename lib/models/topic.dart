class Topic {
  final String id;
  final String subjectId;
  final String name;
  final String? nameAr;
  final String? nameFr;
  final String? description;
  final int displayOrder;
  final bool isActive;

  Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    this.nameAr,
    this.nameFr,
    this.description,
    required this.displayOrder,
    required this.isActive,
  });

  // Getter for title (alias for name)
  String get title => name;

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'],
      subjectId: json['subject_id'],
      name: json['name'],
      nameAr: json['name_ar'],
      nameFr: json['name_fr'],
      description: json['description'],
      displayOrder: json['display_order'],
      isActive: json['is_active'] ?? true,
    );
  }
}
