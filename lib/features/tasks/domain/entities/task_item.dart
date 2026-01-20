class TaskItem {
  final String description;
  final double quantity;
  final double cost; // Budgeted Unit Cost
  final double? realCost; // Actual Unit Cost (if bought)
  final bool isDone;
  final DateTime? completedAt;
  final String categoryId; // References ExpenseCategory.id

  TaskItem({
    required this.description,
    this.quantity = 1.0,
    this.cost = 0.0,
    this.realCost,
    this.isDone = false,
    this.completedAt,
    this.categoryId = 'material', // Default to material
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'cost': cost,
      'realCost': realCost,
      'isDone': isDone,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'category': categoryId, // Stored as string now
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    // Migration Logic: handle old int based categories
    String catId = 'material';
    final rawCat = map['category'];
    if (rawCat is int) {
      // Map old indices to new IDs
      const indexToId = ['material', 'eina', 'servei', 'altres'];
      if (rawCat >= 0 && rawCat < indexToId.length) {
        catId = indexToId[rawCat];
      }
    } else if (rawCat is String) {
      catId = rawCat;
    }

    return TaskItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      realCost: (map['realCost'] as num?)?.toDouble(),
      isDone: map['isDone'] ?? false,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      categoryId: catId,
    );
  }

  TaskItem copyWith({
    String? description,
    double? quantity,
    double? cost,
    double? realCost,
    bool? isDone,
    DateTime? completedAt,
    String? categoryId,
  }) {
    return TaskItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      cost: cost ?? this.cost,
      realCost: realCost ?? this.realCost,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt ?? this.completedAt,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
