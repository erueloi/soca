import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/planta_hort.dart';
import '../../domain/entities/placed_plant.dart';
import '../../../trees/presentation/pages/location_picker_page.dart';

import '../../data/repositories/hort_repository.dart';
import 'hort_library_page.dart';
import '../../domain/entities/garden_layout_config.dart';

import '../../domain/entities/espai_hort.dart';
import '../../domain/entities/hort_rotation_pattern.dart';
import 'rotation_patterns_page.dart';

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

enum DesignerTool { plants, patterns, eraser }

class _GardenDesignerPageState extends ConsumerState<GardenDesignerPage> {
  final _repository = HortRepository();
  late EspaiHort _espai;
  String? _selectedSpeciesId;

  // New Coordinate System State
  List<PlacedPlant> _placedPlants = [];

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

  // Dirty flag to show save button
  bool _hasChanges = false;

  // Undo Stack
  final List<List<PlacedPlant>> _undoStack = [];

  void _pushUndo() {
    // Limit stack size? e.g. 20
    if (_undoStack.length >= 20) {
      _undoStack.removeAt(0);
    }
    // Deep copy of the list (PlacedPlant is immutable so shallow list copy is fine as long as we create a new list)
    _undoStack.add(List.from(_placedPlants));
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _placedPlants = _undoStack.removeLast();
      _hasChanges = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Acció desfeta'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _espai = widget.espai;
    _placedPlants = List.from(widget.espai.placedPlants);
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

  Future<void> _saveChanges() async {
    final updatedEspai = _espai.copyWith(placedPlants: _placedPlants);
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

  // --- Coordinate System Logic ---

  void _handleTapOnCanvas(
    Offset localPos,
    double extraPadding,
    double scale,
    List<PlantaHort> plants,
  ) {
    // 1. Convert to CM (Relative coordinates in the canvas space)
    // localPos includes padding? The detector is around the Painter?
    // If the detector wraps custom paint, localPos is relative to the paint.
    // We remove padding.
    double dx = localPos.dx - extraPadding;
    double dy = localPos.dy - extraPadding;

    // Convert pixels to cm
    // scale is pixels per meter (calculated in build as cellPixelSize / 0.2)
    // cm = (pixels / scale) * 100
    double xCm = (dx / scale) * 100;
    double yCm = (dy / scale) * 100;

    if (xCm < 0 || yCm < 0) return; // Margin area

    // Eraser Logic
    if (_selectedTool == DesignerTool.eraser) {
      final index = _placedPlants.lastIndexWhere((p) {
        final r = Rect.fromLTWH(p.x, p.y, p.width, p.height);
        // Inflate rect slightly for easier touch
        return r.inflate(5).contains(Offset(xCm, yCm));
      });
      if (index != -1) {
        _pushUndo();
        setState(() {
          _placedPlants.removeAt(index);
          _hasChanges = true;
        });
      }
      return;
    }

    // 2. Select Plant
    if (_selectedSpeciesId == null) return;

    final selected = plants.firstWhere(
      (p) => p.id == _selectedSpeciesId,
      orElse: () => plants.first,
    );

    // 3. Dimensions
    double pW = selected.distanciaLinies.toDouble();
    double pH = selected.distanciaPlantacio.toDouble();
    if (pW <= 0) pW = 30; // Safety
    if (pH <= 0) pH = 30;

    // 4. Snapping
    Offset snapped = _applySnapping(xCm, yCm, pW, pH);
    double finalX = snapped.dx;
    double finalY = snapped.dy;

    // 5. Centering Logic
    // If we snapped, we are at the top-left of the new plant.
    // If we didn't snap, 'snapped' returned the touch point.
    // The touch point should be the CENTER of the plant usually.
    // If _applySnapping returns the adjusted TOP-LEFT, we use it directly.
    // Let's refine _applySnapping to return the TOP-LEFT of the target position.

    // Check if we are in a valid bed?
    // Conversion to meters
    double xMeters = finalX / 100.0;

    // Bed Restriction (Snap to Bed Edge if in Path)
    // Pass width in meters
    double clampedMeters = _clampToBed(xMeters, pW / 100.0);
    if (clampedMeters != xMeters) {
      // We were in a path, update finalX
      finalX = clampedMeters * 100.0;

      // Show feedback? No, implicit snap is better.
    }

    // Final check just in case (e.g. margin error)
    if (!_isBedAt(finalX / 100.0)) {
      // Should not happen if _clampToBed works, unless logic differs.
      // Let's trust _clampToBed.
    }

    // 6. Check Collision (Overlap)
    final candidateRect = Rect.fromLTWH(finalX, finalY, pW, pH);
    if (_checkCollision(candidateRect)) {
      // Collision detected! Abort.
      if (!_isPaintMode) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🚫 Espai ocupat! No es pot plantar a sobre d\'una altra planta.',
            ),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
      return;
    }

    // Save State for Undo
    _pushUndo(); // <--- ADDED

    setState(() {
      _placedPlants.add(
        PlacedPlant.create(
          speciesId: selected.id,
          x: finalX,
          y: finalY,
          width: pW,
          height: pH,
        ),
      );
      _hasChanges = true;
    });
  }

  void _handleDragInCanvas(
    Offset localPos,
    double extraPadding,
    double scale,
    List<PlantaHort> plants,
  ) {
    // Eraser Logic Handled Here
    if (_selectedTool == DesignerTool.eraser) {
      // Find plant under finger

      // Convert to CM?
      // No, _placedPlants are in CM. We need to convert touch to CM.
      double xCm = ((localPos.dx - extraPadding) / scale) * 100;
      double yCm = ((localPos.dy - extraPadding) / scale) * 100;

      // Find intersecting plant
      final index = _placedPlants.indexWhere((p) {
        final pRect = Rect.fromLTWH(p.x, p.y, p.width, p.height);
        return pRect.contains(Offset(xCm, yCm));
      });

      if (index != -1) {
        _pushUndo();
        setState(() {
          _placedPlants.removeAt(index);
          _hasChanges = true;
        });
        // Haptic feedback?
      }
      return;
    }

    if (!_isPaintMode || _selectedSpeciesId == null) return;

    // We only paint if we moved enough from the last placed plant of this species/stroke
    // But `_placedPlants` is just a list.
    // Minimal distance logic: look at the last added plant.
    if (_placedPlants.isEmpty) {
      if (_selectedTool == DesignerTool.plants) {
        _handleTapOnCanvas(localPos, extraPadding, scale, plants);
      }
      return;
    }

    // Check distance to last plant
    // We want to simulate a "row".
    // Find the last plant added?
    // Or just check if the cursor is far enough from *any* plant?
    // "Pintar per arrossegament: ... segellant plantes automàticament respectant marges"

    double dx = localPos.dx - extraPadding;
    double dy = localPos.dy - extraPadding;
    double xCm = (dx / scale) * 100;
    double yCm = (dy / scale) * 100;

    final last = _placedPlants.last;
    // Distance check (using the last plant's own spacing)
    // Euclidean distance
    double distSq =
        (xCm - (last.x + last.width / 2)) * (xCm - (last.x + last.width / 2)) +
        (yCm - (last.y + last.height / 2)) * (yCm - (last.y + last.height / 2));

    // If dist > planting_distance, place.
    // Let's use the smaller dimension or the planting distance?
    // 'distanciaPlantacio' is usually "in row".

    final selected = plants.firstWhere((p) => p.id == _selectedSpeciesId);
    double threshold = selected.distanciaPlantacio.toDouble();
    if (distSq >= threshold * threshold) {
      _handleTapOnCanvas(localPos, extraPadding, scale, plants);
    }
  }

  Offset _applySnapping(double tapX, double tapY, double width, double height) {
    double bestX = tapX - (width / 2);
    double bestY = tapY - (height / 2);

    // 1. Grid Snapping (Background 10cm or 20cm grid)
    // Helps with "Coherence"
    double gridStep = _cellSize * 100; // e.g. 20cm
    double gridX = (bestX / gridStep).round() * gridStep;
    double gridY = (bestY / gridStep).round() * gridStep;

    if ((bestX - gridX).abs() < 5.0) bestX = gridX; // 5cm threshold
    if ((bestY - gridY).abs() < 5.0) bestY = gridY;

    // 2. Neighbor Snapping (Stronger than Grid)
    // "Magnet" effect if close to 1.5x planting frame

    double thresholdX = width * 1.5;
    double thresholdY = height * 1.5;

    // We want to find the BEST neighbor snap, so we track min distance
    double minDistX = double.infinity;
    double minDistY = double.infinity;

    for (final other in _placedPlants) {
      double ox = other.x;
      double oy = other.y;

      // --- X Alignment ---
      // Candidates: Same Col (ox), Next Col (ox + ow), Prev Col (ox - w)
      List<double> candidatesX = [ox, ox + other.width, ox - width];

      for (final cx in candidatesX) {
        double dist = (bestX - cx).abs();
        if (dist < thresholdX && dist < minDistX) {
          // Only snap if significantly better or close enough
          if (dist < 15.0) {
            // Hard snap distance
            bestX = cx;
            minDistX = dist;

            // Validate Collision for this candidate?
            // If the snap causes collision but original TAP didn't...
            // But we don't have TAP valid status here easily.
            // Better to verify AFTER all bestX found, or during selection.
            // For now, let's select best geometric match.
            // _checkCollision at the end will block if invalid.
            // Improvement: If 'bestX' collides, revert to tapX?
          }
        }
      }

      // --- Y Alignment ---
      // Candidates: Same Row (oy), Next Row (oy + oh), Prev Row (oy - h)
      List<double> candidatesY = [oy, oy + other.height, oy - height];

      for (final cy in candidatesY) {
        double dist = (bestY - cy).abs();
        if (dist < thresholdY && dist < minDistY) {
          if (dist < 15.0) {
            bestY = cy;
            minDistY = dist;
          }
        }
      }
    }

    // 3. Collision Fallback
    // If the best snapped position causes a collision, try to revert to original tap
    // to see if that fits. Priority: Valid Position > Aligned Position.
    final snappedRect = Rect.fromLTWH(bestX, bestY, width, height);
    if (_checkCollision(snappedRect)) {
      double rawX = tapX - (width / 2);
      double rawY = tapY - (height / 2);

      // Try reverting X (Keep Y snapped)
      bool validUnsnapX = !_checkCollision(
        Rect.fromLTWH(rawX, bestY, width, height),
      );

      // Try reverting Y (Keep X snapped)
      bool validUnsnapY = !_checkCollision(
        Rect.fromLTWH(bestX, rawY, width, height),
      );

      // Try reverting BOTH
      bool validUnsnapBoth = !_checkCollision(
        Rect.fromLTWH(rawX, rawY, width, height),
      );

      if (validUnsnapX && !validUnsnapY) {
        bestX = rawX; // Unsnap X
      } else if (!validUnsnapX && validUnsnapY) {
        bestY = rawY; // Unsnap Y
      } else if (validUnsnapBoth) {
        // Fallback to completely unsnapped
        bestX = rawX;
        bestY = rawY;
      }
    }

    return Offset(bestX, bestY);
  }

  double _clampToBed(double xMeters, double widthMeters) {
    if (_espai.layoutConfig == null) return xMeters;
    final config = _espai.layoutConfig!;

    double currentX = 0.0;

    // We want to find the BEST bed for this xMeters.
    // If inside a bed, use that bed.
    // If in path, use closest bed.

    int closestBedIndex = -1;
    double minDistToBe = double.infinity;

    // 1. Identify Target Bed
    for (int i = 0; i < config.numberOfBeds; i++) {
      double pathEnd = currentX + config.pathWidth;
      double bedStart = pathEnd;
      double bedEnd = bedStart + config.bedWidth;

      // Check containment (relaxed)
      if (xMeters >= bedStart && xMeters <= bedEnd) {
        closestBedIndex = i;
        break;
      }

      // Distance to bed
      double dist = 0;
      if (xMeters < bedStart) {
        dist = bedStart - xMeters;
      } else if (xMeters > bedEnd) {
        dist = xMeters - bedEnd;
      }

      if (dist < minDistToBe) {
        minDistToBe = dist;
        closestBedIndex = i;
      }

      currentX = bedEnd;
    }

    if (closestBedIndex == -1) return xMeters; // Should not happen

    // 2. Clamp to THAT Bed
    currentX = 0.0;
    // Fast forward to that bed
    for (int i = 0; i < closestBedIndex; i++) {
      currentX += config.pathWidth + config.bedWidth;
    }

    double bedStart = currentX + config.pathWidth;
    double bedEnd = bedStart + config.bedWidth;

    // STRICT CLAMP
    // x must be >= bedStart
    // x + width must be <= bedEnd -> x <= bedEnd - width

    double minX = bedStart;
    double maxX = bedEnd - widthMeters;

    if (maxX < minX) {
      // Plant is wider than bed!
      // Center it in the bed
      double bedCenter = bedStart + config.bedWidth / 2;
      return bedCenter - widthMeters / 2;
    }

    if (xMeters < minX) return minX;
    if (xMeters > maxX) return maxX;

    return xMeters;
  }

  bool _isBedAt(double xMeters) {
    if (_espai.layoutConfig == null) return true;
    final config = _espai.layoutConfig!;

    // Similar legacy logic
    double x = xMeters;
    double currentX = 0.0;
    for (int i = 0; i < config.numberOfBeds; i++) {
      // Path
      if (x >= currentX && x < currentX + config.pathWidth) return false;
      currentX += config.pathWidth;
      // Bed
      if (x >= currentX && x < currentX + config.bedWidth) return true;
      currentX += config.bedWidth;
    }
    return false;
  }

  bool _checkCollision(Rect candidate) {
    // Tweak: allow microscopic overlap?
    // Rect.overlaps is strict.
    // Let's shrink candidate slightly to ignore edge-touching.
    final shrunken = candidate.deflate(0.1); // 1mm margin

    for (final p in _placedPlants) {
      final existing = Rect.fromLTWH(p.x, p.y, p.width, p.height);
      // If overlaps
      if (shrunken.overlaps(existing)) {
        return true;
      }
    }
    return false;
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
          // Tool Selector (Plants vs Patterns vs Eraser)
          if (_isPaintMode || true)
            ToggleButtons(
              isSelected: [
                _selectedTool == DesignerTool.plants,
                _selectedTool == DesignerTool.patterns,
                _selectedTool == DesignerTool.eraser, // <--- Added Eraser
              ],
              onPressed: (index) {
                setState(() {
                  if (index == 0) _selectedTool = DesignerTool.plants;
                  if (index == 1) _selectedTool = DesignerTool.patterns;
                  if (index == 2) _selectedTool = DesignerTool.eraser;
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
                Tooltip(
                  message: 'Goma',
                  child: Icon(Icons.cleaning_services_outlined),
                ), // Eraser Icon
              ],
            ),
          const SizedBox(width: 8),

          // Undo (Keep visible)
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Desfer',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),

          // Save (Keep visible)
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

          // Overflow Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              switch (val) {
                case 'autofill':
                  _applyPatternsToGrid();
                  break;
                case 'clear':
                  _clearPlants();
                  break;
                case 'library':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HortLibraryPage()),
                  );
                  break;
                case 'settings':
                  _showSettingsDialog();
                  break;
                case 'delete_espai':
                  _confirmAndDeleteEspai(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_selectedTool == DesignerTool.patterns)
                const PopupMenuItem(
                  value: 'autofill',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome),
                    title: Text('Auto-Omplir Patrons'),
                  ),
                ),
              PopupMenuItem(
                value: 'clear',
                enabled: _placedPlants.isNotEmpty,
                child: const ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Netejar Tot'),
                ),
              ),
              const PopupMenuItem(
                value: 'library',
                child: ListTile(
                  leading: Icon(Icons.local_library),
                  title: Text("Biblioteca d'Hort"),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Configuració'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete_espai',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Eliminar Espai',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
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
          // Increase resolution: Base 200px (40px per 20cm cell)
          final double pixelsPerMeter = 200.0 / (_cellSize / 0.2);
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
                child: _buildToolPanel(plants),
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
                                    // Local Position relative to the Container (Canvas)
                                    final localPos = details.localPosition;

                                    if (_isPaintMode) {
                                      if (_selectedTool ==
                                              DesignerTool.plants ||
                                          _selectedTool ==
                                              DesignerTool.eraser) {
                                        _handleTapOnCanvas(
                                          localPos,
                                          gridPadding,
                                          pixelsPerMeter,
                                          plants,
                                        );
                                      } else if (_selectedTool ==
                                          DesignerTool.patterns) {
                                        // Pattern assignment: check if we tapped a bed
                                        double dx = localPos.dx - gridPadding;
                                        double xMeters = dx / pixelsPerMeter;
                                        _onBedTap(xMeters);
                                      }
                                    } else {
                                      // Move/View Mode -> Open Config
                                      double dx = localPos.dx - gridPadding;
                                      double xMeters = dx / pixelsPerMeter;
                                      _onBedTap(xMeters);
                                    }
                                  },
                                  onPanUpdate:
                                      (_isPaintMode &&
                                          (_selectedTool ==
                                                  DesignerTool.plants ||
                                              _selectedTool ==
                                                  DesignerTool.eraser))
                                      ? (details) {
                                          _handleDragInCanvas(
                                            details.localPosition,
                                            gridPadding,
                                            pixelsPerMeter,
                                            plants,
                                          );
                                        }
                                      : null,
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
                                          placedPlants: _placedPlants,
                                          plants: plants,
                                          isBedAt: _isBedAt,
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

  Widget _buildToolPanel(List<PlantaHort> plants) {
    switch (_selectedTool) {
      case DesignerTool.plants:
        return _buildPlantsList(plants);
      case DesignerTool.patterns:
        return _buildPatternsList();
      case DesignerTool.eraser:
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cleaning_services_outlined, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Toca o arrossega per esborrar plantes',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
    }
  }

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
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RotationPatternsPage(initialPatternId: p.id),
                    ),
                  );
                },
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
        // Find plant dimensions
        // Strategy:
        // 1. Try Exact ID Match
        // 2. Try Case-Insensitive Name Match
        PlantaHort? plant;
        try {
          plant = _currentPlantsList.firstWhere((p) => p.id == suggestedId);
        } catch (e) {
          // Not found by ID, try Common Name
          try {
            plant = _currentPlantsList.firstWhere(
              (p) => p.nomComu.toLowerCase() == suggestedId!.toLowerCase(),
            );
          } catch (e2) {
            // Still not found
            continue;
          }
        }

        // Fill Bed with Smart Tiling
        // Calculate Bed Bounds in CM
        final p = config.pathWidth;
        final b = config.bedWidth;
        final bedStartM = p + i * (b + p);

        // Start from top of bed (y=0) to bottom (totalLength)
        // Iterate Y by plantingDistance
        // Iterate X by linesDistance (centered in bed?)

        double bedWidthCm = b * 100;
        double bedLengthCm = config.totalLength * 100;
        double bedStartXCm = bedStartM * 100;

        double plantWCm = plant.distanciaLinies.toDouble();
        double plantHCm = plant.distanciaPlantacio.toDouble();

        // Safety check to avoid infinite loops
        if (plantWCm <= 0) plantWCm = 30;
        if (plantHCm <= 0) plantHCm = 30;

        // Calculate Grid Dimensions
        // Rows (Y) and Cols (X) based on spacing
        // Standard formula: floor(BedDim / Spacing)
        int numCols = (bedWidthCm / plantWCm).floor();
        int numRows = (bedLengthCm / plantHCm).floor();

        // Ensure at least 1 if it fits loosely (or strict?)
        // User asked for floor logic, so if width 113 and spacing 120, result 0.
        // But usually we can fit 1. Let's strictly follow floor for multi-row logic,
        // but if 0 and bed > 20cm, maybe force 1?
        // Let's stick to floor for strict standard density.
        if (numCols == 0 && bedWidthCm > plantWCm * 0.5) numCols = 1;
        if (numRows == 0 && bedLengthCm > plantHCm * 0.5) numRows = 1;

        // Calculate Centering Offsets
        double usedWidth = numCols * plantWCm;
        double usedHeight = numRows * plantHCm;

        double offsetX = (bedWidthCm - usedWidth) / 2;
        double offsetY = (bedLengthCm - usedHeight) / 2;

        // Fill Grid
        for (int r = 0; r < numRows; r++) {
          for (int c = 0; c < numCols; c++) {
            // Absolute placement
            double relX = offsetX + c * plantWCm;
            double relY = offsetY + r * plantHCm;

            double absX = bedStartXCm + relX;
            double absY = relY;

            // Add Plant
            _placedPlants.add(
              PlacedPlant.create(
                speciesId: suggestedId,
                x: absX,
                y: absY,
                width: plantWCm,
                height: plantHCm,
              ),
            );
            changesCount++;
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
          'Segur que vols eliminar totes les plantes del disseny?',
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
      _pushUndo(); // Support Undo
      setState(() {
        _placedPlants.clear();
        _hasChanges = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Disseny netejat.')));
      }
    }
  }

  void _onBedTap(double xMeters) {
    if (_espai.layoutConfig == null) return;
    final bedIndex = _getBedIndexFromX(xMeters);
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
    if (_placedPlants.isEmpty) return const SizedBox.shrink();

    double totalHarvestKg = 0;
    int totalPlants = _placedPlants.length;
    int maxDays = 0;

    // Group counts
    final counts = <String, int>{};
    for (var p in _placedPlants) {
      counts[p.speciesId] = (counts[p.speciesId] ?? 0) + 1;
    }

    for (var entry in counts.entries) {
      final plant = plants.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => plants.first,
      );
      if (!plants.any((p) => p.id == entry.key)) continue;

      // Area calculations
      // Real Area = sum(width * height) in cm2 => /10000 -> m2
      double plantAreaM2 = 0;
      for (var p in _placedPlants.where((p) => p.speciesId == entry.key)) {
        plantAreaM2 += (p.width * p.height) / 10000.0;
      }

      // Rendiment is kg/m2
      totalHarvestKg += plantAreaM2 * plant.rendiment;

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
            () => _showDetailedStats('harvest', plants),
          ),
          _buildStatItem(
            Icons.local_florist,
            'Plantes',
            '$totalPlants u.',
            () => _showDetailedStats('plants', plants),
          ),
          _buildStatItem(
            Icons.timer,
            'Cicle Màx',
            '$maxDays dies',
            () => _showDetailedStats('cycle', plants),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
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
        ),
      ),
    );
  }

  void _showDetailedStats(String type, List<PlantaHort> startPlants) {
    if (_espai.layoutConfig == null) return;

    // 1. Group Data by Bed
    final bedStats = <int, Map<String, dynamic>>{};
    // Structure: BedIndex -> { 'name': 'Bancal 1', 'items': [ ... ] }

    // Init Beds
    for (int i = 0; i < _espai.layoutConfig!.numberOfBeds; i++) {
      bedStats[i] = {
        'name': _espai.layoutConfig!.beds[i]?.name ?? 'Bancal ${i + 1}',
        'items': <String, dynamic>{}, // SpeciesId -> Value (Count/Kg/MaxDays)
      };
    }

    // Assign Plants to Beds
    for (var p in _placedPlants) {
      // Find Bed
      // p.x is center? NO, Left.
      // Bed check logic uses meters. p.x is cm.
      // Logic assumes plant is inside bed?
      // Use center of plant for more robust 'belonging' check
      double centerXCm = p.x + p.width / 2;
      double centerXM = centerXCm / 100.0;
      int? bedIndex = _getBedIndexFromX(centerXM);

      if (bedIndex != null) {
        final plantDef = startPlants.firstWhere(
          (sp) => sp.id == p.speciesId,
          orElse: () => startPlants.first,
        );

        final items = bedStats[bedIndex]!['items'] as Map<String, dynamic>;

        if (type == 'harvest') {
          // Add Kg
          double areaM2 = (p.width * p.height) / 10000.0;
          double kg = areaM2 * plantDef.rendiment;
          items[p.speciesId] = (items[p.speciesId] ?? 0.0) + kg;
        } else if (type == 'plants') {
          // Add Count
          items[p.speciesId] = (items[p.speciesId] ?? 0) + 1;
        } else if (type == 'cycle') {
          // Max Cycle
          int currentMax = items[p.speciesId] ?? 0;
          if (plantDef.diesEnCamp > currentMax) {
            items[p.speciesId] = plantDef.diesEnCamp;
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detall de ${type == 'harvest'
                    ? 'Collita'
                    : type == 'plants'
                    ? 'Plantes'
                    : 'Cicle'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: bedStats.length,
                  itemBuilder: (context, index) {
                    final bIndex = bedStats.keys.elementAt(index);
                    final data = bedStats[bIndex]!;
                    final items = data['items'] as Map<String, dynamic>;

                    if (items.isEmpty) return const SizedBox.shrink();

                    double totalBedValue = 0;
                    if (type == 'harvest' || type == 'plants') {
                      for (var v in items.values) {
                        totalBedValue += (v as num).toDouble();
                      }
                    } else {
                      // Max of bed
                      for (var v in items.values) {
                        if ((v as num) > totalBedValue) {
                          totalBedValue = (v).toDouble();
                        }
                      }
                    }

                    if (totalBedValue == 0) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  data['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  type == 'harvest'
                                      ? '${totalBedValue.toStringAsFixed(1)} kg'
                                      : type == 'plants'
                                      ? '${totalBedValue.toInt()} u.'
                                      : '${totalBedValue.toInt()} dies',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            ...items.entries.map((e) {
                              final plant = startPlants.firstWhere(
                                (sp) => sp.id == e.key,
                                orElse: () => startPlants.first,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          plant.partComestible.icon,
                                          size: 16,
                                          color: plant.color,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(plant.nomComu),
                                      ],
                                    ),
                                    Text(
                                      type == 'harvest'
                                          ? '${(e.value as double).toStringAsFixed(1)} kg'
                                          : type == 'plants'
                                          ? '${e.value} u.'
                                          : '${e.value} dies',
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

  int? _getBedIndexFromX(double xMeters) {
    final config = _espai.layoutConfig;
    if (config == null) return null;

    final p = config.pathWidth;
    final b = config.bedWidth;

    for (int i = 0; i < config.numberOfBeds; i++) {
      final start = p + i * (b + p);
      final end = start + b;
      if (xMeters >= start && xMeters < end) {
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
  final List<PlacedPlant> placedPlants;
  final List<PlantaHort> plants;
  final bool Function(double xMeters) isBedAt;
  final GardenLayoutConfig? layoutConfig;
  final List<HortRotationPattern> patterns;

  final double padding;

  GardenGridPainter({
    required this.rows,
    required this.cols,
    required this.cellPixelSize,
    required this.placedPlants,
    required this.plants,
    required this.isBedAt,
    this.layoutConfig,
    this.patterns = const [],
    this.padding = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(padding, padding);

    final paint = Paint()..style = PaintingStyle.fill;

    // Scale factor: pixels per meter = cellPixelSize / 0.2 (assuming grid is 20cm default step)
    // Wait, let's use the explicit conversion if we want robust 1cm precision.
    // The grid is drawn based on rows/cols usually.
    // Let's stick to drawing the background grid first.

    // Background Grid
    // Draw Bed backgrounds
    // We iterate strictly over pixels or use the layout config directly?
    // Using layout config directly is cleaner for the background.

    double ppm =
        cellPixelSize /
        0.2; // Pixels per Meter (approx 50px if cell is 10px and size is 0.2m?)
    // Actually cellPixelSize is passed in.

    // 1. Draw Layout (Beds/Paths)
    if (layoutConfig != null) {
      final totalHeightM = layoutConfig!.totalLength;

      // Draw total ground
      // canvas.drawRect(Rect.fromLTWH(0, 0, totalWidthM * ppm, totalHeightM * ppm), paint..color = const Color(0xFFEFEBE9));

      double currentX = 0.0;
      for (int i = 0; i < layoutConfig!.numberOfBeds; i++) {
        // Path
        double pathW = layoutConfig!.pathWidth;
        // Draw Path rect? (It's background color usually)
        // canvas.drawRect(Rect.fromLTWH(currentX * ppm, 0, pathW * ppm, totalHeightM * ppm), paint..color = Colors.grey[200]!);
        currentX += pathW;

        // Bed
        double bedW = layoutConfig!.bedWidth;
        canvas.drawRect(
          Rect.fromLTWH(currentX * ppm, 0, bedW * ppm, totalHeightM * ppm),
          paint..color = const Color(0xFF8D6E63), // Bed Color
        );

        // Highlight pattern if exists?
        // ...
        currentX += bedW;
      }
      // Final Path?
    } else {
      // No layout, just one big bed? or grid
      // paint..color = const Color(0xFF8D6E63);
      // canvas.drawRect(Rect.fromLTWH(0,0, cols*cellPixelSize, rows*cellPixelSize), paint);
    }

    // 2. Draw Grid Lines (Reference)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black12.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    // Vertical lines (every cellPixelSize = 20cm)
    for (int c = 0; c <= cols; c++) {
      double x = c * cellPixelSize;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cellPixelSize), linePaint);
    }
    // Horizontal lines
    for (int r = 0; r <= rows; r++) {
      double y = r * cellPixelSize;
      canvas.drawLine(Offset(0, y), Offset(cols * cellPixelSize, y), linePaint);
    }

    // 3. Draw Plants
    // Pre-calculate Icon Painters

    // Iterate Placed Plants
    for (final p in placedPlants) {
      // p.x, p.y, p.width, p.height are in CM.
      // Convert to Pixels.
      // ppm is pixels per meter.
      // x_px = (p.x / 100) * ppm

      double xPx = (p.x / 100) * ppm;
      double yPx = (p.y / 100) * ppm;
      double wPx = (p.width / 100) * ppm;
      double hPx = (p.height / 100) * ppm;

      final rect = Rect.fromLTWH(xPx, yPx, wPx, hPx);

      final plantDef = plants.firstWhere(
        (pl) => pl.id == p.speciesId,
        orElse: () => plants.first,
      );

      // 1. Area of Respect (Background)
      // Visual feedback: Faint fill + Outline
      final respectPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = plantDef.color.withValues(alpha: 0.2); // Faint background

      final respectBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = plantDef.color
            .withValues(alpha: 0.5) // Darker border
        ..strokeWidth = 1.0;

      // Draw dashed effect? Stick to solid for performance/simplicity first.
      canvas.drawRect(rect, respectPaint);
      canvas.drawRect(rect, respectBorderPaint);

      // 2. Planting Point (Center)
      // User request: Small tomato icon at the visual center.
      // We use the icon from the plant definition (partComestible).

      // Calculate icon size based on cell dimensions to prevent overflow
      double minDim = wPx < hPx ? wPx : hPx;
      double iconPixelSize = minDim * 0.6;

      // Clamp slightly to avoid tiny or massive icons if zoom is extreme
      if (iconPixelSize < 8) iconPixelSize = 8;
      // if (iconPixelSize > 50) iconPixelSize = 50;

      final textSpan = TextSpan(
        text: String.fromCharCode(plantDef.partComestible.icon.codePoint),
        style: TextStyle(
          fontSize: iconPixelSize,
          fontFamily: plantDef.partComestible.icon.fontFamily,
          color: plantDef.color.withValues(
            alpha: 1.0,
          ), // Solid color for the icon
          fontWeight: FontWeight.bold,
        ),
      );

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();

      // Center exactly
      final dx = xPx + (wPx - tp.width) / 2;
      final dy = yPx + (hPx - tp.height) / 2;

      // Draw a small white backing circle for contrast?
      // canvas.drawCircle(Offset(xPx + wPx/2, yPx + hPx/2), iconPixelSize * 0.6, Paint()..color=Colors.white);

      tp.paint(canvas, Offset(dx, dy));
    }

    // 4. Ghost / Guide Logic (Rotation Patterns & Bed Names)
    if (layoutConfig != null) {
      double currentX = 0.0;
      final year = DateTime.now().year;

      for (int i = 0; i < layoutConfig!.numberOfBeds; i++) {
        // Path
        currentX += layoutConfig!.pathWidth;

        // Bed
        double bedW = layoutConfig!.bedWidth;
        final bedData = layoutConfig!.beds[i];

        // Prepare TextSpan
        TextSpan? labelSpan;

        if (bedData != null &&
            bedData.rotationPatternId != null &&
            patterns.isNotEmpty) {
          // ... Pattern Logic ...
          final pattern = patterns.firstWhere(
            (p) => p.id == bedData.rotationPatternId,
            orElse: () => patterns.first,
          );

          // Determine current stage based on year
          final startDate = bedData.rotationStartDate ?? DateTime(year, 1, 1);
          int startYear = startDate.year;
          int elapsedYears = year - startYear;
          int stageIndex = elapsedYears % pattern.stages.length;
          if (stageIndex < 0) stageIndex = 0;

          final currentStage = pattern.stages[stageIndex];
          String stageText = currentStage.label;
          if (!stageText.toLowerCase().contains('any ') &&
              !stageText.toLowerCase().contains('year ')) {
            stageText = 'Any ${stageIndex + 1}: $stageText';
          }

          labelSpan = TextSpan(
            children: [
              TextSpan(
                text: '${pattern.name}\n',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '$stageText\n',
                style: TextStyle(color: Colors.black54, fontSize: 10),
              ),
              TextSpan(
                text: '(${currentStage.exigency.name})',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        } else {
          // Default Label
          labelSpan = TextSpan(
            text: 'Bancal ${i + 1}',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        // Draw Label centered in Bed (pushed down to avoid sticking out)
        double rectX = currentX * ppm;
        double rectW = bedW * ppm;

        final tp = TextPainter(
          text: labelSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        tp.layout(maxWidth: rectW + 80); // Allow slightly wider

        // Paint background tag ABOVE the bed
        final tagRect = Rect.fromCenter(
          center: Offset(rectX + rectW / 2, -35), // 35px above
          width: tp.width + 12,
          height: tp.height + 8,
        );

        // Use a lighter color style since it's outside
        final tagPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

        canvas.drawRRect(
          RRect.fromRectAndRadius(tagRect, const Radius.circular(6)),
          tagPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(tagRect, const Radius.circular(6)),
          borderPaint,
        );

        tp.paint(canvas, tagRect.topLeft + const Offset(6, 4));

        currentX += bedW;
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GardenGridPainter oldDelegate) {
    return true; // Simplified for now
  }
}
