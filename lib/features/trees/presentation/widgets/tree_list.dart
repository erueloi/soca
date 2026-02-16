import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/species.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/tree_extensions.dart';
import '../../domain/entities/watering_event.dart';
import '../providers/trees_provider.dart';
import '../widgets/tree_detail.dart';

import '../../../../core/utils/icon_utils.dart';

class TreeList extends ConsumerWidget {
  final List<Tree> trees;

  const TreeList({super.key, required this.trees});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trees.isEmpty) {
      return const Center(child: Text('No hi ha arbres registrats.'));
    }

    final selectedTree = ref.watch(selectedTreeProvider);
    final speciesAsync = ref.watch(speciesStreamProvider);

    // Create a map for quick access, defaulting to empty if loading/error
    final speciesMap = speciesAsync.maybeWhen(
      data: (list) => {for (var s in list) s.id: s},
      orElse: () => <String, Species>{},
    );

    return ListView.builder(
      itemCount: trees.length,
      itemBuilder: (context, index) {
        final tree = trees[index];
        final isSelected = selectedTree?.id == tree.id;
        final species = speciesMap[tree.speciesId];

        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: (tree.photoUrl != null && tree.photoUrl!.isNotEmpty)
                ? Image.network(
                    tree.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        IconUtils.resolveIcon(
                          species?.iconCode ?? Icons.park.codePoint,
                          species?.iconFamily,
                        ),
                        color: Colors.green,
                      );
                    },
                  )
                : Icon(
                    IconUtils.resolveIcon(
                      species?.iconCode ?? Icons.park.codePoint,
                      species?.iconFamily,
                    ),
                    color: Colors.green,
                  ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tree.reference != null && tree.reference!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    tree.reference!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
              Text(
                tree.commonName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tree.species,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(
                tree.status == 'Planned'
                    ? 'Planificat'
                    : 'Plantat: ${tree.plantingDate.day}/${tree.plantingDate.month}/${tree.plantingDate.year}',
                style: TextStyle(
                  color: tree.status == 'Planned'
                      ? Colors.deepPurple
                      : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: tree.status == 'Planned'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Delete button (Available for ALL trees now)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar arbre',
                onPressed: () => _confirmDeleteTree(context, ref, tree),
              ),

              if (tree.status != 'Planned')
                IconButton(
                  icon: Icon(
                    Icons.water_drop,
                    color: tree.waterStatusColor == Colors.grey
                        ? Colors.blue
                        : tree.waterStatusColor,
                  ),
                  onPressed: () => _showQuickWateringSheet(context, ref, tree),
                ),

              const SizedBox(width: 8),
              // Health/Vitality Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getHealthColor(tree.status),
                ),
              ),
            ],
          ),
          onTap: () {
            ref.read(selectedTreeProvider.notifier).selectTree(tree);
            if (MediaQuery.of(context).size.width <= 600) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TreeDetail(tree: tree)),
              );
            }
          },
        );
      },
    );
  }

  Color _getHealthColor(String status) {
    switch (status.toLowerCase()) {
      case 'mort':
        return Colors.black;
      case 'malalt':
        return Colors.orange;
      case 'viable':
        return Colors.green;
      case 'planned':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  /// Handles delete confirmation based on tree status
  void _confirmDeleteTree(BuildContext context, WidgetRef ref, Tree tree) {
    if (tree.status == 'Planned') {
      _confirmDeletePlanned(context, ref, tree);
    } else {
      _confirmDeleteSecure(context, ref, tree);
    }
  }

  /// Deletes a planned tree with simple confirmation
  void _confirmDeletePlanned(BuildContext context, WidgetRef ref, Tree tree) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 40),
        title: const Text('Eliminar Arbre Planificat'),
        content: Text(
          'Vols eliminar "${tree.commonName}" de la planificació?\n\n'
          'Aquesta acció no es pot desfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(treesRepositoryProvider).deleteTree(tree.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${tree.commonName}" eliminat'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('ELIMINAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Deletes an existing tree requiring reference confirmation
  void _confirmDeleteSecure(BuildContext context, WidgetRef ref, Tree tree) {
    final controller = TextEditingController();
    final treeRef = tree.reference ?? '???';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 40,
        ),
        title: const Text('Eliminar Arbre Existent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATENCIÓ: Estàs a punt d\'eliminar "${tree.commonName}" (Plantat).\n\n'
              'Per confirmar, escriu la referència de l\'arbre a continuació:',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                treeRef,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Escriu la referència per confirmar',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL·LAR'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final isValid = value.text.trim() == treeRef;
              return ElevatedButton.icon(
                onPressed: isValid
                    ? () async {
                        Navigator.pop(dialogContext);
                        await ref
                            .read(treesRepositoryProvider)
                            .deleteTree(tree.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"${tree.commonName}" eliminat definitivament',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text('ELIMINAR DEFINITIVAMENT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showQuickWateringSheet(BuildContext context, WidgetRef ref, Tree tree) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow keyboard to push up if needed
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Reg Ràpid: ${tree.commonName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWaterOption(context, ref, tree, 2),
                  _buildWaterOption(context, ref, tree, 5),
                  _buildWaterOption(context, ref, tree, 8),
                  _buildCustomWaterOption(context, ref, tree),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterOption(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
    double liters,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade800,
      ),
      onPressed: () async {
        Navigator.pop(context);
        final event = WateringEvent(
          id: '', // Generated
          date: DateTime.now(),
          liters: liters,
          note: 'Reg Ràpid',
        );
        await ref
            .read(treesRepositoryProvider)
            .addWateringEvent(tree.id, event);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Afegits ${liters.toInt()}L a ${tree.commonName}'),
            ),
          );
        }
      },
      icon: const Icon(Icons.water_drop),
      label: Text('${liters.toInt()}L'),
    );
  }

  Widget _buildCustomWaterOption(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
      ),
      onPressed: () {
        Navigator.pop(context);
        _showCustomWaterDialog(context, ref, tree);
      },
      child: const Text('Altres...'),
    );
  }

  Future<void> _showCustomWaterDialog(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
  ) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quantitat Personalitzada'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Litres',
            suffixText: 'L',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                final event = WateringEvent(
                  id: '',
                  date: DateTime.now(),
                  liters: val,
                  note: 'Reg Manual',
                );
                await ref
                    .read(treesRepositoryProvider)
                    .addWateringEvent(tree.id, event);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Afegits ${val.toInt()}L a ${tree.commonName}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
}
