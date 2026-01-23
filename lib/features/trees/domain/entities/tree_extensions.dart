import 'package:flutter/material.dart';
import 'tree.dart';

extension TreeWaterStatus on Tree {
  bool get needsWater => (soilBalance ?? 0) < -15;

  // Colors based on user request:
  // Green: Critical (< -15) - "Go Water"
  // Orange: Wet (> -5) - "Stop"
  // Grey: Normal

  Color get waterStatusColor {
    // Show water status for Viable AND Sick trees. Hide for Dead/Lost.
    if (status == 'Mort' || status == 'Perdut') return Colors.grey;
    if (soilBalance == null) return Colors.grey;

    if (soilBalance! < -15) return Colors.red; // Estrès Hídric (Urgent)
    if (soilBalance! > -5) return Colors.green; // No regar (Bé)
    return Colors.amber; // Reg Opcional (Atenció)
  }

  String get waterStatusText {
    if (status == 'Mort' || status == 'Perdut') return 'No viable';
    if (soilBalance == null) return 'Desconegut';

    if (soilBalance! < -15) return 'Estrès Hídric';
    if (soilBalance! > -5) return 'No regar';
    return 'Reg Opcional';
  }
}
