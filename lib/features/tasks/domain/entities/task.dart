import 'task_item.dart';

class Task {
  final String id;
  final String title;
  final String bucket;
  final String description;
  final String phase;
  final bool isDone;
  final List<TaskItem> items;
  final List<String> contactIds;
  final DateTime? dueDate;
  final List<String> photoUrls;
  final double? latitude;
  final double? longitude;
  final int order;
  final DateTime? completedAt;
  final String? resolution;
  final String? fincaId;

  const Task({
    required this.id,
    required this.title,
    required this.bucket,
    this.description = '',
    this.phase = '',
    this.isDone = false,
    this.items = const [],
    this.contactIds = const [],
    this.dueDate,
    this.photoUrls = const [],
    this.latitude,
    this.longitude,
    this.order = 0,
    this.completedAt,
    this.resolution,
    this.fincaId,
  });

  Task copyWith({
    String? id,
    String? title,
    String? bucket,
    String? description,
    String? phase,
    bool? isDone,
    List<TaskItem>? items,
    List<String>? contactIds,
    DateTime? dueDate,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
    int? order,
    DateTime? completedAt,
    String? resolution,
    String? fincaId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      bucket: bucket ?? this.bucket,
      description: description ?? this.description,
      phase: phase ?? this.phase,
      isDone: isDone ?? this.isDone,
      items: items ?? this.items,
      contactIds: contactIds ?? this.contactIds,
      dueDate: dueDate ?? this.dueDate,
      photoUrls: photoUrls ?? this.photoUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      order: order ?? this.order,
      completedAt: completedAt ?? this.completedAt,
      resolution: resolution ?? this.resolution,
      fincaId: fincaId ?? this.fincaId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'bucket': bucket,
      'description': description,
      'phase': phase,
      'isDone': isDone,
      'items': items.map((x) => x.toMap()).toList(),
      'contactIds': contactIds,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'photoUrls': photoUrls,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'resolution': resolution,
      'fincaId': fincaId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      title: map['title'] ?? '',
      bucket: map['bucket'] ?? '',
      description: map['description'] ?? '',
      phase: map['phase'] ?? '',
      isDone: map['isDone'] ?? false,
      items: List<TaskItem>.from(
        (map['items'] ?? []).map((x) => TaskItem.fromMap(x)),
      ),
      contactIds: List<String>.from(map['contactIds'] ?? []),
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
          : null,
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      latitude: map['latitude'],
      longitude: map['longitude'],
      order: map['order'] ?? 0,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      resolution: map['resolution'],
      fincaId: map['fincaId'],
    );
  }

  // Calculated properties
  double get totalBudget =>
      items.fold(0.0, (sum, item) => sum + (item.cost * item.quantity));

  double get totalSpent {
    if (isDone) return totalBudget;
    return items
        .where((i) => i.isDone)
        .fold(0.0, (sum, item) => sum + (item.cost * item.quantity));
  }
}
