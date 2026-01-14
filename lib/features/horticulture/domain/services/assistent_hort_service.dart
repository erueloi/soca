import '../entities/planta_hort.dart';

enum HortStatus { aliat, conflicte, riscFamilia, neutre }

class HortScore {
  final HortStatus status;
  final int score;
  final String reason;

  HortScore({required this.status, required this.score, required this.reason});
}

class AssistentHort {
  // 3. Validation Logic
  static HortScore validarVeinatge(PlantaHort a, PlantaHort b) {
    // 1. Check for Conflicts (Enemies)
    // Check if B is in A's enemy list or vice versa
    if (a.enemics.contains(b.nomComu) || b.enemics.contains(a.nomComu)) {
      return HortScore(
        status: HortStatus.conflicte,
        score: -1,
        reason: 'Incompatibilitat detectada (Al·lelopatia negativa).',
      );
    }

    // 2. Check for Family Risk (Same Family)
    // Exclude if they are allies (rare but possible exceptions)
    if (a.familiaBotanica == b.familiaBotanica &&
        a.familiaBotanica.isNotEmpty) {
      return HortScore(
        status: HortStatus.riscFamilia,
        score: 0,
        reason:
            'Mateixa família botànica (${a.familiaBotanica}). Risc de plagues compartides.',
      );
    }

    // 3. Check for Allies (Friends)
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

  // 2. Magic Seed Data logic moved to HortRepository.initBibliotecaRegenerativa
}
