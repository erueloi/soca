import 'package:flutter/material.dart';

class TaskBucketWidget extends StatelessWidget {
  const TaskBucketWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Projectes Actius',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Icon(Icons.list_alt, color: Colors.brown, size: 28),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProjectProgress(
                  context,
                  'Reforma\nMasia',
                  0.65,
                  Colors.orange,
                ),
                _buildProjectProgress(
                  context,
                  'Poda\nHivern',
                  0.30,
                  Colors.green,
                ),
                _buildProjectProgress(
                  context,
                  'Instal·lació\nReg',
                  0.85,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectProgress(
    BuildContext context,
    String label,
    double progress,
    Color color,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
