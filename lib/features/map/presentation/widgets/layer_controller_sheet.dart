import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../providers/map_layers_provider.dart';
import '../providers/species_filter_provider.dart';

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
    for (final tree in trees) {
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
              subtitle: const Text('Mostra marcadors de tasques pendents'),
              secondary: const Icon(
                Icons.check_circle_outline,
                color: Colors.orange,
              ),
              value: layers[MapLayer.tasks] ?? true,
              onChanged: (val) => notifier.toggleLayer(MapLayer.tasks),
            ),
            SwitchListTile(
              title: const Text('Zones de Reg'),
              subtitle: const Text('Mostra les àrees de reg (A/B)'),
              secondary: const Icon(Icons.grass, color: Colors.blue),
              value: layers[MapLayer.irrigationZones] ?? false,
              onChanged: (val) =>
                  notifier.toggleLayer(MapLayer.irrigationZones),
            ),
            SwitchListTile(
              title: const Text('Salut dels Arbres'),
              subtitle: const Text(
                'Codifica els arbres per color segons salut',
              ),
              secondary: const Icon(Icons.health_and_safety, color: Colors.red),
              value: layers[MapLayer.healthStatus] ?? false,
              onChanged: (val) => notifier.toggleLayer(MapLayer.healthStatus),
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
