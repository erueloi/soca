import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/meteocat_service.dart';
import '../../../climate/domain/climate_model.dart';
import '../entities/espai_hort.dart';
import '../entities/garden_layout_config.dart';

import '../../../climate/data/repositories/climate_repository.dart';
import '../../../climate/presentation/providers/climate_provider.dart';

class GardenIrrigationService {
  final MeteocatService _meteocatService;
  final ClimateRepository _climateRepository;

  GardenIrrigationService(this._meteocatService, this._climateRepository);

  /// Synchronizes the soil balance for all beds in an EspaiHort up to today.
  /// Returns a new instance of EspaiHort with updated bed configurations.
  Future<EspaiHort> syncSoilBalance(EspaiHort espai) async {
    final config = espai.layoutConfig;
    if (config == null || config.beds.isEmpty) return espai;

    // Safety: Abort if we don't know the finca yet (Prevents race-condition fallbacks)
    if (_climateRepository.fincaId == null) {
        debugPrint('   [Reg Debug] Aborting Sync: Finca ID is not yet loaded.');
        return espai;
    }

    final now = DateTime.now();
    final today = _normalizeDate(now);

    // We only need to fetch history if there's any bed severely out of date.
    DateTime? earliestUpdateDate;

    for (var entry in config.beds.entries) {
      int bedIndex = entry.key;
      BedData bed = entry.value;

      // Calculate oldestPlacedAt for this bed early to know how far back to look
      DateTime? oldestPlacedAt;
      double bedStartX = config.getBedStartX(bedIndex) * 100;
      double bedEndX = bedStartX + config.getBedWidth(bedIndex) * 100;

      for (var p in espai.placedPlants) {
        if (p.placedAt == null) continue;
        double cx = p.x + p.width / 2;
        if (cx >= bedStartX && cx < bedEndX) {
          if (oldestPlacedAt == null || p.placedAt!.isBefore(oldestPlacedAt)) {
            oldestPlacedAt = _normalizeDate(p.placedAt!);
          }
        }
      }

      // If bed needs sync
      if (bed.irrigationMethod == IrrigationMethod.drip && bed.cabalSistemaLitersHora == null) {
          continue; 
      }

      DateTime lastUpdate;
      if (bed.soilBalance == null) {
          lastUpdate = oldestPlacedAt ?? today;
      } else {
          lastUpdate = _normalizeDate(bed.lastBalanceUpdate ?? today);
          
          final balanceVal = bed.soilBalance ?? 0.0;
          // Legacy check: common multiples of fallbacks
          final isLegacy = balanceVal < -0.1 && (balanceVal * 10).round() % 4 == 0;
          final isRecent = oldestPlacedAt != null && today.difference(oldestPlacedAt).inDays < 7;
          
          if (isLegacy || (isRecent && balanceVal < -0.1) || (oldestPlacedAt != null && !lastUpdate.isAfter(oldestPlacedAt)) || (oldestPlacedAt == null && balanceVal < -0.1)) {
              lastUpdate = oldestPlacedAt ?? today;
          }
      }

      if (lastUpdate.isBefore(today)) {
        if (earliestUpdateDate == null ||
            lastUpdate.isBefore(earliestUpdateDate)) {
          earliestUpdateDate = lastUpdate;
        }
      }
    }

    if (earliestUpdateDate == null ||
        earliestUpdateDate.isAtSameMomentAs(today)) {
      return espai;
    }

    // 1. Fetch from Local Repository FIRST
    final List<ClimateDailyData> repoData = await _climateRepository.getHistory(
      earliestUpdateDate,
      today.subtract(const Duration(days: 1)),
    );
    
    // 2. Fetch from Meteocat (might be empty due to Quota Saver)
    final recordsRaw = await _meteocatService.getDailyHistory(
      earliestUpdateDate,
      today.subtract(const Duration(days: 1)),
    );
    
    final Map<DateTime, ClimateDailyData> dailyData = {};
    
    for (var d in repoData) {
      final normalizedDate = _normalizeDate(d.date);
      dailyData[normalizedDate] = d;
    }
    
    for (var item in recordsRaw) {
      try {
        final d = DateTime.parse(item['date']);
        final day = _normalizeDate(d);
        dailyData[day] = ClimateDailyData.fromMeteocat(
          day,
          item['data']['data_list'][0],
        );
      } catch (_) {}
    }

    final newBeds = Map<int, BedData>.from(config.beds);
    bool hasChanges = false;

    for (var entry in newBeds.entries) {
      int bedIndex = entry.key;
      BedData bed = entry.value;

      DateTime? oldestPlacedAt;
      double bedStartX = config.getBedStartX(bedIndex) * 100;
      double bedEndX = bedStartX + config.getBedWidth(bedIndex) * 100;

      for (var p in espai.placedPlants) {
        if (p.placedAt == null) continue;
        double cx = p.x + p.width / 2;
        if (cx >= bedStartX && cx < bedEndX) {
          if (oldestPlacedAt == null || p.placedAt!.isBefore(oldestPlacedAt)) {
            oldestPlacedAt = _normalizeDate(p.placedAt!);
          }
        }
      }

      if (bed.irrigationMethod == IrrigationMethod.drip &&
          bed.cabalSistemaLitersHora == null) {
        continue;
      }

      DateTime bedDate;
      double balance;
      
      bool needsReset = false;
      final currentBal = bed.soilBalance ?? 0.0;
      // Legacy check: common multiples of fallbacks (3.2, 9.6, 2.4, 1.2, 0.4)
      final isLegacy = currentBal < -0.1 && (currentBal.abs() * 10).round() % 4 == 0;

      if (oldestPlacedAt == null) {
        if (currentBal < -0.1) needsReset = true;
      } else {
        final isRecent = today.difference(oldestPlacedAt).inDays < 7;
        if (bed.soilBalance == null || 
            bed.lastBalanceUpdate == null || 
            !bed.lastBalanceUpdate!.isAfter(oldestPlacedAt) ||
            isLegacy ||
            (isRecent && currentBal < -0.1)) {
          
          if (currentBal.abs() < 0.01 && bed.lastBalanceUpdate != null && _normalizeDate(bed.lastBalanceUpdate!).isAtSameMomentAs(oldestPlacedAt)) {
              needsReset = false;
          } else {
              needsReset = true;
          }
        }
      }

      if (needsReset || bed.soilBalance == null) {
        if (oldestPlacedAt == null) {
          bedDate = today;
          balance = 0.0;
        } else {
          bedDate = oldestPlacedAt;
          balance = 0.0;
          debugPrint('   [Reg Debug] Bed ${bed.name ?? "B${bedIndex + 1}"} resets to Day Zero (Planted ${oldestPlacedAt.toIso8601String().split('T')[0]})');
        }
      } else {
        bedDate = _normalizeDate(bed.lastBalanceUpdate ?? today);
        balance = bed.soilBalance!;
        if (oldestPlacedAt != null && bedDate.isAtSameMomentAs(oldestPlacedAt) && balance < -0.1) {
           balance = 0.0;
        }
      }

      while (bedDate.isBefore(today)) {
        double dynamicKc = 0.8;
        if (oldestPlacedAt != null) {
           final ageInDays = bedDate.difference(oldestPlacedAt).inDays;
           if (ageInDays < 20) dynamicKc = 0.3;
        }

        final data = dailyData[bedDate];
        if (data != null) {
          double etc = data.et0 * dynamicKc;
          double rain = data.rain;
          balance = balance + rain - etc;
          debugPrint(
            "   [Reg Debug] Dt: ${bedDate.toIso8601String().split('T')[0]} | "
            "Rain: $rain mm | ET0: ${data.et0} mm | Kc: $dynamicKc | "
            "ETc (Perd): ${etc.toStringAsFixed(2)} mm -> Balance: ${balance.toStringAsFixed(2)}",
          );
        } else {
          double fallbackEtc = 4.0 * dynamicKc;
          balance -= fallbackEtc;
          debugPrint(
            "   [Reg Debug] Dt: ${bedDate.toIso8601String().split('T')[0]} | "
            "⚠️ Sense Clima a DB local (Finca: ${_climateRepository.fincaId}). Aplicant fallback ${fallbackEtc.toStringAsFixed(1)}mm -> Balance: $balance",
          );
        }

        if (balance > 0.0) balance = 0.0;
        bedDate = bedDate.add(const Duration(days: 1));
        bedDate = _normalizeDate(bedDate); // Strict normalization
      }

      newBeds[bedIndex] = bed.copyWith(
        soilBalance: balance,
        lastBalanceUpdate: today,
      );
      hasChanges = true;
    }

    if (hasChanges) {
      return espai.copyWith(layoutConfig: config.copyWith(beds: newBeds));
    }
    return espai;
  }

