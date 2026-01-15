import 'planta_hort.dart';

class HortRotationStage {
  final int stageIndex; // 0 to 3 (2 years cycle)
  final String label; // e.g. "Year 1 - Spring"
  final HortExigenciaNutrients exigency;
  final List<String> suggestedSpeciesIds; // IDs from Hort Library
  final int durationMonths; // Default 6

  const HortRotationStage({
    required this.stageIndex,
    required this.label,
    required this.exigency,
    this.suggestedSpeciesIds = const [],
    this.durationMonths = 6,
  });

  Map<String, dynamic> toMap() {
    return {
      'stageIndex': stageIndex,
      'label': label,
      'exigency': exigency.name, // Enum to string
      'suggestedSpeciesIds': suggestedSpeciesIds,
      'durationMonths': durationMonths,
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
      suggestedSpeciesIds: List<String>.from(map['suggestedSpeciesIds'] ?? []),
      durationMonths: map['durationMonths'] ?? 6,
    );
  }
}

class HortRotationPattern {
  final String id;
  final String name; // e.g. "O1", "P1"
  final String description;
  final List<HortRotationStage> stages;

  HortRotationPattern({
    required this.id,
    required this.name,
    this.description = '',
    required this.stages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'stages': stages.map((x) => x.toMap()).toList(),
    };
  }

  factory HortRotationPattern.fromMap(Map<String, dynamic> map, [String? id]) {
    return HortRotationPattern(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      stages: map['stages'] != null
          ? List<HortRotationStage>.from(
              (map['stages'] as List).map(
                (x) => HortRotationStage.fromMap(x as Map<String, dynamic>),
              ),
            )
          : [],
    );
  }
}
