class TaskItem {
  final String description;
  final double quantity;
  final double cost;
  final bool isDone;
  final DateTime? completedAt;

  TaskItem({
    required this.description,
    this.quantity = 1.0,
    this.cost = 0.0,
    this.isDone = false,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'cost': cost,
      'isDone': isDone,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      isDone: map['isDone'] ?? false,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }

  TaskItem copyWith({
    String? description,
    double? quantity,
    double? cost,
    bool? isDone,
    DateTime? completedAt,
  }) {
    return TaskItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      cost: cost ?? this.cost,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
