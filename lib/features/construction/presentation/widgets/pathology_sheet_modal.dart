import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/construction_point.dart';
import '../providers/construction_provider.dart';

class PathologySheetModal extends ConsumerStatefulWidget {
  final ConstructionPoint point;
  final Function(ConstructionPoint) onSave;

  const PathologySheetModal({
    super.key,
    required this.point,
    required this.onSave,
  });

  @override
  ConsumerState<PathologySheetModal> createState() =>
      _PathologySheetModalState();
}

class _PathologySheetModalState extends ConsumerState<PathologySheetModal> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _causesController;
  late TextEditingController
  _currentStateController; // e.g. "Active", "Stabilized"
  late TextEditingController _actionController;

  InjuryType _selectedType = InjuryType.fisica;
  double _severity = 5;
  List<PathologyPhoto> _photos = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.point.pathology;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _causesController = TextEditingController(text: p?.causes ?? '');
    _currentStateController = TextEditingController(
      text: p?.currentState ?? '',
    );
    _actionController = TextEditingController(text: p?.recommendedAction ?? '');
    _selectedType = p?.type ?? InjuryType.fisica;
    _severity = p?.severity.toDouble() ?? 5.0;
    _photos = List.from(p?.photos ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _causesController.dispose();
    _currentStateController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
    ); // Or gallery preference
    if (file != null) {
      setState(() => _isUploading = true);

      final repo = ref.read(constructionRepositoryProvider);
      final url = await repo.uploadPathologyImage(file);

      if (url != null) {
        setState(() {
          _photos.add(PathologyPhoto(url: url, date: DateTime.now()));
        });
      }

      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Fitxa de Patologia',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Títol / Localització',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InjuryType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipus de Lesió',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: InjuryType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripció Detallada',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _causesController,
              decoration: const InputDecoration(
                labelText: 'Causes Probables',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentStateController,
              decoration: const InputDecoration(
                labelText: 'Estat Actual',
                hintText: 'Ex: Activa, Estabilitzada...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _actionController,
              decoration: const InputDecoration(
                labelText: 'Actuació Recomanada',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gravetat: ${_severity.toInt()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _severity,
              min: 1,
              max: 10,
              divisions: 9,
              label: _severity.toInt().toString(),
              activeColor: _severity > 6
                  ? Colors.red
                  : (_severity > 3 ? Colors.orange : Colors.green),
              onChanged: (val) => setState(() => _severity = val),
            ),
            const SizedBox(height: 16),
            _buildPhotosSection(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    final oldPathology = widget.point.pathology;
    final List<HistoryEntry> newHistory = List.from(
      oldPathology?.history ?? [],
    );
    final DateTime now = DateTime.now();
    const currentUser =
        'Usuari Actual'; // Replace with actual user provider if available

    // 1. Check for Status Change
    final oldState = oldPathology?.currentState ?? '';
    final newState = _currentStateController.text;
    if (oldState != newState && newState.isNotEmpty) {
      newHistory.add(
        HistoryEntry(
          date: now,
          action: "Canvi d'estat",
          user: currentUser,
          comment: oldState.isEmpty
              ? 'Estat inicial: "$newState"'
              : 'De "$oldState" a "$newState"',
        ),
      );
    }

    // 2. Check for New Photos
    final oldPhotoCount = oldPathology?.photos.length ?? 0;
    final newPhotoCount = _photos.length;
    if (newPhotoCount > oldPhotoCount) {
      newHistory.add(
        HistoryEntry(
          date: now,
          action: 'Noves fotos',
          user: currentUser,
          comment: "S'han afegit ${newPhotoCount - oldPhotoCount} fotos.",
        ),
      );
    }

    final pathology = PathologySheet(
      title: _titleController.text,
      type: _selectedType,
      description: _descriptionController.text,
      photos: _photos,
      causes: _causesController.text,
      currentState: _currentStateController.text,
      recommendedAction: _actionController.text,
      severity: _severity.toInt(),
      subActions: oldPathology?.subActions ?? [],
      history: newHistory,
    );

    final updatedPoint = ConstructionPoint(
      id: widget.point.id,
      floorId: widget.point.floorId,
      xPercent: widget.point.xPercent,
      yPercent: widget.point.yPercent,
      createdAt: widget.point.createdAt,
      pathology: pathology,
      status: widget.point.status,
    );

    widget.onSave(updatedPoint);
    Navigator.pop(context);
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Fotografies', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              onPressed: _pickAndUploadImage,
            ),
          ],
        ),
        if (_isUploading) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        if (_photos.isEmpty)
          const Text(
            'Cap fotografia afegida',
            style: TextStyle(color: Colors.grey),
          ),
        if (_photos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Image.network(
                          _photos[index].url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _photos.removeAt(index);
                              });
                            },
                            child: Container(
                              color: Colors.black54,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
