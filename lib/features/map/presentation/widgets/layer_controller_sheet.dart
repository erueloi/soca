import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../providers/map_layers_provider.dart';
import '../providers/species_filter_provider.dart';
import '../providers/map_filter_provider.dart';

class LayerControllerSheet extends ConsumerWidget {
  const LayerControllerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(mapLayersProvider);
    final notifier = ref.read(mapLayersProvider.notifier);
    final treesAsync = ref.watch(treesStreamProvider);
    final hiddenSpecies = ref.watch(hiddenSpeciesProvider);
    final speciesNotifier = ref.read(hiddenSpeciesProvider.notifier);

    final trees = treesAsync.value ?? [];
    final speciesCounts = <String, int>{};

    // Get Date Filter
    final mapFilterState = ref.watch(mapFilterProvider);
    final dateRange = mapFilterState.plantingDateRange;

    // Filter trees based on active layers BEFORE counting
    final showPlanted = layers[MapLayer.plantedTrees] ?? true;
    final showPlanned = layers[MapLayer.provisionalTrees] ?? false;

    for (final tree in trees) {
      // 1. Check if tree type is visible
      final isPlanned = tree.status == 'Planned';
      if (isPlanned && !showPlanned) continue;
      if (!isPlanned && !showPlanted) continue;

      // 2. Check Date Range
      if (dateRange != null) {
        final start = DateTime(
          dateRange.start.year,
          dateRange.start.month,
          dateRange.start.day,
        );
        final end = DateTime(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day,
          23,
          59,
          59,
        );
        final date = tree.plantingDate;
        final isInRange =
            date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end);

        if (!isInRange) continue;
      }

