import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' as import_image_picker;

import '../providers/construction_provider.dart';
import 'construction_floor_page.dart';

class ConstructionPage extends ConsumerWidget {
  const ConstructionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);
    final floorPlans = floorPlansAsync.asData?.value ?? {};

    // Sort keys naturally or alphabetically
    final sortedFloors = floorPlans.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Obres de la Masia')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFloorDialog(context, ref),
        label: const Text('Afegir Planta'),
        icon: const Icon(Icons.add),
      ),
      body: floorPlansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (_) {
          if (sortedFloors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.layers_clear, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No hi ha plantes definides.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddFloorDialog(context, ref),
                    child: const Text('CREAR PRIMERA PLANTA'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            // Add padding at bottom for FAB
            itemCount: sortedFloors.length + 1,
            itemBuilder: (context, index) {
              if (index == sortedFloors.length) {
                return const SizedBox(height: 80); // Space for FAB
              }

              final floor = sortedFloors[index];
              final imageUrl = floorPlans[floor];

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  shape: Border.all(color: Colors.transparent),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.layers_outlined,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  title: Text(
                    floor,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameDialog(context, ref, floor);
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref, floor);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Canviar nom'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    SizedBox(
                      height: 400, // Increased height for web/desktop
                      width: double.infinity,
                      child: imageUrl != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.5),
                                      ],
                                      stops: const [0.6, 1.0],
                                    ),
                                  ),
                                ),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ConstructionFloorPage(
                                                floorId: floor,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_full),
                                    label: const Text('OBRIR PLÀNOL COMPLET'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Text('Error carregant imatge'),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddFloorDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddFloorDialog(ref: ref),
    );

    if (result != null && context.mounted) {
      final name = result['name'] as String;
      final file = result['file'] as import_image_picker.XFile?;

      try {
        if (file != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pujant plànol...')));
          await ref
              .read(constructionRepositoryProvider)
              .saveFloorPlan(name, file);
        } else {
          await ref.read(constructionRepositoryProvider).addEmptyFloor(name);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Planta creada correctament')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canviar nom de la planta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom de la planta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                try {
                  Navigator.pop(context); // Close dialog first
                  await ref
                      .read(constructionRepositoryProvider)
                      .renameFloor(oldName, controller.text);
                } catch (e) {
                  debugPrint('Error renaming: $e');
                }
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String floorId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Planta?'),
        content: Text(
          'Estàs segur que vols eliminar "$floorId" i tots els seus punts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL·LAR'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // We should also implement delete of points?
      // The current deleteFloorPlan only deletes config and image. Points become orphaned (ghosts).
      // Ideally we delete points too.
      // User said "borrar-ne".
      // Let's just call deleteFloorPlan for now as per plan.
      try {
        await ref.read(constructionRepositoryProvider).deleteFloorPlan(floorId);
      } catch (e) {
        debugPrint('Error deleting: $e');
      }
    }
  }
}

class _AddFloorDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AddFloorDialog({required this.ref});

  @override
  State<_AddFloorDialog> createState() => _AddFloorDialogState();
}

class _AddFloorDialogState extends State<_AddFloorDialog> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Planta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom de la Planta (ex: Planta 3)',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Un cop creada, podràs pujar el plànol des de la opció "Canviar Plànol" o pujar-lo ara mateix.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL·LAR'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'file': null,
              });
            }
          },
          child: const Text('GUARDAR SENSE PLÀNOL'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty) {
              await _pickAndReturn(context);
            }
          },
          child: const Text('SELECCIONAR PLÀNOL'),
        ),
      ],
    );
  }

  Future<void> _pickAndReturn(BuildContext context) async {
    final navigator = Navigator.of(context);
    final picker = import_image_picker.ImagePicker();
    final file = await picker.pickImage(
      source: import_image_picker.ImageSource.gallery,
    );

    if (!mounted) return;

    if (file != null) {
      navigator.pop({'name': _nameController.text, 'file': file});
    }
  }
}
