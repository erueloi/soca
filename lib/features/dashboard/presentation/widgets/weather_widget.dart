import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soca/features/dashboard/presentation/providers/weather_provider.dart';
import '../../../climate/presentation/pages/clima_page.dart';

class WeatherWidget extends ConsumerWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClimaPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Compact padding
          child: weatherAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.red, fontSize: 10),
              ),
            ),
            data: (weather) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. HEADER & ICON
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.satellite_alt,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    weather.stationName.isNotEmpty &&
                                            weather.stationName.length > 3
                                        ? weather.stationName
                                        : 'La Floresta',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8), // Added spacing
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _showHelpDialog(context),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 20,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.refresh,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () async {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Actualitzant dades... ⏳',
                                        ),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    try {
                                      // Trigger refresh and await result to catch errors
                                      final _ = await ref.refresh(
                                        weatherProvider.future,
                                      );
                                      // Success is handled by UI update
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error actualitzant: ${e.toString().replaceAll("Exception:", "")}',
                                            ),
                                            backgroundColor: Colors.orange,
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                            if (weather.alerts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: weather.alerts.map((alert) {
                                    return Tooltip(
                                      message: alert.message,
                                      triggerMode: TooltipTriggerMode.tap,
                                      showDuration: const Duration(seconds: 3),
                                      child: Chip(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        labelPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                        backgroundColor: Colors.red.shade100,
                                        avatar: Icon(
                                          _getAlertIcon(alert.icon),
                                          size: 14,
                                          color: Colors.red.shade900,
                                        ),
                                        label: Text(
                                          alert.title,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.red.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: Just the Weather Icon now
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                        child: Icon(
                          _getWeatherIcon(weather.rainProbability),
                          color: _getWeatherColor(weather.rainProbability),
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 2. MAIN METRICS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            '${weather.temperature.toStringAsFixed(1)}°C',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 52, // BIGGER
                                ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildMetricRow(
                            Icons.water_drop,
                            '${weather.rainAccumulated}mm',
                          ),
                          _buildMetricRow(
                            Icons.opacity,
                            '${weather.humidity}%',
                          ),
                          _buildMetricRow(
                            Icons.air,
                            '${weather.windSpeed.toStringAsFixed(1)} m/s',
                          ),
                          _buildMetricRow(
                            Icons.wb_sunny_outlined,
                            'ET0: ${weather.et0.toStringAsFixed(1)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 3. IRRIGATION ADVICE
                  Container(
                    padding: const EdgeInsets.all(6),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _getAdviceColor(
                        weather.irrigationAdvice,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAdviceColor(weather.irrigationAdvice),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Recomanació de Reg',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                        ),
                        Text(
                          weather.irrigationAdvice,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _getAdviceColor(
                                  weather.irrigationAdvice,
                                ).withValues(alpha: 1.0),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Compact logic for divider
                  if (weather.forecast.isNotEmpty) ...[
                    const Divider(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weather.forecast.map((f) {
                          return Column(
                            children: [
                              Text(
                                [
                                  'Dl',
                                  'Dt',
                                  'Dc',
                                  'Dj',
                                  'Dv',
                                  'Ds',
                                  'Dg',
                                ][f.date.weekday - 1],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                _getWeatherIcon(f.rainProb),
                                size: 16,
                                color: _getWeatherColor(f.rainProb),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${f.minTemp}° / ${f.maxTemp}°',
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guia del Tauler'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Colors de recomanació:'),
              const SizedBox(height: 8),
              _buildHelpRow(Colors.green, 'Reg Recomanat', 'Dèficit > 5mm'),
              _buildHelpRow(
                Colors.orange,
                'No regar / Esperar',
                'Pluja recent, alta humitat o previsió de pluja',
              ),
              _buildHelpRow(
                Colors.grey,
                'Reg Opcional',
                'Balanç equilibrat (-5 a 5mm)',
              ),
              const SizedBox(height: 16),
              const Text('Mètriques:'),
              const SizedBox(height: 8),
              // Forecast Help Row
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.wb_sunny, size: 16, color: Colors.orange),
                    const Text('/', style: TextStyle(fontSize: 12)),
                    Icon(Icons.cloud_queue, size: 16, color: Colors.blueGrey),
                    const Text('/', style: TextStyle(fontSize: 12)),
                    Icon(Icons.cloud, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sol (<30%) / Variable (<70%) / Ennubolat (>70%)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              _buildMetricHelp(Icons.water_drop, 'Pluja acumulada (24h)'),
              _buildMetricHelp(Icons.opacity, 'Humitat relativa'),
              _buildMetricHelp(Icons.air, 'Velocitat del vent'),
              _buildMetricHelp(
                Icons.wb_sunny_outlined,
                'ET0: Evapotranspiració (Aigua que perd el sòl)',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entesos'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(Color color, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$title: $desc', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricHelp(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[800]), // Darker & Larger
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 13, // Larger
              fontWeight: FontWeight.w500, // Bolder
              color: Colors.grey[900], // Darker
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(String iconName) {
    switch (iconName) {
      case 'warning':
        return Icons.warning;
      case 'check':
        return Icons.check_circle;
      case 'palette':
        return Icons.format_paint;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'air':
        return Icons.air;
      default:
        return Icons.info;
    }
  }

  Color _getAdviceColor(String advice) {
    if (advice.contains('No regar') || advice.contains('Esperar')) {
      return Colors.orange;
    }
    if (advice.contains('Reg recomanat')) return Colors.green;
    return Colors.grey;
  }

  // --- Helpers for Weather Icons ---
  IconData _getWeatherIcon(int prob) {
    if (prob < 30) return Icons.wb_sunny;
    if (prob < 70) return Icons.cloud_queue; // Variable / Partly
    return Icons.cloud; // Cloudy / Rain
  }

  Color _getWeatherColor(int prob) {
    if (prob < 30) return Colors.orange;
    if (prob < 70) return Colors.blueGrey;
    return Colors.grey;
  }
}
