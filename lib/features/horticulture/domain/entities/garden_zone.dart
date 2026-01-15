import 'package:cloud_firestore/cloud_firestore.dart';

class GardenZone {
  final String id;
  final String name;
  final List<GeoPoint> polygon; // Defining the shape on the map
  final double areaM2;
  final String notes;

  final String? rotationPatternId;
  final DateTime? rotationStartDate;

  GardenZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.areaM2,
    this.notes = '',
    this.rotationPatternId,
    this.rotationStartDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'polygon': polygon,
      'areaM2': areaM2,
      'notes': notes,
      'rotationPatternId': rotationPatternId,
      'rotationStartDate': rotationStartDate?.toIso8601String(),
    };
  }

  factory GardenZone.fromMap(Map<String, dynamic> map, String documentId) {
    return GardenZone(
      id: documentId,
      name: map['name'] ?? '',
      polygon:
          (map['polygon'] as List<dynamic>?)
              ?.map((e) => e as GeoPoint)
              .toList() ??
          [],
      areaM2: (map['areaM2'] ?? 0.0).toDouble(),
      notes: map['notes'] ?? '',
      rotationPatternId: map['rotationPatternId'],
      rotationStartDate: map['rotationStartDate'] != null
          ? DateTime.parse(map['rotationStartDate'])
          : null,
    );
  }
}
