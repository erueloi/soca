import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/garden_layout_config.dart';
import '../../domain/entities/planta_hort.dart';
import '../../domain/services/assistent_hort_service.dart';
import '../../data/repositories/hort_repository.dart';
import '../widgets/layout_creation_wizard.dart';

class GardenDesignerPage extends ConsumerStatefulWidget {
  const GardenDesignerPage({super.key});

  @override
  ConsumerState<GardenDesignerPage> createState() => _GardenDesignerPageState();
}

class _GardenDesignerPageState extends ConsumerState<GardenDesignerPage> {
  final _repository = HortRepository();
  GardenLayoutConfig? _config;
  String? _selectedSpeciesId;

  // Grid Data: "row_col" -> speciesId
  final Map<String, String> _grid = {};

  // Cell Size in Meters (Dynamic from Config)
  double get _cellSize => _config?.cellSize ?? 0.20;

  // Layout Calculations
  final List<double> _bedStarts = [];
  final List<double> _bedEnds = [];

  final TransformationController _transformationController =
      TransformationController();
  bool _initialCenterDone = false;

  bool _isPaintMode = false;
  final Set<String> _draggedCells = {};

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _calculateLayout() {
    if (_config == null) return;

    _bedStarts.clear();
    _bedEnds.clear();
    _initialCenterDone = false;

    final n = _config!.numberOfBeds;
    final wBed = _config!.bedWidth;
    final wPath = _config!.pathWidth;

    double currentX = 0;

    // Pattern: Path -> Bed -> Path -> Bed ... Path
    // Path 0
    currentX += wPath;

    for (int i = 0; i < n; i++) {
      _bedStarts.add(currentX); // Bed starts after path
      currentX += wBed;
      _bedEnds.add(currentX); // Bed ends

      // Next Path
      currentX += wPath;
    }
  }

  // Helper to determine if a column index corresponds to a Bed
  bool _isBed(int colIndex) {
    if (_config == null) return false;

    // Pixel/Meter position
    // We want to check the CENTER of the cell for more accurate hit-testing,
    // or the left edge. Let's use left edge for simplicity of grid alignment.
    double xPos = colIndex * _cellSize;

    for (int i = 0; i < _bedStarts.length; i++) {
      // Check if xPos is within Bed[i] range
      // Relaxing boundaries slightly for floating point comparisons
      if (xPos >= _bedStarts[i] - 0.01 && xPos < _bedEnds[i] - 0.01) {
        return true;
      }
    }
    return false; // It's a path
  }

