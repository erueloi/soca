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
  moltExigent,
  mitjanamentExigent,
  pocExigent,
  millorant;

  String get label {
    switch (this) {
      case HortExigenciaNutrients.moltExigent:
        return 'Molt Exigent (Exhauridora)';
      case HortExigenciaNutrients.mitjanamentExigent:
        return 'Mitjanament Exigent';
      case HortExigenciaNutrients.pocExigent:
        return 'Poc Exigent';
      case HortExigenciaNutrients.millorant:
        return 'Millorant (Fixadora N)';
    }
  }

  Color get color {
    switch (this) {
      case HortExigenciaNutrients.moltExigent:
        return Colors.red;
      case HortExigenciaNutrients.mitjanamentExigent:
        return Colors.orange;
      case HortExigenciaNutrients.pocExigent:
        return Colors.yellow.shade700;
      case HortExigenciaNutrients.millorant:
        return Colors.green;
    }
  }
}

enum HortTipusSembra {
  directa,
  trasplantament;

  String get label {
    switch (this) {
      case HortTipusSembra.directa:
        return 'Sembra Directa';
      case HortTipusSembra.trasplantament:
        return 'Trasplantament';
    }
  }
}

enum HortGrupRotacio {
  fruit, // C1
  fulla, // C2
  arrel, // C3
  millorant; // C4

  String get label {
    switch (this) {
      case HortGrupRotacio.fruit:
        return 'Grup 1: Fruit (Exhauridora)';
      case HortGrupRotacio.fulla:
        return 'Grup 2: Fulla (Consumidora)';
      case HortGrupRotacio.arrel:
        return 'Grup 3: Arrel (Consumidora)';
      case HortGrupRotacio.millorant:
        return 'Grup 4: Millorant (Llegum)';
    }
  }

  Color get color {
    switch (this) {
      case HortGrupRotacio.fruit:
        return Colors.red;
      case HortGrupRotacio.fulla:
        return Colors.green;
      case HortGrupRotacio.arrel:
        return Colors.orange;
      case HortGrupRotacio.millorant:
        return Colors.purple;
    }
  }
}

enum HortViaMetabolica {
  c3,
  c4,
  cam;

  String get label {
    switch (this) {
      case HortViaMetabolica.c3:
        return 'C3 (Majoritaris)';
      case HortViaMetabolica.c4:
        return 'C4 (Clima Càlid)';
      case HortViaMetabolica.cam:
        return 'CAM (Suculentes/Cactus)';
    }
  }
}

class PlantaHort {
  final String id;
  final String nomComu;
  final String? nomCientific;
  final String familiaBotanica;
  final List<String> aliats;
  final List<String> enemics;
  final String? fincaId;

  // Permaculture specific
  final HortPartComestible partComestible;
  final HortExigenciaNutrients exigenciaNutrients;
  final double distanciaPlantacio; // cm
  final double distanciaLinies; // cm
  final String funcio;
  final String marcPlantacio;
  final Color color;

  // New Agronomic Fields
  final double rendiment; // kg/m2
  final int diesEnCamp; // dies cicle
  final HortTipusSembra tipusSembra;
  final HortGrupRotacio grupRotacio;
  final HortViaMetabolica viaMetabolica;

  const PlantaHort({
    required this.id,
    required this.nomComu,
    this.nomCientific,
    required this.familiaBotanica,
    this.aliats = const [],
    this.enemics = const [],
    this.fincaId,
    this.partComestible = HortPartComestible.fruit,
    this.exigenciaNutrients = HortExigenciaNutrients.mitjanamentExigent,
    this.distanciaPlantacio = 30.0,
    this.distanciaLinies = 40.0,
    this.funcio = 'Comestible',
    this.marcPlantacio = '30x40 cm',
    this.color = Colors.green,
    this.rendiment = 0.0,
    this.diesEnCamp = 90,
    this.tipusSembra = HortTipusSembra.trasplantament,
    this.grupRotacio = HortGrupRotacio.fulla,
    this.viaMetabolica = HortViaMetabolica.c3,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomComu': nomComu,
      'nomCientific': nomCientific,
      'familiaBotanica': familiaBotanica,
      'aliats': aliats,
      'enemics': enemics,
      'fincaId': fincaId,
      'partComestible': partComestible.name,
      'exigenciaNutrients': exigenciaNutrients.name,
      'distanciaPlantacio': distanciaPlantacio,
      'distanciaLinies': distanciaLinies,
      'funcio': funcio,
      'marcPlantacio': marcPlantacio,
      'color': color.toARGB32(),
      'rendiment': rendiment,
      'diesEnCamp': diesEnCamp,
      'tipusSembra': tipusSembra.name,
      'grupRotacio': grupRotacio.name,
      'viaMetabolica': viaMetabolica.name,
    };
  }

