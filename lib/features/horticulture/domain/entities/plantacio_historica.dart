import 'package:uuid/uuid.dart';

/// Represents an archived planting record for a bed/espai.
/// When the user "finalizes a cycle", all current plants are archived here.
class PlantacioHistorica {
  final String id;
  final String? mainCropId;
  final List<String> auxiliaryCropIds;
  final DateTime dataPlantacio;
  final DateTime dataFinalitzacio;
  final String? notes;

  /// Optional: bed index within the EspaiHort layout (null = whole espai)
  final int? bedIndex;

  const PlantacioHistorica({
    required this.id,
    this.mainCropId,
    this.auxiliaryCropIds = const [],
    required this.dataPlantacio,
    required this.dataFinalitzacio,
    this.notes,
    this.bedIndex,
  });

  factory PlantacioHistorica.create({
    String? mainCropId,
    List<String> auxiliaryCropIds = const [],
    required DateTime dataPlantacio,
    DateTime? dataFinalitzacio,
    String? notes,
    int? bedIndex,
  }) {
    return PlantacioHistorica(
      id: const Uuid().v4(),
      mainCropId: mainCropId,
      auxiliaryCropIds: auxiliaryCropIds,
      dataPlantacio: dataPlantacio,
      dataFinalitzacio: dataFinalitzacio ?? DateTime.now(),
      notes: notes,
      bedIndex: bedIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mainCropId': mainCropId,
      'auxiliaryCropIds': auxiliaryCropIds,
      'dataPlantacio': dataPlantacio.millisecondsSinceEpoch,
      'dataFinalitzacio': dataFinalitzacio.millisecondsSinceEpoch,
      'notes': notes,
      'bedIndex': bedIndex,
    };
  }

  factory PlantacioHistorica.fromMap(Map<String, dynamic> map) {
    return PlantacioHistorica(
      id: map['id'] ?? '',
      mainCropId: map['mainCropId'],
      auxiliaryCropIds: List<String>.from(map['auxiliaryCropIds'] ?? []),
      dataPlantacio: map['dataPlantacio'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dataPlantacio'])
          : DateTime.now(),
      dataFinalitzacio: map['dataFinalitzacio'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dataFinalitzacio'])
          : DateTime.now(),
      notes: map['notes'],
      bedIndex: map['bedIndex'],
    );
  }
}
