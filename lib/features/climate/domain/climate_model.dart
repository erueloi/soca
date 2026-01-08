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
  });

  /// Parses Meteocat API response
  /// [date] is passed explicitly as API might structure data strangely
  /// [et0] can be calculated externally and passed in
  factory ClimateDailyData.fromMeteocat(
    DateTime date,
    Map<String, dynamic> json, {
    double calculatedEt0 = 0.0,
  }) {
    // Variables
    final variables = json['variables'] as List<dynamic>? ?? [];

    double max40 = -999.0;
    double min42 = 999.0;

    // Backup (32 is mean usually, but sometimes instant)
    double max32 = -999.0;
    double min32 = 999.0;

    double rainVal = 0.0;
    double humidVal = 0.0;
    double radVal = 0.0;
    double windVal = 0.0;

    bool has40 = false;
    bool has42 = false;
    bool has32 = false;

    for (var v in variables) {
      final code = v['codi'];
      final readings = v['lectures'] as List<dynamic>?;

      if (readings != null && readings.isNotEmpty) {
        // Usually we take the first value or iterate
        // For daily data, usually just one value at 00:00 or similar
        final val = (readings[0]['valor'] as num).toDouble();

        // Temp Instant (32) - Backup
        if (code == 32) {
          if (val > max32) max32 = val;
          if (val < min32) min32 = val;
          has32 = true;
        }
        // Temp Max Abs (40)
        if (code == 40) {
          if (val > max40) max40 = val;
          has40 = true;
        }
        // Temp Min Abs (42)
        if (code == 42) {
          if (val < min42) min42 = val;
          has42 = true;
        }

        // Rain Intensity/Accumulated (35)
        if (code == 35) rainVal = val;

        // Humidity Max (33 is relative humidity)
        if (code == 33) humidVal = val;

        // Radiation (34)
        if (code == 34) radVal = val;

        // Wind (30)
        if (code == 30) windVal = val;
      }
    }

    // Resolve temps
    double finalMax = has40 ? max40 : (has32 ? max32 : 0.0);
    double finalMin = has42 ? min42 : (has32 ? min32 : 0.0);

    return ClimateDailyData(
      date: date,
      maxTemp: finalMax,
      minTemp: finalMin,
      rain: rainVal,
      rainAccumulated: 0.0, // provider handles this
      humidity: humidVal,
      radiation: radVal,
      windSpeed: windVal,
      et0: calculatedEt0,
      isMock: false,
    );
  }

  // Serialization
  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'maxTemp': maxTemp,
      'minTemp': minTemp,
      'rain': rain,
      'rainAccumulated': rainAccumulated,
      'humidity': humidity,
      'radiation': radiation,
      'windSpeed': windSpeed,
    };
  }

  factory ClimateDailyData.fromMap(Map<String, dynamic> map) {
    return ClimateDailyData(
      date: DateTime.parse(map['date']),
      maxTemp: map['maxTemp']?.toDouble() ?? 0.0,
      minTemp: map['minTemp']?.toDouble() ?? 0.0,
      rain: map['rain']?.toDouble() ?? 0.0,
      rainAccumulated: map['rainAccumulated']?.toDouble() ?? 0.0,
      humidity: map['humidity']?.toDouble() ?? 0.0,
      radiation: map['radiation']?.toDouble() ?? 0.0,
      windSpeed: map['windSpeed']?.toDouble() ?? 0.0,
    );
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
      currentData.fold(0.0, (sum, d) => sum + d.rain);
  double get totalRainPrevious =>
      previousData.fold(0.0, (sum, d) => sum + d.rain);

  double get diffPercentage {
    if (totalRainPrevious == 0) return totalRainCurrent > 0 ? 100.0 : 0.0;
    return ((totalRainCurrent - totalRainPrevious) / totalRainPrevious) * 100;
  }
}
