/// Curriculum Model
/// Represents an educational curriculum/program in the app
class Curriculum {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameFr;
  final String? description;
  final String? descriptionAr;
  final String? descriptionFr;
  final String? iconUrl;
  final String color;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Contact information fields
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? logoUrl; // SVG only

  Curriculum({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameFr,
    this.description,
    this.descriptionAr,
    this.descriptionFr,
    this.iconUrl,
    this.color = '#4CAF50',
    this.displayOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.phone,
    this.whatsapp,
    this.email,
    this.logoUrl,
  });

  /// Get localized name based on locale
  String getLocalizedName(String locale) {
    switch (locale) {
      case 'ar':
        return nameAr ?? name;
      case 'fr':
        return nameFr ?? name;
      default:
        return name;
    }
  }

  /// Get localized description based on locale
  String? getLocalizedDescription(String locale) {
    switch (locale) {
      case 'ar':
        return descriptionAr ?? description;
      case 'fr':
        return descriptionFr ?? description;
      default:
        return description;
    }
  }

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    return Curriculum(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
      nameFr: json['name_fr'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      descriptionFr: json['description_fr'] as String?,
      iconUrl: json['icon_url'] as String?,
      color: json['color'] as String? ?? '#4CAF50',
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'description': description,
      'description_ar': descriptionAr,
      'description_fr': descriptionFr,
      'icon_url': iconUrl,
      'color': color,
      'display_order': displayOrder,
      'is_active': isActive,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'logo_url': logoUrl,
    };
  }

  Curriculum copyWith({
    String? id,
    String? name,
    String? nameAr,
    String? nameFr,
    String? description,
    String? descriptionAr,
    String? descriptionFr,
    String? iconUrl,
    String? color,
    int? displayOrder,
    bool? isActive,
    String? phone,
    String? whatsapp,
    String? email,
    String? logoUrl,
  }) {
    return Curriculum(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      nameFr: nameFr ?? this.nameFr,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionFr: descriptionFr ?? this.descriptionFr,
      iconUrl: iconUrl ?? this.iconUrl,
      color: color ?? this.color,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }

  @override
  String toString() {
    return 'Curriculum(id: $id, name: $name, nameAr: $nameAr)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Curriculum && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
