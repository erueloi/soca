// import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Wait, `ExpenseCategory` in `farm_config.dart` uses `const FarmConfig`. `FarmConfig` uses `Color`? No, it uses Strings and doubles.
// Ah, `FarmConfig.empty` uses `Colors.blue` which is from material.
// Let's check `FarmConfig.empty` implementation again.
// It uses hex strings 'FF2196F3'. It does NOT use `Colors` class directly in my previous edit.
// So `package:flutter/material.dart` IS truly unused in `farm_config.dart`.
// Exception: `iconCode` is int.
// So safe to remove.

import '../../../../features/tasks/domain/entities/bucket.dart';

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
  final List<TaskPhase> taskPhases; // Custom phases/labels
  final List<ExpenseCategory> expenseCategories; // Custom expense categories
  final List<Bucket> buckets; // Task buckets (columns)
  final List<PermacultureZone> permacultureZones; // [NEW] PDC Zones
  final List<ResourceCategoryConfig>
  resourceCategories; // [NEW] Resource Categories
  final List<ResourceTypeConfig> resourceTypes; // [NEW] Resource Types

  final String? fincaId;
  final List<String> authorizedEmails;
  final String? coverPhotoUrl; // [NEW] Cover photo for reports

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
    this.taskPhases = const [],
    this.expenseCategories = const [],
    this.buckets = const [],
    this.permacultureZones = const [],
    this.resourceCategories = const [],
    this.resourceTypes = const [],
    this.fincaId,
    this.authorizedEmails = const [],
    this.coverPhotoUrl, // [NEW]
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
      taskPhases: [
        TaskPhase(
          name: 'Urgent',
          colorHex: 'FFF44336',
          iconCode: 0xe6a5,
        ), // warning
        TaskPhase(
          name: 'Compra',
          colorHex: 'FF2196F3',
          iconCode: 0xe59c,
        ), // shopping_cart
        TaskPhase(
          name: 'Manteniment',
          colorHex: 'FFFF9800',
          iconCode: 0xe182,
        ), // build
        TaskPhase(
          name: 'Planificació',
          colorHex: 'FF9C27B0',
          iconCode: 0xe0e7,
        ), // calendar_today
      ],
      expenseCategories: [
        ExpenseCategory(
          id: 'material',
          name: 'Material',
          colorHex: 'FF2196F3',
          iconCode: 0xe17f,
        ), // Icons.construction
        ExpenseCategory(
          id: 'eina',
          name: 'Eina',
          colorHex: 'FFFF9800',
          iconCode: 0xe182,
        ), // Icons.build
        ExpenseCategory(
          id: 'servei',
          name: 'Servei',
          colorHex: 'FF9C27B0',
          iconCode: 0xefd3,
        ), // Icons.design_services
        ExpenseCategory(
          id: 'altres',
          name: 'Altres',
          colorHex: 'FF9E9E9E',
          iconCode: 0xe3e3,
        ), // Icons.more_horiz
      ],
      buckets: [],
      permacultureZones: [],
      resourceCategories: [], // Migrated to database
      resourceTypes: [], // Migrated to database
      fincaId: null,
      authorizedEmails: [],
      coverPhotoUrl: null,
    );
  }

  /// Default resource categories for first-time initialization
  static List<ResourceCategoryConfig> get defaultResourceCategories => [
    ResourceCategoryConfig(
      id: 'admin',
      name: 'Administració',
      colorHex: 'FF9E9E9E',
      iconCode: 0xe3e3,
    ),
    ResourceCategoryConfig(
      id: 'technical',
      name: 'Tècnic',
      colorHex: 'FF2196F3',
      iconCode: 0xe182,
    ),
    ResourceCategoryConfig(
      id: 'events',
      name: 'Esdeveniments',
      colorHex: 'FF9C27B0',
      iconCode: 0xe567,
    ),
    ResourceCategoryConfig(
      id: 'materials',
      name: 'Materials',
      colorHex: 'FFFF9800',
      iconCode: 0xe17f,
    ),
    ResourceCategoryConfig(
      id: 'other',
      name: 'Altres',
      colorHex: 'FF607D8B',
      iconCode: 0xe88e,
    ),
  ];

  /// Default resource types for first-time initialization
  static List<ResourceTypeConfig> get defaultResourceTypes => [
    ResourceTypeConfig(
      id: 'link',
      name: 'Enllaç Web',
      colorHex: 'FF2196F3',
      iconCode: 0xe3b6,
    ),
    ResourceTypeConfig(
      id: 'pdf',
      name: 'Document PDF',
      colorHex: 'FFF44336',
      iconCode: 0xe415,
    ),
    ResourceTypeConfig(
      id: 'excel',
      name: 'Full de Càlcul',
      colorHex: 'FF4CAF50',
      iconCode: 0xf02e,
    ),
    ResourceTypeConfig(
      id: 'image',
      name: 'Imatge',
      colorHex: 'FF9C27B0',
      iconCode: 0xe3b3,
    ),
    ResourceTypeConfig(
      id: 'other',
      name: 'Altre',
      colorHex: 'FF9E9E9E',
      iconCode: 0xe24d,
    ),
  ];

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
      'taskPhases': taskPhases.map((e) => e.toMap()).toList(),
      'expenseCategories': expenseCategories.map((e) => e.toMap()).toList(),
      'buckets': buckets.map((b) => b.toMap()).toList(),
      'permacultureZones': permacultureZones.map((z) => z.toMap()).toList(),
      'resourceCategories': resourceCategories.map((e) => e.toMap()).toList(),
      'resourceTypes': resourceTypes.map((e) => e.toMap()).toList(),
      'fincaId': fincaId,
      'authorizedEmails': authorizedEmails,
      'coverPhotoUrl': coverPhotoUrl,
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
      taskPhases:
          (map['taskPhases'] as List<dynamic>?)?.map((e) {
            if (e is String) {
              return TaskPhase.fromLegacyString(e);
            }
            return TaskPhase.fromMap(e);
          }).toList() ??
          [
            TaskPhase(
              name: 'Urgent',
              colorHex: 'FFF44336',
              iconCode: 0xe6a5,
            ), // warning
            TaskPhase(
              name: 'Compra',
              colorHex: 'FF2196F3',
              iconCode: 0xe59c,
            ), // shopping_cart
            TaskPhase(
              name: 'Manteniment',
              colorHex: 'FFFF9800',
              iconCode: 0xe182,
            ), // build
            TaskPhase(
              name: 'Planificació',
              colorHex: 'FF9C27B0',
              iconCode: 0xe0e7,
            ), // calendar_today
          ],
      expenseCategories:
          (map['expenseCategories'] as List<dynamic>?)
              ?.map((e) => ExpenseCategory.fromMap(e))
              .toList() ??
          [
            ExpenseCategory(
              id: 'material',
              name: 'Material',
              colorHex: 'FF2196F3',
              iconCode: 0xe17f,
            ),
            ExpenseCategory(
              id: 'eina',
              name: 'Eina',
              colorHex: 'FFFF9800',
              iconCode: 0xe182,
            ),
            ExpenseCategory(
              id: 'servei',
              name: 'Servei',
              colorHex: 'FF9C27B0',
              iconCode: 0xefd3,
            ),
            ExpenseCategory(
              id: 'altres',
              name: 'Altres',
              colorHex: 'FF9E9E9E',
              iconCode: 0xe3e3,
            ),
          ],
      buckets:
          (map['buckets'] as List<dynamic>?)
              ?.map((e) => Bucket.fromMap(e))
              .toList() ??
          [],
      permacultureZones:
          (map['permacultureZones'] as List<dynamic>?)
              ?.map((z) => PermacultureZone.fromMap(z))
              .toList() ??
          [],
      resourceCategories:
          (map['resourceCategories'] as List<dynamic>?)
              ?.map((e) => ResourceCategoryConfig.fromMap(e))
              .toList() ??
          [
            ResourceCategoryConfig(
              id: 'admin',
              name: 'Administració',
              colorHex: 'FF9E9E9E',
              iconCode: 0xe3e3,
            ),
            ResourceCategoryConfig(
              id: 'technical',
              name: 'Tècnic',
              colorHex: 'FF2196F3',
              iconCode: 0xe182,
            ),
            ResourceCategoryConfig(
              id: 'events',
              name: 'Esdeveniments',
              colorHex: 'FF9C27B0',
              iconCode: 0xe567,
            ),
            ResourceCategoryConfig(
              id: 'materials',
              name: 'Materials',
              colorHex: 'FFFF9800',
              iconCode: 0xe17f,
            ),
            ResourceCategoryConfig(
              id: 'other',
              name: 'Altres',
              colorHex: 'FF607D8B',
              iconCode: 0xe88e,
            ),
          ],
      resourceTypes:
          (map['resourceTypes'] as List<dynamic>?)
              ?.map((e) => ResourceTypeConfig.fromMap(e))
              .toList() ??
          [
            ResourceTypeConfig(
              id: 'link',
              name: 'Enllaç Web',
              colorHex: 'FF2196F3',
              iconCode: 0xe3b6,
            ),
            ResourceTypeConfig(
              id: 'pdf',
              name: 'Document PDF',
              colorHex: 'FFF44336',
              iconCode: 0xe415,
            ),
            ResourceTypeConfig(
              id: 'excel',
              name: 'Full de Càlcul',
              colorHex: 'FF4CAF50',
              iconCode: 0xf02e,
            ),
            ResourceTypeConfig(
              id: 'image',
              name: 'Imatge',
              colorHex: 'FF9C27B0',
              iconCode: 0xe3b3,
            ),
            ResourceTypeConfig(
              id: 'other',
              name: 'Altre',
              colorHex: 'FF9E9E9E',
              iconCode: 0xe24d,
            ),
          ],
      fincaId: map['fincaId'],
      authorizedEmails:
          (map['authorizedEmails'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coverPhotoUrl: map['coverPhotoUrl'],
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
    List<TaskPhase>? taskPhases,
    List<ExpenseCategory>? expenseCategories,
    List<Bucket>? buckets,
    List<PermacultureZone>? permacultureZones,
    List<ResourceCategoryConfig>? resourceCategories,
    List<ResourceTypeConfig>? resourceTypes,
    String? fincaId,
    List<String>? authorizedEmails,
    String? coverPhotoUrl,
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
      taskPhases: taskPhases ?? this.taskPhases,
      expenseCategories: expenseCategories ?? this.expenseCategories,
      buckets: buckets ?? this.buckets,
      permacultureZones: permacultureZones ?? this.permacultureZones,
      resourceCategories: resourceCategories ?? this.resourceCategories,
      resourceTypes: resourceTypes ?? this.resourceTypes,
      fincaId: fincaId ?? this.fincaId,
      authorizedEmails: authorizedEmails ?? this.authorizedEmails,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
    );
  }
}

