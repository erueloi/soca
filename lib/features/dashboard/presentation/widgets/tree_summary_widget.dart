import 'package:flutter/material.dart';

class TreeSummaryWidget extends StatelessWidget {
  const TreeSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  Icons.forest,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  'Inventari',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                '1,245',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Center(child: Text('Arbres Geolocalitzats')),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