  factory PlantaHort.fromMap(Map<String, dynamic> map, [String? id]) {
    HortPartComestible parsePart(String? val) =>
        HortPartComestible.values.firstWhere(
          (e) => e.name == val,
          orElse: () => HortPartComestible.fruit,
        );
    HortExigenciaNutrients parseExigencia(String? val) {
      // Legacy mapping
      if (val == 'exhauridora') return HortExigenciaNutrients.moltExigent;
      if (val == 'consumidora') {
        return HortExigenciaNutrients.mitjanamentExigent;
      }

      return HortExigenciaNutrients.values.firstWhere(
        (e) => e.name == val,
        orElse: () => HortExigenciaNutrients.mitjanamentExigent,
      );
    }

    HortTipusSembra parseSembra(String? val) =>
        HortTipusSembra.values.firstWhere(
          (e) => e.name == val,
          orElse: () => HortTipusSembra.trasplantament,
        );
    HortGrupRotacio parseRotacio(String? val) => HortGrupRotacio.values
        .firstWhere((e) => e.name == val, orElse: () => HortGrupRotacio.fulla);
    HortViaMetabolica parseVia(String? val) => HortViaMetabolica.values
        .firstWhere((e) => e.name == val, orElse: () => HortViaMetabolica.c3);

    return PlantaHort(
      id: id ?? map['id'] ?? '',
      nomComu: map['nomComu'] ?? '',
      nomCientific: map['nomCientific'],
      familiaBotanica: map['familiaBotanica'] ?? 'Desconeguda',
      aliats: List<String>.from(map['aliats'] ?? []),
      enemics: List<String>.from(map['enemics'] ?? []),
      fincaId: map['fincaId'],
      partComestible: parsePart(map['partComestible']),
      exigenciaNutrients: parseExigencia(map['exigenciaNutrients']),
      distanciaPlantacio: (map['distanciaPlantacio'] ?? 30.0).toDouble(),
      distanciaLinies: (map['distanciaLinies'] ?? 40.0).toDouble(),
      funcio: map['funcio'] ?? 'Comestible',
      marcPlantacio: map['marcPlantacio'] ?? '30x40 cm',
      color: Color(map['color'] ?? 0xFF4CAF50),
      rendiment: (map['rendiment'] ?? 0.0).toDouble(),
      diesEnCamp: map['diesEnCamp'] ?? 90,
      tipusSembra: parseSembra(map['tipusSembra']),
      grupRotacio: parseRotacio(map['grupRotacio']),
      viaMetabolica: parseVia(map['viaMetabolica']),
    );
  }

  PlantaHort copyWith({
    String? id,
    String? nomComu,
    String? nomCientific,
    String? familiaBotanica,
    List<String>? aliats,
    List<String>? enemics,
    String? fincaId,
    HortPartComestible? partComestible,
    HortExigenciaNutrients? exigenciaNutrients,
    double? distanciaPlantacio,
    double? distanciaLinies,
    String? funcio,
    String? marcPlantacio,
    Color? color,
    double? rendiment,
    int? diesEnCamp,
    HortTipusSembra? tipusSembra,
    HortGrupRotacio? grupRotacio,
    HortViaMetabolica? viaMetabolica,
  }) {
    return PlantaHort(
      id: id ?? this.id,
      nomComu: nomComu ?? this.nomComu,
      nomCientific: nomCientific ?? this.nomCientific,
      familiaBotanica: familiaBotanica ?? this.familiaBotanica,
      aliats: aliats ?? this.aliats,
      enemics: enemics ?? this.enemics,
      fincaId: fincaId ?? this.fincaId,
      partComestible: partComestible ?? this.partComestible,
      exigenciaNutrients: exigenciaNutrients ?? this.exigenciaNutrients,
      distanciaPlantacio: distanciaPlantacio ?? this.distanciaPlantacio,
      distanciaLinies: distanciaLinies ?? this.distanciaLinies,
      funcio: funcio ?? this.funcio,
      marcPlantacio: marcPlantacio ?? this.marcPlantacio,
      color: color ?? this.color,
      rendiment: rendiment ?? this.rendiment,
      diesEnCamp: diesEnCamp ?? this.diesEnCamp,
      tipusSembra: tipusSembra ?? this.tipusSembra,
      grupRotacio: grupRotacio ?? this.grupRotacio,
      viaMetabolica: viaMetabolica ?? this.viaMetabolica,
    );
  }
}
