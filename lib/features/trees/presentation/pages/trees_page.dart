import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trees_provider.dart';
import '../widgets/tree_list.dart';
import '../widgets/tree_detail.dart';
import '../widgets/tree_form_sheet.dart';
import 'species_library_page.dart';

class TreesPage extends ConsumerStatefulWidget {
  const TreesPage({super.key});

  @override
  ConsumerState<TreesPage> createState() => _TreesPageState();
}

class _TreesPageState extends ConsumerState<TreesPage> {
  final TextEditingController _searchController = TextEditingController();

  void _openAddTreeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TreeFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treesAsync = ref.watch(treesStreamProvider);
    final selectedTree = ref.watch(selectedTreeProvider);
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

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
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (val) {
                setState(() {}); // Rebuild to filter
              },
            ),
          ),
        ),
      ),
      body: treesAsync.when(
        data: (trees) {
          final query = _searchController.text.toLowerCase();
          final filteredTrees = trees.where((t) {
            return t.commonName.toLowerCase().contains(query) ||
                t.species.toLowerCase().contains(query);
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