  WateringRequirement getWateringRecommendation(BedData bed, double bedAreaSqm) {
    final String bedName = (bed.name == null || bed.name == 'Unknown') ? 'Bancal' : bed.name!;
    debugPrint('--- [Reg Debug] START CALC FOR BED $bedName ---');
    double actualAreaM2 = bedAreaSqm;

    if (actualAreaM2 > 1000) {
      actualAreaM2 = actualAreaM2 / 10000.0;
    }
    debugPrint('   [Reg Debug] 1. Bed Area M2: $actualAreaM2 m2');

    if (bed.soilBalance == null || bed.soilBalance! > -2.0) {
      debugPrint('   [Reg Debug] 2. Soil Balance: ${bed.soilBalance?.toStringAsFixed(1) ?? "NULL"} mm (Satiated / No Watering Needed)');
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: false,
        actionText: '🟢 Sòl Humit',
        buttonText: 'Sòl Saciat',
        amountValue: 0.0,
      );
    }

    double deficitMm = bed.soilBalance!.abs();
    debugPrint('   [Reg Debug] 2. Soil Deficit (mm): $deficitMm mm');

    double litersNeeded = deficitMm * actualAreaM2;
    debugPrint('   [Reg Debug] 3. Liters Needed = Deficit($deficitMm) * Area($actualAreaM2) = $litersNeeded L');

