class WeatherModel {
  final double temperature;
  final int humidity;
  final double rainAccumulated;
  final int rainProbability;
  final String irrigationAdvice;
  final String stationName;
  final double windSpeed;
  final double et0;
  final List<DailyForecast> forecast;
  final List<SafetyAlert> alerts;

  WeatherModel({
    required this.temperature,
    required this.humidity,
    required this.rainAccumulated,
    required this.rainProbability,
    required this.irrigationAdvice,
    required this.stationName,
    this.windSpeed = 0.0,
    this.et0 = 0.0,
    this.forecast = const [],
    this.alerts = const [],
  });

  factory WeatherModel.empty() {
    return WeatherModel(
      temperature: 0,
      humidity: 0,
      rainAccumulated: 0,
      rainProbability: 0,
      irrigationAdvice: 'Carregant...',
      stationName: '',
      windSpeed: 0,
      et0: 0,
      forecast: [],
      alerts: [],
    );
  }
}

class DailyForecast {
  final DateTime date;
  final int minTemp;
  final int maxTemp;
  final int rainProb;
  final String symbol;

  DailyForecast({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.rainProb,
    required this.symbol,
  });
}

class SafetyAlert {
  final String title;
  final String message;
  final String icon;

  SafetyAlert({required this.title, required this.message, required this.icon});
}
