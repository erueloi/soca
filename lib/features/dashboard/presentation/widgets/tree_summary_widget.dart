import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/presentation/pages/trees_page.dart';
import '../../../trees/domain/entities/tree.dart';

class TreeSummaryWidget extends ConsumerWidget {
  const TreeSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treesAsync = ref.watch(treesStreamProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TreesPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.forest,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24, // Consistent Icon Size
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Inventari', // Inventory
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              treesAsync.when(
                data: (trees) => _buildContent(context, trees),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Tree> trees) {
    if (trees.isEmpty) {
      return const Center(child: Text('0 Arbres'));
    }

    int viable = 0;
    int malalt = 0;
    int mort = 0;

    for (var tree in trees) {
      final status = tree.status.toLowerCase();
      if (status == 'viable') {
        viable++;
      } else if (status == 'mort') {
        mort++;
      } else {
        // Assume anything else is "Malalt" or "Mitjà" for the chart, simplified
        malalt++;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // BIG NUMBER
        Column(
          children: [
            Text(
              '${trees.length}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Text('Arbres Total'),
          ],
        ),
        const SizedBox(width: 16),
        // CHART
        SizedBox(
          height: 80,
          width: 80,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 15, // Donut style
              sections: [
                if (viable > 0)
                  PieChartSectionData(
                    color: Colors.green,
                    value: viable.toDouble(),
                    radius: 12,
                    showTitle: false,
                  ),
                if (malalt > 0)
                  PieChartSectionData(
                    color: Colors.orange,
                    value: malalt.toDouble(),
                    radius: 12,
                    showTitle: false,
                  ),
                if (mort > 0)
                  PieChartSectionData(
                    color: Colors.red,
                    value: mort.toDouble(),
                    radius: 12,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
