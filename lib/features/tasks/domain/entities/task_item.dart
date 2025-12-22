class TaskItem {
  final String description;
  final double quantity;
  final bool isDone;

  TaskItem({
    required this.description,
    this.quantity = 1.0,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {'description': description, 'quantity': quantity, 'isDone': isDone};
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] ?? 1.0).toDouble(),
      isDone: map['isDone'] ?? false,
    );
  }

  TaskItem copyWith({String? description, double? quantity, bool? isDone}) {
    return TaskItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      isDone: isDone ?? this.isDone,
    );
  }
}
