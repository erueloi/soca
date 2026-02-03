import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trees_provider.dart';
import '../providers/tree_filter_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../widgets/tree_list.dart';
import '../widgets/tree_detail.dart';
import '../widgets/tree_form_sheet.dart';
import 'species_library_page.dart';

import 'inventory_stats_page.dart';

class TreesPage extends ConsumerStatefulWidget {
  const TreesPage({super.key});

  @override
  ConsumerState<TreesPage> createState() => _TreesPageState();
}

class _TreesPageState extends ConsumerState<TreesPage> {
  final TextEditingController _searchController =
      TextEditingController(); // Search query controller

  void _openAddTreeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TreeFormSheet(),
    );
  }

  void _showFilterDialog(
    List<dynamic> allTrees,
    Map<String, String> zoneNames,
  ) async {
    // Cast to List<Tree> if needed or use dynamic if type is not strictly imported in this file context yet
    // But better to use proper type. trees_provider.dart probably exports it or we can import it.
    // Let's assume strict typing is preferred. I'll add the import if needed in a separate step or assume it's available.
    // Actually, `Tree` is used in `TreeDetail(tree: selectedTree)`.
    // Let's check imports again.
    // No explicit import of `tree.dart`.
    // But `TreeList` assigns `trees`.
    // I will use `dynamic` or `var` in map/where to avoid type errors if `Tree` is not explicitly imported,
    // OR I should add the import.
    // Let's add the import to be safe? No, let's use `allTrees` as is, dart infers types.
    // But for method signature `List<Tree>` is better.
    // I will use `var` inside method.

    // Actually, let's look at `build` method. `data: (trees)` -> `trees`.
    // It's `List<Tree>`.
    // So I can just say `List<dynamic>` or `List<Object>` if I don't want to import, but better to use `List` and cast elements or just let type inference work.
    // I'll use `List allTrees` to be safe, or just import it.
    // Wait, I can't add import easily in this `replace_file_content` without touching top of file.
    // I'll stick to `List allTrees` (raw list) and cast inside or dynamic.
    // Actually, I'll use `var` for the elements.

    final availableSpecies =
        allTrees.map((t) => t.species as String).toSet().toList()..sort();
    final availableZones =
        allTrees
            .map((t) => t.zoneId as String?)
            .where((z) => z != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();
    final availableStatuses =
        allTrees.map((t) => t.status as String).toSet().toList()..sort();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final filterState = ref.watch(treeFilterProvider);
          final filterNotifier = ref.read(treeFilterProvider.notifier);
          final configAsync = ref.watch(farmConfigStreamProvider);

          // Create Zone ID -> Name Map internally to ensure it's reactive
          final Map<String, String> zoneNames = {};
          final config = configAsync.asData?.value;
          if (config != null) {
            for (final zone in config.permacultureZones) {
              zoneNames[zone.id] = zone.name;
            }
          }

          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtres Avançats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        filterNotifier.clearFilters();
                      },
                      child: const Text('Netejar tot'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      // Status Filter (Replacing Planned Toggle)
                      const Text(
                        'Estat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: availableStatuses.map((status) {
                          // Display 'Planificat' for consistent UX
                          final label = (status == 'Planned')
                              ? 'Planificat'
                              : status;
                          // Selected if NOT hidden
                          final isSelected = !filterState.hiddenStatuses
                              .contains(status);

                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              filterNotifier.toggleStatusVisibility(status);
                            },
                            showCheckmark: true,
                            avatar: isSelected
                                ? null
                                : const Icon(Icons.visibility_off, size: 16),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Species Filter
                      if (availableSpecies.isNotEmpty) ...[
                        const Text(
                          'Espècie',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: availableSpecies.map((species) {
                            final isSelected = filterState.selectedSpecies
                                .contains(species);
                            return FilterChip(
                              label: Text(species),
                              selected: isSelected,
                              onSelected: (selected) {
                                filterNotifier.toggleSpecies(species);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Zone Filter
                      if (availableZones.isNotEmpty) ...[
                        const Text(
                          'Zona (Bancal)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: availableZones.map((zoneId) {
                            final zoneName = zoneNames[zoneId] ?? zoneId;
                            final isSelected = filterState.selectedZones
                                .contains(zoneId);
                            return FilterChip(
                              label: Text(zoneName),
                              selected: isSelected,
                              onSelected: (selected) {
                                filterNotifier.toggleZone(zoneId);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('TANCAR'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treesAsync = ref.watch(treesStreamProvider);
    final configAsync = ref.watch(farmConfigStreamProvider);
    final filterState = ref.watch(treeFilterProvider);
    final selectedTree = ref.watch(selectedTreeProvider);
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    // Create Zone ID -> Name Map
    final Map<String, String> zoneNames = {};
    final config = configAsync.asData?.value;
    if (config != null) {
      for (final zone in config.permacultureZones) {
        zoneNames[zone.id] = zone.name;
      }
    }

    ref.listen(selectedTreeProvider, (previous, next) {
      if (next != null && !isLargeScreen) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TreeDetail(tree: next)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arbres de la Soca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Estadístiques',
            onPressed: () {
              final trees = treesAsync.asData?.value ?? [];
              if (trees.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryStatsPage(trees: trees),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Carregant dades...')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.local_florist),
            tooltip: 'Biblioteca d\'Espècies',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SpeciesLibraryPage()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cercar espècie o nom...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {}); // Rebuild to filter
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final trees = treesAsync.asData?.value ?? [];
                    if (trees.isNotEmpty) {
                      _showFilterDialog(trees, zoneNames);
                    }
                  },
                  icon: Badge(
                    isLabelVisible:
                        filterState.hiddenStatuses.isNotEmpty ||
                        filterState.selectedSpecies.isNotEmpty ||
                        filterState.selectedZones.isNotEmpty,
                    label: Text(
                      '${filterState.hiddenStatuses.length + filterState.selectedSpecies.length + filterState.selectedZones.length}',
                    ),
                    child: const Icon(Icons.tune),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: treesAsync.when(
        data: (trees) {
          final query = _searchController.text.toLowerCase();
          final filteredTrees = trees.where((t) {
            // 1. Text Search
            final matchesQuery =
                t.commonName.toLowerCase().contains(query) ||
                t.species.toLowerCase().contains(query);
            if (!matchesQuery) return false;

            // 2. Status Filter (Blacklist logic)
            // If status is in hiddenStatuses, we EXCLUDE it.
            if (filterState.hiddenStatuses.contains(t.status)) {
              return false;
            }

            // 3. Species Filter (Whitelist logic)
            if (filterState.selectedSpecies.isNotEmpty) {
              if (!filterState.selectedSpecies.contains(t.species)) {
                return false;
              }
            }

            // 4. Zone Filter (Whitelist logic)
            if (filterState.selectedZones.isNotEmpty) {
              if (t.zoneId == null ||
                  !filterState.selectedZones.contains(t.zoneId)) {
                return false;
              }
            }

            return true;
          }).toList();

          if (isLargeScreen) {
            // Master-Detail
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: TreeList(trees: filteredTrees),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: selectedTree != null
                      ? TreeDetail(tree: selectedTree)
                      : const Center(
                          child: Text(
                            'Selecciona un arbre per veure els detalls',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                ),
              ],
            );
          } else {
            // Mobile List (navigates to detail on tap handled in TreeList? No, TreeList updates state.
            // We need to listen to state change/tap and push route on mobile)
            // Actually, the TreeList widget updates the provider.
            // So here we need to react to that provider update if mobile.
            // Or better: pass a callback to TreeList.
            // Let's modify TreeList to accept onTreeSelected.
            // But wait, TreeList uses standard ListTile onTap which updates provider.
            // So we can listen to provider changes here? No, user tap event is better controlled via callback.
            // Let's wrap TreeList or assume TreeList updates provider.
            // Actually, for mobile, we should probably push a new screen.
            // Let's Refactor TreeList to take an OnTap callback instead of hardcoding provider update, for flexibility?
            // Or simpler: We watch `selectedTree`. If non-null and mobile, push page? No, that causes loop on pop.

            // Simplest: Just check if selectedTree changed?
            // Let's make TreeList specialized or handle taps here?
            // Since TreeList is already built, let's see logic there.
            // TreeList updates `selectedTreeProvider`.
            // On Mobile, we can use a Listener on the provider?

            // BETTER APPROACH: Make TreeList take a callback `onTreeTap`.
            // In Tablet: Update provider.
            // In Mobile: Navigator.push(...Detail).

            // I will use a direct generic approach here.
            // NOTE: I will have to edit TreeList to support custom callback or check my implementation.
            // My implementation of TreeList updates provider.
            // So on mobile, `ref.listen` to provider?

            // Let's stick with: On mobile, clicking an item opens a new page.
            // I'll rewrite TreeList logic slightly in `TreeList` file to support this difference
            // OR I will just implement the list here if it's simple? No, reuse is good.

            // Let's rely on `ref.listen` in this page.

            return TreeList(trees: filteredTrees);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTreeSheet,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Afegir a Camp'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}
