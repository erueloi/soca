import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:soca/core/services/meteocat_service.dart';
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
          padding: const EdgeInsets.all(8.0), // Compact padding 8.0
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
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    weather.stationName.isNotEmpty &&
                                            weather.stationName.length > 3
                                        ? weather.stationName
                                        : 'La Floresta',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Icons with fixed width - won't be clipped
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 16,
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
                                    size: 18, // Smaller icon
                                    color: Colors.grey,
                                  ),
                                  onPressed: () async {
                                    // Check if data is recent (< 4 hours)
                                    final last =
                                        weather.lastUpdated ??
                                        DateTime.fromMillisecondsSinceEpoch(0);
                                    final diff = DateTime.now().difference(
                                      last,
                                    );

                                    if (diff.inHours < 4) {
                                      final shouldForce = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Dades Recents'),
                                          content: Text(
                                            'Les dades tenen menys de 4h '
                                            '(Fa ${diff.inHours}h ${diff.inMinutes % 60}m).\n\n'
                                            'Vols forçar una actualització? Això consumirà quota mensual.\n\n'
                                            '⚠️ Nota: Hauràs de recalcular manualment a la pàgina de Clima per actualitzar el balanç.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                false,
                                              ), // No
                                              child: const Text('Mantenir'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                true,
                                              ), // Sí
                                              child: const Text(
                                                'Forçar',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (shouldForce != true) return;

                                      // Set Force Flag
                                      ref
                                          .read(meteocatServiceProvider)
                                          .setForceNextUpdate(true);
                                    }

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Actualitzant dades... ⏳',
                                        ),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    try {
                                      final _ = await ref.refresh(
                                        weatherProvider.future,
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error: ${e.toString().replaceAll("Exception:", "")}',
                                            ),
                                            backgroundColor: Colors.orange,
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
                                  spacing: 2, // Tighter
                                  runSpacing: 2, // Tighter
                                  children: weather.alerts.map((alert) {
                                    return Tooltip(
                                      message: alert.message,
                                      triggerMode: TooltipTriggerMode.tap,
                                      showDuration: const Duration(seconds: 3),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getAlertIcon(alert.icon),
                                              size: 12,
                                              color: Colors.red.shade900,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              alert.title,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.red.shade900,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Top Right Timestamp
                      if (weather.lastUpdated != null)
                        Text(
                          'Act: ${DateFormat('dd/MM HH:mm').format(weather.lastUpdated!.toLocal())}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  // 2. MAIN METRICS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Icon(
                            _getWeatherIcon(weather.rainProbability),
                            color: _getWeatherColor(weather.rainProbability),
                            size: 48, // Balanced with Text
                          ),
                          Text(
                            '${weather.temperature.toStringAsFixed(1)}°C',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 42,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            '${(weather.windSpeed * 3.6).toStringAsFixed(1)} km/h',
                          ),
                          _buildMetricRow(
                            Icons.wb_sunny_outlined,
                            'ET0: ${weather.et0.toStringAsFixed(1)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  // 3. IRRIGATION ADVICE
                  Container(
                    padding: const EdgeInsets.all(4), // Reduced padding
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
                                fontSize: 9, // Smaller
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
                                fontSize: 11, // Smaller
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
                    const Divider(height: 8), // Reduced height
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
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
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(height: 0), // Removed spacing
                              Icon(
                                _getWeatherIcon(f.rainProb),
                                size: 14,
                                color: _getWeatherColor(f.rainProb),
                              ),
                              const SizedBox(height: 0), // Removed spacing
                              Text(
                                '${f.minTemp}° / ${f.maxTemp}°',
                                style: const TextStyle(fontSize: 8),
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
              _buildHelpRow(
                Colors.red,
                'Reg Recomanat',
                'Reserva Crítica (< -15mm)',
              ),
              _buildHelpRow(
                Colors.amber,
                'Reg Opcional',
                'Estrès Moderat (-5 a -15mm)',
              ),
              _buildHelpRow(
                Colors.green,
                'No regar / Esperar',
                'Terra Humida (> -5mm) o Pluja/Boira',
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
                'ET0: Evapotranspiració (Estimació acumulada al final del dia)',
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
      return Colors.green;
    }
    if (advice.contains('Reg recomanat')) return Colors.red;
    return Colors.amber;
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
