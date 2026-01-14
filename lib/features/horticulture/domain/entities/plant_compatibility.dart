enum CompatibilityType { friend, enemy, neutral }

class PlantCompatibility {
  final String speciesIdA;
  final String speciesIdB;
  final CompatibilityType type;
  final String reason;

  PlantCompatibility({
    required this.speciesIdA,
    required this.speciesIdB,
    required this.type,
    this.reason = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'speciesIdA': speciesIdA,
      'speciesIdB': speciesIdB,
      'type': type.name,
      'reason': reason,
    };
  }

  factory PlantCompatibility.fromMap(Map<String, dynamic> map) {
    return PlantCompatibility(
      speciesIdA: map['speciesIdA'] ?? '',
      speciesIdB: map['speciesIdB'] ?? '',
      type: CompatibilityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CompatibilityType.neutral,
      ),
      reason: map['reason'] ?? '',
    );
  }
}
