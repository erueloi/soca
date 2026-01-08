import 'package:cloud_firestore/cloud_firestore.dart';

class GrowthEntry {
  final String id;
  final DateTime date;
  final String photoUrl;
  final double height; // cm
  final double trunkDiameter; // cm
  final String healthStatus;
  final String observations;

  const GrowthEntry({
    required this.id,
    required this.date,
    required this.photoUrl,
    required this.height,
    required this.trunkDiameter,
    required this.healthStatus,
    required this.observations,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'photoUrl': photoUrl,
      'alcada': height,
      'diametre_tronc': trunkDiameter,
      'estat_salut': healthStatus,
      'observacions': observations,
    };
  }

  factory GrowthEntry.fromMap(Map<String, dynamic> map, String id) {
    return GrowthEntry(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      photoUrl: map['photoUrl'] ?? '',
      height: (map['alcada'] as num?)?.toDouble() ?? 0.0,
      trunkDiameter: (map['diametre_tronc'] as num?)?.toDouble() ?? 0.0,
      healthStatus: map['estat_salut'] ?? 'Desconegut',
      observations: map['observacions'] ?? '',
    );
  }
}
