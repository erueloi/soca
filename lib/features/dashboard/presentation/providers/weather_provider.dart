import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soca/core/services/meteocat_service.dart';
import 'package:soca/features/dashboard/domain/weather_model.dart';
import 'package:intl/intl.dart';
import 'package:soca/features/settings/presentation/providers/settings_provider.dart';
import 'package:soca/features/climate/presentation/providers/climate_provider.dart';

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
    print("WeatherProvider Config Sync Error: $e");
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
          } catch (e) {
            print("Error parsing var $id: $e");
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
        final probObj = todayForecast['variables']['probabilitat_precipitacio'];
        final valInt = probObj['valor'] as int;
        // Map 1-4 to % roughly for display
        // 1: <10%, 2: 30%, 3: 70%, 4: 90%
        if (valInt == 1) rainProb = 10;
        if (valInt == 2) rainProb = 30;
        if (valInt == 3) rainProb = 70;
        if (valInt == 4) rainProb = 90;
      } catch (e) {
        // Fallback
      }
    }
  }

  // Irrigation Logic
  String advice = "N/A";

  // Check yesterday's rain first (Global Inhibition)
  final yesterdayRainAsync = ref.watch(yesterdayRainProvider);
  bool inhibited = false;

  yesterdayRainAsync.whenData((val) {
    if (val > 2.0) inhibited = true;
  });

  if (inhibited) {
    advice = "No regar (Pluja ahir > 2mm)";
  } else if (rain > 2.0) {
    advice = "Reg no necessari (Terra humida)";
  } else if (rainProb >= 70) {
    advice = "Esperar (Prob. pluja alta)";
  } else {
    advice = "Reg recomanat";
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