      // 3. Count species
      if (tree.species.isNotEmpty) {
        speciesCounts[tree.species] = (speciesCounts[tree.species] ?? 0) + 1;
      }
    }
    final allSpecies = speciesCounts.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Capes del Mapa',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final configAsync = ref.watch(farmConfigStreamProvider);
                final config = configAsync.asData?.value;
                final currentSize = config?.mapMarkerSize ?? 20.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Mida Icones: ${currentSize.toInt()}px',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Slider(
                      value: currentSize,
                      min: 10,
                      max: 50,
                      divisions: 8,
                      label: '${currentSize.toInt()}px',
                      onChanged: config == null
                          ? null
                          : (val) {
                              ref
                                  .read(settingsRepositoryProvider)
                                  .saveFarmConfig(
                                    config.copyWith(mapMarkerSize: val),
                                  );
                            },
                    ),
                  ],
                );
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Tasques'),
              subtitle: const Text('Mostra marcadors de tasques'),
              secondary: const Icon(
                Icons.check_circle_outline,
                color: Colors.orange,
              ),
              value: layers[MapLayer.tasks] ?? true,
              onChanged: (val) => notifier.toggleLayer(MapLayer.tasks),
            ),
            // Sub-option for pending only (indented visually)
            if (layers[MapLayer.tasks] ?? true)
              Padding(
                padding: const EdgeInsets.only(left: 32.0),
                child: SwitchListTile(
                  title: const Text('Només Pendents'),
                  subtitle: const Text('Amaga les tasques completades'),
                  secondary: const Icon(
                    Icons.pending_actions,
                    color: Colors.amber,
                  ),
                  value: layers[MapLayer.pendingTasksOnly] ?? true,
                  onChanged: (val) =>
                      notifier.toggleLayer(MapLayer.pendingTasksOnly),
                ),
              ),
            SwitchListTile(
              title: const Text('Espais d\'Hort'),
              subtitle: const Text('Mostra les zones de cultiu (horts)'),
              secondary: const Icon(Icons.grass, color: Color(0xFF556B2F)),
              value: layers[MapLayer.espaisHort] ?? true,
              onChanged: (val) => notifier.toggleLayer(MapLayer.espaisHort),
            ),
            SwitchListTile(
              title: const Text('Zones Permacultura (PDC)'),
              subtitle: const Text('Mostra les zones de disseny'),
              secondary: const Icon(Icons.terrain, color: Colors.teal),
              value: layers[MapLayer.permacultureZones] ?? false,
              onChanged: (val) =>
                  notifier.toggleLayer(MapLayer.permacultureZones),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Arbres Plantats'),
              subtitle: const Text('Mostra arbres existents'),
              secondary: const Icon(Icons.park, color: Colors.green),
              value: layers[MapLayer.plantedTrees] ?? true,
              onChanged: (val) => notifier.toggleLayer(MapLayer.plantedTrees),
            ),
            SwitchListTile(
              title: const Text('Arbres Planificats'),
              subtitle: const Text('Mostra arbres provisionals'),
              secondary: const Icon(
                Icons.design_services,
                color: Colors.orange,
              ),
              value: layers[MapLayer.provisionalTrees] ?? false,
              onChanged: (val) =>
                  notifier.toggleLayer(MapLayer.provisionalTrees),
            ),
            if (layers[MapLayer.provisionalTrees] ?? false)
              Padding(
                padding: const EdgeInsets.only(left: 32.0),
                child: SwitchListTile(
                  title: const Text('Mida Adulta (ALO)'),
                  subtitle: const Text('Mostra l\'ocupació màxima futura'),
                  secondary: const Icon(
                    Icons.circle_outlined,
                    color: Colors.grey,
                  ),
                  value: layers[MapLayer.adultCanopy] ?? true,
                  onChanged: (val) =>
                      notifier.toggleLayer(MapLayer.adultCanopy),
                ),
              ),
            SwitchListTile(
              title: const Text('Ocultar Regats Avui'),
              subtitle: const Text('Amaga els arbres que ja has regat avui'),
              secondary: const Icon(Icons.water_drop, color: Colors.blue),
              value:
                  !(layers[MapLayer.wateredToday] ??
                      true), // Inverted logic for UI ("Hide" vs "Show")
              onChanged: (val) => notifier.toggleLayer(MapLayer.wateredToday),
            ),
            SwitchListTile(
              title: const Text('IDs dels Arbres'),
              subtitle: const Text('Mostra etiquetes amb el codi de l\'arbe'),
              secondary: const Icon(Icons.tag, color: Colors.grey),
              value: layers[MapLayer.treeLabels] ?? false,
              onChanged: (val) => notifier.toggleLayer(MapLayer.treeLabels),
            ),
            const Divider(), // Visual separation for Map Settings
            SwitchListTile(
              title: const Text('Fer servir OpenStreetMap'),
              subtitle: const Text('Si desactivat, fa servir ICGC (Catalunya)'),
              secondary: const Icon(Icons.public, color: Colors.blueAccent),
              value: layers[MapLayer.useOpenStreetMap] ?? false,
              onChanged: (val) =>
                  notifier.toggleLayer(MapLayer.useOpenStreetMap),
            ),
            SwitchListTile(
              title: const Text('Vista Satèl·lit'),
              subtitle: const Text(
                'Canvia entre mapa Topogràfic i Satèl·lit (ICGC)',
              ),
              secondary: const Icon(Icons.satellite_alt, color: Colors.purple),
              value: layers[MapLayer.satellite] ?? false,
              onChanged: (val) => notifier.toggleLayer(MapLayer.satellite),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Filtrar per Data de Plantació',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final mapFilterState = ref.watch(mapFilterProvider);
                final range = mapFilterState.plantingDateRange;

                String dateText = 'Totes les dates';
                if (range != null) {
                  dateText =
                      '${range.start.day}/${range.start.month}/${range.start.year} - ${range.end.day}/${range.end.month}/${range.end.year}';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        dateText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: range == null
                              ? Colors.grey[600]
                              : Colors.green[800],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ), // Future proof
                              initialDateRange: range,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Colors.green,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              ref
                                  .read(mapFilterProvider.notifier)
                                  .setPlantingDateRange(picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Seleccionar dates'),
                        ),
                        if (range != null)
                          IconButton(
                            onPressed: () {
                              ref
                                  .read(mapFilterProvider.notifier)
                                  .setPlantingDateRange(null);
                            },
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Esborrar filtre',
                            color: Colors.red,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),

            if (allSpecies.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtrar per Espècie',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => speciesNotifier.showAll(),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Totes'),
                      ),
                      TextButton(
                        onPressed: () => speciesNotifier.hideAll(allSpecies),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Cap'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allSpecies.length,
                itemBuilder: (context, index) {
                  final species = allSpecies[index];
                  final isVisible = !hiddenSpecies.contains(species);
                  final count = speciesCounts[species] ?? 0;

                  return CheckboxListTile(
                    title: Text.rich(
                      TextSpan(
                        text: species,
                        children: [
                          TextSpan(
                            text: ' ($count)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    value: isVisible,
                    activeColor: Colors.green,
                    onChanged: (val) => speciesNotifier.toggle(species),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
