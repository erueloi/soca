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
    );
  }
}
