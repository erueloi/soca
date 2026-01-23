import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_item.dart';
import '../../../contacts/data/contacts_data.dart';
import 'package:latlong2/latlong.dart';
import '../../../map/presentation/widgets/location_picker_sheet.dart';
import '../providers/tasks_provider.dart';
import '../../../settings/domain/entities/farm_config.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class TaskEditSheet extends ConsumerStatefulWidget {
  final Task? task;
  final String initialBucket;
  final Function(Task) onSave;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  const TaskEditSheet({
    super.key,
    this.task,
    required this.initialBucket,
    required this.onSave,
    this.onDelete,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _ItemController {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController cost;
  String categoryId; // Changed from ItemCategory enum to String ID

  _ItemController(TaskItem item)
    : description = TextEditingController(text: item.description),
      quantity = TextEditingController(text: item.quantity.toString()),
      cost = TextEditingController(text: item.cost.toString()),
      categoryId = item.categoryId;

  void dispose() {
    description.dispose();
    quantity.dispose();
    cost.dispose();
  }
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _phase;
  // late List<TaskItem> _items; // Removed in favor of controllers source of truth
  late List<_ItemController> _itemControllers;
  late List<bool> _itemDoneStates;
  late List<DateTime?> _itemCompletedDates;
  late List<String> _contactIds;
  DateTime? _dueDate;
  double? _latitude;
  double? _longitude;

  // Image handling
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isUploading = false;
  List<String> _currentPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _phase = widget.task?.phase ?? '';

    final initialItems = widget.task?.items ?? [];
    _itemControllers = initialItems.map((i) => _ItemController(i)).toList();
    _itemDoneStates = initialItems.map((i) => i.isDone).toList();
    _itemCompletedDates = initialItems.map((i) => i.completedAt).toList();

    _contactIds = List.from(widget.task?.contactIds ?? []);
    _currentPhotoUrls = List.from(widget.task?.photoUrls ?? []);
    _dueDate = widget.task?.dueDate;
    _latitude = widget.task?.latitude;
    _longitude = widget.task?.longitude;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1); // Allow past dates up to 1 year
    final initial = _dueDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate.isBefore(initial) ? firstDate : initial,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final source = await _showImageSourceActionSheet(context);
    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<ImageSource?> _showImageSourceActionSheet(BuildContext context) async {
    if (kIsWeb) return ImageSource.gallery;
    return await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fer Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Triar de la Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Visor', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch FarmConfig for dynamic settings
    final configAsync = ref.watch(farmConfigStreamProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error carregant configuració: $e')),
      data: (config) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Títol de la Tasca',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        readOnly: widget.isReadOnly,
                      ),
                      const SizedBox(height: 16),
                      if (!widget.isReadOnly) _buildActionButtons(context),
                      if (_imageBytes != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: MemoryImage(_imageBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      setState(() => _imageBytes = null),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Existing Images Gallery
                      if (_currentPhotoUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _currentPhotoUrls.length,
                            itemBuilder: (context, index) {
                              final url = _currentPhotoUrls[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          _showFullScreenImage(context, url),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(url),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!widget.isReadOnly)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _currentPhotoUrls.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripció detallada',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        readOnly: widget.isReadOnly,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildPhaseSelector(config)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: widget.isReadOnly ? null : _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data Límit',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _dueDate == null
                                      ? 'Sense data'
                                      : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildItemsList(config),
                      const SizedBox(height: 24),
                      _buildContactsSelector(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!widget.isReadOnly)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _saveTask,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isUploading ? 'PUJANT FOTO...' : 'GUARDAR CANVIS',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isReadOnly
                  ? 'Detall de la Tasca'
                  : (widget.task == null ? 'Nova Tasca' : 'Editar Tasca'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        Row(
          children: [
            if (widget.task != null &&
                widget.onDelete != null &&
                !widget.isReadOnly)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar Tasca',
                onPressed: () {
                  // Confirm deletion
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar Tasca?'),
                      content: const Text(
                        'Estàs segur que vols eliminar aquesta tasca definitivament?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel·lar'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx); // Close dialog
                            Navigator.pop(context); // Close sheet
                            widget.onDelete!();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Adjuntar Foto'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              // Open Location Picker
              final LatLng? initialPos =
                  (_latitude != null && _longitude != null)
                  ? LatLng(_latitude!, _longitude!)
                  : null;

              final LatLng? pickedLocation = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LocationPickerSheet(initialLocation: initialPos),
                ),
              );

              if (pickedLocation != null) {
                setState(() {
                  _latitude = pickedLocation.latitude;
                  _longitude = pickedLocation.longitude;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ubicació guardada! 📍')),
                  );
                }
              }
            },
            icon: const Icon(Icons.location_on),
            label: Text(_latitude == null ? 'Ubicar' : 'Ubicat ✅'),
            style: _latitude != null
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseSelector(FarmConfig config) {
    final phases = config.taskPhases;
    // Ensure current phase is in list or add it temporarily if not found (edge case)
    final items = [
      const DropdownMenuItem(value: '', child: Text('Cap')),
      ...phases.map((p) => DropdownMenuItem(value: p, child: Text(p))),
    ];

    // If _phase has a value but it's not in the list, we might want to still show it or reset it.
    // DropdownButtonFormField throws if value is not in items.
    // So we check:
    final bool valueExists = _phase.isEmpty || phases.contains(_phase);
    final String? effectiveValue = valueExists
        ? (_phase.isEmpty ? null : _phase)
        : null;

    // If value doesn't exist (e.g. was deleted from config), we default to null (Cap).
    // Or we could add a temporary item for the missing value. For now, reset to null is safer.

    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      decoration: const InputDecoration(labelText: 'Fase / Etiqueta'),
      items: items,
      onChanged: widget.isReadOnly
          ? null
          : (val) => setState(() => _phase = val ?? ''),
    );
  }

  Widget _buildItemsList(FarmConfig config) {
    double totalBudget = 0;
    double totalSpent = 0;

    // Calculate totals on the fly from controllers
    for (int i = 0; i < _itemControllers.length; i++) {
      final c = _itemControllers[i];
      final q = double.tryParse(c.quantity.text) ?? 0.0;
      final cost = double.tryParse(c.cost.text) ?? 0.0;
      final isDone = _itemDoneStates[i];

      final itemTotal = cost * q;
      totalBudget += itemTotal;
      if (isDone) {
        totalSpent += itemTotal;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtasques / Material'),
            if (!widget.isReadOnly)
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  setState(() {
                    _itemControllers.add(
                      _ItemController(
                        TaskItem(description: '', quantity: 1.0, cost: 0.0),
                      ),
                    );
                    _itemDoneStates.add(false);
                    _itemCompletedDates.add(null);
                  });
                },
              ),
          ],
        ),
        if (_itemControllers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Afegeix subtasques per calcular el pressupost.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ..._itemControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: _itemDoneStates[index],
                  onChanged: widget.isReadOnly
                      ? null
                      : (val) {
                          setState(() {
                            final isDone = val ?? false;
                            _itemDoneStates[index] = isDone;
                            _itemCompletedDates[index] = isDone
                                ? DateTime.now()
                                : null;
                          });
                        },
                ),
                // Category Icon Button (Dynamic PopMenu)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: PopupMenuButton<String>(
                    tooltip: 'Canviar Categoria',
                    initialValue: controller.categoryId,
                    itemBuilder: (context) => config.expenseCategories.map((
                      cat,
                    ) {
                      return PopupMenuItem(
                        value: cat.id,
                        child: Row(
                          children: [
                            Icon(
                              IconData(
                                cat.iconCode,
                                fontFamily: 'MaterialIcons',
                              ),
                              color: Color(int.parse(cat.colorHex, radix: 16)),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(cat.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onSelected: widget.isReadOnly
                        ? null
                        : (val) {
                            setState(() {
                              controller.categoryId = val;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(
                          controller.categoryId,
                          config,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(controller.categoryId, config),
                        color: _getCategoryColor(controller.categoryId, config),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: controller.description,
                    decoration: const InputDecoration(
                      labelText: 'Descripció',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    readOnly: widget.isReadOnly,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: controller.quantity,
                    decoration: const InputDecoration(
                      labelText: 'Quant.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    readOnly: widget.isReadOnly,
                    onChanged: (_) => setState(() {}), // Trigger recalc
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: controller.cost,
                    decoration: const InputDecoration(
                      labelText: 'Preu U. (€)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    readOnly: widget.isReadOnly,
                    onChanged: (_) => setState(() {}), // Trigger recalc
                  ),
                ),
                if (!widget.isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _itemControllers[index].dispose();
                        _itemControllers.removeAt(index);
                        _itemDoneStates.removeAt(index);
                        _itemCompletedDates.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    'PRESSUPOST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${totalBudget.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade400),
              Column(
                children: [
                  const Text(
                    'GASTAT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${totalSpent.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: totalSpent > totalBudget
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade400),
              Column(
                children: [
                  const Text(
                    'SALDO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${(totalBudget - totalSpent).toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: (totalBudget - totalSpent) < 0
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assignar a:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: ContactsData.allContacts.map((contact) {
            final isSelected = _contactIds.contains(contact.id);
            return FilterChip(
              label: Text(contact.name),
              avatar: CircleAvatar(
                backgroundColor: Theme.of(context).canvasColor,
                child: Text(
                  contact.name.substring(0, 1),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              selected: isSelected,
              onSelected: widget.isReadOnly
                  ? null
                  : (selected) {
                      setState(() {
                        if (selected) {
                          _contactIds.add(contact.id);
                        } else {
                          _contactIds.remove(contact.id);
                        }
                      });
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El títol és obligatori')));
      return;
    }

    setState(() => _isUploading = true);

    String? photoUrl;
    // Use existing ID or generate new one
    final taskId =
        widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Upload image if selected
    if (_imageBytes != null) {
      // Use the provider to access repository
      final repo = ref.read(tasksRepositoryProvider);
      photoUrl = await repo.uploadTaskImage(_imageBytes!, taskId);
    }

    // Prepare photo URLs list
    List<String> finalPhotoUrls = List.from(_currentPhotoUrls);
    if (photoUrl != null) {
      finalPhotoUrls.add(photoUrl);
    }

    final newTask = Task(
      id: taskId,
      title: _titleController.text,
      bucket: widget.task?.bucket ?? widget.initialBucket,
      description: _descriptionController.text,
      phase: _phase,
      isDone: widget.task?.isDone ?? false,
      items: _itemControllers.asMap().entries.map((entry) {
        final index = entry.key;
        final c = entry.value;
        return TaskItem(
          description: c.description.text,
          quantity: double.tryParse(c.quantity.text) ?? 1.0,
          cost: double.tryParse(c.cost.text) ?? 0.0,
          isDone: _itemDoneStates[index],
          completedAt: _itemCompletedDates[index],
          categoryId: c.categoryId,
        );
      }).toList(),
      contactIds: _contactIds,
      dueDate: _dueDate,
      latitude: _latitude,
      longitude: _longitude,
      photoUrls: finalPhotoUrls,
    );

    widget.onSave(newTask);

    if (mounted) {
      setState(() => _isUploading = false);
      Navigator.pop(context);
    }
  }

  Color _getCategoryColor(String categoryId, FarmConfig config) {
    final cat = config.expenseCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => config.expenseCategories.first,
    );
    return Color(int.parse(cat.colorHex, radix: 16));
  }

  IconData _getCategoryIcon(String categoryId, FarmConfig config) {
    final cat = config.expenseCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => config.expenseCategories.first,
    );
    return IconData(cat.iconCode, fontFamily: 'MaterialIcons');
  }
}
