import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/data/repositories/species_repository.dart';
import '../../../trees/domain/entities/species.dart';
import '../../../trees/presentation/pages/species_library_page.dart';

final speciesListStreamProvider = StreamProvider<List<Species>>((ref) {
  final repo = ref.watch(speciesRepositoryProvider);
  return repo.getSpecies();
});

class FarmersCalendarWidget extends ConsumerWidget {
  const FarmersCalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treesAsync = ref.watch(treesStreamProvider);
    final speciesListAsync = ref.watch(speciesListStreamProvider);
    final now = DateTime.now();
    final currentMonth = now.month;
    final repo = ref.read(speciesRepositoryProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        // Main Column for the Card
        children: [
          Expanded(
            // Make the entire inkwell area expandable
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SpeciesLibraryPage(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.indigo,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Calendari del Pagès - ${_getMonthName(currentMonth)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.indigo.shade900,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Content
                    Expanded(
                      child: treesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('Error: $e'),
                        data: (trees) {
                          if (trees.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hi ha arbres per analitzar.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          // 1. Identify distinct species
                          final speciesMap = <String, int>{}; // Name -> Count
                          final activeSpecies = <String>{};

                          for (final tree in trees) {
                            final name = tree.species.isNotEmpty
                                ? tree.species
                                : tree.commonName;
                            if (name.isNotEmpty) {
                              speciesMap[name] = (speciesMap[name] ?? 0) + 1;
                              activeSpecies.add(name);
                            }
                          }

                          return speciesListAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (_, _) => const SizedBox.shrink(),
                            data: (allSpecies) {
                              // Build lookup map (Common + Scientific)
                              final lookupMap = <String, Species>{};
                              for (final s in allSpecies) {
                                lookupMap[s.commonName.toLowerCase()] = s;
                                lookupMap[s.scientificName.toLowerCase()] = s;
                              }

                              // 2. Fetch Species Details & Categorize
                              final pruningList = <String>[];
                              final harvestList = <MapEntry<String, int>>[];
                              final plantingList = <String>[];
                              final climateAlerts = <Widget>[];

                              for (final name in activeSpecies) {
                                // Priority: Online Data -> Offline Fallback
                                final species =
                                    lookupMap[name.toLowerCase()] ??
                                    repo.findOfflineSpecies(name);

                                if (species != null) {
                                  // Pruning
                                  if (species.pruningMonths.contains(
                                    currentMonth,
                                  )) {
                                    pruningList.add(species.commonName);
                                  }
                                  // Harvest
                                  if (species.harvestMonths.contains(
                                    currentMonth,
                                  )) {
                                    final count = speciesMap[name] ?? 0;
                                    harvestList.add(
                                      MapEntry(species.commonName, count),
                                    );
                                  }
                                  // Planting
                                  if (species.plantingMonths.contains(
                                    currentMonth,
                                  )) {
                                    plantingList.add(species.commonName);
                                  }
                                  // Climate
                                  _checkClimate(
                                    context,
                                    species,
                                    currentMonth,
                                    climateAlerts,
                                  );
                                }
                              }

                              // Remove duplicates logic continues below...
                              // Need to match the closing structure of the original code.
                              // Original code ended the loop and then processed lists.
                              // I need to return the Column here directly?
                              // The original code returned `Column` AFTER the loop.
                              // So I should perform the processing inside `data` callback and return result.

                              final uniquePruning = pruningList
                                  .toSet()
                                  .toList();

                              final uniquePlanting = plantingList
                                  .toSet()
                                  .toList();

                              if (uniquePruning.isEmpty &&
                                  harvestList.isEmpty &&
                                  uniquePlanting.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Res a fer aquest mes! Gaudeix del paisatge.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (uniquePruning.isNotEmpty)
                                            _buildTaskRow(
                                              context,
                                              'PODA',
                                              uniquePruning,
                                              Icons.cut,
                                              Colors.orange,
                                            ),
                                          if (harvestList.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: _buildTaskRow(
                                                context,
                                                'COLLITA',
                                                harvestList
                                                    .map((e) => e.key)
                                                    .toList(),
                                                Icons.shopping_basket,
                                                Colors.green,
                                              ),
                                            ),
                                          if (uniquePlanting.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: _buildTaskRow(
                                                context,
                                                'PLANTACIÓ',
                                                uniquePlanting,
                                                Icons.spa,
                                                Colors.blue,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (climateAlerts.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: climateAlerts,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: Colors.indigo,
                                        ),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Veure resum detallat',
                                        onPressed: () => _showSummaryDialog(
                                          context,
                                          trees,
                                          allSpecies,
                                          currentMonth,
                                          repo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    String label,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    const int maxItems = 3;
    final displayItems = items.take(maxItems).join(', ');
    final remaining = items.length - maxItems;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: items.join(', '),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                    fontFamily: 'Inter',
                  ),
                  children: [
                    TextSpan(text: displayItems),
                    if (remaining > 0) ...[
                      const TextSpan(text: ' i '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: InkWell(
                          onTap: () {
                            _showListDialog(context, label, items, icon, color);
                          },
                          child: Text(
                            '$remaining més',
                            style: TextStyle(
                              color: color,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showListDialog(
    BuildContext context,
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(e),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tancar'),
          ),
        ],
      ),
    );
  }

  void _checkClimate(
    BuildContext context,
    Species species,
    int month,
    List<Widget> alerts,
  ) {
    // Frost (Winter)
    if ([12, 1, 2].contains(month) &&
        species.frostSensitivity.toLowerCase().contains('alta')) {
      alerts.add(
        _buildClimateChip(
          Icons.ac_unit,
          'Protegir ${species.commonName}',
          Colors.blue.shade100,
          Colors.blue.shade800,
        ),
      );
    }
    // Sun/Water (Summer)
    if ([6, 7, 8].contains(month)) {
      if (species.sunNeeds.toLowerCase() == 'baix') {
        alerts.add(
          _buildClimateChip(
            Icons.wb_sunny,
            'Ombra per ${species.commonName}',
            Colors.orange.shade100,
            Colors.orange.shade800,
          ),
        );
      }
      if (species.kc > 0.8) {
        // High water need
        alerts.add(
          _buildClimateChip(
            Icons.water_drop,
            'Regar ${species.commonName}',
            Colors.lightBlue.shade100,
            Colors.lightBlue.shade800,
          ),
        );
      }
    }
  }

  Widget _buildClimateChip(IconData icon, String label, Color bg, Color fb) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fb.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fb),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: fb,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(
    BuildContext context,
    List<dynamic> trees,
    List<Species> allSpecies,
    int currentMonth,
    SpeciesRepository repo,
  ) {
    // Re-run logic for full lists
    final speciesMap = <String, int>{};
    final activeSpecies = <String>{};
    for (final tree in trees) {
      final name = tree.species.isNotEmpty ? tree.species : tree.commonName;
      if (name.isNotEmpty) {
        speciesMap[name] = (speciesMap[name] ?? 0) + 1;
        activeSpecies.add(name);
      }
    }

    final lookupMap = <String, Species>{};
    for (final s in allSpecies) {
      lookupMap[s.commonName.toLowerCase()] = s;
      lookupMap[s.scientificName.toLowerCase()] = s;
    }

    final pruningList = <String>[];
    final harvestList = <String>[];
    final plantingList = <String>[];

    for (final name in activeSpecies) {
      final species =
          lookupMap[name.toLowerCase()] ?? repo.findOfflineSpecies(name);
      if (species != null) {
        if (species.pruningMonths.contains(currentMonth)) {
          pruningList.add(species.commonName);
        }
        if (species.harvestMonths.contains(currentMonth)) {
          harvestList.add(species.commonName);
        }
        if (species.plantingMonths.contains(currentMonth)) {
          plantingList.add(species.commonName);
        }
      }
    }

    final uniquePruning = pruningList.toSet().toList();
    final uniqueHarvest = harvestList.toSet().toList();
    final uniquePlanting = plantingList.toSet().toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resum del Mes - ${_getMonthName(currentMonth)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _generateSummary(
                  uniquePruning,
                  uniqueHarvest,
                  uniquePlanting,
                  isFull: true,
                ),
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              if (uniquePruning.isNotEmpty) ...[
                _buildSectionHeader(Icons.cut, 'PODA', Colors.orange),
                Text(uniquePruning.join(', ')),
                const SizedBox(height: 12),
              ],
              if (uniqueHarvest.isNotEmpty) ...[
                _buildSectionHeader(
                  Icons.shopping_basket,
                  'COLLITA',
                  Colors.green,
                ),
                Text(uniqueHarvest.join(', ')),
                const SizedBox(height: 12),
              ],
              if (uniquePlanting.isNotEmpty) ...[
                _buildSectionHeader(Icons.spa, 'PLANTACIÓ', Colors.blue),
                Text(uniquePlanting.join(', ')),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tancar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _generateSummary(
    List<String> pruning,
    List<String> harvest,
    List<String> planting, {
    bool isFull = false,
  }) {
    if (pruning.isEmpty && harvest.isEmpty && planting.isEmpty) {
      return 'Mes tranquil al camp.';
    }
    final parts = <String>[];

    if (isFull) {
      if (pruning.isNotEmpty) {
        parts.add('es pot podar ${_naturalJoin(pruning)}');
      }
      if (harvest.isNotEmpty) {
        parts.add('collir ${_naturalJoin(harvest)}');
      }
      if (planting.isNotEmpty) {
        parts.add('plantar ${_naturalJoin(planting)}');
      }
    } else {
      if (pruning.isNotEmpty) parts.add('es pot podar');
      if (harvest.isNotEmpty) parts.add('collir');
      if (planting.isNotEmpty) parts.add('plantar');
    }

    String result = 'Aquest mes ${parts.join(" i ")}.';
    return result[0].toUpperCase() + result.substring(1);
  }

  String _naturalJoin(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(", ")} i ${items.last}';
  }

  String _getMonthName(int month) {
    const months = [
      'Gener',
      'Febrer',
      'Març',
      'Abril',
      'Maig',
      'Juny',
      'Juliol',
      'Agost',
      'Setembre',
      'Octubre',
      'Novembre',
      'Desembre',
    ];
    return months[month - 1];
  }
}
