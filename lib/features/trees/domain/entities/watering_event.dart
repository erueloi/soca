import 'package:cloud_firestore/cloud_firestore.dart';

class WateringEvent {
  final String id;
  final DateTime date;
  final double liters;
  final String? note;
  final String? treeId;

  const WateringEvent({
    required this.id,
    required this.date,
    required this.liters,
    this.note,
    this.treeId,
  });

  WateringEvent copyWith({
    String? id,
    DateTime? date,
    double? liters,
    String? note,
    String? treeId,
  }) {
    return WateringEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      liters: liters ?? this.liters,
      note: note ?? this.note,
      treeId: treeId ?? this.treeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'liters': liters,
      'note': note,
      if (treeId != null) 'treeId': treeId,
    };
  }

  factory WateringEvent.fromMap(Map<String, dynamic> map, String id) {
    return WateringEvent(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      liters: (map['liters'] as num).toDouble(),
      note: map['note'],
      treeId: map['treeId'],
    );
  }
}