  void _plantAt(int row, int col, List<PlantaHort> availablePlants) {
    if (!_isBed(col)) return;

    if (_selectedSpeciesId == null) {
      if (_grid.containsKey('${row}_$col')) {
        setState(() {
          _grid.remove('${row}_$col');
        });
      }
      return;
    }

    // Safe lookup
    final selected = availablePlants.firstWhere(
      (s) => s.id == _selectedSpeciesId,
      orElse: () => availablePlants.first,
    ); // Fallback usually shouldn't happen if logic correct?
    // Actually if ID not found (deleted?), we should probably handle gracefully.
    // For now check if exists.
    bool exists = availablePlants.any((s) => s.id == _selectedSpeciesId);
    if (!exists) return;

    // Check if already planted with same
    if (_grid['${row}_$col'] == _selectedSpeciesId) return;

    // Smart Planting: Check Compatibility Neighbor Check
    bool conflictFound = false;
    String conflictReason = '';

    final offsets = [
      const Offset(-1, 0),
      const Offset(1, 0),
      const Offset(0, -1),
      const Offset(0, 1),
    ];

    for (var o in offsets) {
      final key = '${row + o.dy.toInt()}_${col + o.dx.toInt()}';
      if (_grid.containsKey(key)) {
        final neighborId = _grid[key];
        final neighbor = availablePlants.firstWhere(
          (s) => s.id == neighborId,
          orElse: () => selected,
        );

        final result = AssistentHort.validarVeinatge(selected, neighbor);
        if (result.status == HortStatus.conflicte) {
          conflictFound = true;
          conflictReason = result.reason;
          break;
        }
      }
    }

    if (conflictFound) {
      if (!_isPaintMode) {
        // Only show snackbar in tap mode or throttle
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Alerta: $conflictReason'),
            backgroundColor: Colors.orange,
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }

    setState(() {
      _grid['${row}_$col'] = _selectedSpeciesId!;
    });
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

    // Adjust for padding
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

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return LayoutCreationWizard(
        onConfigCompleted: (config) {
          setState(() {
            _config = config;
            _calculateLayout();
          });
        },
      );
    }

    return StreamBuilder<List<PlantaHort>>(
      stream: _repository.getPlantsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final plants = snapshot.data!;
        if (plants.isEmpty) {
          // Handle empty library case (prompt to verify)
          return Center(
            child: Text('No hi ha plantes a la biblioteca. Afegeix-ne primer!'),
          );
        }

        // Calculate Grid Dimensions
        final int cols = (_config!.totalWidth / _cellSize).floor();
        final int rows = (_config!.totalLength / _cellSize).floor();

        // Visual Scaling
        final double pixelsPerMeter = 200.0;
        final double cellPixelSize = _cellSize * pixelsPerMeter;

        // Total Grid Size (Content Size) includes padding
        const double gridPadding = 64.0;
        final double contentWidth = (cols * cellPixelSize) + (gridPadding * 2);
        final double contentHeight = (rows * cellPixelSize) + (gridPadding * 2);

        return Column(
          children: [
            // Top Bar: Info & Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Layout: ${_config!.numberOfBeds} Bancals',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Grid: ${rows}x$cols cel·les (${(_cellSize * 100).toStringAsFixed(0)}cm)',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Paint Mode Toggle
                      IconButton(
                        icon: Icon(
                          _isPaintMode ? Icons.brush : Icons.pan_tool,
                          color: _isPaintMode ? Colors.green : Colors.grey,
                        ),
                        tooltip: _isPaintMode
                            ? 'Mode Pintar (Touch to Paint)'
                            : 'Mode Moure (Pan/Zoom)',
                        onPressed: () {
                          setState(() {
                            _isPaintMode = !_isPaintMode;
                            if (_isPaintMode && _selectedSpeciesId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selecciona una planta per pintar!',
                                  ),
                                ),
                              );
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_backup_restore),
                        tooltip: 'Reset Layout',
                        onPressed: () {
                          setState(() {
                            _config = null;
                            _grid.clear();
                            _isPaintMode = false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Toolbar (Species Selector)
            Container(
              height: 90,
              color: Colors.grey[50],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: plants.length,
                itemBuilder: (context, index) {
                  final s = plants[index];
                  final isSelected = s.id == _selectedSpeciesId;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedSpeciesId = isSelected ? null : s.id;
                      if (_selectedSpeciesId != null && !_isPaintMode) {
                        // Optional: Auto-enable paint mode?
                      }
                    }),
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green[100] : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              s.partComestible.icon,
                              size: 14,
                              color: Colors.white,
                            ), // Added icon
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.nomComu,
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // The Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Center the grid on first load
                  if (!_initialCenterDone) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_initialCenterDone && mounted) {
                        final double viewportW = constraints.maxWidth;
                        final double viewportH = constraints.maxHeight;

                        // Calculate offset to center content
                        final double dx = (viewportW - contentWidth) / 2;
                        final double dy = (viewportH - contentHeight) / 2;

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
                    boundaryMargin: const EdgeInsets.all(
                      2000,
                    ), // Large margin for panning
                    constrained: false, // Infinite canvas feeling
                    panEnabled: !_isPaintMode, // Disable pan when painting
                    scaleEnabled: !_isPaintMode,
                    child: Listener(
                      onPointerDown: (event) {
                        if (_isPaintMode) {
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
                        if (_isPaintMode) {
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
                        padding: const EdgeInsets.all(
                          gridPadding,
                        ), // Margin around grid
                        color: Colors.grey[200],
                        child: Container(
                          // Inner container is the actual grid
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 20),
                            ],
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                ),
                            itemCount: rows * cols,
                            itemBuilder: (context, index) {
                              final r = index ~/ cols;
                              final c = index % cols;

                              final bool isBed = _isBed(c);

                              // Visual Selection
                              Color cellColor;

                              if (!isBed) {
                                cellColor = Colors.brown[400]!; // Darker Path
                              } else {
                                // Is Bed
                                final speciesId = _grid['${r}_$c'];
                                if (speciesId != null) {
                                  // Look up in actual plants list
                                  final s = plants.firstWhere(
                                    (s) => s.id == speciesId,
                                    orElse: () => plants.first, // fallback
                                  );
                                  cellColor = s.color;
                                  // Maybe show small icon or dot?
                                } else {
                                  cellColor = const Color(0xFFFFFdd0); // Cream
                                }
                              }

                              return GestureDetector(
                                onTap: () => _onCellTap(r, c, plants),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    border: Border.all(
                                      color: Colors.black12.withValues(
                                        alpha: 0.05,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
