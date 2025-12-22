import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_item.dart';
import '../../../contacts/data/contacts_data.dart';

class TaskEditSheet extends ConsumerStatefulWidget {
  final Task? task;
  final String initialBucket;
  final Function(Task) onSave;

  const TaskEditSheet({
    super.key,
    this.task,
    required this.initialBucket,
    required this.onSave,
  });

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _phase;
  late List<TaskItem> _items;
  late List<String> _contactIds;
  DateTime? _dueDate;
  double? _latitude;
  double? _longitude;

  // Image handling
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _phase = widget.task?.phase ?? '';
    _items = List.from(widget.task?.items ?? []);
    _contactIds = List.from(widget.task?.contactIds ?? []);
    _dueDate = widget.task?.dueDate;
    _latitude = widget.task?.latitude;
    _longitude = widget.task?.longitude;
  }

  void _addItem() {
    setState(() {
      _items.add(TaskItem(description: '', quantity: 1.0));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                  if (_imageFile != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _imageFile = null),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
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
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildPhaseSelector()),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
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
                  _buildItemsList(),
                  const SizedBox(height: 24),
                  _buildContactsSelector(),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                label: Text(_isUploading ? 'PUJANT FOTO...' : 'GUARDAR CANVIS'),
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
              widget.task == null ? 'Nova Tasca' : 'Editar Tasca',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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
            onPressed: () {
              // Placeholder implementation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('S\'obriria el mapa... 🗺️')),
              );
              setState(() {
                _latitude = 41.3851; // Dummy coords
                _longitude = 2.1734;
              });
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

  Widget _buildPhaseSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _phase.isEmpty ? null : _phase,
      decoration: const InputDecoration(labelText: 'Fase / Etiqueta'),
      items: const [
        DropdownMenuItem(value: '', child: Text('Cap')),
        DropdownMenuItem(value: 'Urgent', child: Text('Urgent 🔴')),
        DropdownMenuItem(value: 'Compra', child: Text('Compra 🛒')),
        DropdownMenuItem(value: 'Manteniment', child: Text('Manteniment 🔧')),
        DropdownMenuItem(value: 'Planificació', child: Text('Planificació 📅')),
      ],
      onChanged: (val) => setState(() => _phase = val ?? ''),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtasques / Material'),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _addItem,
            ),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item.description,
                    decoration: const InputDecoration(
                      labelText: 'Descripció',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      _items[index] = item.copyWith(description: val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Quantitat',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final quantity = double.tryParse(val);
                      if (quantity != null) {
                        _items[index] = item.copyWith(quantity: quantity);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
          );
        }),
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
              onSelected: (selected) {
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

  // ... (Wait, I need to add imports to TaskEditSheet for ImagePicker and File)

  // Let's rewrite the save function to be generic for now, and I will do a separate pass for imports + logic.
  void _saveTask() {
    // This will be replaced by async logic in the next tool call
    // We can either call the callback or just do logic here.
    // The callback on TasksPage does repo.addTask/updateTask.
    // So we invoke it.
    // widget.onSave(newTask); // newTask is not defined here, this will be part of the next step.

    if (mounted) {
      setState(() => _isUploading = false);
      Navigator.pop(context);
    }
  }
}
