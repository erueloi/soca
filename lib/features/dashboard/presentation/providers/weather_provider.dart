import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soca/core/services/meteocat_service.dart';
import 'package:soca/features/dashboard/domain/weather_model.dart';
import 'package:intl/intl.dart';
import 'package:soca/features/settings/presentation/providers/settings_provider.dart';

import 'package:soca/features/climate/domain/climate_model.dart';
import 'package:soca/features/climate/data/repositories/climate_repository.dart';
import 'package:soca/features/trees/presentation/providers/trees_provider.dart';
import 'package:soca/features/trees/data/repositories/species_repository.dart';

final weatherProvider = FutureProvider<WeatherModel>((ref) async {
  final service = ref.watch(meteocatServiceProvider);

  // Sync Station from Firestore Config if available
  // Use .future to get the value
  try {
    final config = await ref.watch(farmConfigStreamProvider.future);
    if (config.meteocatStationCode != null &&
        config.meteocatStationCode!.isNotEmpty) {
      await service.setCachedStation(config.meteocatStationCode!);
    }
  } catch (e) {
    // Ignore config load error, fallback to cache
    // print("WeatherProvider Config Sync Error: $e");
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

  double temp = 0.0;
  int humidity = 0;
  double rain = 0.0;
  double windSpeed = 0.0;

  if (obsData != null && obsData['data_list'] != null) {
    List<dynamic> list = obsData['data_list'];
    if (list.isNotEmpty) {
      final stationData = list.first; // Should be the station we asked for
      if (stationData['variables'] != null) {
        final List<dynamic> vars = stationData['variables'];

        for (var v in vars) {
          final id = v['codi'];
          final List<dynamic>? readings = v['lectures'];

          if (readings == null || readings.isEmpty) continue;

          // Get latest reading
          final latest = readings.last;
          final val = latest['valor'];

          if (val == null) continue;

          try {
            if (id == 32) temp = (val as num).toDouble();
            if (id == 33) humidity = (val as num).toInt();
            if (id == 35) rain = (val as num).toDouble();
            if (id == 30) windSpeed = (val as num).toDouble(); // Parse Wind
          } catch (e) {
            // print("Error parsing var $id: $e");
          }
        }
      }
    }
  }

  // Parse Forecast
  // /pronostic/v1/municipal/{codi} -> "dies": [ { "data": "...", "variables": { "probabilitat_precipitacio": { "valor": 3 } } } ]
  int rainProb = 0;
  if (forecastData != null && forecastData['dies'] != null) {
    List<dynamic> dies = forecastData['dies'];
    if (dies.isNotEmpty) {
      // Find today
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayForecast = dies.firstWhere(
        (element) => element['data'].toString().contains(todayStr),
        orElse: () => dies.first,
      );

      // Metocat structure for vars is complex sometimes.
      // "probabilitat_precipitacio" usually has "valor" 1-6 scale or percentage?
      // API docs: "probabilitat_precipitacio": { "valor": 3 } -> 3 means "Medium"?
      // Actually Meteocat often uses indices.
      // 1: 0-10%, 2: 10-30%, 3: 30-70%, 4: >70%.
      // Let's assume this scale.

      if (todayForecast['variables'] != null &&
          todayForecast['variables']['estat_cel'] != null) {
        // just checking structure
      }

      // Check specific variable
      // Usually it's in a list or map. Let's try to be safe.
      // Documentation says "variables" object has keys like "probabilitat_precipitacio".
      // { "probabilitat_precipitacio": { "valor": 2 } }

      try {
        if (todayForecast['variables'] != null) {
          final probObj =
              todayForecast['variables']['probabilitat_precipitacio'];
          if (probObj != null) {
            final valInt = probObj['valor'] as int;
            // Map 1-4 to % roughly for display
            // 1: <10%, 2: 30%, 3: 70%, 4: 90%
            if (valInt == 1) rainProb = 10;
            if (valInt == 2) rainProb = 30;
            if (valInt == 3) rainProb = 70;
            if (valInt == 4) rainProb = 90;
          }
        }
      } catch (e) {
        // Fallback
      }
    }
  }

  // Alerts Logic
  final List<SafetyAlert> alerts = [];

  // 1. Obres / Teulada (Wind > 25 km/h OR Rain > 0.5 mm)
  // Wind comes in m/s usually from Meteocat (check logic, standard is m/s). 25 km/h ~= 7 m/s
  // If Meteocat returns km/h, use 25. Let's assume m/s: 25 km/h / 3.6 = 6.94 m/s.
  // Actually Meteocat 30 is usually m/s.
  if (windSpeed * 3.6 > 25 || rain > 0.5) {
    alerts.add(
      SafetyAlert(
        title: 'Perill Obres',
        message: 'Vent > 25km/h o Pluja. Evita feines a la teulada.',
        icon: 'warning',
      ),
    );
  }

  // 2. Tractaments (Wind < 12 km/h AND Hum < 85% AND No Rain Forecast)
  // 12 km/h ~= 3.3 m/s
  if (windSpeed * 3.6 < 12 && humidity < 85 && rainProb < 30) {
    // Good conditions
    alerts.add(
      SafetyAlert(
        title: 'Tractaments OK',
        message: 'Condicions òptimes per fitosanitaris.',
        icon: 'check',
      ),
    );
  }

  // 3. Pintar / Exterior (Hum > 75% OR Rain Forecast)
  if (humidity > 75 || rainProb >= 30) {
    alerts.add(
      SafetyAlert(
        title: 'No Pintar',
        message: 'Humitat alta o risc de pluja.',
        icon: 'palette',
      ),
    );
  }

  // 4. Gelades (Temp < 0.5)
  if (temp < 0.5) {
    alerts.add(
      SafetyAlert(
        title: 'Risc Gelada',
        message: 'Temperatura propera a 0ºC.',
        icon: 'ac_unit',
      ),
    );
  }

  // Irrigation Logic (Advanced)
  String advice = "N/A";

  // 1. Fetch History (Last 7 days) for Balance
  final repo = ref.read(climateRepositoryProvider);
  final end = DateTime.now();
  final start = end.subtract(const Duration(days: 7));

  // We use .future or just await since we are in async provider
  final history = await repo.getHistory(start, end);

  // Data for Inhibitor (Last 48h = Today + Yesterday)
  // We have today's rain in `rain` variable (from observations)
  // We need yesterday's rain from history
  double yesterdayRain = 0.0;
  final yesterdayDate = DateTime.now().subtract(const Duration(days: 1));

  // Find yesterday in history (normalize dates)
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

  // Inhibitor Logic: Rain > 2mm in last 48h
  final last48hRain = rain + yesterdayRain;
  final bool inhibited = last48hRain > 2.0;

  if (inhibited) {
    advice = "No regar (Terra Humida)"; // >2mm accumulated
  } else {
    // Balance Logic
    // Reg_net = (ET0 * Kc) - Rain
    // If we assume a generic crop (e.g. Olive 0.6) for the dashboard overview
    // Or we could sum up all trees, but that's too heavy for a simple widget.
    // Let's use Olive (0.6) as the "Farm Standard".
    double farmKc = 0.6;
    try {
      final trees = await ref.read(treesStreamProvider.future);
      final speciesRepo = ref.read(speciesRepositoryProvider);
      final allSpecies = await speciesRepo.getSpecies().first;

      if (trees.isNotEmpty) {
        double totalKc = 0.0;
        int count = 0;

        final speciesMap = {for (var s in allSpecies) s.id: s.kc};

        for (var t in trees) {
          double? k;
          if (t.speciesId != null && speciesMap.containsKey(t.speciesId)) {
            k = speciesMap[t.speciesId]; // Priority: Library
          } else {
            k = t.kc; // Fallback: Manual/Legacy
          }
          totalKc += (k ?? 0.6);
          count++;
        }
        if (count > 0) {
          farmKc = totalKc / count;
        }
      }
    } catch (e) {
      // debugPrint("Error calculating Kc: $e");
    }

    double weeklyBalance = 0.0;

    for (var day in history) {
      // Daily Reg = (ET0 * Kc) - Rain
      double dailyNet = (day.et0 * farmKc) - day.rain;
      weeklyBalance += dailyNet;
    }

    // Add today's (partial) deficit?
    // Today ET0 isn't calculated yet fully, but we can assume some.
    // Let's stick to history balance.

    if (weeklyBalance > 5.0) {
      // Threshold: 5mm deficit
      advice = "Reg Necessari (${weeklyBalance.toStringAsFixed(1)}mm dèficit)";
    } else if (weeklyBalance < -5.0) {
      advice = "No regar (Excés hídric)";
    } else {
      advice = "Reg Opcional (Equilibrat)";
    }

    // Override if Rain Probability is high manually?
    if (rainProb > 70 && weeklyBalance > 0) {
      advice = "Esperar (Prob. pluja)";
    }
  }

  return WeatherModel(
    temperature: temp,
    humidity: humidity,
    rainAccumulated: rain,
    rainProbability: rainProb,
    irrigationAdvice: advice,
    stationName: stationCode ?? '?',
  );
});
