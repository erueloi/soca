import 'package:cloud_firestore/cloud_firestore.dart';

class WateringEvent {
  final String id;
  final DateTime date;
  final double liters;
  final String? note;

  const WateringEvent({
    required this.id,
    required this.date,
    required this.liters,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {'date': Timestamp.fromDate(date), 'liters': liters, 'note': note};
  }

  factory WateringEvent.fromMap(Map<String, dynamic> map, String id) {
    return WateringEvent(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      liters: (map['liters'] as num).toDouble(),
      note: map['note'],
    );
  }
}
