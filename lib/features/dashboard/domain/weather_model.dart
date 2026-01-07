class WeatherModel {
  final double temperature;
  final int humidity;
  final double rainAccumulated;
  final int rainProbability;
  final String irrigationAdvice;
  final String stationName;

  WeatherModel({
    required this.temperature,
    required this.humidity,
    required this.rainAccumulated,
    required this.rainProbability,
    required this.irrigationAdvice,
    required this.stationName,
  });

  factory WeatherModel.empty() {
    return WeatherModel(
      temperature: 0,
      humidity: 0,
      rainAccumulated: 0,
      rainProbability: 0,
      irrigationAdvice: 'Carregant...',
      stationName: '',
    );
  }
}
