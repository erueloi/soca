import 'package:flutter/material.dart';

class WeatherWidget extends StatelessWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('El Temps', style: Theme.of(context).textTheme.titleLarge),
                const Icon(Icons.wb_sunny, color: Colors.orange, size: 32),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '24°C',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [Text('Pluja esperada: 0mm'), Text('Humitat: 45%')],
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Probabilitat de pluja (12h)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  return Container(
                    width: 8,
                    height: (index % 5 + 1) * 6.0, // Mock data
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
