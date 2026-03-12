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

  GardenLayoutConfig copyWith({
    double? totalWidth,
    double? totalLength,
    int? numberOfBeds,
    double? bedWidth,
    double? pathWidth,
    double? cellSize,
    Map<int, BedData>? beds,
  }) {
    return GardenLayoutConfig(
      totalWidth: totalWidth ?? this.totalWidth,
      totalLength: totalLength ?? this.totalLength,
      numberOfBeds: numberOfBeds ?? this.numberOfBeds,
      bedWidth: bedWidth ?? this.bedWidth,
      pathWidth: pathWidth ?? this.pathWidth,
      cellSize: cellSize ?? this.cellSize,
      beds: beds ?? this.beds,
    );
  }
}

enum IrrigationMethod { manual, drip }

class WateringEvent {
  final DateTime date;
  final double litersApplied;

  WateringEvent({required this.date, required this.litersApplied});

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'litersApplied': litersApplied,
    };
  }

  factory WateringEvent.fromMap(Map<String, dynamic> map) {
    return WateringEvent(
      date: DateTime.parse(map['date']),
      litersApplied: (map['litersApplied'] as num).toDouble(),
    );
  }
}

class BedData {
  final String? rotationPatternId;
  final DateTime? rotationStartDate;
  final String? name;
  final double? widthOverride;
  // Irrigation Config
  final IrrigationMethod irrigationMethod;
  final double? cabalSistemaLitersHora; // L/h/m2
  final double? soilBalance; // mm
  final DateTime? lastBalanceUpdate;
  final List<WateringEvent>? wateringEvents;

  BedData({
    this.rotationPatternId,
    this.rotationStartDate,
    this.name,
    this.widthOverride,
    this.irrigationMethod = IrrigationMethod.manual,
    this.cabalSistemaLitersHora,
    this.soilBalance,
    this.lastBalanceUpdate,
    this.wateringEvents,
  });

  Map<String, dynamic> toMap() {
    return {
      'rotationPatternId': rotationPatternId,
      'rotationStartDate': rotationStartDate?.toIso8601String(),
      'name': name,
      'widthOverride': widthOverride,
      'irrigationMethod': irrigationMethod.name,
      'cabalSistemaLitersHora': cabalSistemaLitersHora,
      'soilBalance': soilBalance,
      'lastBalanceUpdate': lastBalanceUpdate?.toIso8601String(),
      'wateringEvents': wateringEvents?.map((x) => x.toMap()).toList(),
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
      irrigationMethod: map['irrigationMethod'] != null
          ? IrrigationMethod.values.firstWhere(
              (e) => e.name == map['irrigationMethod'],
              orElse: () => IrrigationMethod.manual,
            )
          : IrrigationMethod.manual,
      cabalSistemaLitersHora: (map['cabalSistemaLitersHora'] as num?)
          ?.toDouble(),
      soilBalance: (map['soilBalance'] as num?)?.toDouble(),
      lastBalanceUpdate: map['lastBalanceUpdate'] != null
          ? DateTime.parse(map['lastBalanceUpdate'])
          : null,
      wateringEvents: map['wateringEvents'] != null
          ? List<WateringEvent>.from(
              (map['wateringEvents'] as List).map(
                (x) => WateringEvent.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  BedData copyWith({
    String? rotationPatternId,
    DateTime? rotationStartDate,
    String? name,
    double? widthOverride,
    IrrigationMethod? irrigationMethod,
    double? cabalSistemaLitersHora,
    double? soilBalance,
    DateTime? lastBalanceUpdate,
    List<WateringEvent>? wateringEvents,
  }) {
    return BedData(
      rotationPatternId: rotationPatternId ?? this.rotationPatternId,
      rotationStartDate: rotationStartDate ?? this.rotationStartDate,
      name: name ?? this.name,
      widthOverride: widthOverride ?? this.widthOverride,
      irrigationMethod: irrigationMethod ?? this.irrigationMethod,
      cabalSistemaLitersHora:
          cabalSistemaLitersHora ?? this.cabalSistemaLitersHora,
      soilBalance: soilBalance ?? this.soilBalance,
      lastBalanceUpdate: lastBalanceUpdate ?? this.lastBalanceUpdate,
      wateringEvents: wateringEvents ?? this.wateringEvents,
    );
  }
}
