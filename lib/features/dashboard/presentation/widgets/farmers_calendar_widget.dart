import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/data/repositories/species_repository.dart';
import '../../../trees/domain/entities/species.dart';
import '../../../trees/presentation/pages/species_library_page.dart';

class FarmersCalendarWidget extends ConsumerWidget {
  const FarmersCalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treesAsync = ref.watch(treesStreamProvider);
    final now = DateTime.now();
    final currentMonth = now.month;
    final repo = ref.read(speciesRepositoryProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SpeciesLibraryPage()),
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
                  Text(
                    'Calendari del Pagès - ${_getMonthName(currentMonth)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ...
              // ...

              // Content
              treesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
                data: (trees) {
                  if (trees.isEmpty) {
                    return const Text('No hi ha arbres per analitzar.');
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

                  // 2. Fetch Species Details & Categorize
                  final pruningList = <String>[];
                  final harvestList =
                      <MapEntry<String, int>>[]; // entries for count
                  final plantingList = <String>[];
                  final climateAlerts = <Widget>[];

                  for (final name in activeSpecies) {
                    final species = repo.findOfflineSpecies(name);
                    if (species != null) {
                      // Pruning
                      if (species.pruningMonths.contains(currentMonth)) {
                        pruningList.add(species.commonName);
                      }
                      // Harvest
                      if (species.harvestMonths.contains(currentMonth)) {
                        final count = speciesMap[name] ?? 0;
                        harvestList.add(MapEntry(species.commonName, count));
                      }
                      // Planting (Suggestion based on what we already have, "Expand inventory")
                      if (species.plantingMonths.contains(currentMonth)) {
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

                  // Remove duplicates
                  final uniquePruning = pruningList.toSet().toList();
                  final uniquePlanting = plantingList.toSet().toList();

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
                      // Task Rows
                      if (uniquePruning.isNotEmpty)
                        _buildTaskRow(
                          context,
                          'PODA',
                          uniquePruning.join(', '),
                          Icons.cut,
                          Colors.orange,
                          'Tisores a punt?',
                        ),
                      if (harvestList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildTaskRow(
                            context,
                            'COLLITA',
                            harvestList
                                .map((e) => '${e.key} (${e.value})')
                                .join(', '),
                            Icons.shopping_basket,
                            Colors.green,
                            'Bona collita!',
                          ),
                        ),
                      if (uniquePlanting.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildTaskRow(
                            context,
                            'PLANTACIÓ',
                            uniquePlanting.join(', '),
                            Icons.spa, // Sprout equivalent
                            Colors.blue,
                            'Bon moment per ampliar.',
                          ),
                        ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Summary Text
                      Text(
                        _generateSummary(
                          uniquePruning,
                          harvestList.map((e) => e.key).toList(),
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      if (climateAlerts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: climateAlerts,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    String label,
    String items,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: tooltip,
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
              Text(
                items,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
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

  String _generateSummary(List<String> pruning, List<String> harvest) {
    if (pruning.isEmpty && harvest.isEmpty) return 'Mes tranquil al camp.';

    final parts = <String>[];
    if (pruning.isNotEmpty) parts.add('es pot podar ${_naturalJoin(pruning)}');
    if (harvest.isNotEmpty) parts.add('collir ${_naturalJoin(harvest)}');

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
