import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';

class TaskBucketWidget extends ConsumerWidget {
  const TaskBucketWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final bucketsAsync = ref.watch(bucketsStreamProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for usage in ScrollView
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
            const SizedBox(height: 16),
            tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error: $e'),
              data: (tasks) => bucketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
                data: (buckets) {
                  final activeBuckets = buckets
                      .where((b) => !b.isArchived && b.showOnDashboard)
                      .toList();

                  if (activeBuckets.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hi ha projectes destacats.\nVes a "Gestionar Columnes" per destacar-ne algun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 110, // Fixed height for the horizontal list
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: activeBuckets.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 24),
                      itemBuilder: (context, index) {
                        final bucket = activeBuckets[index];
                        final bucketTasks = tasks
                            .where((t) => t.bucket == bucket.name)
                            .toList();

                        // Calculate Progress
                        double progress = 0.0;
                        if (bucketTasks.isNotEmpty) {
                          final completedCount = bucketTasks
                              .where((t) => t.isDone)
                              .length;
                          progress = completedCount / bucketTasks.length;
                        }

                        // Determine Color (Cycle through a few options or random)
                        // Simple determinism based on name length or hash
                        final colors = [
                          Colors.orange,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                          Colors.teal,
                        ];
                        final color =
                            colors[bucket.name.hashCode.abs() % colors.length];

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TasksPage(initialBucketFilter: bucket.name),
                              ),
                            );
                          },
                          child: _buildProjectProgress(
                            context,
                            bucket.name,
                            progress,
                            color,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
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
      mainAxisAlignment: MainAxisAlignment.center,
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
        SizedBox(
          width: 80, // Limit text width
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
