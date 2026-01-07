class ClimateDailyData {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final double rain;
  final double rainAccumulated;
  final double humidity; // Code 33
  final double radiation; // Code 34
  final double windSpeed; // Code 30

  ClimateDailyData({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.rain,
    required this.rainAccumulated,
    this.humidity = 0.0,
    this.radiation = 0.0,
    this.windSpeed = 0.0,
  });

  // Factory to parse generic Meteocat structure
  factory ClimateDailyData.fromMeteocat(
    DateTime date,
    Map<String, dynamic> json,
  ) {
    // Trackers
    double max32 = -1000;
    double min32 = 1000;
    bool has32 = false;

    double max40 = -1000;
    bool has40 = false;

    double min42 = 1000;
    bool has42 = false;

    double rainVal = 0.0;
    double humidVal = 0.0;
    double radVal = 0.0;
    double windVal = 0.0;

    if (json.containsKey('data_list') && json['data_list'] is List) {
      final list = json['data_list'] as List;
      for (var item in list) {
        final vars = item['variables'] as List;
        for (var v in vars) {
          final int code = int.tryParse(v['codi'].toString()) ?? 0;
          final List<dynamic>? readings = v['lectures'];

          if (readings != null) {
            for (var r in readings) {
              // Quality Control: Relaxed to allow Provisional (P) data for recent dates.
              // if (r['estat'] != 'V') continue;

              final double? val = double.tryParse(r['valor'].toString());
              if (val == null) continue;

              // Temp Instant (32) - Backup
              if (code == 32) {
                if (val > max32) max32 = val;
                if (val < min32) min32 = val;
                has32 = true;
              }
              // Temp Max Abs (40) - Primary for Max
              if (code == 40) {
                if (val > max40) max40 = val;
                has40 = true;
              }
              // Temp Min Abs (42) - Primary for Min
              if (code == 42) {
                if (val < min42) min42 = val;
                has42 = true;
              }

              // Rain Intensity (35) - Primary for Rain
              // Usually sum if multiple readings, but daily summary is one reading
              if (code == 35) {
                rainVal = val;
              }

              // Humidity (33)
              if (code == 33) humidVal = val;

              // Radiation (34)
              if (code == 34) radVal = val;

              // Wind Speed (30)
              if (code == 30) windVal = val;
            }
          }
        }
      }
    }

    // Decide Final Min/Max
    // Prefer 40/42 if available (absolute extremes), else 32 (instant samples)
    final double finalMax = has40 ? max40 : (has32 ? max32 : 0.0);
    final double finalMin = has42 ? min42 : (has32 ? min32 : 0.0);

    return ClimateDailyData(
      date: date,
      maxTemp: finalMax,
      minTemp: finalMin,
      rain: rainVal,
      rainAccumulated:
          rainVal, // This is calculated later usually, but init with rain
      humidity: humidVal,
      radiation: radVal,
      windSpeed: windVal,
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
