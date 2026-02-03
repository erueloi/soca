import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../construction/presentation/providers/construction_provider.dart';
import '../../../construction/presentation/pages/construction_floor_page.dart';
import '../../../construction/presentation/pages/construction_page.dart';

class FarmStatusWidget extends ConsumerWidget {
  const FarmStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(allConstructionPointsProvider);
    final floorsAsync = ref.watch(floorPlansStreamProvider);

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ConstructionPage()),
          );
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(
                      Icons.architecture,
                      color: Colors.indigo,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Estat de la Masia',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 8),

                pointsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                  data: (points) {
                    // 1. Calculate Progress
                    final total = points.length;
                    final completed = points
                        .where((p) => p.status == 'Finalitzat')
                        .length;
                    final percent = total == 0 ? 0.0 : (completed / total);

                    // 2. Calculate Urgencies
                    final urgencies = points
                        .where(
                          (p) =>
                              (p.pathology?.severity ?? 0) >= 8 &&
                              p.status != 'Finalitzat',
                        )
                        .toList();

                    return Column(
                      children: [
                        // Global Progress Row
                        Row(
                          children: [
                            CircularPercentIndicator(
                              radius: 35.0,
                              lineWidth: 8.0,
                              percent: percent,
                              center: Text(
                                "${(percent * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              progressColor: Colors.green,
                              backgroundColor: Colors.grey.shade200,
                              circularStrokeCap: CircularStrokeCap.round,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$completed / $total Actuacions',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    'Finalitzades', // Or "Completat"
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Urgency Alert
                        if (urgencies.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${urgencies.length} Actuacions Urgents Pendents',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Floor Plans List
                        floorsAsync.when(
                          data: (floors) {
                            // Sort floors logically? Alphabetic or predefined order?
                            // Let's rely on simple sort for now or map entry list.
                            // Assuming keys like "Planta Baixa", "Planta 1"...
                            final sortedKeys = floors.keys.toList()..sort();

                            return Column(
                              children: sortedKeys.map((floorId) {
                                final count = points
                                    .where((p) => p.floorId == floorId)
                                    .length;
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ConstructionFloorPage(
                                              floorId: floorId,
                                            ),
                                      ),
                                    );
                                    // Ideally navigate to specific tab?
                                    // ConstructionPage manages tabs internally.
                                    // We might need to pass initial index or floorId.
                                    // For now, just open main page.
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(floorId),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Colors.indigo,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
