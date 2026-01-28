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
        // TOP ROW: Title + Chart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // CHART - Larger
            SizedBox(
              height: 120, // Increased from 100
              width: 120, // Increased from 100
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 20, // Increased from 16
                  startDegreeOffset: -90,
                  sections: [
                    if (viable > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: viable.toDouble(),
                        title: viable.toString(),
                        radius: 25,
                        showTitle: true,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (malalt > 0)
                      PieChartSectionData(
                        color: Colors.orange,
                        value: malalt.toDouble(),
                        title: malalt.toString(),
                        radius: 25,
                        showTitle: true,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (mort > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: mort.toDouble(),
                        title: mort.toString(),
                        radius: 25,
                        showTitle: true,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8), // Reduced from 24 to 8 to avoid overflow
        // METRICS COLUMN (Bottom)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricRow(
              context,
              Icons.check_circle_outline,
              Colors.green,
              '$viabilityPct% Viables ($viable)',
            ),
            const SizedBox(height: 8), // Reduced from 12
            _buildMetricRow(
              context,
              Icons.height,
              Colors.blue,
              'Alçada Mitjana: ${avgHeight.toStringAsFixed(2)} m',
            ),
            const SizedBox(height: 8), // Reduced from 12
            _buildMetricRow(
              context,
              Icons.eco,
              Colors.purple,
              '$fruiters Fruiters',
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
        Icon(icon, size: 18, color: color), // Slightly smaller icon (20->18)
        const SizedBox(width: 8), // Reduced padding (12->8)
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ), // Slightly smaller text (14->13)
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