class PermacultureZone {
  final String id;
  final String name; // e.g. "Zona 1"
  final String colorHex;
  final String descriptionPdc;
  final List<GeoPoint> polygon;

  const PermacultureZone({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.descriptionPdc,
    required this.polygon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'descriptionPdc': descriptionPdc,
      'polygon': polygon, // Firestore handles List<GeoPoint>
    };
  }

  factory PermacultureZone.fromMap(Map<String, dynamic> map) {
    return PermacultureZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF4CAF50', // Default Green
      descriptionPdc: map['descriptionPdc'] ?? '',
      polygon:
          (map['polygon'] as List<dynamic>?)
              ?.map((e) => e as GeoPoint)
              .toList() ??
          [],
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
    this.rotationPatternId,
    this.rotationStartDate,
  });

  final String? rotationPatternId;
  final DateTime? rotationStartDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'cropType': cropType,
      'rotationPatternId': rotationPatternId,
      'rotationStartDate': rotationStartDate?.toIso8601String(),
    };
  }

  factory FarmZone.fromMap(Map<String, dynamic> map) {
    return FarmZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF2196F3', // Default Blue
      cropType: map['cropType'] ?? '',
      rotationPatternId: map['rotationPatternId'],
      rotationStartDate: map['rotationStartDate'] != null
          ? DateTime.parse(map['rotationStartDate'])
          : null,
    );
  }
}

