import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soca/features/dashboard/presentation/providers/weather_provider.dart';

class WeatherWidget extends ConsumerWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'La Floresta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          onPressed: () => ref.refresh(weatherProvider),
                        ),
                        Icon(
                          weather.rainProbability > 50
                              ? Icons.cloud_queue
                              : Icons.wb_sunny,
                          color: weather.rainProbability > 50
                              ? Colors.grey
                              : Colors.orange,
                          size: 32,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${weather.temperature.toStringAsFixed(1)}°C',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Pluja (24h): ${weather.rainAccumulated}mm'),
                        Text('Humitat: ${weather.humidity}%'),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        weather.irrigationAdvice,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getAdviceColor(
                            weather.irrigationAdvice,
                          ).withValues(alpha: 1.0), // solid
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getAdviceColor(String advice) {
    if (advice.contains('No regar') || advice.contains('Esperar')) {
      return Colors.orange;
    }
    if (advice.contains('Reg recomanat')) return Colors.green;
    return Colors.grey;
  }
}
