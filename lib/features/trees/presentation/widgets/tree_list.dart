import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tree.dart';
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
          selectedTileColor: Colors.green.withOpacity(0.1),
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
          trailing: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(tree.status),
            ),
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
}