    if (bed.irrigationMethod == IrrigationMethod.manual) {
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: true,
        actionText: '🔴 💧 Rega amb ${litersNeeded.round()} L',
        buttonText: 'Registrar Reg (${litersNeeded.round()} L)',
        amountValue: litersNeeded,
      );
    } else {
      if (bed.cabalSistemaLitersHora == null || bed.cabalSistemaLitersHora! <= 0) {
        debugPrint('--- [Reg Debug] END CALC ---');
        return WateringRequirement(
          needsWater: false,
          actionText: '⚠️ Faltan les dades del Cabal',
          buttonText: 'Configura el Cabal',
          amountValue: 0.0,
        );
      }
      double minutes = (litersNeeded / bed.cabalSistemaLitersHora!) * 60.0;
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: true,
        actionText: '🔴 💧 Obre la clau ${minutes.round()} min',
        buttonText: 'Registrar Reg (${minutes.round()} min)',
        amountValue: minutes,
      );
    }
  }

  DateTime _normalizeDate(DateTime dt) {
    // Force local time before stripping hours to ensure consistency in lookups
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class WateringRequirement {
  final bool needsWater;
  final String actionText;
  final String buttonText;
  final double amountValue;

  WateringRequirement({
    required this.needsWater,
    required this.actionText,
    required this.buttonText,
    required this.amountValue,
  });
}

final gardenIrrigationServiceProvider = Provider((ref) {
  return GardenIrrigationService(
    ref.watch(meteocatServiceProvider),
    ref.watch(climateRepositoryProvider),
  );
});
