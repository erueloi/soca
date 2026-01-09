import 'package:cloud_firestore/cloud_firestore.dart';

enum InjuryType { fisica, quimica, mecanica, estructural }

class PathologySheet {
  final String title;
  final InjuryType type;
  final String description;
  final List<String> photoUrls;
  final String causes;
  final String currentState;
  final String recommendedAction;
  final int severity; // 1-10

  PathologySheet({
    required this.title,
    required this.type,
    required this.description,
    required this.photoUrls,
    required this.causes,
    required this.currentState,
    required this.recommendedAction,
    required this.severity,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'description': description,
      'photoUrls': photoUrls,
      'causes': causes,
      'currentState': currentState,
      'recommendedAction': recommendedAction,
      'severity': severity,
    };
  }

  factory PathologySheet.fromMap(Map<String, dynamic> map) {
    return PathologySheet(
      title: map['title'] ?? '',
      type: InjuryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InjuryType.fisica,
      ),
      description: map['description'] ?? '',
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      causes: map['causes'] ?? '',
      currentState: map['currentState'] ?? '',
      recommendedAction: map['recommendedAction'] ?? '',
      severity: map['severity'] ?? 1,
    );
  }
}

class ConstructionPoint {
  final String id;
  final String floorId; // "Planta Baixa", "Planta 1", etc.
  final double xPercent;
  final double yPercent;
  final PathologySheet? pathology;
  final DateTime createdAt;
  final String status; // "Pendent", "En Progrés", "Finalitzat"

  ConstructionPoint({
    required this.id,
    required this.floorId,
    required this.xPercent,
    required this.yPercent,
    this.pathology,
    required this.createdAt,
    this.status = 'Pendent',
  });

  Map<String, dynamic> toMap() {
    return {
      'floorId': floorId,
      'xPercent': xPercent,
      'yPercent': yPercent,
      'pathology': pathology?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory ConstructionPoint.fromMap(Map<String, dynamic> map, String id) {
    return ConstructionPoint(
      id: id,
      floorId: map['floorId'] ?? '',
      xPercent: (map['xPercent'] ?? 0).toDouble(),
      yPercent: (map['yPercent'] ?? 0).toDouble(),
      pathology: map['pathology'] != null
          ? PathologySheet.fromMap(map['pathology'])
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'Pendent',
    );
  }
}
