import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/growth_entry.dart';
import '../providers/trees_provider.dart';

class TreeGrowthTimelinePage extends ConsumerWidget {
  final Tree tree;

  const TreeGrowthTimelinePage({super.key, required this.tree});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Històric de Creixement'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<GrowthEntry>>(
        stream: ref
            .read(treesRepositoryProvider)
            .getGrowthEntriesStream(tree.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          var displayedEntries = List<GrowthEntry>.from(entries);

          // Prepend Main Image if exists and not already in list
          if (tree.photoUrl != null) {
            final mainUrl = tree.photoUrl!;
            final exists = displayedEntries.any((e) => e.photoUrl == mainUrl);
            if (!exists) {
              final mainEntry = GrowthEntry(
                id: 'MAIN_PHOTO',
                date: tree.plantingDate,
                photoUrl: mainUrl,
                height: 0,
                trunkDiameter: 0,
                healthStatus: 'Inicial',
                observations: 'Foto Principal',
              );
              displayedEntries.add(
                mainEntry,
              ); // Add to end (oldest) if sorting desc?
              // Wait, timeline is usually Newest First.
              // If main photo is "Initial", it should be at the END of the list (Oldest).
              // Let's check sort order. Repository usually returns desc (newest first).
              // So if we simply add it, it goes to the end (oldest).
              // BUT we should verify date.

              displayedEntries.sort((a, b) => b.date.compareTo(a.date));
            }
          }

          if (displayedEntries.isEmpty) {
            return const Center(
              child: Text(
                'Encara no hi ha registres de seguiment.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Calculate summary
          // Assuming entries are sorted descending (Newest first) by the repository query.
          // Growth = Newest Height - Oldest Height.
          // Note: If only 1 entry, growth is 0 unless we assume initial height was 0?
          // Usually trees are planted at some height.
          // Let's assume growth from FIRST entry to LAST entry.

          // Re-sort to be sure? Repo does orderBy('date', descending: true).
          // So entries[0] is newest. entries.last is oldest.

          double currentHeight = displayedEntries.first.height;
          double initialHeight = displayedEntries.last.height;
          double growth = currentHeight - initialHeight;
          if (growth < 0) {
            growth = 0; // Should not happen usually unless error or cutting.
          }

          return Column(
            children: [
              // Summary Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.indigo.shade50,
                child: Column(
                  children: [
                    Text(
                      'Resum de Creixement',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade300,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Has crescut ${growth.toStringAsFixed(1)} cm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    Text(
                      'Des de ${DateFormat('dd/MM/yyyy').format(displayedEntries.last.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = displayedEntries[index];
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Timeline
                          SizedBox(
                            width: 60,
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('dd/MM').format(entry.date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                                Text(
                                  DateFormat('yyyy').format(entry.date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: Colors.indigo.shade100,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right: Card
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 24),
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (entry.photoUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            insetPadding: EdgeInsets.zero,
                                            backgroundColor: Colors.transparent,
                                            child: InteractiveViewer(
                                              child: Image.network(
                                                entry.photoUrl,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: SizedBox(
                                        height: 250,
                                        width: double.infinity,
                                        child: Image.network(
                                          entry.photoUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildMetric(
                                              'Alçada',
                                              '${entry.height} cm',
                                            ),
                                            _buildMetric(
                                              'Diàmetre',
                                              '${entry.trunkDiameter} cm',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.health_and_safety,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              entry.healthStatus,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (entry.observations.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            entry.observations,
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
