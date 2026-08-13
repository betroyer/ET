class CategoryModel {
  const CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.isDefault = false,
  });

  final int? id;
  final String name;
  final String icon;
  final String type; // expense | income
  final bool isDefault;

  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    String? type,
    bool? isDefault,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'type': type,
        'is_default': isDefault ? 1 : 0,
      };

  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      type: map['type'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }
}
