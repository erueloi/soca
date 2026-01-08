class WeatherModel {
  final double temperature;
  final int humidity;
  final double rainAccumulated;
  final int rainProbability;
  final String irrigationAdvice;
  final String stationName;
  final List<SafetyAlert> alerts;

  WeatherModel({
    required this.temperature,
    required this.humidity,
    required this.rainAccumulated,
    required this.rainProbability,
    required this.irrigationAdvice,
    required this.stationName,
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
      alerts: [],
    );
  }
}

class SafetyAlert {
  final String title;
  final String message;
  final String icon; // Asset or Material Icon name

  SafetyAlert({required this.title, required this.message, required this.icon});
}
