class Species {
  final String id;
  final String scientificName;
  final String commonName;
  final double kc;
  final String leafType; // 'Perenne' or 'Caduca'
  final String frostSensitivity; // 'Baixa', 'Mitjana', 'Alta', etc.
  final bool fruit;
  final String? fruitType;
  final String color; // Hex color
  final int? iconCode; // Material Icon code point
  final String? iconName; // e.g. "park"
  final String? iconFamily;
  final String prefix;
  final List<int> pruningMonths;
  final List<int> harvestMonths;
  final List<int> floweringMonths;
  final String sunNeeds;

  // New Fields
  final List<int> plantingMonths;
  final double adultHeight; // meters
  final double adultDiameter; // meters
  final String growthRate; // Lent, Mig, Ràpid
  final int droughtResistance; // 1-5

  final int? lifeExpectancyYears;
  final List<String> commonDiseases;

  const Species({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.kc,
    required this.leafType,
    required this.frostSensitivity,
    required this.fruit,
    this.fruitType,
    this.prefix = '',
    this.pruningMonths = const [],
    this.harvestMonths = const [],
    this.floweringMonths = const [],
    this.plantingMonths = const [],
    this.sunNeeds = 'Alt',
    required this.color,
    this.iconCode,
    this.iconName,
    this.iconFamily,
    this.adultHeight = 0.0,
    this.adultDiameter = 0.0,
    this.growthRate = 'Mig',
    this.droughtResistance = 3,
    this.lifeExpectancyYears,
    this.commonDiseases = const [],
  });

  Species copyWith({
    String? id,
    String? scientificName,
    String? commonName,
    double? kc,
    String? leafType,
    String? frostSensitivity,
    bool? fruit,
    String? fruitType,
    String? prefix,
    List<int>? pruningMonths,
    List<int>? harvestMonths,
    List<int>? floweringMonths,
    String? sunNeeds,
    String? color,
    int? iconCode,
    String? iconName,
    String? iconFamily,
    List<int>? plantingMonths,
    double? adultHeight,
    double? adultDiameter,
    String? growthRate,
    int? droughtResistance,
    int? lifeExpectancyYears,
    List<String>? commonDiseases,
  }) {
    return Species(
      id: id ?? this.id,
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      kc: kc ?? this.kc,
      leafType: leafType ?? this.leafType,
      frostSensitivity: frostSensitivity ?? this.frostSensitivity,
      fruit: fruit ?? this.fruit,
      fruitType: fruitType ?? this.fruitType,
      prefix: prefix ?? this.prefix,
      pruningMonths: pruningMonths ?? this.pruningMonths,
      harvestMonths: harvestMonths ?? this.harvestMonths,
      floweringMonths: floweringMonths ?? this.floweringMonths,
      plantingMonths: plantingMonths ?? this.plantingMonths,
      sunNeeds: sunNeeds ?? this.sunNeeds,
      color: color ?? this.color,
      iconCode: iconCode ?? this.iconCode,
      iconName: iconName ?? this.iconName,
      iconFamily: iconFamily ?? this.iconFamily,
      adultHeight: adultHeight ?? this.adultHeight,
      adultDiameter: adultDiameter ?? this.adultDiameter,
      growthRate: growthRate ?? this.growthRate,
      droughtResistance: droughtResistance ?? this.droughtResistance,
      lifeExpectancyYears: lifeExpectancyYears ?? this.lifeExpectancyYears,
      commonDiseases: commonDiseases ?? this.commonDiseases,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scientificName': scientificName,
      'commonName': commonName,
      'kc': kc,
      'leafType': leafType,
      'frostSensitivity': frostSensitivity,
      'fruit': fruit,
      'fruitType': fruitType,
      'prefix': prefix,
      'pruningMonths': pruningMonths,
      'harvestMonths': harvestMonths,
      'floweringMonths': floweringMonths,
      'plantingMonths': plantingMonths,
      'sunNeeds': sunNeeds,
      'color': color,
      'iconCode': iconCode,
      'iconName': iconName,
      'iconFamily': iconFamily,
      'adultHeight': adultHeight,
      'adultDiameter': adultDiameter,
      'growthRate': growthRate,
      'droughtResistance': droughtResistance,
      'lifeExpectancyYears': lifeExpectancyYears,
      'commonDiseases': commonDiseases,
    };
  }

  factory Species.fromMap(Map<String, dynamic> map, String id) {
    String p = map['prefix'] ?? '';
    if (p.isEmpty && (map['commonName'] as String? ?? '').isNotEmpty) {
      // Fallback generator if missing in DB
      final cn = (map['commonName'] as String).toUpperCase();
      p = cn.length >= 3 ? cn.substring(0, 3) : cn;
    }
    return Species(
      id: id,
      scientificName: map['scientificName'] ?? '',
      commonName: map['commonName'] ?? '',
      kc: (map['kc'] as num?)?.toDouble() ?? 0.6,
      leafType: map['leafType'] ?? 'Desconegut',
      frostSensitivity: map['frostSensitivity'] ?? 'Desconeguda',
      fruit: map['fruit'] ?? false,
      fruitType: map['fruitType'],
      prefix: p,
      pruningMonths: List<int>.from(map['pruningMonths'] ?? []),
      harvestMonths: List<int>.from(map['harvestMonths'] ?? []),
      floweringMonths: List<int>.from(map['floweringMonths'] ?? []),
      sunNeeds: map['sunNeeds'] ?? 'Alt',
      color: map['color'] ?? '4CAF50',
      iconCode: map['iconCode'],
      iconName: map['iconName'],
      iconFamily: map['iconFamily'],
      plantingMonths: List<int>.from(map['plantingMonths'] ?? []),
      adultHeight: (map['adultHeight'] as num?)?.toDouble() ?? 0.0,
      adultDiameter: (map['adultDiameter'] as num?)?.toDouble() ?? 0.0,
      growthRate: map['growthRate'] ?? 'Mig',
      droughtResistance: map['droughtResistance'] ?? 3,
      lifeExpectancyYears: map['lifeExpectancyYears'],
      commonDiseases: List<String>.from(map['commonDiseases'] ?? []),
    );
  }
}
