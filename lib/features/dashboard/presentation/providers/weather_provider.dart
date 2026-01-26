import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soca/core/services/meteocat_service.dart';
import 'package:soca/features/dashboard/domain/weather_model.dart';
import 'package:intl/intl.dart';
import 'package:soca/features/settings/presentation/providers/settings_provider.dart';
import 'package:soca/core/calculators/et0_calculator.dart';

import 'package:soca/features/climate/domain/climate_model.dart';
import 'package:soca/features/climate/presentation/providers/climate_provider.dart';
import 'package:soca/features/trees/presentation/providers/trees_provider.dart';
import 'package:soca/features/trees/data/repositories/species_repository.dart';

final weatherProvider = FutureProvider<WeatherModel>((ref) async {
  final service = ref.watch(meteocatServiceProvider);

  final configAsync = await ref.read(
    farmConfigStreamProvider.future,
  ); // Use read for config to be sure

  // Read repository AFTER config is loaded so it has the correct FincaId
  final repository = ref.read(climateRepositoryProvider);

  // Sync Station from Firestore Config if available
  // Use .future to get the value
  try {
    final config = await ref.watch(farmConfigStreamProvider.future);
    if (config.meteocatStationCode != null &&
        config.meteocatStationCode!.isNotEmpty) {
      await service.setCachedStation(config.meteocatStationCode!);
    }
  } catch (e) {
    // Ignore config load error
  }

  // Ensure config is available for saving (need fincaId)
  if (configAsync.fincaId == null) {
    // print("WeatherProvider: No FincaID, cannot auto-save.");
  }

  final data = await service.getWeatherData();

  if (data.isEmpty) return WeatherModel.empty();

  // Parse Observation
  // API Structure for observations: "dades": { "variables": [ { "codi": 32, "valor": 20.5 }, ... ] }
  // Actually checking structure of 'getLatestObservations' result.
  // Assuming the service returns the raw JSON from /estacions/{codi}/ultimes
  // It usually has a top level object or list.
  // The service implements: return jsonDecode(response.body); which is object with "dades".
  // "dades" is a List of observation moments. We want the last one.

  final obsData = data['observation'];
  final forecastData = data['forecast'];
  final stationCode = data['station'];
  final DateTime? lastUpdated = data['last_updated'] as DateTime?;

  double temp = 0.0;
  int humidity = 0;
  double rain = 0.0;
  double windSpeed = 0.0;

  double et0 = 0.0;
  double estimatedDailyRadiation = 0.0;
  List<DailyForecast> parsedForecast = [];
  double avgHumidity6h = 0.0;
  int rainProb = 0;

  if (obsData != null && obsData['data_list'] != null) {
    List<dynamic> list = obsData['data_list']; // Hourly observations

    // 1. Current Conditions (Latest)
    if (list.isNotEmpty) {
      final stationData = list.first; // Should be the station we asked for
      if (stationData['variables'] != null) {
        final List<dynamic> vars = stationData['variables'];

        // --- Radiation Integration Logic ---
        // Find Code 36 (Global Irradiance W/m2)
        try {
          final radVar = vars.firstWhere(
            (v) => v['codi'] == 36,
            orElse: () => null,
          );
          if (radVar != null && radVar['lectures'] != null) {
            final List<dynamic> readings = radVar['lectures'];
            double accumJoules = 0.0;
            // Assume 30 min interval (standard Meteocat XEMA) = 1800 seconds
            // Integration: Sum(Watts * Seconds) = Joules
            const double intervalSeconds = 1800.0;

            for (var r in readings) {
              if (r['valor'] != null) {
                accumJoules += (r['valor'] as num).toDouble() * intervalSeconds;
              }
            }
            // Convert Joules/m2 to MJ/m2
            estimatedDailyRadiation = accumJoules / 1000000.0;
          }
        } catch (e) {
          // Ignore integration error
        }
        // -----------------------------------

        for (var v in vars) {
          final id = v['codi'];
          final List<dynamic>? readings = v['lectures'];
          if (readings == null || readings.isEmpty) continue;

          // For Rain (35), we want the SUM of the day
          if (id == 35) {
            double iterSum = 0.0;
            for (var r in readings) {
              final val = r['valor'];
              if (val != null) iterSum += (val as num).toDouble();
            }
            rain = iterSum;
          } else {
            // For others (Temp, Wind, Hum), we want the LATEST reading
            // Assuming list is chronological, or we could sort by 'data' if needed.
            // Using .last is standard for XEMA.
            final latest = readings.last;
            final val = latest['valor'];
            if (val == null) continue;

            try {
              if (id == 32) temp = (val as num).toDouble();
              if (id == 33) humidity = (val as num).toInt();
              // Wind (30)
              if (id == 30) windSpeed = (val as num).toDouble();
            } catch (e) {
              // Parser error
            }
          }
        }
      }

      // --- AUTO-SAVE LOGIC (Smart Sync) ---
      // If we have valid data, save it to History DB so chart updates automatically.
      if (configAsync.fincaId != null) {
        try {
          final now = DateTime.now();
          // Use fromMeteocat to get consistent Daily Aggregates (Mean Wind, Sum Rain, etc.)
          final tempObj = ClimateDailyData.fromMeteocat(now, stationData);

          // Calculate ET0 for the day so far
          final dailyEt0 = ET0Calculator.calculate(
            lat: configAsync.latitude,
            date: now,
            tMax: tempObj.maxTemp,
            tMin: tempObj.minTemp,
            rhMean: tempObj.humidity > 0 ? tempObj.humidity : null,
            windSpeed: tempObj.windSpeed > 0 ? tempObj.windSpeed : null,
            radiation: tempObj.radiation > 0 ? tempObj.radiation : null,
          );

          final toSave = ClimateDailyData(
            date: tempObj.date,
            maxTemp: tempObj.maxTemp,
            minTemp: tempObj.minTemp,
            rain: tempObj.rain,
            rainAccumulated: tempObj.rainAccumulated,
            humidity: tempObj.humidity,
            radiation: tempObj.radiation,
            windSpeed: tempObj.windSpeed,
            et0: dailyEt0,
            isMock: false,
            fincaId: configAsync.fincaId,
            lastUpdated: tempObj.lastUpdated,
          );

          // Fire and forget save
          repository.saveHistory([toSave]);
        } catch (e) {
          // Ignore parsing errors during auto-save
        }
      }
    }

    // 2. Fog Logic: Avg Humidity Last 6 Hours
    // Assuming 'list' contains objects like { "data_lectura": "...", "variables": [...] }
    // Actually Meteocat structure: "data_list" -> [ { "variables": [...] } ] ?
    // No, Usually top level is station.
    // Wait, typical response: { "data_list": [ { "codi_estacio": "X", "variables": [...] } ] }
    // The history is INSIDE "variables" -> "lectures".

    // Let's refine parsing for 6h Avg Humidity
    if (list.isNotEmpty) {
      final stationData = list.first;
      if (stationData['variables'] != null) {
        final List<dynamic> vars = stationData['variables'];
        final humVar = vars.firstWhere(
          (v) => v['codi'] == 33,
          orElse: () => null,
        );

        if (humVar != null) {
          final List<dynamic> readings = humVar['lectures'] ?? [];
          // Readings should have "data" field. Calculate avg of last 6h.
          double sumHum = 0;
          int countHum = 0;

          for (var r in readings.reversed) {
            // Newest last? Usually chronological.
            // Check timestamp? API usually returns string ISO.
            // Let's assume readings are recent. If we take last 12 readings (30min interval per reading = 6h).
            // Meteocat usually 30 min.
            if (countHum >= 12) break;
            if (r['valor'] != null) {
              sumHum += (r['valor'] as num);
              countHum++;
            }
          }
          if (countHum > 0) {
            avgHumidity6h = sumHum / countHum;
          } else {
            avgHumidity6h = humidity.toDouble();
          }
        }
      }
    }
  }

  String municipalityName = '';

  // Parse Forecast (Next 3 days)
  if (forecastData != null) {
    if (forecastData['nom'] != null) {
      municipalityName = forecastData['nom'];
    }

    if (forecastData['dies'] != null) {
      List<dynamic> dies = forecastData['dies'];
      // Take up to 3 days
      for (var i = 0; i < 3 && i < dies.length; i++) {
        final day = dies[i];
        String dateStr = day['data']; // yyyy-MM-dd or yyyy-MM-ddZ
        if (dateStr.endsWith('Z')) {
          dateStr = dateStr.substring(0, dateStr.length - 1);
        }
        final date = DateTime.parse(dateStr);

        int minT = 0;
        int maxT = 0;
        int rProb = 0;
        String sym = '';

        if (day['variables'] != null) {
          try {
            final vars = day['variables'];

            // Helper for parsing values that might be String or Num
            double parseVal(dynamic v) {
              if (v == null) return 0.0;
              if (v is num) return v.toDouble();
              if (v is String) return double.tryParse(v) ?? 0.0;
              return 0.0;
            }

            // Handle new keys (tmin, tmax, precipitacio, estatCel)
            if (vars['tmin'] != null) {
              minT = parseVal(vars['tmin']['valor']).round();
            } else if (vars['temp_min'] != null) {
              minT = parseVal(vars['temp_min']['valor']).round();
            }

            if (vars['tmax'] != null) {
              maxT = parseVal(vars['tmax']['valor']).round();
            } else if (vars['temp_max'] != null) {
              maxT = parseVal(vars['temp_max']['valor']).round();
            }

            // Precipitacio / Probabilitat
            if (vars['precipitacio'] != null) {
              try {
                // If it's probability percentage (e.g. "55.6"), map to 1-4 scale logic or just use it?
                // Original logic mapped 1=10%, 2=30%, 3=70%, 4=90%
                // Inspecting debug output: "unitat":"%" and "valor":"55.6".
                // So it is actual percentage now!
                double val = parseVal(vars['precipitacio']['valor']);
                rProb = val.round();
              } catch (e) {
                /* ignore */
              }
            } else if (vars['probabilitat_precipitacio'] != null) {
              int val = parseVal(
                vars['probabilitat_precipitacio']['valor'],
              ).toInt();
              if (val == 1) rProb = 10;
              if (val == 2) rProb = 30;
              if (val == 3) rProb = 70;
              if (val == 4) rProb = 90;
            }

            if (vars['estatCel'] != null) {
              // sym = vars['estatCel']['valor']
              sym = 'cloud';
            } else if (vars['simbol_cel'] != null) {
              sym = 'cloud';
            }
          } catch (e) {
            /* ignore */
          }
        }

        parsedForecast.add(
          DailyForecast(
            date: date,
            minTemp: minT,
            maxTemp: maxT,
            rainProb: rProb,
            symbol: sym,
          ),
        );
      }

      // Set current rain prob from Today's forecast
      if (parsedForecast.isNotEmpty) {
        // Check if first day is today
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final firstDay = DateFormat(
          'yyyy-MM-dd',
        ).format(parsedForecast.first.date);
        if (today == firstDay) {
          rainProb = parsedForecast.first.rainProb;
        }
      }
    }
  }

  // ET0 Calculation (Penman-Monteith / Hargreaves)
  try {
    double tMaxCalc = temp;
    double tMinCalc = temp;

    // Attempt to use Forecast for TMax/TMin (Better for Hargreaves)
    if (parsedForecast.isNotEmpty) {
      final now = DateTime.now();
      final first = parsedForecast.first;
      if (first.date.year == now.year &&
          first.date.month == now.month &&
          first.date.day == now.day) {
        tMaxCalc = first.maxTemp.toDouble();
        tMinCalc = first.minTemp.toDouble();
      }
    }

    // Safety Fallback: If TMax == TMin (Forecast missing or data error),
    // Hargreaves will return 0 because sqrt(Tmax-Tmin) is 0.
    // We force a minimal diurnal range estimate (e.g. 5 degrees) to get a non-zero value.
    if (tMaxCalc == tMinCalc) {
      tMaxCalc += 2.5;
      tMinCalc -= 2.5;
    }

    final config = await ref.watch(farmConfigStreamProvider.future);

    // Use Radiation if we found it (> 0.1 MJ/m2 to avoid zero-data issues)
    double? radToPass = estimatedDailyRadiation > 0.1
        ? estimatedDailyRadiation
        : null;

    et0 = ET0Calculator.calculate(
      lat: config.latitude,
      date: DateTime.now(),
      tMax: tMaxCalc,
      tMin: tMinCalc,
      rhMean: humidity.toDouble(),
      windSpeed: windSpeed,
      radiation: radToPass,
    );
  } catch (e) {
    // Ignore calculation errors
  }

  // Alerts Logic
  final List<SafetyAlert> alerts = [];

  // Data for Alerts Scope: Next 24h (Today + Tomorrow)
  bool frostForecast = parsedForecast.take(2).any((f) => f.minTemp < 1);
  bool windForecast = false;
  // Note: Wind Forecast is usually under 'vent' variable in 'dies'.
  // Simplified: If current wind is high, trigger.
  // Or check specific vars if available. Using current wind + 20% margin for forecast simulation or just current.
  // User asked for "Previsió Vent Fort".
  // Let's assume if current > 20 km/h it's windy, or check `ratxa_max` in variables if available.
  // For now: Alert if current wind > 30 km/h (User request).
  if (windSpeed * 3.6 > 30) windForecast = true;

  // 1. Obres
  if (windSpeed * 3.6 > 25 || rain > 0.5) {
    alerts.add(
      SafetyAlert(
        title: 'Perill Obres',
        message:
            'Motiu: Perillós treballar a l\'exterior.\nCriteri: Vent > 25km/h o Pluja > 0.5mm.',
        icon: 'warning',
      ),
    );
  }

  // 2. Severe Weather (User Request)
  if (frostForecast) {
    alerts.add(
      SafetyAlert(
        title: 'Risc de Gelada',
        message:
            'Motiu: Perill per a cultius sensibles.\nCriteri: Mínima < 1ºC properes 24h.',
        icon: 'ac_unit',
      ),
    );
  }
  if (windForecast) {
    alerts.add(
      SafetyAlert(
        title: 'Vent Fort',
        message:
            'Motiu: Risc de danys estructurals o caiguda de branques.\nCriteri: Ratxes > 30 km/h.',
        icon: 'air',
      ),
    );
  }

  if (windSpeed * 3.6 < 12 && humidity < 85 && rainProb < 30) {
    alerts.add(
      SafetyAlert(
        title: 'Aplicacions OK',
        message:
            'Motiu: Ideal per aplicar preparats (sense pèrdues per vent o pluja).\nCriteri: Vent < 12km/h, Hum < 85% i sense pluja.',
        icon: 'check',
      ),
    );
  }

  // Irrigation Logic
  String advice = "N/A";

  // 1. Fetch History
  final repo = ref.read(climateRepositoryProvider);
  final end = DateTime.now();
  final start = end.subtract(const Duration(days: 7));
  final history = await repo.getHistory(start, end);

  // Inhibitor Logic
  double yesterdayRain = 0.0;
  final yesterdayDate = DateTime.now().subtract(const Duration(days: 1));
  final yesterdayItem = history.firstWhere(
    (e) =>
        e.date.year == yesterdayDate.year &&
        e.date.month == yesterdayDate.month &&
        e.date.day == yesterdayDate.day,
    orElse: () => ClimateDailyData(
      date: yesterdayDate,
      maxTemp: 0,
      minTemp: 0,
      rain: 0,
      rainAccumulated: 0,
    ),
  );
  yesterdayRain = yesterdayItem.rain;
  final last48hRain = rain + yesterdayRain;

  // LOGIC TREE
  if (avgHumidity6h > 90) {
    // Fog Factor (User Request)
    advice = "No regar (Boira/Humitat alta)";
  } else if (last48hRain > 2.0) {
    advice = "No regar (Terra Humida)";
  } else {
    // Calculate Kc
    double farmKc = 0.6;
    try {
      final trees = await ref.read(treesStreamProvider.future);
      final speciesRepo = ref.read(speciesRepositoryProvider);
      final allSpecies = await speciesRepo.getSpecies().first;
      final speciesMap = {for (var s in allSpecies) s.id: s.kc};

      if (trees.isNotEmpty) {
        double totalKc = 0;
        int count = 0;
        for (var t in trees) {
          double? k = t.kc;
          if (t.speciesId != null && speciesMap.containsKey(t.speciesId)) {
            k = speciesMap[t.speciesId];
          }
          totalKc += (k ?? 0.6);
          count++;
        }
        if (count > 0) farmKc = totalKc / count;
      }
    } catch (e) {
      // Ignore error calculating Kc
    }

    // RuralCat Logic Integration
    // Try to find latest soilBalance
    double? latestBalance;
    double? previousBalance;

    // Sort history by date desc to find latest easily
    final sortedHistory = List<ClimateDailyData>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (var day in sortedHistory) {
      if (day.soilBalance != null) {
        if (latestBalance == null) {
          latestBalance = day.soilBalance;
        } else {
          previousBalance = day.soilBalance;
          break; // Found both
        }
      }
    }

    if (latestBalance != null) {
      // Use RuralCat Model
      final sb = latestBalance;
      String trend = "";
      if (previousBalance != null) {
        if (sb < previousBalance) {
          trend = "📉";
        } else if (sb > previousBalance) {
          trend = "📈";
        } else {
          trend = "➡️";
        }
      }

      if (sb > -5) {
        advice = "No regar (Terra Humida) $trend";
      } else if (sb >= -15) {
        advice = "Reg Opcional ($trend ${sb.toStringAsFixed(1)} mm)";
      } else {
        advice =
            "Reg Recomanat (Falten ${(sb.abs() - 5).toStringAsFixed(1)} mm) $trend";
      }
    } else {
      // Fallback to Weekly Balance (Old Logic)
      double weeklyBalance = 0.0;
      for (var day in history) {
        double dailyNet = (day.et0 * farmKc) - day.rain;
        weeklyBalance += dailyNet;
      }

      if (weeklyBalance > 5.0) {
        advice =
            "Reg Necessari (${weeklyBalance.toStringAsFixed(1)}mm dèficit) [Estimat]";
      } else if (weeklyBalance < -5.0) {
        advice = "No regar (Excés hídric) [Estimat]";
      } else {
        advice = "Reg Opcional (Equilibrat) [Estimat]";
      }
    }

    if (rainProb > 70 && (latestBalance != null ? latestBalance < -15 : true)) {
      // Only inhibit if strictly necessary? Or always if rain is coming?
      // Original: if weeklyBalance > 0 (Deficit).
      // RuralCat: If < -15 (Deficit critical)
      advice = "Esperar (Prob. pluja)";
    }
  }

  return WeatherModel(
    temperature: temp,
    humidity: humidity,
    rainAccumulated: rain,
    rainProbability: rainProb,
    irrigationAdvice: advice,
    stationName: municipalityName.isNotEmpty
        ? municipalityName
        : (stationCode ?? '?'),
    windSpeed: windSpeed,
    et0: et0,
    forecast: parsedForecast,
    alerts: alerts,
    lastUpdated: lastUpdated,
  );
});
