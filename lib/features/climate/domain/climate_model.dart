import 'package:cloud_firestore/cloud_firestore.dart';

class ClimateDailyData {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final double rain;
  final double rainAccumulated;
  final double humidity; // Code 33
  final double radiation; // Code 34
  final double windSpeed; // Code 30

  // Advanced Fields
  final double et0; // Reference Evapotranspiration (mm/day)
  final bool isMock; // Flag for generated data
  final String? fincaId;
  final double? soilBalance;
  final DateTime? lastUpdated;
  final DateTime? calculatedAt; // New: When soilBalance was calculated

  ClimateDailyData({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.rain,
    required this.rainAccumulated,
    this.humidity = 0.0,
    this.radiation = 0.0,
    this.windSpeed = 0.0,
    this.et0 = 0.0,
    this.isMock = false,
    this.fincaId,
    this.soilBalance,
    this.lastUpdated,
    this.calculatedAt,
  });

  /// Parses Meteocat API response
  /// [date] is passed explicitly as API might structure data strangely
  /// [et0] can be calculated externally and passed in
  factory ClimateDailyData.fromMeteocat(
    DateTime date,
    Map<String, dynamic> json, {
    double calculatedEt0 = 0.0,
  }) {
    final variables = json['variables'] as List<dynamic>? ?? [];

    double? max40; // Max Abs
    double? min42; // Min Abs

    // Aggregators for 30-min data
    double tempMax32 = -999.0;
    double tempMin32 = 999.0;
    bool has32 = false;

    double rainSum = 0.0;

    // Averages
    double humidSum = 0.0;
    int humidCount = 0;

    double radSum = 0.0;

    double windSum = 0.0;
    int windCount = 0;

    // Track the latest reading timestamp
    DateTime? latestReading;

    for (var v in variables) {
      final code = v['codi']; // int
      final readings = v['lectures'] as List<dynamic>?;

      if (readings != null && readings.isNotEmpty) {
        for (var r in readings) {
          final double val = (r['valor'] as num).toDouble();

          // Parse Reading Timestamp
          if (r.containsKey('data')) {
            try {
              final dt = DateTime.parse(r['data']);
              if (latestReading == null || dt.isAfter(latestReading)) {
                latestReading = dt;
              }
            } catch (_) {}
          }

          // 32: Temperature (Instant)
          if (code == 32) {
            if (val > tempMax32) tempMax32 = val;
            if (val < tempMin32) tempMin32 = val;
            has32 = true;
          }

          // 40: Max Temp (Daily Value? or list of 1?)
          // If it's a list, usually it contains the max for the period.
          if (code == 40) {
            if (max40 == null || val > max40) max40 = val;
          }

          // 42: Min Temp
          if (code == 42) {
            if (min42 == null || val < min42) min42 = val;
          }

          // 35: Rain (Precipitation)
          if (code == 35) {
            rainSum += val;
          }

          // 33: Relative Humidity
          if (code == 33) {
            humidSum += val;
            humidCount++;
          }

          // 36: Global Solar Irradiance (RS) - W/m2
          // Replaces incorrect Code 34 (which was Pressure!)
          if (code == 36) {
            radSum += val; // Summing W/m2
          }

          // 30: Wind Speed (10m)
          // ONLY Code 30. Code 31 is Direction (Do not add!)
          if (code == 30) {
            windSum += val;
            windCount++;
          }
        }
      }
    }

    // Final calculations
    double finalMax = max40 ?? (has32 ? tempMax32 : 0.0);
    double finalMin = min42 ?? (has32 ? tempMin32 : 0.0);
    double finalHumid = humidCount > 0 ? humidSum / humidCount : 0.0;

    // Radiation: Sum(W/m2) * 1800s (30min) = Joules/m2. Divide by 1e6 => MJ/m2
    // If radSum is sum of means... (Avg W/m2 * 1800s) = Joules for that 30min slot.
    // Summing them gives total Joules for the day.
    double finalRad = radSum * 1800 / 1000000;

    double finalWind = windCount > 0 ? windSum / windCount : 0.0;

    return ClimateDailyData(
      date: date,
      maxTemp: finalMax,
      minTemp: finalMin,
      rain: rainSum, // Accumulated sum
      rainAccumulated: 0.0,
      humidity: finalHumid, // Mean
      radiation: finalRad, // Mean
      windSpeed: finalWind, // Mean
      et0: calculatedEt0,
      isMock: false,
      fincaId: null,
      lastUpdated:
          latestReading ?? DateTime.now(), // Fallback to now if no data found
    );
  }

  // Serialization
  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String().split('T').first, // Store as YYYY-MM-DD
      'maxTemp': maxTemp,
      'minTemp': minTemp,
      'rain': rain,
      'rainAccumulated': rainAccumulated,
      'humidity': humidity,
      'radiation': radiation,
      'windSpeed': windSpeed,
      'et0': et0,
      'fincaId': fincaId,
      if (soilBalance != null) 'soilBalance': soilBalance,
      if (lastUpdated != null) 'lastUpdated': Timestamp.fromDate(lastUpdated!),
      if (calculatedAt != null)
        'calculatedAt': Timestamp.fromDate(calculatedAt!),
    };
  }

  factory ClimateDailyData.fromMap(Map<String, dynamic> map) {
    return ClimateDailyData(
      date: _parseDateTime(map['date']) ?? DateTime.now(),
      maxTemp: map['maxTemp']?.toDouble() ?? 0.0,
      minTemp: map['minTemp']?.toDouble() ?? 0.0,
      rain: map['rain']?.toDouble() ?? 0.0,
      rainAccumulated: map['rainAccumulated']?.toDouble() ?? 0.0,
      humidity: map['humidity']?.toDouble() ?? 0.0,
      radiation: map['radiation']?.toDouble() ?? 0.0,
      windSpeed: map['windSpeed']?.toDouble() ?? 0.0,
      et0: map['et0']?.toDouble() ?? 0.0,
      fincaId: map['fincaId'],
      soilBalance: map['soilBalance']?.toDouble(),
      lastUpdated: _parseDateTime(map['lastUpdated']),
      calculatedAt: _parseDateTime(map['calculatedAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class ClimateMonthComparison {
  final DateTime month;
  final List<ClimateDailyData> currentData;
  final List<ClimateDailyData> previousData;

  ClimateMonthComparison({
    required this.month,
    required this.currentData,
    required this.previousData,
  });

  // Helpers
  double get totalRainCurrent =>
      currentData.fold(0.0, (total, d) => total + d.rain);
  double get totalRainPrevious =>
      previousData.fold(0.0, (total, d) => total + d.rain);

  double get diffPercentage {
    if (totalRainPrevious == 0) return totalRainCurrent > 0 ? 100.0 : 0.0;
    return ((totalRainCurrent - totalRainPrevious) / totalRainPrevious) * 100;
  }
}
