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

    // 1. Calculations
    int viable = 0;
    int malalt = 0;
    int mort = 0;

    double totalHeight = 0;
    int heightCount = 0;

    int fruiters = 0;

    for (var tree in trees) {
      // Status
      final status = tree.status.toLowerCase();
      if (status.contains('viable')) {
        viable++;
      } else if (status.contains('mort')) {
        mort++;
      } else if (status.contains('malalt')) {
        malalt++;
      }

      // Height
      if (tree.height != null && tree.height! > 0) {
        totalHeight += tree.height!;
        heightCount++;
      }

      // Function
      if (tree.ecologicalFunction == 'Fruit') {
        fruiters++;
      }
    }

    final total = trees.length;
    double avgHeight = heightCount > 0 ? totalHeight / heightCount : 0.0;
    // Heuristic: If avgHeight > 4, assume it's cm (e.g. 265 cm) -> convert to m
    // Trees > 4m are possible, but 265m is impossible.
    if (avgHeight > 10) {
      avgHeight = avgHeight / 100;
    }

    final viabilityPct = total > 0
        ? (viable / total * 100).toStringAsFixed(0)
        : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BIG TITLE
        Text(
          '$total Arbres',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        Text(
          'Inventari General',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            // METRICS COLUMN
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMetricRow(
                    context,
                    Icons.check_circle_outline,
                    Colors.green,
                    '$viabilityPct% Viables ($viable)',
                  ),
                  const SizedBox(height: 12), // Visual Air
                  _buildMetricRow(
                    context,
                    Icons.height,
                    Colors.blue,
                    'Alçada Mitjana: ${avgHeight.toStringAsFixed(2)} m',
                  ),
                  const SizedBox(height: 12), // Visual Air
                  _buildMetricRow(
                    context,
                    Icons.eco,
                    Colors.purple,
                    '$fruiters Fruiters',
                  ),
                ],
              ),
            ),

            // CHART - Reduced Size
            SizedBox(
              height: 75,
              width: 75,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 10,
                  startDegreeOffset: -90,
                  sections: [
                    if (viable > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: viable.toDouble(),
                        radius: 14,
                        showTitle: false,
                      ),
                    if (malalt > 0)
                      PieChartSectionData(
                        color: Colors.orange,
                        value: malalt.toDouble(),
                        radius: 14,
                        showTitle: false,
                      ),
                    if (mort > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: mort.toDouble(),
                        radius: 14,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    IconData icon,
    Color color,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Align center
      children: [
        Icon(icon, size: 20, color: color), // Slightly larger icon
        const SizedBox(width: 12), // More padding lateral
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
