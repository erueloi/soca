import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bucket.dart';
import '../providers/tasks_provider.dart';

class BucketManagementSheet extends ConsumerStatefulWidget {
  const BucketManagementSheet({super.key});

  @override
  ConsumerState<BucketManagementSheet> createState() =>
      _BucketManagementSheetState();
}

class _BucketManagementSheetState extends ConsumerState<BucketManagementSheet> {
  List<Bucket> _localBuckets = [];
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final bucketsAsync = ref.watch(bucketsStreamProvider);
      bucketsAsync.whenData((buckets) {
        setState(() {
          _localBuckets = List.from(buckets);
          _isInit = false;
        });
      });
    }
  }

  Future<void> _saveBuckets() async {
    try {
      await ref.read(tasksRepositoryProvider).saveBuckets(_localBuckets);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardant els canvis: $e')),
        );
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final bucket = _localBuckets.removeAt(oldIndex);
      _localBuckets.insert(newIndex, bucket);
    });
    _saveBuckets();
  }

  void _addBucket() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Nova Columna'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nom de la columna'),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _localBuckets.add(Bucket(name: name));
                  });
                  _saveBuckets();
                  Navigator.pop(context);
                }
              },
              child: const Text('Afegir'),
            ),
          ],
        );
      },
    );
  }

  void _editBucket(int index) {
    final bucket = _localBuckets[index];
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: bucket.name);
        return AlertDialog(
          title: const Text('Editar Columna'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nom de la columna'),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty && name != bucket.name) {
                  // Rename tasks first
                  try {
                    await ref
                        .read(tasksRepositoryProvider)
                        .renameBucket(bucket.name, name);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error reanomenant tasques: $e'),
                        ),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    setState(() {
                      _localBuckets[index] = bucket.copyWith(name: name);
                    });
                    _saveBuckets();
                    Navigator.pop(context);
                  }
                } else if (name == bucket.name) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _toggleArchive(int index) {
    setState(() {
      final bucket = _localBuckets[index];
      _localBuckets[index] = bucket.copyWith(isArchived: !bucket.isArchived);
    });
    _saveBuckets();
  }

  void _togglePin(int index) {
    setState(() {
      final bucket = _localBuckets[index];
      _localBuckets[index] = bucket.copyWith(
        showOnDashboard: !bucket.showOnDashboard,
      );
    });
    _saveBuckets();
  }

  /// Available icons for bucket selection
  static const List<({IconData icon, String label})> _availableIcons = [
    (icon: Icons.check_circle, label: 'Tasca'),
    (icon: Icons.forest, label: 'Bosc'),
    (icon: Icons.water_drop, label: 'Aigua'),
    (icon: Icons.build, label: 'Construcció'),
    (icon: Icons.agriculture, label: 'Agricultura'),
    (icon: Icons.home, label: 'Casa'),
    (icon: Icons.star, label: 'Important'),
    (icon: Icons.warning, label: 'Atenció'),
    (icon: Icons.eco, label: 'Ecologia'),
    (icon: Icons.spa, label: 'Plantes'),
    (icon: Icons.landscape, label: 'Paisatge'),
    (icon: Icons.construction, label: 'Obra'),
  ];

  void _changeIcon(int index) {
    final bucket = _localBuckets[index];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Icona per "${bucket.name}"'),
          content: SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableIcons.map((item) {
                final isSelected = bucket.iconCode == item.icon.codePoint;
                return Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _localBuckets[index] = bucket.copyWith(
                          iconCode: item.icon.codePoint,
                          iconFamily: item.icon.fontFamily,
                        );
                      });
                      _saveBuckets();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Icon(
                        item.icon,
                        size: 28,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
          ],
        );
      },
    );
  }

  /// Available colors for bucket icon
  static const List<({Color color, String label})> _availableColors = [
    (color: Colors.orange, label: 'Taronja'),
    (color: Colors.green, label: 'Verd'),
    (color: Colors.blue, label: 'Blau'),
    (color: Colors.red, label: 'Vermell'),
    (color: Colors.purple, label: 'Lila'),
    (color: Colors.teal, label: 'Turquesa'),
    (color: Colors.brown, label: 'Marró'),
    (color: Colors.pink, label: 'Rosa'),
    (color: Colors.amber, label: 'Àmbar'),
    (color: Colors.indigo, label: 'Índigo'),
    (color: Colors.cyan, label: 'Cian'),
    (color: Colors.grey, label: 'Gris'),
  ];

  void _changeColor(int index) {
    final bucket = _localBuckets[index];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Color per "${bucket.name}"'),
          content: SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableColors.map((item) {
                final isSelected =
                    bucket.iconColorValue == item.color.toARGB32();
                return Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _localBuckets[index] = bucket.copyWith(
                          iconColorValue: item.color.toARGB32(),
                        );
                      });
                      _saveBuckets();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // We watch the provider to keep sync if externa changes happen,
    // but for reordering we use local state and optimistic updates.
    // Ideally we should sync local state with provider updates if they differ significantly,
    // but for simplicity we'll initialize once.
    // Actually, listening to stream updates while reordering might cause jumps.
    // Let's rely on _localBuckets for the UI and only update from stream if we haven't modified?
    // For now, let's keep it simple: initial load from stream (handled in didChangeDependencies),
    // then local manipulations save to stream. Updates from other devices might override local unsaved changes?
    // Since we save immediately on every action, it should be fine.

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.view_column_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Gestionar Columnes',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _localBuckets.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final bucket = _localBuckets[index];
                      return ListTile(
                        key: ValueKey(bucket.name + index.toString()),
                        contentPadding: EdgeInsets.zero,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _changeIcon(index),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  bucket.icon,
                                  color: bucket.iconColor,
                                  size: 24,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _changeColor(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: bucket.iconColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          bucket.name,
                          style: TextStyle(
                            decoration: bucket.isArchived
                                ? TextDecoration.lineThrough
                                : null,
                            color: bucket.isArchived
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bucket.isArchived)
                              IconButton(
                                icon: const Icon(
                                  Icons.unarchive,
                                  color: Colors.green,
                                ),
                                onPressed: () => _toggleArchive(index),
                                tooltip: 'Desarxivar',
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                              ),
                              onPressed: () => _onDeleteRequest(index),
                              tooltip: 'Eliminar/Arxivar',
                            ),
                            if (!bucket.isArchived)
                              IconButton(
                                icon: Icon(
                                  bucket.showOnDashboard
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: bucket.showOnDashboard
                                      ? Colors.amber
                                      : Colors.grey,
                                ),
                                onPressed: () => _togglePin(index),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editBucket(index),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 0,
              child: FloatingActionButton(
                onPressed: _addBucket,
                tooltip: 'Afegir Columna',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDeleteRequest(int index) {
    if (index >= _localBuckets.length) return;

    final bucket = _localBuckets[index];
    final tasks = ref.read(tasksStreamProvider).asData?.value ?? [];
    // Count active or completed tasks in this bucket
    final tasksInBucket = tasks.where((t) => t.bucket == bucket.name).toList();

    if (tasksInBucket.isEmpty) {
      // Empty -> Offer real delete
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar Columna'),
          content: Text(
            'Segur que vols eliminar la columna "${bucket.name}"? Aquesta acció no es pot desfer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            TextButton(
              onPressed: () {
                _deleteBucket(index);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
    } else {
      // Has tasks -> Offer Archive (if not already archived)
      if (bucket.isArchived) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No es pot eliminar'),
            content: Text(
              'Aquesta columna conté ${tasksInBucket.length} tasques (actives o completades). No es pot eliminar fins que l\'estigui buida.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('D\'acord'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Arxivar Columna?'),
            content: Text(
              'La columna "${bucket.name}" conté ${tasksInBucket.length} tasques. No es pot eliminar, però la pots arxivar perquè no surti a la pissarra.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel·lar'),
              ),
              TextButton(
                onPressed: () {
                  _toggleArchive(index); // Sets represented Logic
                  Navigator.pop(context);
                },
                child: const Text('Arxivar'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _deleteBucket(int index) {
    setState(() {
      _localBuckets.removeAt(index);
    });
    _saveBuckets();
  }
}
