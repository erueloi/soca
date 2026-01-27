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
import '../../../../features/auth/data/repositories/auth_repository.dart';

class PathologyCarouselPage extends StatelessWidget {
  final List<ConstructionPoint> points;
  final int initialIndex;

  const PathologyCarouselPage({
    super.key,
    required this.points,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final PageController controller = PageController(initialPage: initialIndex);

    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: points.length,
          itemBuilder: (context, index) {
            return PathologyDetailView(point: points[index]);
          },
        ),
        // Desktop Navigation Arrows
        Positioned(
          left: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                size: 32,
                color: Colors.black54,
              ),
              onPressed: () {
                controller.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 32,
                color: Colors.black54,
              ),
              onPressed: () {
                controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PathologyDetailView extends ConsumerStatefulWidget {
  final ConstructionPoint point;

  const PathologyDetailView({super.key, required this.point});

  @override
  ConsumerState<PathologyDetailView> createState() =>
      _PathologyDetailViewState();
}

class _PathologyDetailViewState extends ConsumerState<PathologyDetailView> {
  late ConstructionPoint point;
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _causesController;
  late TextEditingController _actionController;
  List<PathologyPhoto> _currentPhotos = [];
  int _severity = 1;
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;

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
    // Status is now handled by _selectedStatus variables or direct controller text if needed,
    // but for Dropdown we usually use a variable.
    // However, to keep it simple with existing controller structure, we can keep controller
    // or switch to a local variable. Let's use a local variable for the dropdown value.
    _selectedStatus = p?.currentState ?? 'Pendent';
    if (!_validStatuses.contains(_selectedStatus)) {
      _selectedStatus = 'Pendent'; // Fallback if invalid
    }

    _currentPhotos = List.from(p?.photos ?? []);
    // Sort photos by date (Newest first)
    _currentPhotos.sort((a, b) {
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    _severity = p?.severity ?? 1;
  }

  // Define valid statuses
  final List<String> _validStatuses = [
    'Pendent',
    'En Progrés',
    'Finalitzat',
    'Aturat',
  ];
  String _selectedStatus = 'Pendent';

  @override
  void didUpdateWidget(PathologyDetailView oldWidget) {
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
    // _statusController.dispose(); // Removed
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
    final oldPathology = point.pathology;
    final user = ref.read(authRepositoryProvider).currentUser;
    final userName = user?.displayName ?? user?.email ?? 'Usuari';

    List<HistoryEntry> newHistory = [];

    // 1. Detect Status Change
    if (_selectedStatus != (oldPathology?.currentState ?? '')) {
      newHistory.add(
        HistoryEntry(
          date: DateTime.now(),
          action: "Canvi d'estat",
          user: userName,
          comment:
              "${oldPathology?.currentState ?? 'Pendent'} -> $_selectedStatus",
        ),
      );
    }

    // 2. Detect Severity Change
    if (_severity != (oldPathology?.severity ?? 1)) {
      newHistory.add(
        HistoryEntry(
          date: DateTime.now(),
          action: "Canvi gravetat",
          user: userName,
          comment: "${oldPathology?.severity ?? 1} -> $_severity",
        ),
      );
    }

    // 3. Detect Text Changes (Generic)
    bool textChanged = false;
    if (_titleController.text != (oldPathology?.title ?? '') ||
        _descriptionController.text != (oldPathology?.description ?? '') ||
        _causesController.text != (oldPathology?.causes ?? '') ||
        _actionController.text != (oldPathology?.recommendedAction ?? '')) {
      textChanged = true;
    }

    if (textChanged) {
      newHistory.add(
        HistoryEntry(
          date: DateTime.now(),
          action: "Actualització de dades",
          user: userName,
          comment: "S'han modificat els camps de text",
        ),
      );
    }

    if (_currentPhotos.length != (oldPathology?.photos.length ?? 0)) {
      final diff = _currentPhotos.length - (oldPathology?.photos.length ?? 0);
      if (diff < 0) {
        newHistory.add(
          HistoryEntry(
            date: DateTime.now(),
            action: "Fotos eliminades",
            user: userName,
            comment: "${diff.abs()} foto(s) eliminada(es)",
          ),
        );
      } else if (diff > 0) {
        newHistory.add(
          HistoryEntry(
            date: DateTime.now(),
            action: "Fotos",
            user: userName,
            comment: "$diff foto(s) afegida(es)",
          ),
        );
      }
    }

    final updatedHistory = <HistoryEntry>[
      ...(oldPathology?.history ?? []),
      ...newHistory,
    ];

    final updatedPathology = point.pathology?.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
      causes: _causesController.text,
      recommendedAction: _actionController.text,
      photos: _currentPhotos,
      currentState: _selectedStatus,
      severity: _severity,
      history: updatedHistory,
    );

    // Also update Point status if needed (ConstructionPoint has a status field too!)
    // The model implies `status` on ConstructionPoint AND `currentState` on PathologySheet.
    // We should sync them.
    final updatedPoint = point.copyWith(
      status: _selectedStatus,
      pathology: updatedPathology,
    );

    await ref.read(constructionRepositoryProvider).updatePoint(updatedPoint);

    setState(() {
      point = updatedPoint; // Update local point
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvis guardats correctament')),
      );
    }
  }

  Future<void> _relocatePoint() async {
    final floorPlans = ref.read(floorPlansStreamProvider).asData?.value ?? {};
    final floorPlanUrl = floorPlans[point.floorId];

    if (floorPlanUrl == null) {
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

      // We should verify if _updatePoint updates the coordinates or just the pathology sheet.
      // The implementation in this file of _updatePoint (not visible in this snippet but in context)
      // takes a PathologySheet? and calls repo.updatePoint with point.copyWith(pathology: sheet).
      // So _updatePoint as defined in this file (helper) is NOT sufficient for coordinates.
      // We should call repo directly.

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

      if (!mounted) return;

      // Ask for date
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        helpText: 'DATA DE LA FOTO',
        cancelText: 'NO DEFINIR',
        confirmText: 'SELECCIONAR',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(
                context,
              ).colorScheme.copyWith(primary: Colors.indigo),
            ),
            child: child!,
          );
        },
      );

      final dateToUse = pickedDate ?? DateTime.now();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pujant imatge...')));
      }

