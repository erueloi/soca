import 'package:cloud_firestore/cloud_firestore.dart';

class AIAnalysisEntry {
  final String id;
  final DateTime date;
  final String health;
  final String vigor;
  final String advice;

  const AIAnalysisEntry({
    required this.id,
    required this.date,
    required this.health,
    required this.vigor,
    required this.advice,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'health': health,
      'vigor': vigor,
      'advice': advice,
    };
  }

  factory AIAnalysisEntry.fromMap(Map<String, dynamic> map, String id) {
    return AIAnalysisEntry(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      health: map['health'] ?? 'N/A',
      vigor: map['vigor'] ?? 'N/A',
      advice: map['advice'] ?? '',
    );
  }
}
