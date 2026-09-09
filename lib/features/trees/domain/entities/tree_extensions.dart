import 'package:flutter/material.dart';
import 'tree.dart';

extension TreeWaterStatus on Tree {
  bool get needsWater {
    if (isMature) return false;
    return (soilBalance ?? 0) < -15;
  }

  /// Dosi recomanada de reg de suport (gota a gota):
  /// - Arbre estàndard (1 degoter de 4 L/h) -> 2h = 8 L
  /// - Arbre gran (2 degoters de 4 L/h) -> 2h = 16 L
  /// Si el sòl està saciat (> -5 mm) o l'arbre és madur/arrelat: 0 L
  int get waterNeedLiters {
    if (isMature || status == 'Mort' || status == 'Perdut') return 0;
    final balance = soilBalance ?? 0.0;
    if (balance >= -5) return 0;

    final rate = totalDripRate > 0 ? totalDripRate : 4.0;
    return (rate * 2.0).round();
  }

  /// Hores recomanades d'obertura del reg gota a gota
  double get recommendedWateringHours {
    if (waterNeedLiters == 0) return 0.0;
    return 2.0;
  }

  // Colors based on user request:
  // Green: Critical (< -15) - "Go Water"
  // Orange: Wet (> -5) - "Stop"
  // Grey: Normal

  Color get waterStatusColor {
    // Show water status for Viable AND Sick trees. Hide for Dead/Lost.
    if (status == 'Mort' || status == 'Perdut') return Colors.grey;
    if (isMature) return Colors.green;
    if (soilBalance == null) return Colors.grey;

    if (soilBalance! < -15) return Colors.red; // Estrès Hídric (Urgent)
    if (soilBalance! > -5) return Colors.green; // No regar (Bé)
    return Colors.amber; // Reg Opcional (Atenció)
  }

  String get waterStatusText {
    if (status == 'Mort' || status == 'Perdut') return 'No viable';
    if (isMature) return 'Arbre Arrelat / Sòl Profund';
    if (soilBalance == null) return 'Desconegut';

    if (soilBalance! < -15) return 'Estrès Hídric';
    if (soilBalance! > -5) return 'No regar';
    return 'Reg Opcional';
  }
}
