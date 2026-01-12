import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/construction_point.dart';
import '../../../tasks/domain/entities/task.dart' as task_entity;
import '../../../tasks/presentation/widgets/task_edit_sheet.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../providers/construction_provider.dart';
import '../widgets/interactive_floor_plan.dart';
import 'floor_plan_picker_page.dart';

class PathologyDetailPage extends ConsumerStatefulWidget {
  final ConstructionPoint point;
  final String? floorPlanUrl;
  final VoidCallback onEdit;

  const PathologyDetailPage({
    super.key,
    required this.point,
    required this.floorPlanUrl,
    required this.onEdit,
  });

  @override
  ConsumerState<PathologyDetailPage> createState() =>
      _PathologyDetailPageState();
}

class _PathologyDetailPageState extends ConsumerState<PathologyDetailPage> {
  late ConstructionPoint point;
  bool _isEditing = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _causesController;
  late TextEditingController _actionController;
  late TextEditingController _statusController;
  List<PathologyPhoto> _currentPhotos = [];
  int _severity = 1;

  @override
  void initState() {
    super.initState();
    point = widget.point;
    _initializeControllers();
  }

  void _initializeControllers() {
    final p = point.pathology;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _causesController = TextEditingController(text: p?.causes ?? '');
    _actionController = TextEditingController(text: p?.recommendedAction ?? '');
    _statusController = TextEditingController(text: p?.currentState ?? '');
    _currentPhotos = List.from(p?.photos ?? []);
    _severity = p?.severity ?? 1;
  }

  @override
  void didUpdateWidget(PathologyDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point) {
      setState(() {
        point = widget.point;
        if (!_isEditing) {
          _initializeControllers();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _causesController.dispose();
    _actionController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset to current point values if cancelled
        _initializeControllers();
      }
    });
  }

  Future<void> _saveChanges() async {
    final updatedPathology = point.pathology?.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
      causes: _causesController.text,
      recommendedAction: _actionController.text,
      photos: _currentPhotos,
      currentState: _statusController.text,
      severity: _severity,
    );

