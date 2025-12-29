class Bucket {
  final String name;
  final bool isArchived;
  final bool showOnDashboard;

  const Bucket({
    required this.name,
    this.isArchived = false,
    this.showOnDashboard = false,
  });

  Bucket copyWith({String? name, bool? isArchived, bool? showOnDashboard}) {
    return Bucket(
      name: name ?? this.name,
      isArchived: isArchived ?? this.isArchived,
      showOnDashboard: showOnDashboard ?? this.showOnDashboard,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isArchived': isArchived,
      'showOnDashboard': showOnDashboard,
    };
  }

  factory Bucket.fromMap(Map<String, dynamic> map) {
    return Bucket(
      name: map['name'] ?? '',
      isArchived: map['isArchived'] ?? false,
      showOnDashboard: map['showOnDashboard'] ?? false,
    );
  }
}
