import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/planta_hort.dart';
import '../../../trees/presentation/pages/location_picker_page.dart';

import '../../data/repositories/hort_repository.dart';
import 'hort_library_page.dart';
import '../../domain/entities/garden_layout_config.dart';

import '../../domain/entities/espai_hort.dart';
import '../../domain/entities/hort_rotation_pattern.dart';

final rotationPatternsStreamProvider =
    StreamProvider<List<HortRotationPattern>>((ref) {
      return ref.watch(hortRepositoryProvider).getPatternsStream();
    });

class GardenDesignerPage extends ConsumerStatefulWidget {
  final EspaiHort espai;
  const GardenDesignerPage({super.key, required this.espai});

  @override
  ConsumerState<GardenDesignerPage> createState() => _GardenDesignerPageState();
}

enum DesignerTool { plants, patterns }

class _GardenDesignerPageState extends ConsumerState<GardenDesignerPage> {
  final _repository = HortRepository();
  late EspaiHort _espai;
  String? _selectedSpeciesId;

  // Grid Data: "row_col" -> speciesId
  final Map<String, String> _grid = {};

  late Stream<List<PlantaHort>> _plantsStream;

  // Dimensions
  double get _cellSize => _espai.gridCellSize;
  int get _cols => (_espai.width / _cellSize).floor();
  int get _rows => (_espai.length / _cellSize).floor();

  final TransformationController _transformationController =
      TransformationController();
  bool _initialCenterDone = false;
  List<PlantaHort> _currentPlantsList = [];

  bool _isPaintMode = false;
  DesignerTool _selectedTool = DesignerTool.plants;
  String? _selectedPatternId; // For Pattern Tool (instead of selectedSpeciesId)
  final Set<String> _draggedCells = {};

  // Dirty flag to show save button
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _espai = widget.espai;
    _grid.addAll(widget.espai.gridState);
    _plantsStream = _repository.getPlantsStream();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // Note: Previous _calculateLayout logic (beds vs paths) assumes a specific layout config.
  // EspaiHort is generic (just a rect).
  // For now, we assume the WHOLE rect is one big bed/plot unless we add "Walkways" feature later.
  // OR we keep the "LayoutConfig" inside EspaiHort if we want to auto-generate beds?
  // User Requirement: "Form to create new spaces (Name, Dimensions) ... then show grid".
  // So we default to "All Valid".

  bool _isBed(int colIndex) {
    if (_espai.layoutConfig == null) {
      return true; // No config? All valid.
    }

    final config = _espai.layoutConfig!;
    // Calculate if this colIndex corresponds to a Path
    // X position in meters
    final double x = colIndex * config.cellSize;

    // Logic: Path | Bed | Path | Bed | Path ...
    // Assuming starts with Path? "Formula N+1 Passadissos" implies P B P B P

    // Check if within the first path
    if (x < config.pathWidth) return false;

    // Modulo arithmetic?
    // x falls into a pattern.
    // Shift by first path

    // How many Full Segments (Bed+Path) have passed?
    // A segment is Bed then Path.
    // Wait, Formula N+1 Path means: Path, Bed, Path, Bed, Path.
    // So distinct regions:
    // [0, P) -> Path
    // [P, P+B) -> Bed 1
    // [P+B, 2P+B) -> Path
    // [2P+B, 2P+2B) -> Bed 2
    // etc.

    // Let's implement robust check
    double currentX = 0.0;
    // Iterate until we pass x or run out of beds
    for (int i = 0; i < config.numberOfBeds; i++) {
      // Path before bed
      if (x >= currentX && x < currentX + config.pathWidth) return false;
      currentX += config.pathWidth;

      // Bed
      if (x >= currentX && x < currentX + config.bedWidth) return true;
      currentX += config.bedWidth;
    }
    // Final path
    if (x >= currentX) return false;

    return false;
  }

