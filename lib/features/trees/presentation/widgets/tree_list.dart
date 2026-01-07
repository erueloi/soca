import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/watering_event.dart';
import '../providers/trees_provider.dart';
import '../widgets/tree_detail.dart';

class TreeList extends ConsumerWidget {
  final List<Tree> trees;

  const TreeList({super.key, required this.trees});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trees.isEmpty) {
      return const Center(child: Text('No hi ha arbres registrats.'));
    }

    final selectedTree = ref.watch(selectedTreeProvider);

    return ListView.builder(
      itemCount: trees.length,
      itemBuilder: (context, index) {
        final tree = trees[index];
        final isSelected = selectedTree?.id == tree.id;

        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.green.withValues(alpha: 0.1),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: (tree.photoUrl != null && tree.photoUrl!.isNotEmpty)
                    ? NetworkImage(tree.photoUrl!)
                    : const AssetImage('assets/images/placeholder_tree.png')
                          as ImageProvider, // Placeholder needed
                fit: BoxFit.cover,
                // Fallback icon if image fails or placeholder missing (handled via errorBuilder if using Image.network)
                // But simplified here for specific requested style "Thumbnail"
              ),
              color: Colors.grey[300],
            ),
            child: (tree.photoUrl == null || tree.photoUrl!.isEmpty)
                ? const Icon(Icons.park, color: Colors.green)
                : null,
          ),
          title: Text(
            tree.commonName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tree.species,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(
                'Plantat: ${tree.plantingDate.day}/${tree.plantingDate.month}/${tree.plantingDate.year}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.water_drop, color: Colors.blue),
                onPressed: () => _showQuickWateringSheet(context, ref, tree),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(tree.status),
                ),
              ),
            ],
          ),
          onTap: () {
            ref.read(selectedTreeProvider.notifier).selectTree(tree);
            // Check screen size to navigate or not?
            // Actually, the page should handle the policy. But TreeList doesn't know context size easily without query.
            // Let's modify TreeList to just be a dumb list and let the Page pass the callback?
            // Or simpler navigation logic inside ListTile:
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Viable':
        return Colors.green;
      case 'Malalt':
        return Colors.orange;
      case 'Mort':
        return Colors.black;
      default:
        return Colors.grey;
    }
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
