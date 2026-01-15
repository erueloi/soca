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

  // Helper to validate if beds fit in width
  bool get isValid {
    double requiredWidth =
        (numberOfBeds * bedWidth) + ((numberOfBeds - 1) * pathWidth);
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

  BedData({this.rotationPatternId, this.rotationStartDate, this.name});

  Map<String, dynamic> toMap() {
    return {
      'rotationPatternId': rotationPatternId,
      'rotationStartDate': rotationStartDate?.toIso8601String(),
      'name': name,
    };
  }

  factory BedData.fromMap(Map<String, dynamic> map) {
    return BedData(
      rotationPatternId: map['rotationPatternId'],
      rotationStartDate: map['rotationStartDate'] != null
          ? DateTime.parse(map['rotationStartDate'])
          : null,
      name: map['name'],
    );
  }

  BedData copyWith({
    String? rotationPatternId,
    DateTime? rotationStartDate,
    String? name,
  }) {
    return BedData(
      rotationPatternId: rotationPatternId ?? this.rotationPatternId,
      rotationStartDate: rotationStartDate ?? this.rotationStartDate,
      name: name ?? this.name,
    );
  }

  // Allow clearing values by passing explicit nulls (logic helper)
  // Or just rely on replacing the object
}