  Future<void> _saveChanges() async {
    final updatedEspai = _espai.copyWith(gridState: _grid);
    await ref.read(hortRepositoryProvider).saveEspai(updatedEspai);
    if (!mounted) return;
    setState(() {
      _espai = updatedEspai;
      _hasChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Espai guardat correctament!')),
    );
  }

  void _plantAt(int row, int col, List<PlantaHort> availablePlants) {
    // If erasing
    if (_selectedSpeciesId == null) {
      if (_grid.containsKey('${row}_$col')) {
        setState(() {
          _grid.remove('${row}_$col');
          _hasChanges = true;
        });
      }
      return;
    }

    final selected = availablePlants.firstWhere(
      (s) => s.id == _selectedSpeciesId,
      orElse: () => availablePlants.first,
    );
    bool exists = availablePlants.any((s) => s.id == _selectedSpeciesId);
    if (!exists) return;

    // Dynamic Size Logic (Rectangular Brush)
    // Width (Cols) = Lines Spacing (assuming lines run parallel to bed length)
    // Height (Rows) = Plant Spacing within line
    int widthCells = (selected.distanciaLinies / 20.0).round();
    int heightCells = (selected.distanciaPlantacio / 20.0).round();
    if (widthCells < 1) widthCells = 1;
    if (heightCells < 1) heightCells = 1;

    // Just loop and paint valid cells (Clipping)
    int paintedCount = 0;
    for (int r = 0; r < heightCells; r++) {
      for (int c = 0; c < widthCells; c++) {
        final tr = row + r;
        final tc = col + c;
        // Skip out of bounds or paths
        if (tr >= _rows || tc >= _cols) continue;
        if (!_isBed(tc)) continue;

        final key = '${tr}_$tc';

        // Compatibility Check (if needed, but overwrite is standard)

        _grid[key] = selected.id;
        if (_isPaintMode) {
          _draggedCells.add(key);
        }
        paintedCount++;
      }
    }

    if (paintedCount > 0) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _onCellTap(int row, int col, List<PlantaHort> plants) {
    if (!_isBed(col)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚫 Zona de pas (Passadís). No s\'hi pot plantar.'),
          duration: Duration(milliseconds: 500),
        ),
      );
      return;
    }
    _plantAt(row, col, plants);
  }

  void _handlePaint(
    Offset localPos,
    double cellPixelSize,
    int maxRows,
    int maxCols,
    double padding,
    List<PlantaHort> plants,
  ) {
    if (!_isPaintMode) return;
    final dx = localPos.dx - padding;
    final dy = localPos.dy - padding;
    if (dx < 0 || dy < 0) return;
    final col = (dx / cellPixelSize).floor();
    final row = (dy / cellPixelSize).floor();
    if (col < 0 || col >= maxCols || row < 0 || row >= maxRows) return;
    final key = '${row}_$col';
    if (!_draggedCells.contains(key)) {
      _draggedCells.add(key);
      _plantAt(row, col, plants);
    }
  }

  Future<void> _confirmAndDeleteEspai(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Espai?'),
        content: const Text(
          'Segur que vols eliminar aquest espai permanentment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(hortRepositoryProvider).deleteEspai(_espai.id);
      if (context.mounted) {
        // Pop any open dialogs (like settings dialog)
        if (Navigator.canPop(context)) Navigator.pop(context);
        // Pop the current page
        Navigator.pop(context);
      }
    }
  }

  Future<LatLng?> _showLocationPicker(
    BuildContext context,
    LatLng initialPosition, {
    double? width,
    double? height,
    String? label,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLocation: initialPosition,
          width: width,
          height: height,
          label: label,
        ),
      ),
    );
    if (result is LatLng) return result;
    return null;
  }

  void _showSettingsDialog() {
    // Controllers
    final nameCtrl = TextEditingController(text: _espai.nom);
    final widthCtrl = TextEditingController(text: _espai.width.toString());
    final lengthCtrl = TextEditingController(text: _espai.length.toString());

    // Layout Config Controllers
    final bedsCtrl = TextEditingController(
      text: _espai.layoutConfig?.numberOfBeds.toString() ?? '1',
    );
    final pathCtrl = TextEditingController(
      text: _espai.layoutConfig?.pathWidth.toString() ?? '0.5',
    );

    // Position
    final latCtrl = TextEditingController(
      text: _espai.center.latitude.toString(),
    );
    final lngCtrl = TextEditingController(
      text: _espai.center.longitude.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuració de l\'Espai'),
        content: SizedBox(
          width: 400,
          child: StatefulBuilder(
            builder: (context, setState) {
              // Calculation Logic matching EspaiListPage
              Widget feedbackWidget = const SizedBox.shrink();
              final w = double.tryParse(widthCtrl.text) ?? 0;
              final n = int.tryParse(bedsCtrl.text) ?? 0;
              final p = double.tryParse(pathCtrl.text) ?? 0;

              if (w > 0 && n > 0 && p >= 0) {
                final totalPath = (n + 1) * p;
                final totalBed = w - totalPath;
                if (totalBed <= 0) {
                  feedbackWidget = Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    color: Colors.red[100],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Massa estret! No hi caben els bancals.',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  final bedW = totalBed / n;
                  feedbackWidget = Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9), // Light Green
                      border: Border(
                        bottom: BorderSide(color: Colors.green[800]!, width: 2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_box, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Amplada de cada bancal: ${bedW.toStringAsFixed(2)} m',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- General ---
                    const Text(
                      'General',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'Espai',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 24),

                    // --- Dimensions ---
                    const Text(
                      'Dimensions & Posició',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amplada (m)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lengthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Llargada (m)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Latitud',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lngCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Longitud',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.map, color: Colors.blue),
                          tooltip: 'Seleccionar al Mapa',
                          onPressed: () async {
                            final lat = double.tryParse(latCtrl.text) ?? 0;
                            final lng = double.tryParse(lngCtrl.text) ?? 0;
                            final w =
                                double.tryParse(widthCtrl.text) ?? _espai.width;
                            final l =
                                double.tryParse(lengthCtrl.text) ??
                                _espai.length;

                            final newPos = await _showLocationPicker(
                              context,
                              LatLng(lat, lng),
                              width: w,
                              height: l,
                              label: nameCtrl.text,
                            );

                            if (newPos != null) {
                              latCtrl.text = newPos.latitude.toStringAsFixed(6);
                              lngCtrl.text = newPos.longitude.toStringAsFixed(
                                6,
                              );
                              // Rebuild to show updated coordinates?
                              // TextController update should show it.
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // --- Layout ---
                    const Text(
                      'Distribució (Layout)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.blue.withValues(alpha: 0.1),
                      child: const Text(
                        'Fórmula N+1: Es calcularà automàticament l\'amplada dels bancals tenint en compte passadissos a tots els costats.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: bedsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Núm. Bancals',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: pathCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amplada Passadís',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    feedbackWidget,
                    const SizedBox(height: 8),
                    const Text(
                      '⚠️ Modificar les dimensions o distribució pot desajustar el cultiu existent.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          // Delete Button
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close settings dialog first
              await _confirmAndDeleteEspai(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Parse Values
              final nom = nameCtrl.text;
              final w = double.tryParse(widthCtrl.text) ?? _espai.width;
              final l = double.tryParse(lengthCtrl.text) ?? _espai.length;
              final lat =
                  double.tryParse(latCtrl.text) ?? _espai.center.latitude;
              final lng =
                  double.tryParse(lngCtrl.text) ?? _espai.center.longitude;

              final nBeds = int.tryParse(bedsCtrl.text) ?? 1;
              final pWidth = double.tryParse(pathCtrl.text) ?? 0.5;

              // Setup new config
              // Recalculate bedWidth: (Width - (N+1)*P) / N
              // We trust the user wants to fit it in W.
              final totalPath = (nBeds + 1) * pWidth;
              final totalBedSpace = w - totalPath;
              double bedWidth = (totalBedSpace > 0 && nBeds > 0)
                  ? totalBedSpace / nBeds
                  : 0.0;

              final newConfig = GardenLayoutConfig(
                totalWidth: w,
                totalLength: l,
                numberOfBeds: nBeds,
                bedWidth: bedWidth,
                pathWidth: pWidth,
                cellSize:
                    _espai.layoutConfig?.cellSize ??
                    0.2, // Keep existing cell size
              );

              setState(() {
                _espai = _espai.copyWith(
                  nom: nom,
                  width: w,
                  length: l,
                  center: LatLng(lat, lng),
                  layoutConfig: newConfig,
                );
              });

              // Persist logic
              await _saveChanges();

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _espai.nom,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '$_cols x $_rows (${(_cellSize * 100).toStringAsFixed(0)}cm) - ${_espai.layoutConfig?.numberOfBeds ?? 0} Bancals',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          ToggleButtons(
            isSelected: [!_isPaintMode, _isPaintMode],
            onPressed: (index) {
              final newMode = index == 1; // 0=Move, 1=Paint
              if (_isPaintMode != newMode) {
                setState(() {
                  _isPaintMode = newMode;
                  _showModeSnackBar();
                });
              }
            },
            color: Colors.white70,
            selectedColor: Colors.white,
            fillColor: Colors.white24,
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
            children: const [
              Tooltip(message: 'Mode Moure', child: Icon(Icons.pan_tool)),
              Tooltip(message: 'Mode Pintar', child: Icon(Icons.brush)),
            ],
          ),
          const SizedBox(width: 8),
          // Tool Selector (Plants vs Patterns)
          if (_isPaintMode ||
              true) // Always show or only in paint mode? User wanted unified.
            ToggleButtons(
              isSelected: [
                _selectedTool == DesignerTool.plants,
                _selectedTool == DesignerTool.patterns,
              ],
              onPressed: (index) {
                setState(() {
                  _selectedTool = index == 0
                      ? DesignerTool.plants
                      : DesignerTool.patterns;
                });
              },
              color: Colors.white70,
              selectedColor: Colors.white,
              fillColor: Colors.white24,
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
              children: const [
                Tooltip(message: 'Plantes', child: Icon(Icons.grass)),
                Tooltip(message: 'Patrons', child: Icon(Icons.sync)),
              ],
            ),
          const SizedBox(width: 8),

          // Auto-Fill Action (Only for Patterns?)
          if (_selectedTool == DesignerTool.patterns)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Aplicar Patrons (Auto-Omplir)',
              onPressed: _applyPatternsToGrid,
            ),

          if (_isPaintMode && _selectedTool == DesignerTool.plants)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Netejar Tot',
              onPressed: _clearPlants,
            ),

          IconButton(
            icon: const Icon(Icons.save),
            color: _hasChanges
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.54),
            tooltip: 'Guardar Canvis',
            onPressed: _hasChanges ? _saveChanges : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red[100],
            tooltip: 'Eliminar Espai',
            onPressed: () async {
              await _confirmAndDeleteEspai(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuració',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.local_library),
            tooltip: 'Biblioteca d\'Hort',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HortLibraryPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PlantaHort>>(
        stream: _plantsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No hi ha dades.'));
          }

          _currentPlantsList = snapshot.data!;
          final plants = _currentPlantsList;

          // Metrics
          final int cols = _cols;
          final int rows = _rows;
          final double pixelsPerMeter = 50.0 / (_cellSize / 0.2);
          final double cellPixelSize = _cellSize * pixelsPerMeter;
          const double gridPadding = 64.0;
          final double contentWidth =
              (cols * cellPixelSize) + (gridPadding * 2);
          final double contentHeight =
              (rows * cellPixelSize) + (gridPadding * 2);

          return Column(
            children: [
              // Toolbar Content
              Container(
                height: 100,
                color: Colors.grey[50], // Light background
                child: _selectedTool == DesignerTool.plants
                    ? _buildPlantsList(plants)
                    : _buildPatternsList(),
              ),
              const Divider(height: 1),

              // GRID
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (!_initialCenterDone) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_initialCenterDone && mounted) {
                          final dx = (constraints.maxWidth - contentWidth) / 2;
                          final dy =
                              (constraints.maxHeight - contentHeight) / 2;
                          _transformationController.value =
                              Matrix4.translationValues(dx, dy, 0);
                          setState(() {
                            _initialCenterDone = true;
                          });
                        }
                      });
                    }

                    return InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.1,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(2000),
                      constrained: false,
                      panEnabled: !_isPaintMode,
                      scaleEnabled: !_isPaintMode,
                      child: Listener(
                        onPointerDown: (event) {
                          if (_isPaintMode &&
                              _selectedTool == DesignerTool.plants) {
                            _draggedCells.clear();
                            _handlePaint(
                              event.localPosition,
                              cellPixelSize,
                              rows,
                              cols,
                              gridPadding,
                              plants,
                            );
                          }
                        },
                        onPointerMove: (event) {
                          if (_isPaintMode &&
                              _selectedTool == DesignerTool.plants) {
                            _handlePaint(
                              event.localPosition,
                              cellPixelSize,
                              rows,
                              cols,
                              gridPadding,
                              plants,
                            );
                          }
                        },
                        child: Container(
                          width: contentWidth,
                          height: contentHeight,
                          color: Colors.transparent,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5F5DC),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: GestureDetector(
                                    onTapUp: (details) {
                                      final dx =
                                          details.localPosition.dx -
                                          gridPadding;
                                      final dy =
                                          details.localPosition.dy -
                                          gridPadding;
                                      final c = (dx / cellPixelSize).floor();
                                      final r = (dy / cellPixelSize).floor();

                                      if (c >= 0 &&
                                          c < cols &&
                                          r >= 0 &&
                                          r < rows) {
                                        if (_isPaintMode) {
                                          if (_selectedTool ==
                                              DesignerTool.plants) {
                                            _onCellTap(r, c, plants);
                                          } else if (_selectedTool ==
                                              DesignerTool.patterns) {
                                            _onBedTap(c); // Or direct assign?
                                          }
                                        } else {
                                          _onBedTap(
                                            c,
                                          ); // Always config bed if Move Mode
                                        }
                                      }
                                    },
                                    child: Consumer(
                                      builder: (context, ref, child) {
                                        final patterns =
                                            ref
                                                .watch(
                                                  rotationPatternsStreamProvider,
                                                )
                                                .asData
                                                ?.value ??
                                            [];
                                        return CustomPaint(
                                          size: Size(
                                            cols * cellPixelSize,
                                            rows * cellPixelSize,
                                          ),
                                          painter: GardenGridPainter(
                                            rows: rows,
                                            cols: cols,
                                            cellPixelSize: cellPixelSize,
                                            gridState: _grid,
                                            plants: plants,
                                            isBed: _isBed,
                                            layoutConfig: _espai.layoutConfig,
                                            patterns: patterns,
                                            padding: gridPadding,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildStatsPanel(plants),
            ],
          );
        },
      ),
    );
  }

  // --- Helpers ---

  Widget _buildPlantsList(List<PlantaHort> plants) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        final s = plants[index];
        final isSelected = s.id == _selectedSpeciesId;
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedSpeciesId = isSelected ? null : s.id),
          onLongPress: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HortLibraryPage(initialSearch: s.nomComu),
              ),
            );
          },
          child: Container(
            width: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green[50] : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    s.partComestible.icon,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    s.nomComu,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${s.distanciaPlantacio.round()}x${s.distanciaLinies.round()}',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatternsList() {
    return Consumer(
      builder: (context, ref, _) {
        final patternsAsync = ref.watch(rotationPatternsStreamProvider);
        return patternsAsync.when(
          data: (patterns) => ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            itemCount: patterns.length,
            itemBuilder: (context, index) {
              final p = patterns[index];
              final isSelected = p.id == _selectedPatternId;
              return GestureDetector(
                onTap: () => setState(
                  () => _selectedPatternId = isSelected ? null : p.id,
                ),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange[50] : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepOrange
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isSelected)
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );
      },
    );
  }

  void _applyPatternsToGrid() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Aplicant patrons...')));

    // Proper Logic (requires Ref to fetch patterns? Or use cached patterns if available?)
    // Ideally we need the list of Patterns to map IDs.
    // Since `_buildPatternsList` uses `ref.watch`, we can't easily access patterns here unless we access provider.
    // But `ConsumerState` allows `ref.read`.

    final patterns = await ref.read(rotationPatternsStreamProvider.future);
    if (!mounted) return;
    final config = _espai.layoutConfig;
    if (config == null) return;

    int changesCount = 0;

    // For each bed
    for (int i = 0; i < config.numberOfBeds; i++) {
      final bedData = config.beds[i];
      if (bedData == null || bedData.rotationPatternId == null) continue;

      final pattern = patterns.firstWhere(
        (p) => p.id == bedData.rotationPatternId,
        orElse: () => patterns.first,
      );
      if (bedData.rotationPatternId != pattern.id) continue;

      // Start Date
      final start = bedData.rotationStartDate ?? DateTime.now();
      // Calc Current Plant ID
      final now = DateTime.now();
      int monthsDiff = (now.year - start.year) * 12 + now.month - start.month;
      int totalDuration = pattern.stages.fold(
        0,
        (s, e) => s + e.durationMonths,
      );
      if (totalDuration == 0) continue;

      int currentMonth = monthsDiff % totalDuration;
      if (monthsDiff < 0) currentMonth = 0;

      String? suggestedId;
      int accumulated = 0;
      for (final stage in pattern.stages) {
        if (currentMonth < accumulated + stage.durationMonths) {
          if (stage.suggestedSpeciesIds.isNotEmpty) {
            suggestedId = stage.suggestedSpeciesIds.first;
          }
          break;
        }
        accumulated += stage.durationMonths;
      }

      if (suggestedId != null) {
        // Fill Bed with suggestedId
        // Iterate all cells in garden. If cell is in bed i, paint it.
        // This is loop heavy. Optimization: Determine Bed X range.
        final p = config.pathWidth;
        final b = config.bedWidth;
        final bedStartM = p + i * (b + p);
        final bedEndM = bedStartM + b;

        // Convert to cell info
        // _plantAt logic handles individual cells. Simple loop:
        for (int c = 0; c < _cols; c++) {
          double cellM = c * _cellSize; // Start of cell
          // Check overlap. Center of cell?
          double centerM = cellM + (_cellSize / 2);
          if (centerM >= bedStartM && centerM < bedEndM) {
            for (int r = 0; r < _rows; r++) {
              _grid['${r}_$c'] = suggestedId;
              changesCount++;
            }
          }
        }
      }
    }

    if (changesCount > 0) {
      setState(() {
        _hasChanges = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-omplert completat: $changesCount cel·les.'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No s\'han trobat patrons actius o plantes per assignar.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearPlants() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Netejar Plantes?'),
        content: const Text(
          'Segur que vols eliminar totes les plantes del disseny? Aquesta acció no es pot desfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Netejar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _grid.clear();
        _hasChanges = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Disseny netejat.')));
      }
    }
  }

  void _onBedTap(int col) {
    if (_espai.layoutConfig == null) return;
    final bedIndex = _getBedIndexFromCol(col);
    if (bedIndex != null) {
      if (_selectedTool == DesignerTool.patterns &&
          _isPaintMode &&
          _selectedPatternId != null) {
        // Direct Assign
        setState(() {
          final old = _espai.layoutConfig!.beds[bedIndex];
          _espai.layoutConfig!.beds[bedIndex] = BedData(
            rotationPatternId: _selectedPatternId,
            rotationStartDate:
                old?.rotationStartDate ??
                DateTime.now(), // Preserve date or reset?
          );
          _hasChanges = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patró assignat al bancal!')),
        );
      } else {
        _showBedConfigDialog(bedIndex);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Això és un passadís.'),
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  Widget _buildStatsPanel(List<PlantaHort> plants) {
    if (_grid.isEmpty) return const SizedBox.shrink();

    double totalHarvestKg = 0;
    int totalPlants = 0;
    int maxDays = 0;

    // Group counts
    final counts = <String, int>{};
    for (var id in _grid.values) {
      counts[id] = (counts[id] ?? 0) + 1;
    }

    for (var entry in counts.entries) {
      final plant = plants.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => plants.first,
      );
      if (!plants.any((p) => p.id == entry.key)) continue;

      // Area calculations
      // Cell is 20x20cm = 0.04 m2
      final area = entry.value * 0.04;
      totalHarvestKg += area * plant.rendiment;

      // Plant Count
      // How many cells per plant?
      // Size = (dist / 20).round()
      // Cells = size * size
      int size = (plant.distanciaPlantacio / 20.0).round();
      if (size < 1) size = 1;
      int cellsPerPlant = size * size;

      // If cellsPerPlant is 0 (impossible), avoid div by zero.
      totalPlants += (entry.value / cellsPerPlant).round();

      if (plant.diesEnCamp > maxDays) maxDays = plant.diesEnCamp;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.scale,
            'Collita',
            '${totalHarvestKg.toStringAsFixed(1)} kg',
          ),
          _buildStatItem(Icons.local_florist, 'Plantes', '$totalPlants u.'),
          _buildStatItem(Icons.timer, 'Cicle Màx', '$maxDays dies'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showModeSnackBar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPaintMode
              ? 'Mode Pintar/Editar ACTIVAT'
              : 'Mode Moure/Veure ACTIVAT',
        ),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  int? _getBedIndexFromCol(int col) {
    final config = _espai.layoutConfig;
    if (config == null) return null;

    final x = col * _cellSize; // Position in meters
    // We assume layout starts at x=0
    // Bed i range: [path + i*(bed+path), path + i*(bed+path) + bed]

    final p = config.pathWidth;
    final b = config.bedWidth;

    for (int i = 0; i < config.numberOfBeds; i++) {
      final start = p + i * (b + p);
      final end = start + b;
      if (x >= start && x < end) {
        return i;
      }
    }
    return null;
  }

  void _showBedConfigDialog(int bedIndex) {
    // Current Data
    final bedData = _espai.layoutConfig!.beds[bedIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String? selectedPattern = bedData?.rotationPatternId;
        DateTime startDate = bedData?.rotationStartDate ?? DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuració Bancal ${bedIndex + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Assignar Patró de Rotació:'),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final patternsAsync = ref.watch(
                        rotationPatternsStreamProvider,
                      );
                      return patternsAsync.when(
                        data: (patterns) => DropdownButtonFormField<String>(
                          initialValue: selectedPattern,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Selecciona un Patró',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Cap (Manual)'),
                            ),
                            ...patterns.map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedPattern = val;
                            });
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => Text('Error loading patterns: $e'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Data d\'Inici de la Rotació:'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${startDate.day}/${startDate.month}/${startDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          startDate = picked;
                        });
                      }
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Save
                        final newBedData = (bedData ?? BedData()).copyWith(
                          rotationPatternId: selectedPattern,
                          rotationStartDate: startDate,
                        );

                        final newBeds = Map<int, BedData>.from(
                          _espai.layoutConfig!.beds,
                        );
                        newBeds[bedIndex] = newBedData;

                        final newConfig = GardenLayoutConfig(
                          totalWidth: _espai.layoutConfig!.totalWidth,
                          totalLength: _espai.layoutConfig!.totalLength,
                          numberOfBeds: _espai.layoutConfig!.numberOfBeds,
                          bedWidth: _espai.layoutConfig!.bedWidth,
                          pathWidth: _espai.layoutConfig!.pathWidth,
                          cellSize: _espai.layoutConfig!.cellSize,
                          beds: newBeds,
                        );

                        // Update outer state
                        // We are inside StatefulBuilder, so 'setState' here updates Dialog.
                        // We need to update page state.
                        // 'this.setState' refers to Page State if we use arrow function or access 'this'.
                        // But we shadowed 'setState'.
                        // We can use a method or access via 'this.setState' (which might be ambiguous).
                        // Better: Use a dedicated method in PageState class `_updateConfig(newConfig)`.
                        // Or just reference the PageState's setState?
                        // `_GardenDesignerPageState` methods are accessible.
                        // But `setState` is shadowed.
                        // We can store a reference to pageSetState?
                        // Or just call `_saveBedData(newConfig)`.

                        _saveBedData(newConfig);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Guardar Configuració Bancal'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveBedData(GardenLayoutConfig newConfig) async {
    setState(() {
      _espai = _espai.copyWith(layoutConfig: newConfig);
    });
    await _saveChanges();
  }
}

class GardenGridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellPixelSize;
  final Map<String, String> gridState;
  final List<PlantaHort> plants;
  final bool Function(int col) isBed;
  final GardenLayoutConfig? layoutConfig;
  final List<HortRotationPattern> patterns;

  final double padding;

  GardenGridPainter({
    required this.rows,
    required this.cols,
    required this.cellPixelSize,
    required this.gridState,
    required this.plants,
    required this.isBed,
    this.layoutConfig,
    this.patterns = const [],
    this.padding = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(padding, padding);

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black12.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    // Pre-calculate Icon Painters to optimize performance
    final Map<String, TextPainter> iconPainters = {};
    for (final plant in plants) {
      final icon = plant.partComestible.icon;
      final textSpan = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: cellPixelSize * 0.6,
          fontFamily: icon.fontFamily,
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.bold, // Make it pop
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      iconPainters[plant.id] = tp;
    }

    final config = layoutConfig;

    // ... loop starts ...
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final left = c * cellPixelSize;
        final top = r * cellPixelSize;
        final rect = Rect.fromLTWH(left, top, cellPixelSize, cellPixelSize);

        // Determine Bed Index
        int? bedIndex;
        if (config != null) {
          final x = c * config.cellSize; // meters
          final p = config.pathWidth;
          final b = config.bedWidth;

          // Optimization: Calculate directly instead of loop?
          // Since beds are regular: Start = p + i*(b+p).
          // We can iterate or use math. Loop is safer for small N.
          for (int i = 0; i < config.numberOfBeds; i++) {
            final start = p + i * (b + p);
            final end = start + b;
            if (x >= start && x < end) {
              bedIndex = i;
              break;
            }
          }
        } else {}

        final bool isBedCell = bedIndex != null;

        if (isBedCell) {
          // Bed Background (Earthy Brown)
          canvas.drawRect(
            rect,
            paint
              ..color = const Color(0xFF8D6E63), // Brown 400 (Darker, richer)
          );
        } else {
          // Path Background (Light Path/Ground)
          canvas.drawRect(
            rect,
            paint..color = const Color(0xFFEFEBE9), // Brown 50 (Neutral ground)
          );
        }

        // Plant Logic
        final key = '${r}_$c';
        final plantId = gridState[key];

        // 1. Draw Actual Plant
        if (plantId != null) {
          if (plants.any((p) => p.id == plantId)) {
            final plant = plants.firstWhere((p) => p.id == plantId);
            canvas.drawRect(rect, paint..color = plant.color);

            // Draw Icon
            final tp = iconPainters[plantId];
            if (tp != null) {
              // Center the icon
              final dx = left + (cellPixelSize - tp.width) / 2;
              final dy = top + (cellPixelSize - tp.height) / 2;
              tp.paint(canvas, Offset(dx, dy));
            }
          }
        }

        // 2. Ghost / Guide Logic
        if (bedIndex != null && config != null) {
          final bedData = config.beds[bedIndex];
          if (bedData != null && bedData.rotationPatternId != null) {
            final pattern = patterns.firstWhere(
              (p) => p.id == bedData.rotationPatternId,
              orElse: () => patterns.isEmpty
                  ? HortRotationPattern(id: '', name: '', stages: [])
                  : patterns.first,
            );

            if (pattern.stages.isNotEmpty &&
                bedData.rotationStartDate != null) {
              final startDate = bedData.rotationStartDate!;
              final now = DateTime.now();
              int monthsDiff =
                  (now.year - startDate.year) * 12 +
                  now.month -
                  startDate.month;

              int totalDuration = pattern.stages.fold(
                0,
                (s, e) => s + e.durationMonths,
              );

              if (totalDuration > 0) {
                int currentMonth = monthsDiff % totalDuration;
                if (monthsDiff < 0) currentMonth = 0; // Future

                HortRotationStage? currentStage;
                int accumulated = 0;
                for (final stage in pattern.stages) {
                  if (currentMonth < accumulated + stage.durationMonths) {
                    currentStage = stage;
                    break;
                  }
                  accumulated += stage.durationMonths;
                }

                if (currentStage != null &&
                    currentStage.suggestedSpeciesIds.isNotEmpty) {
                  final suggId = currentStage.suggestedSpeciesIds.first;

                  // Only draw ghost if NO plant is present
                  if (plantId == null) {
                    // Draw Ghost
                    if (plants.any((p) => p.id == suggId)) {
                      final suggPlant = plants.firstWhere(
                        (p) => p.id == suggId,
                      );
                      canvas.drawRect(
                        rect.deflate(4),
                        paint..color = suggPlant.color.withValues(alpha: 0.3),
                      );
                    }
                  }
                  // Warning removed as requested
                }
              }
            }
          }
        }

        // Border
        canvas.drawRect(rect, borderPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GardenGridPainter oldDelegate) {
    // Re-paint if grid changes, or dimensions, or plants list update
    if (oldDelegate.gridState != gridState) return true;
    if (oldDelegate.cellPixelSize != cellPixelSize) return true;
    if (oldDelegate.rows != rows || oldDelegate.cols != cols) return true;
    // Deep check depends on map identity. `_grid` is mutated or replaced?
    // In `_plantAt` we mutate `_grid` but we call `setState`.
    // If we passed the SAME map instance, `!=` checks reference equality.
    // `_grid` is final in state? No, it's `Map<String, String> _grid = {}`.
    // In `_plantAt`: `_grid['...'] = ...`. Reference is same.
    // So `oldDelegate.gridState != gridState` might contain same ref.
    // CustomPainter usually repaints if parameters change.
    // We should pass a *copy* or force repaint?
    // Or just return true?
    // Usually efficient to return true only if needed.
    // But since we mutate the map in place, CustomPainter might think it's same.
    // Workaround: Pass `gridState.length` or a version/hash?
    // Or just return true? Canvas drawing is fast enough.
    // Let's rely on Flutter passing a new instance of Painter on build,
    // BUT the properties inside might be same ref.
    // Actually, `shouldRepaint` compares the *old delegate*.
    // If we create a NEW delegate instance every build (which we do),
    // `oldDelegate` is the previous one.
    // If `gridState` is the SAME object, `!=` is false.
    // So we need to detect content change.
    // Simplest: Pass a `changeToken` or similar (e.g. `_grid.length` + `_grid.keys.last` hash?).
    // Or just always return true for now? It's cleaner than stale UI.
    return true;
  }
}
