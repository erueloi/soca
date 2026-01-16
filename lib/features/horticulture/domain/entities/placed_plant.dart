import 'package:uuid/uuid.dart';

class PlacedPlant {
  final String id;
  final String speciesId;
  final double x; // cm (from left)
  final double y; // cm (from top)
  final double width; // cm (vital space width)
  final double height; // cm (vital space height)
  final DateTime placedAt;

  const PlacedPlant({
    required this.id,
    required this.speciesId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.placedAt,
  });

  factory PlacedPlant.create({
    required String speciesId,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    return PlacedPlant(
      id: const Uuid().v4(),
      speciesId: speciesId,
      x: x,
      y: y,
      width: width,
      height: height,
      placedAt: DateTime.now(),
    );
  }

  PlacedPlant copyWith({
    String? id,
    String? speciesId,
    double? x,
    double? y,
    double? width,
    double? height,
    DateTime? placedAt,
  }) {
    return PlacedPlant(
      id: id ?? this.id,
      speciesId: speciesId ?? this.speciesId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      placedAt: placedAt ?? this.placedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'speciesId': speciesId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'placedAt': placedAt.millisecondsSinceEpoch,
    };
  }

  factory PlacedPlant.fromMap(Map<String, dynamic> map) {
    return PlacedPlant(
      id: map['id'] ?? '',
      speciesId: map['speciesId'] ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 30.0,
      height: (map['height'] as num?)?.toDouble() ?? 30.0,
      placedAt: map['placedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['placedAt'])
          : DateTime.now(),
    );
  }
}
