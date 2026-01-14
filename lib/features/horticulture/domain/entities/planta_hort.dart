import 'package:flutter/material.dart';

enum HortPartComestible {
  arrel,
  fulla,
  fruit,
  florLlegum;

  String get label {
    switch (this) {
      case HortPartComestible.arrel:
        return 'Arrel';
      case HortPartComestible.fulla:
        return 'Fulla';
      case HortPartComestible.fruit:
        return 'Fruit';
      case HortPartComestible.florLlegum:
        return 'Flor/Llegum';
    }
  }

  IconData get icon {
    switch (this) {
      case HortPartComestible.arrel:
        return Icons.grass; // Placeholder for root
      case HortPartComestible.fulla:
        return Icons.eco;
      case HortPartComestible.fruit:
        return Icons.local_florist; // Fruit often comes from flower
      case HortPartComestible.florLlegum:
        return Icons.spa; // Legumeish
    }
  }
}

enum HortExigenciaNutrients {
  millorant, // Nitrogen fixers (legumes)
  consumidora, // Moderate
  exhauridora; // Heavy feeders (solanaceae usually)

  String get label {
    switch (this) {
      case HortExigenciaNutrients.millorant:
        return 'Millorant (N)';
      case HortExigenciaNutrients.consumidora:
        return 'Consumidora';
      case HortExigenciaNutrients.exhauridora:
        return 'Exhauridora';
    }
  }

  Color get color {
    switch (this) {
      case HortExigenciaNutrients.millorant:
        return Colors.green[800]!;
      case HortExigenciaNutrients.consumidora:
        return Colors.orange[700]!;
      case HortExigenciaNutrients.exhauridora:
        return Colors.red[800]!;
    }
  }
}

class PlantaHort {
  final String id;
  final String nomComu;
  final String? nomCientific;
  final String familiaBotanica; // e.g., "Solanàcies"
  final List<String> aliats; // IDs or Names
  final List<String> enemics; // IDs or Names

  // Permaculture specific
  final HortPartComestible partComestible;
  final HortExigenciaNutrients exigenciaNutrients;
  final double distanciaPlantacio; // cm

  final double distanciaLinies; // cm

  final String funcio; // Still useful for generic tags like "Repulsiu"
  final String
  marcPlantacio; // Text desc (e.g. "40x40 cm") - Keep for backwards compat or UI display
  final Color color;

  const PlantaHort({
    required this.id,
    required this.nomComu,
    this.nomCientific,
    required this.familiaBotanica,
    this.aliats = const [],
    this.enemics = const [],
    this.partComestible = HortPartComestible.fruit,
    this.exigenciaNutrients = HortExigenciaNutrients.consumidora,
    this.distanciaPlantacio = 30.0,
    this.distanciaLinies = 40.0,
    this.funcio = 'Comestible',
    this.marcPlantacio = '30x30 cm',
    this.color = Colors.green,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomComu': nomComu,
      'nomCientific': nomCientific,
      'familiaBotanica': familiaBotanica,
      'aliats': aliats,
      'enemics': enemics,
      'partComestible': partComestible.name,
      'exigenciaNutrients': exigenciaNutrients.name,
      'distanciaPlantacio': distanciaPlantacio,
      'distanciaLinies': distanciaLinies,
      'funcio': funcio,
      'marcPlantacio': marcPlantacio,
      'color': color.toARGB32(),
    };
  }

  factory PlantaHort.fromMap(Map<String, dynamic> map, [String? id]) {
    // Handle Enum parsing with safe defaults
    HortPartComestible parsePart(String? val) {
      return HortPartComestible.values.firstWhere(
        (e) => e.name == val,
        orElse: () => HortPartComestible.fruit,
      );
    }

    HortExigenciaNutrients parseExigencia(String? val) {
      return HortExigenciaNutrients.values.firstWhere(
        (e) => e.name == val,
        orElse: () => HortExigenciaNutrients.consumidora,
      );
    }

    return PlantaHort(
      id: id ?? map['id'] ?? '',
      nomComu: map['nomComu'] ?? '',
      nomCientific: map['nomCientific'],
      familiaBotanica: map['familiaBotanica'] ?? 'Desconeguda',
      aliats: List<String>.from(map['aliats'] ?? []),
      enemics: List<String>.from(map['enemics'] ?? []),
      partComestible: parsePart(map['partComestible']),
      exigenciaNutrients: parseExigencia(map['exigenciaNutrients']),
      distanciaPlantacio: (map['distanciaPlantacio'] ?? 30.0).toDouble(),
      distanciaLinies: (map['distanciaLinies'] ?? 40.0).toDouble(),
      funcio: map['funcio'] ?? 'Comestible',
      marcPlantacio: map['marcPlantacio'] ?? '30x30 cm',
      color: Color(map['color'] ?? 0xFF4CAF50),
    );
  }

  PlantaHort copyWith({
    String? id,
    String? nomComu,
    String? nomCientific,
    String? familiaBotanica,
    List<String>? aliats,
    List<String>? enemics,
    HortPartComestible? partComestible,
    HortExigenciaNutrients? exigenciaNutrients,
    double? distanciaPlantacio,
    double? distanciaLinies,
    String? funcio,
    String? marcPlantacio,
    Color? color,
  }) {
    return PlantaHort(
      id: id ?? this.id,
      nomComu: nomComu ?? this.nomComu,
      nomCientific: nomCientific ?? this.nomCientific,
      familiaBotanica: familiaBotanica ?? this.familiaBotanica,
      aliats: aliats ?? this.aliats,
      enemics: enemics ?? this.enemics,
      partComestible: partComestible ?? this.partComestible,
      exigenciaNutrients: exigenciaNutrients ?? this.exigenciaNutrients,
      distanciaPlantacio: distanciaPlantacio ?? this.distanciaPlantacio,
      distanciaLinies: distanciaLinies ?? this.distanciaLinies,
      funcio: funcio ?? this.funcio,
      marcPlantacio: marcPlantacio ?? this.marcPlantacio,
      color: color ?? this.color,
    );
  }
}
