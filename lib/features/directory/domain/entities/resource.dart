class Resource {
  final String id;
  final String title;
  final String typeId; // Changed from ResourceType enum
  final String url;
  final String categoryId; // Changed from ResourceCategory enum
  final DateTime createdAt;
  final String? description;

  const Resource({
    required this.id,
    required this.title,
    required this.typeId,
    required this.url,
    required this.categoryId,
    required this.createdAt,
    this.description,
  });

  Resource copyWith({
    String? id,
    String? title,
    String? typeId,
    String? url,
    String? categoryId,
    DateTime? createdAt,
    String? description,
  }) {
    return Resource(
      id: id ?? this.id,
      title: title ?? this.title,
      typeId: typeId ?? this.typeId,
      url: url ?? this.url,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': typeId,
      'url': url,
      'category': categoryId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'description': description,
    };
  }

  factory Resource.fromMap(Map<String, dynamic> map, String id) {
    // Migration logic for old Enum values stored as strings
    var type = map['type'] ?? 'other';
    // If it was stored as "ResourceType.link" or just "link" (enum.name)
    // The defaults in FarmConfig match the old enum names: 'link', 'pdf', 'excel', 'image', 'other'

    var category = map['category'] ?? 'other';
    // Defaults: 'admin', 'technical', 'events', 'materials', 'other'

    return Resource(
      id: id,
      title: map['title'] ?? '',
      typeId: type,
      url: map['url'] ?? '',
      categoryId: category,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      description: map['description'],
    );
  }
}