class ExpenseCategory {
  final String id;
  final String name;
  final String colorHex;
  final int iconCode; // Store IconData codePoint

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconCode,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'colorHex': colorHex, 'iconCode': iconCode};
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF9E9E9E',
      iconCode: map['iconCode'] ?? 0xe3e3,
    );
  }
}

class TaskPhase {
  final String name;
  final String colorHex;
  final int iconCode; // Using int for IconData codePoint

  const TaskPhase({
    required this.name,
    required this.colorHex,
    required this.iconCode,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'colorHex': colorHex, 'iconCode': iconCode};
  }

  factory TaskPhase.fromMap(Map<String, dynamic> map) {
    return TaskPhase(
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF9E9E9E',
      iconCode: map['iconCode'] ?? 0xe88e, // Default: label
    );
  }

  // Smart migration for existing strings
  factory TaskPhase.fromLegacyString(String name) {
    String color = 'FF9E9E9E'; // Grey
    int icon = 0xe88e; // label

    final lower = name.toLowerCase();
    if (lower.contains('urgent')) {
      color = 'FFF44336'; // Red
      icon = 0xe6a5; // warning (priority_high)
    } else if (lower.contains('compra') || lower.contains('buying')) {
      color = 'FF2196F3'; // Blue
      icon = 0xe59c; // shopping_cart
    } else if (lower.contains('manteniment') || lower.contains('reparació')) {
      color = 'FFFF9800'; // Orange
      icon = 0xe182; // build
    } else if (lower.contains('planificació') || lower.contains('admin')) {
      color = 'FF9C27B0'; // Purple
      icon = 0xe0e7; // calendar_today
    } else if (lower.contains('feina') || lower.contains('treball')) {
      color = 'FF795548'; // Brown
      icon = 0xe934; // work ?? e8f9=work
    }

    return TaskPhase(name: name, colorHex: color, iconCode: icon);
  }
}

class ResourceCategoryConfig {
  final String id;
  final String name;
  final String colorHex;
  final int iconCode;

  const ResourceCategoryConfig({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconCode,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'colorHex': colorHex, 'iconCode': iconCode};
  }

  factory ResourceCategoryConfig.fromMap(Map<String, dynamic> map) {
    return ResourceCategoryConfig(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF9E9E9E',
      iconCode: map['iconCode'] ?? 0xe3e3,
    );
  }
}

class ResourceTypeConfig {
  final String id;
  final String name;
  final String colorHex;
  final int iconCode;

  const ResourceTypeConfig({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconCode,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'colorHex': colorHex, 'iconCode': iconCode};
  }

  factory ResourceTypeConfig.fromMap(Map<String, dynamic> map) {
    return ResourceTypeConfig(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? 'FF9E9E9E',
      iconCode: map['iconCode'] ?? 0xe3e3,
    );
  }
}