      final url = await ref
          .read(constructionRepositoryProvider)
          .uploadPathologyImage(image);

      if (url != null) {
        final newPhoto = PathologyPhoto(url: url, date: dateToUse);

        setState(() {
          _currentPhotos.add(newPhoto);
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

  void _showFullScreenImage(
    BuildContext context,
    List<PathologyPhoto> photos,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _FullScreenGallery(photos: photos, initialIndex: initialIndex),
      ),
    );
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

    // Fetch floor plan for mini-map
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);
    final floorPlanUrl = floorPlansAsync.asData?.value[point.floorId];

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
                                  : Stack(
                                      children: [
                                        PageView.builder(
                                          controller: _pageController,
                                          itemCount: _currentPhotos.length,
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentPhotoIndex = index;
                                            });
                                          },
                                          itemBuilder: (context, index) {
                                            final photo = _currentPhotos[index];
                                            return Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    if (!_isEditing) {
                                                      _showFullScreenImage(
                                                        context,
                                                        _currentPhotos,
                                                        index,
                                                      );
                                                    }
                                                  },
                                                  child: Image.network(
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
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                        // Previous Arrow
                                        if (_currentPhotos.length > 1 &&
                                            _currentPhotoIndex > 0)
                                          Positioned(
                                            left: 8,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black38,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.arrow_back_ios,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _pageController
                                                        .previousPage(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    300,
                                                              ),
                                                          curve:
                                                              Curves.easeInOut,
                                                        );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Next Arrow
                                        if (_currentPhotos.length > 1 &&
                                            _currentPhotoIndex <
                                                _currentPhotos.length - 1)
                                          Positioned(
                                            right: 8,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black38,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.arrow_forward_ios,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _pageController.nextPage(
                                                      duration: const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                      curve: Curves.easeInOut,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Date Overlay (from original code, just repositioning if needed)
                                        Positioned(
                                          bottom: 30,
                                          left: 8,
                                          child: GestureDetector(
                                            onTap: _isEditing
                                                ? () async {
                                                    final photo =
                                                        _currentPhotos[_currentPhotoIndex];
                                                    final newDate =
                                                        await showDatePicker(
                                                          context: context,
                                                          initialDate:
                                                              photo.date ??
                                                              DateTime.now(),
                                                          firstDate: DateTime(
                                                            2000,
                                                          ),
                                                          lastDate:
                                                              DateTime.now(),
                                                        );
                                                    if (newDate != null) {
                                                      setState(() {
                                                        _currentPhotos[_currentPhotoIndex] =
                                                            PathologyPhoto(
                                                              url: photo.url,
                                                              date: newDate,
                                                            );
                                                        // Sort descending
                                                        _currentPhotos.sort((
                                                          a,
                                                          b,
                                                        ) {
                                                          if (a.date == null) {
                                                            return 1;
                                                          }
                                                          if (b.date == null) {
                                                            return -1;
                                                          }
                                                          return b.date!
                                                              .compareTo(
                                                                a.date!,
                                                              );
                                                        });
                                                        // Reset index to finder logic? Or just stay.
                                                        // Sort might move the photo.
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
                                                    BorderRadius.circular(8),
                                                border: _isEditing
                                                    ? Border.all(
                                                        color: Colors.white,
                                                        width: 1,
                                                      )
                                                    : null,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _currentPhotos[_currentPhotoIndex]
                                                                .date !=
                                                            null
                                                        ? _formatDate(
                                                            _currentPhotos[_currentPhotoIndex]
                                                                .date!,
                                                          )
                                                        : 'Sense data',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (_isEditing) ...[
                                                    const SizedBox(width: 4),
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

                                        // Delete & Counter Overlays
                                        if (_isEditing)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: CircleAvatar(
                                              backgroundColor: Colors.white70,
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
                                                      _currentPhotoIndex,
                                                    );
                                                    if (_currentPhotoIndex >=
                                                            _currentPhotos
                                                                .length &&
                                                        _currentPhotoIndex >
                                                            0) {
                                                      _currentPhotoIndex--;
                                                    }
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
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${_currentPhotoIndex + 1}/${_currentPhotos.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
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
                              imageUrl: floorPlanUrl,
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
    // Watch tasks to calculate costs
    final tasksAsync = ref.watch(tasksStreamProvider);

    return tasksAsync.when(
      loading: () => const Center(child: LinearProgressIndicator()),
      error: (e, s) => Text('Error carregant costos: $e'),
      data: (tasks) {
        final subActions = pathology?.subActions ?? [];
        final total = subActions.length;
        final completed = subActions.where((s) => s.isCompleted).length;
        final progress = total > 0 ? completed / total : 0.0;

        // Calculate total estimated cost
        double totalEstimatedCost = 0.0;
        for (var action in subActions) {
          if (action.taskId != null) {
            try {
              final task = tasks.firstWhere((t) => t.id == action.taskId);
              totalEstimatedCost += task.totalBudget;
            } catch (_) {}
          }
        }

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FULL DE RUTA / SUBACTUACIONS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (totalEstimatedCost > 0)
                          Text(
                            'Cost Estimat: ${totalEstimatedCost.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
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
                      // Find task for specific action cost
                      double? actionCost;
                      if (action.taskId != null) {
                        try {
                          final task = tasks.firstWhere(
                            (t) => t.id == action.taskId,
                          );
                          if (task.totalBudget > 0) {
                            actionCost = task.totalBudget;
                          }
                        } catch (_) {}
                      }

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: action.isCompleted,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _toggleSubAction(action, value);
                            }
                          },
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                action.title,
                                style: TextStyle(
                                  decoration: action.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (actionCost != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  '${actionCost.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () {
                            if (action.taskId != null) {
                              // Edit linked task
                              _openLinkedTask(action.taskId!);
                            } else {
                              // Edit simple action (rename/delete)
                              _editSubAction(context, action);
                            }
                          },
                          tooltip: action.taskId != null
                              ? 'Veure detall tasca'
                              : 'Editar',
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openLinkedTask(String taskId) async {
    // Determine the bucket? We don't know it easily.
    // TaskEditSheet requires a Task object.
    // We can fetch it first.
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final tasks = await repo.getTasksStream().first;
      final task = tasks.cast<task_entity.Task?>().firstWhere(
        (t) => t?.id == taskId,
        orElse: () => null,
      );

      if (task != null && mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => TaskEditSheet(
            task: task,
            initialBucket: task.bucket,
            onSave: (updatedTask) async {
              await repo.updateTask(updatedTask);
              // Also update title in subAction if changed?
              // The SubAction has a copy of the title.
              // It would be nice to keep them in sync, but maybe not strictly required right now.
              // But let's verify if title changed.
              if (updatedTask.title != task.title) {
                // Find the subAction with this taskId
                final subActions = point.pathology?.subActions ?? [];
                final index = subActions.indexWhere((s) => s.taskId == taskId);
                if (index != -1) {
                  final updatedSubActions = List<SubAction>.from(subActions);
                  updatedSubActions[index] = updatedSubActions[index].copyWith(
                    title: updatedTask.title,
                  );
                  _updatePoint(
                    point.pathology!.copyWith(subActions: updatedSubActions),
                  );
                }
              }
            },
            onDelete: () async {
              // Delete task and remove from subActions
              await repo.deleteTask(taskId);
              final subActions = point.pathology?.subActions ?? [];
              final updatedSubActions = subActions
                  .where((s) => s.taskId != taskId)
                  .toList();
              _updatePoint(
                point.pathology!.copyWith(subActions: updatedSubActions),
              );
            },
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No s\'ha trobat la tasca vinculada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error obrint la tasca: $e')));
      }
    }
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
                            ? InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedStatus,
                                    isExpanded: true,
                                    items: _validStatuses.map((String status) {
                                      return DropdownMenuItem<String>(
                                        value: status,
                                        child: Text(status),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedStatus = newValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  _selectedStatus.isNotEmpty
                                      ? _selectedStatus
                                      : 'Sense estat definit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedStatus == 'Finalitzat'
                                        ? Colors.green
                                        : (_selectedStatus == 'Aturat'
                                              ? Colors.red
                                              : Colors.black87),
                                  ),
                                ),
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
    final user = ref.read(authRepositoryProvider).currentUser;
    final userName = user?.displayName ?? user?.email ?? 'Usuari';

    final newEntry = HistoryEntry(
      date: DateTime.now(),
      action: "Nova Tasca Llista",
      user: userName,
      comment: "Afegida: $title",
    );

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
      history: [...(point.pathology?.history ?? []), newEntry],
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

      final user = ref.read(authRepositoryProvider).currentUser;
      final userName = user?.displayName ?? user?.email ?? 'Usuari';
      final newEntry = HistoryEntry(
        date: DateTime.now(),
        action: "Edició Tasca",
        user: userName,
        comment: "Modificada: ${savedTask!.title}",
      );

      final updatedSheet = point.pathology?.copyWith(
        subActions: updatedActions,
        history: [...(point.pathology?.history ?? []), newEntry],
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

    final user = ref.read(authRepositoryProvider).currentUser;
    final userName = user?.displayName ?? user?.email ?? 'Usuari';
    final newEntry = HistoryEntry(
      date: DateTime.now(),
      action: "Estat Tasca",
      user: userName,
      comment: "${action.title}: ${isCompleted ? 'Completada' : 'Pendent'}",
    );

    final updatedSheet = point.pathology?.copyWith(
      subActions: updatedActions,
      history: [...(point.pathology?.history ?? []), newEntry],
    );
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

class _FullScreenGallery extends StatefulWidget {
  final List<PathologyPhoto> photos;
  final int initialIndex;

  const _FullScreenGallery({required this.photos, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          currentPhoto.date != null ? _formatDate(currentPhoto.date!) : '',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    photo.url,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Prev Arrow
          if (widget.photos.length > 1 && _currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Next Arrow
          if (widget.photos.length > 1 &&
              _currentIndex < widget.photos.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Counter
          Positioned(
            bottom: 30,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