    await _updatePoint(updatedPathology);
    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvis guardats correctament')),
      );
    }
  }

  Future<void> _relocatePoint() async {
    if (widget.floorPlanUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hi ha plànol disponible per a aquesta planta.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();

    final newLocation = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (context) => FloorPlanPickerPage(
          floorId: point.floorId,
          currentPointId: point.id,
        ),
      ),
    );

    if (newLocation != null) {
      final updatedPoint = point.copyWith(
        xPercent: newLocation['x']!,
        yPercent: newLocation['y']!,
      );

      await _updatePoint(
        updatedPoint.pathology,
      ); // This only updates pathology?
      // Wait, _updatePoint logic in this file seems to calculate "updatedPathology" and call constructionRepositoryProvider.savePoint(point.copyWith(pathology: updatedPathology)).
      // But here I am changing coordinates, not pathology.
      // I need to verify _updatePoint implementation or call repository directly.

      // Checking _updatePoint implementation in previous context...
      // It takes `PathologySheet?`.
      // Let's modify _updatePoint or just call repo directly here.

      try {
        await ref
            .read(constructionRepositoryProvider)
            .updatePoint(updatedPoint);
        setState(() {
          point = updatedPoint;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Punt reubicat correctament')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error reubicant: $e')));
        }
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    // Simple source choice dialog
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Afegir foto des de...'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Row(
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 8),
                Text('Càmera'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Row(
              children: [
                Icon(Icons.photo_library),
                SizedBox(width: 8),
                Text('Galeria'),
              ],
            ),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pujant imatge...')));
      }

      final url = await ref
          .read(constructionRepositoryProvider)
          .uploadPathologyImage(image);

      if (url != null) {
        setState(() {
          _currentPhotos.add(PathologyPhoto(url: url, date: DateTime.now()));
        });
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error pujant foto: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine header color based on severity
    final severity = point.pathology?.severity ?? 0;
    Color severityColor = Colors.green;
    if (severity >= 8) {
      severityColor = Colors.red.shade700;
    } else if (severity >= 4) {
      severityColor = Colors.orange.shade800;
    }

    final pathology = point.pathology;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: severityColor,
        foregroundColor: Colors.white,
        title: Text('FITXA Nº ${point.id.substring(0, 4).toUpperCase()}'),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleEdit,
                  tooltip: 'Cancel·lar',
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveChanges,
                  tooltip: 'Guardar',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _toggleEdit,
                  tooltip: 'Editar Fitxa',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar Punt?'),
                        content: const Text(
                          'Estàs segur que vols eliminar aquest punt i tota la seva informació associada? Aquesta acció no es pot desfer.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('CANCEL·LAR'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ELIMINAR'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await ref
                            .read(constructionRepositoryProvider)
                            .deletePoint(point.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error eliminant: $e')),
                          );
                        }
                      }
                    }
                  },
                  tooltip: 'Eliminar Punt',
                ),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER TABLE ---
            Table(
              border: TableBorder.all(color: Colors.black, width: 1.0),
              columnWidths: const {
                0: IntrinsicColumnWidth(), // Label width
                1: FlexColumnWidth(), // Content width
              },
              children: [
                _buildTableRow(
                  context,
                  'TIPUS LESIÓ:',
                  pathology?.type.name.split('.').last.toUpperCase() ??
                      'DESCONEGUT',
                  isHeader: true,
                ),
                _buildTableRow(
                  context,
                  'LOCALITZACIÓ:',
                  'Planta: ${point.floorId}',
                  isHeader: true,
                ),
                _buildTableRow(
                  context,
                  'DESCRIPCIÓ:',
                  pathology?.title.toUpperCase() ?? 'SENSE TÍTOL',
                  isHeader: true,
                  isEditable: _isEditing,
                  controller: _titleController,
                ),
              ],
            ),

            // --- VISUAL SECTION (SPLIT) ---
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.black),
                  right: BorderSide(color: Colors.black),
                  bottom: BorderSide(color: Colors.black),
                ),
              ),
              child: SizedBox(
                height: 300,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- PHOTO (LEFT) ---
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.black),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'FOTOGRAFIA/ES:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isEditing)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_a_photo,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Afegir foto',
                                      onPressed: _pickAndUploadPhoto,
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _currentPhotos.isEmpty
                                  ? Container(
                                      color: Colors.grey.shade100,
                                      child: Center(
                                        child: _isEditing
                                            ? TextButton.icon(
                                                onPressed: _pickAndUploadPhoto,
                                                icon: const Icon(
                                                  Icons.add_a_photo,
                                                  size: 32,
                                                  color: Colors.grey,
                                                ),
                                                label: const Text(
                                                  'Afegir Foto',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              )
                                            : const Text(
                                                'Sense Foto',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      ),
                                    )
                                  : PageView.builder(
                                      itemCount: _currentPhotos.length,
                                      itemBuilder: (context, index) {
                                        final photo = _currentPhotos[index];
                                        return Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              photo.url,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (c, w, p) {
                                                if (p == null) return w;
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              },
                                            ),
                                            // Date Overlay
                                            Positioned(
                                              bottom:
                                                  30, // Above page indicator
                                              left: 8,
                                              child: GestureDetector(
                                                onTap: _isEditing
                                                    ? () async {
                                                        final newDate =
                                                            await showDatePicker(
                                                              context: context,
                                                              initialDate:
                                                                  photo.date ??
                                                                  DateTime.now(),
                                                              firstDate:
                                                                  DateTime(
                                                                    2000,
                                                                  ),
                                                              lastDate:
                                                                  DateTime.now(),
                                                            );
                                                        if (newDate != null) {
                                                          setState(() {
                                                            // Need to update the item in the list.
                                                            // Since PathologyPhoto is final, replace it.
                                                            // But wait, class definition in step 844: fields are final.
                                                            // I need to create a new one.
                                                            // Wait, I can only create new one if I have all fields.
                                                            // PathologyPhoto has url and date.
                                                            _currentPhotos[index] =
                                                                PathologyPhoto(
                                                                  url:
                                                                      photo.url,
                                                                  date: newDate,
                                                                );
                                                          });
                                                        }
                                                      }
                                                    : null,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: _isEditing
                                                        ? Border.all(
                                                            color: Colors.white,
                                                            width: 1,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.calendar_today,
                                                        size: 14,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        photo.date != null
                                                            ? _formatDate(
                                                                photo.date!,
                                                              )
                                                            : 'Sense data',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (_isEditing) ...[
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        const Icon(
                                                          Icons.edit,
                                                          size: 12,
                                                          color: Colors.white70,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_isEditing)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: CircleAvatar(
                                                  backgroundColor:
                                                      Colors.white70,
                                                  radius: 18,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _currentPhotos.removeAt(
                                                          index,
                                                        );
                                                      });
                                                    },
                                                    tooltip: 'Eliminar foto',
                                                  ),
                                                ),
                                              ),
                                            if (_currentPhotos.length > 1)
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${index + 1}/${_currentPhotos.length}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- MAP (RIGHT) ---
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'UBICACIÓ:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Reubicar punt',
                                  onPressed: _relocatePoint,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: InteractiveFloorPlan(
                              floorId: point.floorId,
                              imageUrl: widget.floorPlanUrl,
                              points: [point],
                              isReadOnly: true,
                              onPointTap: (x, y) {},
                              onMarkerTap: (p) {},
                              onUploadPlan: (f) {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- DATA SECTIONS ---
            const SizedBox(height: 16), // Space before data cards

            _buildDataSection(
              'Descripció de la lesió:',
              pathology?.description,
              isEditable: _isEditing,
              controller: _descriptionController,
            ),
            _buildDataSection(
              'Causes de la lesió:',
              pathology?.causes,
              isEditable: _isEditing,
              controller: _causesController,
            ),
            _buildStatusAndSeveritySection(),

            _buildDataSection(
              'Actuació recomanada:',
              pathology?.recommendedAction,
              isEditable: _isEditing,
              controller: _actionController,
            ),

            const SizedBox(height: 24),
            _buildSubActionsSection(context, pathology),

            const SizedBox(height: 24),
            _buildHistorySection(context, pathology),
          ],
        ),
      ),
    );
  }

  Widget _buildSubActionsSection(
    BuildContext context,
    PathologySheet? pathology,
  ) {
    final subActions = pathology?.subActions ?? [];
    final total = subActions.length;
    final completed = subActions.where((s) => s.isCompleted).length;
    final progress = total > 0 ? completed / total : 0.0;

    // We need a controller for adding new items.
    // Since this is a ConsumerWidget (stateless), we can't hold a controller easily without rebuilding.
    // However, we can show a dialog to add an item, or switch this to ConsumerStatefulWidget.
    // For simplicity, let's use a Dialog to add sub-actions.

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFD6E8D6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FULL DE RUTA / SUBACTUACIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    _showAddSubActionDialog(context);
                  },
                  tooltip: 'Afegir tasca',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (total > 0) ...[
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? Colors.green : Colors.orange,
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progrés: ${(progress * 100).toInt()}% ($completed/$total)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                if (subActions.isEmpty)
                  const Text(
                    'No hi ha tasques definides.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ...subActions.map((action) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    horizontalTitleGap: 0,
                    leading: Checkbox(
                      value: action.isCompleted,
                      onChanged: (val) {
                        _toggleSubAction(action, val ?? false);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    title: Text(
                      action.title,
                      style: TextStyle(
                        decoration: action.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: action.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editSubAction(context, action),
                      tooltip: 'Editar Tasca',
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, PathologySheet? pathology) {
    final history = pathology?.history ?? [];
    // Sort logic should ideally be in model, but let's reverse here if needed.
    // Assuming new entries are appended, we want newest first.
    final reversedHistory = history.reversed.toList();

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFD6E8D6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Text(
              'HISTORIAL D\'EVOLUCIÓ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (reversedHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sense registres.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          if (reversedHistory.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reversedHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = reversedHistory[index];
                return ListTile(
                  dense: true,
                  leading: Text(
                    _formatDate(entry.date),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(
                    entry.action,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.user}${entry.comment != null ? ' - ${entry.comment}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildStatusAndSeveritySection() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black),
          right: BorderSide(color: Colors.black),
          bottom: BorderSide(color: Colors.black),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ESTAT
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.black)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: const Text(
                        'Estat:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _isEditing
                            ? TextField(
                                controller: _statusController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                maxLines: null,
                              )
                            : Text(
                                _statusController.text.isNotEmpty
                                    ? _statusController.text
                                    : 'Sense estat definit',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // CLASSIFICACIÓ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: const Text(
                      'Classificació:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                      ), // Less padding for slider
                      child: _isEditing
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_severity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _severity >= 8
                                        ? Colors.red
                                        : (_severity >= 4
                                              ? Colors.orange
                                              : Colors.green),
                                  ),
                                ),
                                Slider(
                                  value: _severity.toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  label: '$_severity',
                                  activeColor: _severity >= 8
                                      ? Colors.red
                                      : (_severity >= 4
                                            ? Colors.orange
                                            : Colors.green),
                                  onChanged: (val) {
                                    setState(() => _severity = val.round());
                                  },
                                ),
                              ],
                            )
                          : Center(
                              // Center the read-only text too
                              child: Text(
                                '$_severity',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24, // Bigger for read mode?
                                  color: _severity >= 8
                                      ? Colors.red
                                      : (_severity >= 4
                                            ? Colors.orange
                                            : Colors.green),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSubActionDialog(BuildContext context) async {
    task_entity.Task? taskFromSheet;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TaskEditSheet(
        initialBucket: 'Pendent',
        task: task_entity.Task(
          id: const Uuid().v4(),
          title: '',
          bucket: 'Pendent',
          description:
              'Fitxa #${point.id.substring(0, 4).toUpperCase()} - ${point.pathology?.title ?? "Sense títol"}',
        ),
        onSave: (newTask) {
          taskFromSheet = newTask;
          // TaskEditSheet handles popping the navigator internally
        },
      ),
    );

    // Logic after sheet closes
    if (taskFromSheet != null && context.mounted) {
      // Ask for bucket
      final selectedBucket = await _askForBucket(context);

      // 1. Save Global Task (if bucket selected)
      if (selectedBucket != null) {
        final taskToSave = taskFromSheet!.copyWith(bucket: selectedBucket);
        try {
          await ref.read(tasksRepositoryProvider).addTask(taskToSave);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tasca creada a "$selectedBucket"')),
            );
          }
        } catch (e) {
          debugPrint('Error saving global task: $e');
        }
      }

      // 2. Add Local SubAction (linked if bucket selected)
      await _addSubAction(
        taskFromSheet!.title,
        selectedBucket != null ? taskFromSheet!.id : null,
      );
    }
  }

  Future<String?> _askForBucket(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final bucketsAsync = ref.watch(bucketsStreamProvider);
          return AlertDialog(
            title: const Text('Classificar Tasca'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vols sincronitzar aquesta tasca amb el Tauler Kanban?',
                ),
                const SizedBox(height: 16),
                bucketsAsync.when(
                  data: (buckets) {
                    return Column(
                      children: [
                        ...buckets.map(
                          (b) => ListTile(
                            title: Text(b.name),
                            leading: const Icon(Icons.view_column),
                            onTap: () => Navigator.pop(context, b.name),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          title: const Text('Només guardar a l\'obra'),
                          leading: const Icon(Icons.bookmark_border),
                          onTap: () => Navigator.pop(context, null),
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stackTrace) =>
                      const Text('Error carregant columnes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addSubAction(String title, String? taskId) async {
    // 1. Add SubAction to ConstructionPoint
    final updatedSheet = point.pathology?.copyWith(
      subActions: [
        ...(point.pathology?.subActions ?? []),
        SubAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          taskId: taskId,
        ),
      ],
    );

    // 2. Save Point
    await _updatePoint(updatedSheet);
  }

  Future<void> _editSubAction(BuildContext context, SubAction action) async {
    task_entity.Task? existingTask;

    // 1. Try to find existing global task
    if (action.taskId != null) {
      try {
        final tasks = await ref
            .read(tasksRepositoryProvider)
            .getTasksStream()
            .first;
        existingTask = tasks.cast<task_entity.Task?>().firstWhere(
          (t) => t?.id == action.taskId,
          orElse: () => null,
        );
      } catch (e) {
        debugPrint('Error fetching task: $e');
      }
    }

    // 2. Prepare task object for editing (existing or draft from local)
    final taskToEdit =
        existingTask ??
        task_entity.Task(
          id: action.taskId ?? const Uuid().v4(),
          title: action.title,
          description: '',
          bucket: 'Pendent',
          isDone: action.isCompleted,
        );

    task_entity.Task? savedTask;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TaskEditSheet(
        initialBucket: existingTask?.bucket ?? 'Pendent',
        task: taskToEdit,
        onSave: (newTask) {
          savedTask = newTask;
          // TaskEditSheet pops itself
        },
      ),
    );

    // 3. Process Save
    if (savedTask != null && context.mounted) {
      // If it was already linked or the user selected a valid bucket (implied by TaskEditSheet needing a bucket usually)
      // TaskEditSheet onSave returns a Task with a bucket set.

      // A. Update/Create Global Task
      try {
        // We can use addTask or updateTask. Since ID is preserved, updateTask might work if exists, but strictly safe to use add/set if using firestore set logic?
        // The repo likely splits add/update.
        if (existingTask != null) {
          await ref.read(tasksRepositoryProvider).updateTask(savedTask!);
        } else {
          // It was local, now becoming global?
          // If the user didn't explicitly "pick" a bucket in a "classificator", TaskEditSheet forces a bucket?
          // TaskEditSheet usually has a dropdown for bucket.
          // So yes, save it as a new global task.
          await ref.read(tasksRepositoryProvider).addTask(savedTask!);
        }
      } catch (e) {
        debugPrint('Error saving task: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error guardant tasca global: $e')),
          );
        }
      }

      // B. Update Local SubAction
      final updatedSubAction = action.copyWith(
        title: savedTask!.title,
        taskId: savedTask!.id, // Ensure ID link is set/preserved
        isCompleted: savedTask!.isDone,
      );

      // Update list
      final currentActions = point.pathology?.subActions ?? [];
      final updatedActions = currentActions.map((a) {
        if (a.id == action.id) {
          return updatedSubAction;
        }
        return a;
      }).toList();

      final updatedSheet = point.pathology?.copyWith(
        subActions: updatedActions,
      );
      await _updatePoint(updatedSheet);
    }
  }

  Future<void> _toggleSubAction(SubAction action, bool isCompleted) async {
    // 1. Update Local
    final currentActions = point.pathology?.subActions ?? [];
    final updatedActions = currentActions.map((a) {
      if (a.id == action.id) {
        return a.copyWith(isCompleted: isCompleted);
      }
      return a;
    }).toList();

    final updatedSheet = point.pathology?.copyWith(subActions: updatedActions);
    await _updatePoint(updatedSheet);

    // 2. Sync to Global Task (if linked)
    if (action.taskId != null) {
      try {
        final repo = ref.read(tasksRepositoryProvider);
        final tasksStream = repo.getTasksStream();
        final tasks = await tasksStream.first;
        final taskToUpdate = tasks.cast<task_entity.Task?>().firstWhere(
          (t) => t?.id == action.taskId,
          orElse: () => null,
        );

        if (taskToUpdate != null) {
          final updatedTask = taskToUpdate.copyWith(
            isDone: isCompleted,
            completedAt: isCompleted ? DateTime.now() : null,
          );
          await repo.updateTask(updatedTask);
        }
      } catch (e) {
        debugPrint('Error syncing task: $e');
      }
    }
  }

  Future<void> _updatePoint(PathologySheet? updatedSheet) async {
    final updatedPoint = point.copyWith(pathology: updatedSheet);

    // Immediate UI update
    setState(() {
      point = updatedPoint;
    });

    await ref.read(constructionRepositoryProvider).updatePoint(updatedPoint);
  }

  TableRow _buildTableRow(
    BuildContext context,
    String label,
    String value, {
    bool isHeader = false,
    bool isEditable = false,
    TextEditingController? controller,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey.shade200 : Colors.transparent,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _isEditing && isEditable && controller != null
              ? TextField(
                  controller: controller,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
        ),
      ],
    );
  }

  Widget _buildDataSection(
    String title,
    String? content, {
    Widget? trailing,
    bool isEditable = false,
    TextEditingController? controller,
  }) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFD6E8D6), // Light Green from image
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing && isEditable && controller != null)
                  TextField(
                    controller: controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  Text(
                    content ?? 'Sense informació',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (trailing != null) ...[const SizedBox(height: 8), trailing],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
