import 'package:cloud_firestore/cloud_firestore.dart';

class EvolutionEntry {
  final String id;
  final String photoUrl;
  final DateTime date;
  final String? note;

  const EvolutionEntry({
    required this.id,
    required this.photoUrl,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }

  factory EvolutionEntry.fromMap(Map<String, dynamic> map, String id) {
    return EvolutionEntry(
      id: id,
      photoUrl: map['photoUrl'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
    );
  }
}
