import 'dart:math';

import '../../../trees/domain/entities/species.dart';
import '../../../trees/domain/entities/tree.dart';

class SimulationEngine {
  /// Calculates the simulated radius of a tree at a specific year.
  ///
  /// Formula: r(t) = r_base + (r_max - r_base) * sqrt(t / T_full)
  static double calculateRadius({
    required Tree tree,
    required Species species,
    required double years,
  }) {
    if (species.adultDiameter <= 0) return 0.0;

    // 1. Determine T_full (Time to Full Maturity)
    double timeToFull;
    switch (species.growthRate.toLowerCase()) {
      case 'ràpid':
      case 'rapid':
        timeToFull = 10.0;
        break;
      case 'lent':
      case 'slow':
        timeToFull = 25.0;
        break;
      case 'mig':
      case 'medium':
      default:
        timeToFull = 15.0;
        break;
    }

    // 2. Determine r_base (Initial Radius based on Format)
    double baseRadius = 0.3; // Default for 3L, Arrel nua, Estaca, etc.
    final format = tree.plantingFormat?.toLowerCase() ?? '';

    if (format.contains('alveol') ||
        format.contains('alvèol') ||
        format.contains('forestal')) {
      baseRadius = 0.1;
    } else if (format.contains('10l') || format.contains('20l')) {
      baseRadius = 0.5;
    } else if (format.contains('3l')) {
      baseRadius = 0.3;
    } else if (format.contains('llavor')) {
      baseRadius = 0.05;
    }

    // 3. Determine r_max (Adult Radius)
    final maxRadius = species.adultDiameter / 2;

    // Sanity check: if base is larger than max (impossible ideally), cap it
    if (baseRadius > maxRadius) baseRadius = maxRadius;

    // 4. Calculate Growth Factor (Square Root Curve)
    // Clamp time fraction to 0.0 - 1.0
    // If years > timeToFull, it stays at max size (1.0)
    final timeFraction = (years / timeToFull).clamp(0.0, 1.0);
    final growthFactor = sqrt(timeFraction);

    // 5. Apply Formula
    final currentRadius = baseRadius + (maxRadius - baseRadius) * growthFactor;

    return currentRadius;
  }
}
