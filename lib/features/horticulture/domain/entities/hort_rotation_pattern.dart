import 'planta_hort.dart';

class HortRotationStage {
  final int stageIndex; // 0 to 3 (2 years cycle)
  final String label; // e.g. "Year 1 - Spring"
  final HortExigenciaNutrients exigency;
  final String? mainCropId;
  final List<String> auxiliaryCropIds;
  final int durationMonths; // Default 6
  final int? durationWeeks;

  const HortRotationStage({
    required this.stageIndex,
    required this.label,
    required this.exigency,
    this.mainCropId,
    this.auxiliaryCropIds = const [],
    this.durationMonths = 6,
    this.durationWeeks,
  });

  Map<String, dynamic> toMap() {
    return {
      'stageIndex': stageIndex,
      'label': label,
      'exigency': exigency.name, // Enum to string
      'mainCropId': mainCropId,
      'auxiliaryCropIds': auxiliaryCropIds,
      'durationMonths': durationMonths,
      'durationWeeks': durationWeeks,
    };
  }

  factory HortRotationStage.fromMap(Map<String, dynamic> map) {
    return HortRotationStage(
      stageIndex: map['stageIndex'] ?? 0,
      label: map['label'] ?? '',
      exigency: HortExigenciaNutrients.values.firstWhere(
        (e) => e.name == map['exigency'],
        orElse: () => HortExigenciaNutrients.mitjanamentExigent,
      ),
      mainCropId: map['mainCropId'],
      auxiliaryCropIds: List<String>.from(map['auxiliaryCropIds'] ?? []),
      durationMonths: map['durationMonths'] ?? 6,
      durationWeeks: map['durationWeeks'],
    );
  }

  HortRotationStage copyWith({
    int? stageIndex,
    String? label,
    HortExigenciaNutrients? exigency,
    String? mainCropId,
    List<String>? auxiliaryCropIds,
    int? durationMonths,
    int? durationWeeks,
  }) {
    return HortRotationStage(
      stageIndex: stageIndex ?? this.stageIndex,
      label: label ?? this.label,
      exigency: exigency ?? this.exigency,
      mainCropId: mainCropId ?? this.mainCropId,
      auxiliaryCropIds: auxiliaryCropIds ?? this.auxiliaryCropIds,
      durationMonths: durationMonths ?? this.durationMonths,
      durationWeeks: durationWeeks ?? this.durationWeeks,
    );
  }
}

class HortRotationPattern {
  final String id;
  final String name; // e.g. "O1", "P1"
  final String description;
  final String? fincaId;
  final List<HortRotationStage> stages;

  HortRotationPattern({
    required this.id,
    required this.name,
    this.description = '',
    this.fincaId,
    required this.stages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fincaId': fincaId,
      'stages': stages.map((x) => x.toMap()).toList(),
    };
  }

  factory HortRotationPattern.fromMap(Map<String, dynamic> map, [String? id]) {
    return HortRotationPattern(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      fincaId: map['fincaId'],
      stages: map['stages'] != null
          ? List<HortRotationStage>.from(
              (map['stages'] as List).map(
                (x) => HortRotationStage.fromMap(x as Map<String, dynamic>),
              ),
            )
          : [],
    );
  }

  HortRotationPattern copyWith({
    String? id,
    String? name,
    String? description,
    String? fincaId,
    List<HortRotationStage>? stages,
  }) {
    return HortRotationPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      fincaId: fincaId ?? this.fincaId,
      stages: stages ?? this.stages,
    );
  }
}
