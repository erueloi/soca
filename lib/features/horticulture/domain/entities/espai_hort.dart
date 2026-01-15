import 'dart:convert';
import 'garden_layout_config.dart';
import 'package:latlong2/latlong.dart';

class EspaiHort {
  final String id;
  final String nom;

  // Physical properties
  final LatLng center;
  final double width; // meters (X axis in grid)
  final double length; // meters (Y axis in grid)
  final double
  rotationAngle; // degrees, orientation on map? Default 0 (North aligned?)

  // Grid properties
  final double gridCellSize;
  final Map<String, String> gridState; // "row_col": "speciesId"

  // Layout Configuration (Beds/Paths)
  final GardenLayoutConfig? layoutConfig;

  EspaiHort({
    required this.id,
    required this.nom,
    required this.center,
    required this.width,
    required this.length,
    this.rotationAngle = 0.0,
    this.gridCellSize = 0.2, // 20cm default
    this.gridState = const {},
    this.layoutConfig,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'center': {'lat': center.latitude, 'lng': center.longitude},
      'width': width,
      'length': length,
      'rotationAngle': rotationAngle,
      'gridCellSize': gridCellSize,
      'gridState': gridState,

      'layoutConfig': layoutConfig?.toMap(),
    };
  }

  // Overload toMap for Firestore if needed (handling gridState as direct Map)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'nom': nom,
      'center': {'lat': center.latitude, 'lng': center.longitude},
      'width': width,
      'length': length,
      'rotationAngle': rotationAngle,
      'gridCellSize': gridCellSize,
      'gridState': gridState,

      'layoutConfig': layoutConfig?.toMap(),
    };
  }

  factory EspaiHort.fromMap(Map<String, dynamic> map, [String? id]) {
    final centerMap =
        map['center'] as Map<String, dynamic>? ??
        {'lat': 41.5, 'lng': 0.9}; // Default fallback

    // Grid state parsing: support both Map and JSON String (legacy/migration safety)
    Map<String, String> parsedGrid = {};
    if (map['gridState'] is Map) {
      parsedGrid = Map<String, String>.from(map['gridState']);
    } else if (map['gridState'] is String) {
      try {
        parsedGrid = Map<String, String>.from(jsonDecode(map['gridState']));
      } catch (e) {
        // ignore
      }
    }

    return EspaiHort(
      id: id ?? map['id'] ?? '',
      nom: map['nom'] ?? '',
      center: LatLng(centerMap['lat'] ?? 41.5, centerMap['lng'] ?? 0.9),
      width: (map['width'] as num?)?.toDouble() ?? 1.0,
      length: (map['length'] as num?)?.toDouble() ?? 1.0,
      rotationAngle: (map['rotationAngle'] as num?)?.toDouble() ?? 0.0,
      gridCellSize: (map['gridCellSize'] as num?)?.toDouble() ?? 0.2,
      gridState: parsedGrid,
      layoutConfig: map['layoutConfig'] != null
          ? GardenLayoutConfig.fromMap(
              Map<String, dynamic>.from(map['layoutConfig']),
            )
          : null,
    );
  }

  EspaiHort copyWith({
    String? nom,
    LatLng? center,
    double? width,
    double? length,
    double? rotationAngle,
    double? gridCellSize,
    Map<String, String>? gridState,
    GardenLayoutConfig? layoutConfig,
  }) {
    return EspaiHort(
      id: id, // ID cannot change
      nom: nom ?? this.nom,
      center: center ?? this.center,
      width: width ?? this.width,
      length: length ?? this.length,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      gridCellSize: gridCellSize ?? this.gridCellSize,
      gridState: gridState ?? this.gridState,
      layoutConfig: layoutConfig ?? this.layoutConfig,
    );
  }
}
