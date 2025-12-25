class Bucket {
  final String name;
  final bool isArchived;

  const Bucket({required this.name, this.isArchived = false});

  Bucket copyWith({String? name, bool? isArchived}) {
    return Bucket(
      name: name ?? this.name,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'isArchived': isArchived};
  }

  factory Bucket.fromMap(Map<String, dynamic> map) {
    return Bucket(
      name: map['name'] ?? '',
      isArchived: map['isArchived'] ?? false,
    );
  }
}
