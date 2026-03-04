class GardenLayoutConfig {
  final double totalWidth; // meters (X axis)
  final double totalLength; // meters (Y axis)
  final int numberOfBeds;
  final double bedWidth; // meters
  final double pathWidth; // meters
  // final double orientation; // Degrees, future use

  const GardenLayoutConfig({
    required this.totalWidth,
    required this.totalLength,
    required this.numberOfBeds,
    required this.bedWidth,
    required this.pathWidth,
    this.cellSize = 0.20,
    this.beds = const {},
  });

  final double cellSize; // meters (grid resolution)

  // Per-Bed Configuration (Bed Index -> Bed Data)
  final Map<int, BedData> beds;

  // Helper to get actual width of a bed
  double getBedWidth(int bedIndex) {
    return beds[bedIndex]?.widthOverride ?? bedWidth;
  }

  // Helper to get the starting X coordinate of a bed
  double getBedStartX(int bedIndex) {
    double x = pathWidth;
    for (int i = 0; i < bedIndex; i++) {
      x += getBedWidth(i) + pathWidth;
    }
    return x;
  }

  // Helper to validate if beds fit in width
  bool get isValid {
    double requiredWidth = pathWidth;
    for (int i = 0; i < numberOfBeds; i++) {
      requiredWidth += getBedWidth(i) + pathWidth;
    }
    return requiredWidth <= totalWidth;
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWidth': totalWidth,
      'totalLength': totalLength,
      'numberOfBeds': numberOfBeds,
      'bedWidth': bedWidth,
      'pathWidth': pathWidth,
      'cellSize': cellSize,
      'beds': beds.map((k, v) => MapEntry(k.toString(), v.toMap())),
    };
  }

  factory GardenLayoutConfig.fromMap(Map<String, dynamic> map) {
    return GardenLayoutConfig(
      totalWidth: (map['totalWidth'] as num?)?.toDouble() ?? 0.0,
      totalLength: (map['totalLength'] as num?)?.toDouble() ?? 0.0,
      numberOfBeds: (map['numberOfBeds'] as num?)?.toInt() ?? 0,
      bedWidth: (map['bedWidth'] as num?)?.toDouble() ?? 0.0,
      pathWidth: (map['pathWidth'] as num?)?.toDouble() ?? 0.0,
      cellSize: (map['cellSize'] as num?)?.toDouble() ?? 0.20,
      beds:
          (map['beds'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              int.parse(k),
              BedData.fromMap(Map<String, dynamic>.from(v)),
            ),
          ) ??
          {},
    );
  }
}

class BedData {
  final String? rotationPatternId;
  final DateTime? rotationStartDate;
  final String? name;
  final double? widthOverride;

  BedData({
    this.rotationPatternId,
    this.rotationStartDate,
    this.name,
    this.widthOverride,
  });

  Map<String, dynamic> toMap() {
    return {
      'rotationPatternId': rotationPatternId,
      'rotationStartDate': rotationStartDate?.toIso8601String(),
      'name': name,
      'widthOverride': widthOverride,
    };
  }

  factory BedData.fromMap(Map<String, dynamic> map) {
    return BedData(
      rotationPatternId: map['rotationPatternId'],
      rotationStartDate: map['rotationStartDate'] != null
          ? DateTime.parse(map['rotationStartDate'])
          : null,
      name: map['name'],
      widthOverride: (map['widthOverride'] as num?)?.toDouble(),
    );
  }

  BedData copyWith({
    String? rotationPatternId,
    DateTime? rotationStartDate,
    String? name,
    double? widthOverride,
  }) {
    return BedData(
      rotationPatternId: rotationPatternId ?? this.rotationPatternId,
      rotationStartDate: rotationStartDate ?? this.rotationStartDate,
      name: name ?? this.name,
      widthOverride: widthOverride ?? this.widthOverride,
    );
  }
}
