class FarmConfig {
  final String name;
  final String cif;
  final String address;
  final double latitude;
  final double longitude;
  final double zoom;
  final List<FarmZone> zones;
  final String? meteocatStationCode;
  final double mapMarkerSize;
  final bool dailyNotificationsEnabled; // Evening
  final String dailyNotificationTime; // Evening (e.g. "20:30")
  final bool morningNotificationsEnabled; // Morning
  final String morningNotificationTime; // Morning (e.g. "08:00")
  final List<String> dashboardOrder; // Order of dashboard widgets

  const FarmConfig({
    required this.name,
    required this.cif,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.zones,
    this.meteocatStationCode,
    required this.mapMarkerSize,
    this.dailyNotificationsEnabled = true,
    this.dailyNotificationTime = '20:30',
    this.morningNotificationsEnabled = true,
    this.morningNotificationTime = '08:00',
    this.dashboardOrder = const [],
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
      mapMarkerSize: 20.0,
      dailyNotificationsEnabled: true,
      dailyNotificationTime: '20:30',
      morningNotificationsEnabled: true,
      morningNotificationTime: '08:00',
      dashboardOrder: [],
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
      'mapMarkerSize': mapMarkerSize,
      'dailyNotificationsEnabled': dailyNotificationsEnabled,
      'dailyNotificationTime': dailyNotificationTime,
      'morningNotificationsEnabled': morningNotificationsEnabled,
      'morningNotificationTime': morningNotificationTime,
      'dashboardOrder': dashboardOrder,
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
      mapMarkerSize: (map['mapMarkerSize'] as num?)?.toDouble() ?? 20.0,
      dailyNotificationsEnabled: map['dailyNotificationsEnabled'] ?? true,
      dailyNotificationTime: map['dailyNotificationTime'] ?? '20:30',
      morningNotificationsEnabled: map['morningNotificationsEnabled'] ?? true,
      morningNotificationTime: map['morningNotificationTime'] ?? '08:00',
      dashboardOrder:
          (map['dashboardOrder'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
    double? mapMarkerSize,
    bool? dailyNotificationsEnabled,
    String? dailyNotificationTime,
    bool? morningNotificationsEnabled,
    String? morningNotificationTime,
    List<String>? dashboardOrder,
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
      mapMarkerSize: mapMarkerSize ?? this.mapMarkerSize,
      dailyNotificationsEnabled:
          dailyNotificationsEnabled ?? this.dailyNotificationsEnabled,
      dailyNotificationTime:
          dailyNotificationTime ?? this.dailyNotificationTime,
      morningNotificationsEnabled:
          morningNotificationsEnabled ?? this.morningNotificationsEnabled,
      morningNotificationTime:
          morningNotificationTime ?? this.morningNotificationTime,
      dashboardOrder: dashboardOrder ?? this.dashboardOrder,
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
