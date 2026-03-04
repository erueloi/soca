import '../entities/planta_hort.dart';
import '../entities/plantacio_historica.dart';
import '../entities/placed_plant.dart';

enum HortStatus { aliat, conflicte, riscFamilia, neutre }

class HortScore {
  final HortStatus status;
  final int score;
  final String reason;

  HortScore({required this.status, required this.score, required this.reason});
}

/// Severity level for rotation alerts
enum RotacioNivell { alt, mitja, optim }

/// A rotation alert produced by the validation engine
class RotacioAlerta {
  final RotacioNivell nivell;
  final String titol;
  final String missatge;

  const RotacioAlerta({
    required this.nivell,
    required this.titol,
    required this.missatge,
  });
}

class AssistentHort {
  // --- Neighbour validation (existing) ---
  static HortScore validarVeinatge(PlantaHort a, PlantaHort b) {
    if (a.enemics.contains(b.nomComu) || b.enemics.contains(a.nomComu)) {
      return HortScore(
        status: HortStatus.conflicte,
        score: -1,
        reason: 'Incompatibilitat detectada (Al·lelopatia negativa).',
      );
    }

    if (a.familiaBotanica == b.familiaBotanica &&
        a.familiaBotanica.isNotEmpty) {
      return HortScore(
        status: HortStatus.riscFamilia,
        score: 0,
        reason:
            'Mateixa família botànica (${a.familiaBotanica}). Risc de plagues compartides.',
      );
    }

    if (a.aliats.contains(b.nomComu) || b.aliats.contains(a.nomComu)) {
      return HortScore(
        status: HortStatus.aliat,
        score: 1,
        reason: 'Associació beneficiosa (Aliats).',
      );
    }

    return HortScore(
      status: HortStatus.neutre,
      score: 0,
      reason: 'No s\'han detectat interaccions significatives.',
    );
  }

  // --- Rotation validation (new) ---

  /// Validates whether placing [novaPlanta] on a bed whose last archived
  /// cycle is [ultimRegistre] respects healthy rotation rules.
  /// [ultimaPlanta] is the resolved PlantaHort of the last main crop.
  /// Returns a list of alerts (empty = all clear).
  static List<RotacioAlerta> validarRotacio({
    required PlantaHort novaPlanta,
    PlantaHort? ultimaPlanta,
    PlantacioHistorica? ultimRegistre,
  }) {
    if (ultimaPlanta == null || ultimRegistre == null) {
      return []; // No history = no conflict possible
    }

    final alertes = <RotacioAlerta>[];

    // Regla 1: Mateixa Família Botànica
    if (novaPlanta.familiaBotanica == ultimaPlanta.familiaBotanica &&
        novaPlanta.familiaBotanica.isNotEmpty) {
      alertes.add(
        RotacioAlerta(
          nivell: RotacioNivell.alt,
          titol: '⚠️ Mateixa Família Botànica',
          missatge:
              'La planta "${novaPlanta.nomComu}" pertany a la mateixa família '
              '(${novaPlanta.familiaBotanica}) que l\'últim cultiu "${ultimaPlanta.nomComu}". '
              'Risc alt de plagues acumulades al sòl.',
        ),
      );
    }

    // Regla 2a: Dues "Molt Exigent" seguides sense "Millorant" entremig
    if (novaPlanta.exigenciaNutrients == HortExigenciaNutrients.moltExigent &&
        ultimaPlanta.exigenciaNutrients == HortExigenciaNutrients.moltExigent) {
      alertes.add(
        RotacioAlerta(
          nivell: RotacioNivell.mitja,
          titol: '🔄 Dues Exhauridores Seguides',
          missatge:
              '"${novaPlanta.nomComu}" i "${ultimaPlanta.nomComu}" són ambdues molt '
              'exigents en nutrients. Es recomana un cultiu millorant (lleguminosa) entremig.',
        ),
      );
    }

    // Regla 2b: Mateixa Part Comestible seguida
    if (novaPlanta.partComestible == ultimaPlanta.partComestible) {
      alertes.add(
        RotacioAlerta(
          nivell: RotacioNivell.mitja,
          titol: '🔄 Mateixa Part Comestible',
          missatge:
              '"${novaPlanta.nomComu}" (${novaPlanta.partComestible.label}) repeteix '
              'la mateixa part comestible que "${ultimaPlanta.nomComu}". '
              'Alternar Arrel-Fulla-Fruit-Llegum millora la salut del sòl.',
        ),
      );
    }

    return alertes;
  }

  /// Quick health check for a bed based on its history and a candidate plant.
  /// Returns [RotacioNivell.optim] if no issues, otherwise the worst level found.
  static RotacioNivell saludBancal({
    required List<PlantacioHistorica> historic,
    required int bedIndex,
    required List<PlantaHort> plants,
    required List<PlacedPlant> currentPlants,
    required double Function(double) getBedStartCm,
    required double Function(double) getBedEndCm,
    int? Function(double xMeters)? getBedIndexFromX,
  }) {
    // Find last archived record for this bed
    final bedRecords = historic.where((h) => h.bedIndex == bedIndex).toList()
      ..sort((a, b) => b.dataFinalitzacio.compareTo(a.dataFinalitzacio));

    if (bedRecords.isEmpty) return RotacioNivell.optim;

    final lastRecord = bedRecords.first;
    if (lastRecord.mainCropId == null) return RotacioNivell.optim;

    // Find current species in this bed
    final currentSpeciesIds = <String>{};
    for (var p in currentPlants) {
      if (getBedIndexFromX != null) {
        double centerXCm = p.x + p.width / 2;
        double centerXM = centerXCm / 100.0;
        int? idx = getBedIndexFromX(centerXM);
        if (idx == bedIndex) {
          currentSpeciesIds.add(p.speciesId);
        }
      }
    }

    if (currentSpeciesIds.isEmpty) return RotacioNivell.optim;

    // Resolve last main crop
    PlantaHort? lastPlant;
    try {
      lastPlant = plants.firstWhere((p) => p.id == lastRecord.mainCropId);
    } catch (_) {
      return RotacioNivell.optim;
    }

    RotacioNivell worst = RotacioNivell.optim;
    for (var speciesId in currentSpeciesIds) {
      PlantaHort? currentPlant;
      try {
        currentPlant = plants.firstWhere((p) => p.id == speciesId);
      } catch (_) {
        continue;
      }

      final alertes = validarRotacio(
        novaPlanta: currentPlant,
        ultimaPlanta: lastPlant,
        ultimRegistre: lastRecord,
      );

      for (var a in alertes) {
        if (a.nivell == RotacioNivell.alt) return RotacioNivell.alt;
        if (a.nivell == RotacioNivell.mitja) worst = RotacioNivell.mitja;
      }
    }

    return worst;
  }
}
