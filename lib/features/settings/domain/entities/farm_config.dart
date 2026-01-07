class FarmConfig {
  final String name;
  final String cif;
  final String address;
  final double latitude;
  final double longitude;
  final double zoom;
  final List<FarmZone> zones;
  final String? meteocatStationCode;

  const FarmConfig({
    required this.name,
    required this.cif,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.zones,
    this.meteocatStationCode,
  });

  factory FarmConfig.empty() {
    return const FarmConfig(
      name: '',
      cif: '',
      address: '',
      latitude: 41.5126017, // Default: Molí de Cal Jeroni
      longitude: 0.9185921,
      zoom: 16.0,
      zones: [],
      meteocatStationCode: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cif': cif,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'zones': zones.map((z) => z.toMap()).toList(),
      'meteocatStationCode': meteocatStationCode,
    };
  }

  factory FarmConfig.fromMap(Map<String, dynamic> map) {
    return FarmConfig(
      name: map['name'] ?? '',
      cif: map['cif'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 41.5126017,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.9185921,
      zoom: (map['zoom'] as num?)?.toDouble() ?? 16.0,
      zones:
          (map['zones'] as List<dynamic>?)
              ?.map((z) => FarmZone.fromMap(z))
              .toList() ??
          [],
      meteocatStationCode: map['meteocatStationCode'],
    );
  }

  FarmConfig copyWith({
    String? name,
    String? cif,
    String? address,
    double? latitude,
    double? longitude,
    double? zoom,
    List<FarmZone>? zones,
    String? meteocatStationCode,
  }) {
    return FarmConfig(
      name: name ?? this.name,
      cif: cif ?? this.cif,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
      zones: zones ?? this.zones,
      meteocatStationCode: meteocatStationCode ?? this.meteocatStationCode,
    );
  }
}

class FarmZone {
  final String id;
  final String name;
  final String colorHex;
  final String cropType;

  const FarmZone({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.cropType,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'colorHex': colorHex, 'cropType': cropType};
  }

  factory FarmZone.fromMap(Map<String, dynamic> map) {
    return FarmZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF2196F3', // Default Blue
      cropType: map['cropType'] ?? '',
    );
  }
}
