import '../entities/hort_rotation_pattern.dart';
import '../entities/planta_hort.dart';

class RotationService {
  /// Calculates the current stage of the rotation based on start date and current date.
  /// Assumes a 2-year cycle with 4 stages (6 months each).
  HortRotationStage getCurrentStage(
    HortRotationPattern pattern,
    DateTime startDate,
    DateTime currentDate,
  ) {
    if (pattern.stages.isEmpty) {
      return const HortRotationStage(
        stageIndex: -1,
        label: 'Patró Buit',
        exigency: HortExigenciaNutrients.mitjanamentExigent,
      );
    }

    final diff = currentDate.difference(startDate).inDays;
    // 6 months approx 182 days
    const stageDurationDays = 182;
    const totalCycleDays = stageDurationDays * 4; // 2 years approx

    // Calculate days into the current cycle
    final daysIntoCycle = diff % totalCycleDays;

    // Determine stage index (0 to 3)
    // If negative difference (startDate in future), it defaults to 0 via modular arithmetic behavior in dart?
    // Dart % operator can return negative. Let's handle it.

    int stageIndex = (daysIntoCycle / stageDurationDays).floor();

    if (diff < 0) {
      // Start date in future, show first stage
      stageIndex = 0;
    }

    // Safety clamp
    stageIndex = stageIndex.clamp(0, 3);

    // Map existing stages. If pattern has fewer than 4 stages, wrap around or clamp?
    // User defined fixed 4 stages structure.
    if (stageIndex >= pattern.stages.length) {
      return pattern.stages.last;
    }

    return pattern.stages[stageIndex];
  }

  /// Returns a status string e.g. "Mes 3 de 6"
  String getStageProgressStatus(DateTime startDate, DateTime currentDate) {
    final diff = currentDate.difference(startDate).inDays;
    if (diff < 0) return 'Pendent d\'inici';

    const stageDurationDays = 182;
    final daysIntoStage = diff % stageDurationDays;
    final month = (daysIntoStage / 30).ceil();

    return 'Mes $month de 6';
  }
}
