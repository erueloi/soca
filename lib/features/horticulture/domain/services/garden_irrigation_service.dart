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
  Future<EspaiHort> syncSoilBalance(EspaiHort espai, {bool forceSync = false}) async {
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

    if (!forceSync && (earliestUpdateDate == null ||
        earliestUpdateDate.isAtSameMomentAs(today))) {
      return espai;
    }
    
    // If we only need to sync today (because of forceSync), we still need today's climate data if possible
    if (earliestUpdateDate == null || earliestUpdateDate.isAtSameMomentAs(today)) {
        earliestUpdateDate = today.subtract(const Duration(days: 1)); // Fetch at least yesterday to avoid meteocat errors
    }

    // 1. Fetch from Local Repository FIRST
    final List<ClimateDailyData> repoData = await _climateRepository.getHistory(
      earliestUpdateDate,
      today.subtract(const Duration(days: 1)), // Wait, this gets history up to yesterday. Today's ETc is missing?
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
      
      bool needsReset = forceSync;
      final currentBal = bed.soilBalance ?? 0.0;
      // Legacy check: common multiples of fallbacks (3.2, 9.6, 2.4, 1.2, 0.4)
      final isLegacy = currentBal < -0.1 && (currentBal.abs() * 10).round() % 4 == 0;

      if (!forceSync) {
        if (oldestPlacedAt == null) {
          if (currentBal < -0.1) needsReset = true;
        } else {
          final isRecent = today.difference(oldestPlacedAt).inDays < 7;
          if (bed.soilBalance == null || 
              bed.lastBalanceUpdate == null || 
              (!bed.lastBalanceUpdate!.isAfter(oldestPlacedAt) && !bed.lastBalanceUpdate!.isAtSameMomentAs(oldestPlacedAt)) ||
              isLegacy ||
              (isRecent && currentBal < -0.1 && bed.wateringEvents?.isEmpty == true)) {
            
            if (currentBal.abs() < 0.01 && bed.lastBalanceUpdate != null && _normalizeDate(bed.lastBalanceUpdate!).isAtSameMomentAs(oldestPlacedAt)) {
                needsReset = false;
            } else {
                needsReset = true;
            }
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
        // If forceSync is true, we still want to calculate from lastBalanceUpdate to today.
        bedDate = _normalizeDate(bed.lastBalanceUpdate ?? today);
        balance = bed.soilBalance!;
        // Prevent immediate wipeout if planted today, but handle logic properly
        if (oldestPlacedAt != null && bedDate.isAtSameMomentAs(oldestPlacedAt) && balance < -0.1 && !forceSync) {
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
          
          double irrigatedMm = 0.0;
          if (bed.wateringEvents != null) {
            final double bedAreaSqm = (config.getBedWidth(bedIndex) * config.totalLength);
            // Protect against dividing by zero or very small area:
            final double actualAreaM2 = bedAreaSqm > 1000 ? bedAreaSqm / 10000.0 : bedAreaSqm;
            if (actualAreaM2 > 0) {
              final dailyEvents = bed.wateringEvents!.where((e) => _normalizeDate(e.date).isAtSameMomentAs(bedDate));
              final totalLiters = dailyEvents.fold(0.0, (sum, e) => sum + e.litersApplied);
              irrigatedMm = totalLiters / actualAreaM2;
            }
          }

          balance = balance + rain + irrigatedMm - etc;
          debugPrint(
            "   [Reg Debug] Dt: ${bedDate.toIso8601String().split('T')[0]} | "
            "Rain: $rain mm | Irrigated: ${irrigatedMm.toStringAsFixed(1)} mm | ETc: ${etc.toStringAsFixed(2)} mm -> Balance: ${balance.toStringAsFixed(2)}",
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

    double balance = bed.soilBalance ?? 0.0;

    // Add today's manual watering since syncSoilBalance only computes up to the start of today
    if (bed.wateringEvents != null && bed.wateringEvents!.isNotEmpty) {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final dailyEvents = bed.wateringEvents!.where((e) => e.date.toIso8601String().startsWith(todayStr));
      final totalLiters = dailyEvents.fold(0.0, (sum, e) => sum + e.litersApplied);
      final todayIrrigatedMm = totalLiters / actualAreaM2;
      balance += todayIrrigatedMm;
      if (balance > 0.0) balance = 0.0; 
      debugPrint('   [Reg Debug] Added Today\'s Irrigation: ${todayIrrigatedMm.toStringAsFixed(2)} mm -> Effective Balance: ${balance.toStringAsFixed(2)} mm');
    }

    if (balance > -1.0) {
      debugPrint('   [Reg Debug] 2. Soil Balance: ${balance.toStringAsFixed(1)} mm (Satiated)');
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: false,
        status: WateringStatus.satiated,
        actionText: '🟢 Sòl Humit',
        buttonText: 'Sòl Saciat',
        amountValue: 0.0,
        litersNeeded: 0.0,
      );
    } else if (balance > -2.0) {
      debugPrint('   [Reg Debug] 2. Soil Balance: ${balance.toStringAsFixed(1)} mm (Forecast / Yellow Alert)');
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: false,
        status: WateringStatus.forecast,
        actionText: '🟡 Previsió: Reg imminent si no plou',
        buttonText: 'Sòl gairebé al límit',
        amountValue: 0.0,
        litersNeeded: 0.0,
      );
    }

    double deficitMm = balance.abs();
    debugPrint('   [Reg Debug] 2. Soil Deficit (mm): ${deficitMm.toStringAsFixed(2)} mm');

    double litersNeeded = deficitMm * actualAreaM2;
    debugPrint('   [Reg Debug] 3. Liters Needed = Deficit(${deficitMm.toStringAsFixed(2)}) * Area(${actualAreaM2.toStringAsFixed(2)}) = ${litersNeeded.toStringAsFixed(2)} L');

    if (bed.irrigationMethod == IrrigationMethod.manual) {
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: true,
        status: WateringStatus.critical,
        actionText: '🔴 💧 Rega amb ${litersNeeded.round()} L',
        buttonText: 'Registrar Reg (${litersNeeded.round()} L)',
        amountValue: litersNeeded,
        litersNeeded: litersNeeded,
      );
    } else {
      if (bed.cabalSistemaLitersHora == null || bed.cabalSistemaLitersHora! <= 0) {
        debugPrint('--- [Reg Debug] END CALC ---');
        return WateringRequirement(
          needsWater: false,
          status: WateringStatus.critical, // Even if it lacks data, it IS critical if deficit > 2.0
          actionText: '⚠️ Faltan les dades del Cabal',
          buttonText: 'Configura el Cabal',
          amountValue: 0.0,
          litersNeeded: 0.0,
        );
      }
      double minutes = (litersNeeded / bed.cabalSistemaLitersHora!) * 60.0;
      debugPrint('--- [Reg Debug] END CALC ---');
      return WateringRequirement(
        needsWater: true,
        status: WateringStatus.critical,
        actionText: '🔴 💧 Obre la clau ${minutes.round()} min',
        buttonText: 'Registrar Reg (${minutes.round()} min)',
        amountValue: minutes,
        litersNeeded: litersNeeded,
      );
    }
  }

  DateTime _normalizeDate(DateTime dt) {
    // Force local time before stripping hours to ensure consistency in lookups
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

enum WateringStatus { satiated, forecast, critical }

class WateringRequirement {
  final bool needsWater;
  final WateringStatus status;
  final String actionText;
  final String buttonText;
  final double amountValue;
  final double litersNeeded;

  WateringRequirement({
    required this.needsWater,
    required this.status,
    required this.actionText,
    required this.buttonText,
    required this.amountValue,
    required this.litersNeeded,
  });
}

final gardenIrrigationServiceProvider = Provider((ref) {
  return GardenIrrigationService(
    ref.watch(meteocatServiceProvider),
    ref.watch(climateRepositoryProvider),
  );
});
