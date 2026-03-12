import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/planta_hort.dart';
import '../../domain/entities/placed_plant.dart';
import '../../domain/entities/plantacio_historica.dart';
import '../../domain/services/assistent_hort_service.dart';
import '../../domain/services/garden_irrigation_service.dart';
import '../../../trees/presentation/pages/location_picker_page.dart';

import '../../data/repositories/hort_repository.dart';
import 'hort_library_page.dart';
import '../../domain/entities/garden_layout_config.dart';

import '../../domain/entities/espai_hort.dart';
import '../../domain/entities/hort_rotation_pattern.dart';
import 'rotation_patterns_page.dart';

class GardenDesignerPage extends ConsumerStatefulWidget {
  final EspaiHort espai;
  const GardenDesignerPage({super.key, required this.espai});

  @override
  ConsumerState<GardenDesignerPage> createState() => _GardenDesignerPageState();
}

enum DesignerTool { plants, patterns, eraser }

class _GardenDesignerPageState extends ConsumerState<GardenDesignerPage> {
  late EspaiHort _espai;
  String? _selectedSpeciesId;

  // New Coordinate System State
  List<PlacedPlant> _placedPlants = [];

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

  // Tooltip Overlay
  OverlayEntry? _tooltipOverlay;

  // Drag state: push undo only once per stroke
  bool _dragUndoPushed = false;
  bool _pointerDown = false; // Track if pointer is pressed for drag

  // Track last placed position during paint drag to space plants correctly
  Offset? _lastPaintPos;

  // Lightweight repaint notifier to avoid full setState during eraser drag
  final ValueNotifier<int> _canvasRepaint = ValueNotifier<int>(0);

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
  }

  @override
  void dispose() {
    _hidePlantTooltip();
    _transformationController.dispose();
    _canvasRepaint.dispose();
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

  /// Finds the PlacedPlant under the given canvas-local position.
  PlacedPlant? _findPlantAtPos(
    Offset localPos,
    double extraPadding,
    double scale,
  ) {
    double dx = localPos.dx - extraPadding;
    double dy = localPos.dy - extraPadding;
    double xCm = (dx / scale) * 100;
    double yCm = (dy / scale) * 100;

    for (int i = _placedPlants.length - 1; i >= 0; i--) {
      final p = _placedPlants[i];
      final r = Rect.fromLTWH(p.x, p.y, p.width, p.height);
      if (r.inflate(3).contains(Offset(xCm, yCm))) return p;
    }
    return null;
  }

  /// Shows a floating tooltip overlay near the given screen position.
  void _showPlantTooltip(PlacedPlant placed, Offset globalPos) {
    _hidePlantTooltip();

    PlantaHort? plant;
    try {
      plant = _currentPlantsList.firstWhere((p) => p.id == placed.speciesId);
    } catch (_) {
      return;
    }

    _tooltipOverlay = OverlayEntry(
      builder: (ctx) {
        // Position the tooltip above and to the right of the touch point
        final screenSize = MediaQuery.of(ctx).size;
        double left = globalPos.dx + 12;
        double top = globalPos.dy - 120;

        // Keep on screen
        if (left + 220 > screenSize.width) left = globalPos.dx - 232;
        if (top < 40) top = globalPos.dy + 20;

        return Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[900],
            child: Container(
              padding: const EdgeInsets.all(12),
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: plant!.color.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        plant.partComestible.icon,
                        color: plant.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          plant.nomComu,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (plant.nomCientific != null &&
                      plant.nomCientific!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      plant.nomCientific!,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const Divider(color: Colors.white24, height: 12),
                  _tooltipRow(
                    'Família',
                    plant.familiaBotanica.isNotEmpty
                        ? plant.familiaBotanica
                        : '—',
                  ),
                  _tooltipRow('Part', plant.partComestible.label),
                  _tooltipRow('Exigència', plant.exigenciaNutrients.label),
                  _tooltipRow(
                    'Marcs',
                    '${plant.distanciaLinies}×${plant.distanciaPlantacio} cm',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  Widget _tooltipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _hidePlantTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  Future<void> _handleTapOnCanvas(
    Offset localPos,
    double extraPadding,
    double scale,
    List<PlantaHort> plants,
  ) async {
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

    // 7. Check Rotation History Alerts
    final bedIdx = _getBedIndexFromX(finalX / 100.0);
    final rotationOk = await _checkRotationAlert(selected, bedIdx);
    if (!rotationOk) return; // User cancelled

    // Save State for Undo
    _pushUndo();

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

  /// Checks historic rotation and shows a warning dialog if conflicts exist.
  /// Returns true if the user wants to proceed, false to cancel.
  Future<bool> _checkRotationAlert(PlantaHort plant, int? bedIndex) async {
    if (bedIndex == null) return true; // Outside any bed, no check needed

    // Find last archived record for this bed
    final bedRecords =
        _espai.historic.where((h) => h.bedIndex == bedIndex).toList()
          ..sort((a, b) => b.dataFinalitzacio.compareTo(a.dataFinalitzacio));

    if (bedRecords.isEmpty) return true; // No history

    final lastRecord = bedRecords.first;
    if (lastRecord.mainCropId == null) return true;

    // Resolve last main crop plant
    PlantaHort? lastPlant;
    try {
      lastPlant = _currentPlantsList.firstWhere(
        (p) => p.id == lastRecord.mainCropId,
      );
    } catch (_) {
      return true; // Can't resolve, skip check
    }

    final alertes = AssistentHort.validarRotacio(
      novaPlanta: plant,
      ultimaPlanta: lastPlant,
      ultimRegistre: lastRecord,
    );

    if (alertes.isEmpty) return true;

    // In paint mode (rapid painting), show a brief snackbar instead of a dialog
    if (_isPaintMode) {
      final worst = alertes.any((a) => a.nivell == RotacioNivell.alt)
          ? RotacioNivell.alt
          : RotacioNivell.mitja;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                worst == RotacioNivell.alt ? Icons.warning : Icons.info_outline,
                color: worst == RotacioNivell.alt ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(alertes.first.titol)),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return true; // Allow in paint mode but warn
    }

    // Show dialog in normal mode
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              alertes.any((a) => a.nivell == RotacioNivell.alt)
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              color: alertes.any((a) => a.nivell == RotacioNivell.alt)
                  ? Colors.red
                  : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Alerta de Rotació')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: alertes.map((a) {
              final color = a.nivell == RotacioNivell.alt
                  ? Colors.red
                  : Colors.orange;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.titol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(a.missatge, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Plantar Igualment'),
          ),
        ],
      ),
    );

    return result ?? false;
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
        if (!_dragUndoPushed) {
          _pushUndo();
          _dragUndoPushed = true;
        }
        // DON'T call setState here — just mutate and repaint the canvas
        _placedPlants.removeAt(index);
        _hasChanges = true;
        _canvasRepaint.value++;
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

  /// Lightweight paint-by-drag: places plants at regular intervals
  /// along the drag path. Uses _canvasRepaint to avoid full widget rebuild.
  void _handlePaintDrag(
    Offset localPos,
    double extraPadding,
    double scale,
    List<PlantaHort> plants,
  ) {
    if (_selectedSpeciesId == null) return;

    final selected = plants.firstWhere(
      (p) => p.id == _selectedSpeciesId,
      orElse: () => plants.first,
    );

    double pW = selected.distanciaLinies.toDouble();
    double pH = selected.distanciaPlantacio.toDouble();
    if (pW <= 0) pW = 30;
    if (pH <= 0) pH = 30;

    double dx = localPos.dx - extraPadding;
    double dy = localPos.dy - extraPadding;
    double xCm = (dx / scale) * 100;
    double yCm = (dy / scale) * 100;

    if (xCm < 0 || yCm < 0) return;

    // Check spacing from last placed position
    if (_lastPaintPos != null) {
      double distSq =
          (xCm - _lastPaintPos!.dx) * (xCm - _lastPaintPos!.dx) +
          (yCm - _lastPaintPos!.dy) * (yCm - _lastPaintPos!.dy);
      // Must move at least one planting distance before placing next
      if (distSq < pH * pH * 0.8) return;
    }

    double plantX;
    double plantY;

    if (_lastPaintPos == null) {
      // First plant in stroke: place at cursor, snapped to bed
      plantX = xCm - (pW / 2);
      double xMeters = plantX / 100.0;
      double clampedMeters = _clampToBed(xMeters, pW / 100.0);
      plantX = clampedMeters * 100.0;
      plantY = yCm - (pH / 2);
    } else {
      // Subsequent plants: lock X to first plant, place Y exactly below last
      plantX = _lastPaintPos!.dx - (pW / 2);
      // Determine drag direction (down or up)
      double lastCenterY = _lastPaintPos!.dy;
      if (yCm >= lastCenterY) {
        // Dragging downward: place exactly one spacing below
        plantY = lastCenterY + (pH / 2);
      } else {
        // Dragging upward: place exactly one spacing above
        plantY = lastCenterY - pH - (pH / 2);
      }
    }

    // Clamp Y to bed length
    double bedLengthCm = _espai.length * 100;
    if (plantY < 0) plantY = 0;
    if (plantY + pH > bedLengthCm) plantY = bedLengthCm - pH;

    // Check collision
    final candidateRect = Rect.fromLTWH(plantX, plantY, pW, pH);
    if (_checkCollision(candidateRect)) return;

    // Push undo once per stroke
    if (!_dragUndoPushed) {
      _pushUndo();
      _dragUndoPushed = true;
    }

    // Place plant without setState — use repaint notifier
    _placedPlants.add(
      PlacedPlant.create(
        speciesId: selected.id,
        x: plantX,
        y: plantY,
        width: pW,
        height: pH,
      ),
    );
    _hasChanges = true;
    _lastPaintPos = Offset(plantX + pW / 2, plantY + pH / 2);
    _canvasRepaint.value++;
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
          if (dist < 15.0) {
            // Check this candidate wouldn't place us on top of existing plant
            final testRect = Rect.fromLTWH(cx, bestY, width, height);
            if (!testRect
                .deflate(2.0)
                .overlaps(Rect.fromLTWH(ox, oy, other.width, other.height))) {
              bestX = cx;
              minDistX = dist;
            }
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
            // Check this candidate wouldn't place us on top of existing plant
            final testRect = Rect.fromLTWH(bestX, cy, width, height);
            if (!testRect
                .deflate(2.0)
                .overlaps(Rect.fromLTWH(ox, oy, other.width, other.height))) {
              bestY = cy;
              minDistY = dist;
            }
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

    int closestBedIndex = -1;
    double minDistToBe = double.infinity;

    // 1. Identify Target Bed
    for (int i = 0; i < config.numberOfBeds; i++) {
      double bedStart = config.getBedStartX(i);
      double bedEnd = bedStart + config.getBedWidth(i);

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
    }

    if (closestBedIndex == -1) return xMeters; // Should not happen

    // 2. Clamp to THAT Bed
    double bedStart = config.getBedStartX(closestBedIndex);
    double bedEnd = bedStart + config.getBedWidth(closestBedIndex);

    // STRICT CLAMP
    // x must be >= bedStart
    // x + width must be <= bedEnd -> x <= bedEnd - width

    double minX = bedStart;
    double maxX = bedEnd - widthMeters;

    if (maxX < minX) {
      // Plant is wider than bed!
      // Center it in the bed
      double bedCenter = bedStart + config.getBedWidth(closestBedIndex) / 2;
      return bedCenter - widthMeters / 2;
    }

    if (xMeters < minX) return minX;
    if (xMeters > maxX) return maxX;

    return xMeters;
  }

  bool _isBedAt(double xMeters) {
    if (_espai.layoutConfig == null) return true;
    final config = _espai.layoutConfig!;

    for (int i = 0; i < config.numberOfBeds; i++) {
      double bedStart = config.getBedStartX(i);
      double bedEnd = bedStart + config.getBedWidth(i);
      if (xMeters >= bedStart && xMeters < bedEnd) return true;
    }
    return false;
  }

  bool _checkCollision(Rect candidate) {
    // Allow edge-touching and slight overlap (2cm tolerance)
    // This matches how the pattern tiler places plants directly adjacent.
    final shrunken = candidate.deflate(2.0); // 2cm margin

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
                case 'archive':
                  _archiveCycle();
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
              PopupMenuItem(
                value: 'archive',
                enabled: _placedPlants.isNotEmpty,
                child: const ListTile(
                  leading: Icon(
                    Icons.archive_outlined,
                    color: Colors.deepPurple,
                  ),
                  title: Text(
                    'Arxivar Bancal Sencer (Rotació completa)',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
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
        stream: ref.watch(hortRepositoryProvider).getPlantsStream(),
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
                                    _hidePlantTooltip();
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
                                        double dx = localPos.dx - gridPadding;
                                        double xMeters = dx / pixelsPerMeter;
                                        _onBedTap(xMeters);
                                      }
                                    } else {
                                      double dx = localPos.dx - gridPadding;
                                      double xMeters = dx / pixelsPerMeter;
                                      _onBedTap(xMeters);
                                    }
                                  },
                                  onLongPressStart: (details) {
                                    final placed = _findPlantAtPos(
                                      details.localPosition,
                                      gridPadding,
                                      pixelsPerMeter,
                                    );
                                    if (placed != null) {
                                      _showPlantTooltip(
                                        placed,
                                        details.globalPosition,
                                      );
                                    }
                                  },
                                  onLongPressEnd: (_) => _hidePlantTooltip(),
                                  child: Listener(
                                    onPointerDown:
                                        _isPaintMode &&
                                            (_selectedTool ==
                                                    DesignerTool.eraser ||
                                                _selectedTool ==
                                                    DesignerTool.plants)
                                        ? (event) {
                                            _pointerDown = true;
                                            _dragUndoPushed = false;
                                            _lastPaintPos = null;
                                            _hidePlantTooltip();
                                            if (_selectedTool ==
                                                DesignerTool.eraser) {
                                              _handleDragInCanvas(
                                                event.localPosition,
                                                gridPadding,
                                                pixelsPerMeter,
                                                plants,
                                              );
                                            } else if (_selectedTool ==
                                                    DesignerTool.plants &&
                                                _selectedSpeciesId != null) {
                                              _handlePaintDrag(
                                                event.localPosition,
                                                gridPadding,
                                                pixelsPerMeter,
                                                plants,
                                              );
                                            }
                                          }
                                        : null,
                                    onPointerMove:
                                        _isPaintMode &&
                                            (_selectedTool ==
                                                    DesignerTool.eraser ||
                                                _selectedTool ==
                                                    DesignerTool.plants)
                                        ? (event) {
                                            if (!_pointerDown) return;
                                            if (_selectedTool ==
                                                DesignerTool.eraser) {
                                              _handleDragInCanvas(
                                                event.localPosition,
                                                gridPadding,
                                                pixelsPerMeter,
                                                plants,
                                              );
                                            } else if (_selectedTool ==
                                                    DesignerTool.plants &&
                                                _selectedSpeciesId != null) {
                                              _handlePaintDrag(
                                                event.localPosition,
                                                gridPadding,
                                                pixelsPerMeter,
                                                plants,
                                              );
                                            }
                                          }
                                        : null,
                                    onPointerUp:
                                        _isPaintMode &&
                                            (_selectedTool ==
                                                    DesignerTool.eraser ||
                                                _selectedTool ==
                                                    DesignerTool.plants)
                                        ? (event) {
                                            _pointerDown = false;
                                            _lastPaintPos = null;
                                            if (_dragUndoPushed) {
                                              setState(() {});
                                            }
                                          }
                                        : null,
                                    onPointerCancel:
                                        _isPaintMode &&
                                            (_selectedTool ==
                                                    DesignerTool.eraser ||
                                                _selectedTool ==
                                                    DesignerTool.plants)
                                        ? (event) {
                                            _pointerDown = false;
                                            _lastPaintPos = null;
                                            if (_dragUndoPushed) {
                                              setState(() {});
                                            }
                                          }
                                        : null,
                                    child: MouseRegion(
                                      onHover: (event) {
                                        // Suppress tooltips during active eraser drag
                                        if (_isPaintMode &&
                                            _selectedTool ==
                                                DesignerTool.eraser &&
                                            _dragUndoPushed) {
                                          return;
                                        }
                                        final placed = _findPlantAtPos(
                                          event.localPosition,
                                          gridPadding,
                                          pixelsPerMeter,
                                        );
                                        if (placed != null) {
                                          _showPlantTooltip(
                                            placed,
                                            event.position,
                                          );
                                        } else {
                                          _hidePlantTooltip();
                                        }
                                      },
                                      onExit: (_) => _hidePlantTooltip(),
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
                                              historic: _espai.historic,
                                              getBedIndexFromX:
                                                  _getBedIndexFromX,
                                              repaintNotifier: _canvasRepaint,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
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

    final patterns = await ref.read(rotationPatternsStreamProvider.future);
    if (!mounted) return;
    final config = _espai.layoutConfig;
    if (config == null) return;

    int changesCount = 0;

    for (int i = 0; i < config.numberOfBeds; i++) {
      final bedData = config.beds[i];
      if (bedData == null || bedData.rotationPatternId == null) continue;

      final pattern = patterns.firstWhere(
        (p) => p.id == bedData.rotationPatternId,
        orElse: () => patterns.first,
      );
      if (bedData.rotationPatternId != pattern.id) continue;

      // Find current stage by date
      final start = bedData.rotationStartDate ?? DateTime.now();
      final now = DateTime.now();
      int monthsDiff = (now.year - start.year) * 12 + now.month - start.month;
      int totalDuration = pattern.stages.fold(
        0,
        (s, e) => s + e.durationMonths,
      );
      if (totalDuration == 0) continue;

      int currentMonth = monthsDiff % totalDuration;
      if (monthsDiff < 0) currentMonth = 0;

      HortRotationStage? currentStage;
      int accumulated = 0;
      for (final stage in pattern.stages) {
        if (currentMonth < accumulated + stage.durationMonths) {
          currentStage = stage;
          break;
        }
        accumulated += stage.durationMonths;
      }

      if (currentStage != null) {
        changesCount += _fillBedWithStage(i, currentStage);
      }
    }

    if (changesCount > 0) {
      setState(() => _hasChanges = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gremi aplicat: $changesCount plantes col·locades.'),
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

  /// Core polyculture tiling algorithm.
  /// Fills bed [bedIndex] with the crops from [stage], interleaving
  /// auxiliary crops on the edges and main crop in the centre.
  /// Returns the number of plants placed.
  int _fillBedWithStage(int bedIndex, HortRotationStage stage) {
    final config = _espai.layoutConfig;
    if (config == null) return 0;

    // Collect all species to plant: build a list of (speciesId, PlantaHort)
    final List<PlantaHort> cropSequence = [];

    // Resolve main crop
    PlantaHort? mainPlant;
    if (stage.mainCropId != null) {
      try {
        mainPlant = _currentPlantsList.firstWhere(
          (p) => p.id == stage.mainCropId,
        );
      } catch (_) {
        try {
          mainPlant = _currentPlantsList.firstWhere(
            (p) => p.nomComu.toLowerCase() == stage.mainCropId!.toLowerCase(),
          );
        } catch (_) {}
      }
    }

    // Resolve auxiliary crops
    final List<PlantaHort> auxPlants = [];
    for (final auxId in stage.auxiliaryCropIds) {
      try {
        auxPlants.add(_currentPlantsList.firstWhere((p) => p.id == auxId));
      } catch (_) {
        try {
          auxPlants.add(
            _currentPlantsList.firstWhere(
              (p) => p.nomComu.toLowerCase() == auxId.toLowerCase(),
            ),
          );
        } catch (_) {}
      }
    }

    if (mainPlant == null && auxPlants.isEmpty) return 0;

    // Bed geometry
    final bedStartM = config.getBedStartX(bedIndex);
    final bedWidthCm = config.getBedWidth(bedIndex) * 100;
    double bedLengthCm = config.totalLength * 100;
    double bedStartXCm = bedStartM * 100;

    // Determine the reference plant width to calculate number of columns
    double refWidth = mainPlant?.distanciaLinies.toDouble() ?? 30;
    if (refWidth <= 0) refWidth = 30;

    int numCols = (bedWidthCm / refWidth).floor();
    if (numCols == 0 && bedWidthCm > refWidth * 0.5) numCols = 1;
    if (numCols == 0) return 0;

    // Build column assignment: which plant goes in each column.
    // Strategy: auxiliary crops on the edge columns, main in the centre.
    for (int c = 0; c < numCols; c++) {
      if (numCols == 1) {
        // If only space for 1 line, prioritize the main crop
        cropSequence.add(mainPlant ?? auxPlants.first);
      } else if (numCols == 2) {
        // If space for 2 lines, try to mix [Aux, Main]
        if (c == 0 && auxPlants.isNotEmpty) {
          cropSequence.add(auxPlants.first);
        } else {
          cropSequence.add(mainPlant ?? auxPlants[c % auxPlants.length]);
        }
      } else {
        // 3 or more lines: Aux on edges, Main in the middle
        if (auxPlants.isNotEmpty && c == 0) {
          cropSequence.add(auxPlants[0]);
        } else if (auxPlants.length > 1 && c == numCols - 1) {
          cropSequence.add(auxPlants[1 % auxPlants.length]);
        } else if (auxPlants.isNotEmpty &&
            c == numCols - 1 &&
            mainPlant == null) {
          cropSequence.add(auxPlants[0]);
        } else if (mainPlant != null) {
          cropSequence.add(mainPlant);
        } else if (auxPlants.isNotEmpty) {
          cropSequence.add(auxPlants[c % auxPlants.length]);
        }
      }
    }

    if (cropSequence.isEmpty) return 0;

    // Now tile each column independently with its own plant dimensions
    int placedCount = 0;
    double usedWidth = numCols * refWidth;
    double offsetX = (bedWidthCm - usedWidth) / 2.0;

    for (int c = 0; c < cropSequence.length; c++) {
      final plant = cropSequence[c];
      double plantWCm = plant.distanciaLinies.toDouble();
      double plantHCm = plant.distanciaPlantacio.toDouble();
      if (plantWCm <= 0) plantWCm = 30;
      if (plantHCm <= 0) plantHCm = 30;

      int numRows = (bedLengthCm / plantHCm).floor();
      if (numRows == 0 && bedLengthCm > plantHCm * 0.5) numRows = 1;

      double usedHeight = numRows * plantHCm;
      double offsetY = (bedLengthCm - usedHeight) / 2.0;

      // Local Centering: if this specific crop is narrower than the column
      double columnLocalOffsetX = (refWidth - plantWCm) / 2.0;
      // In case plant is wider than ref, we might want to let it overflow or cap at 0
      if (columnLocalOffsetX < 0) columnLocalOffsetX = 0;

      for (int r = 0; r < numRows; r++) {
        double relX = offsetX + c * refWidth + columnLocalOffsetX;
        double relY = offsetY + r * plantHCm;

        // Y-axis clamp: don't exceed bed length
        if (relY + plantHCm > bedLengthCm) break;

        double absX = bedStartXCm + relX;

        _placedPlants.add(
          PlacedPlant.create(
            speciesId: plant.id,
            x: absX,
            y: relY,
            width: plantWCm,
            height: plantHCm,
          ),
        );
        placedCount++;
      }
    }

    return placedCount;
  }

  /// Shows a dialog to manually choose a Pattern + Stage and apply it to a bed.
  void _showApplyGremiDialog(int bedIndex) async {
    final patterns = await ref.read(rotationPatternsStreamProvider.future);
    if (!mounted || patterns.isEmpty) return;

    HortRotationPattern? selectedPattern = patterns.first;
    HortRotationStage? selectedStage = selectedPattern.stages.isNotEmpty
        ? selectedPattern.stages.first
        : null;

    final result = await showDialog<HortRotationStage>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Aplicar Gremi al Bancal'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona un Patró:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPattern?.id,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Patró',
                      ),
                      items: patterns
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedPattern = patterns.firstWhere(
                              (p) => p.id == val,
                            );
                            selectedStage = selectedPattern!.stages.isNotEmpty
                                ? selectedPattern!.stages.first
                                : null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Selecciona una Fase:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (selectedPattern != null &&
                        selectedPattern!.stages.isNotEmpty)
                      ...selectedPattern!.stages.map((stage) {
                        final isSelected =
                            selectedStage?.stageIndex == stage.stageIndex;
                        // Resolve names for display
                        String mainName = 'Cap';
                        if (stage.mainCropId != null) {
                          try {
                            mainName = _currentPlantsList
                                .firstWhere((p) => p.id == stage.mainCropId)
                                .nomComu;
                          } catch (_) {
                            mainName = stage.mainCropId!;
                          }
                        }
                        final auxCount = stage.auxiliaryCropIds.length;

                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedStage = stage),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stage.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Principal: $mainName · $auxCount auxiliar(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    if (selectedPattern == null ||
                        selectedPattern!.stages.isEmpty)
                      const Text(
                        'Aquest patró no té fases.',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel·lar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Aplicar Gremi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: selectedStage != null
                      ? () => Navigator.pop(ctx, selectedStage)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    _pushUndo();
    final count = _fillBedWithStage(bedIndex, result);

    if (count > 0) {
      setState(() => _hasChanges = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gremi aplicat: $count plantes al bancal ${bedIndex + 1}.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No s\'han pogut resoldre les plantes d\'aquesta fase.',
          ),
        ),
      );
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

  Future<void> _archiveCycle() async {
    if (_placedPlants.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalitzar Cicle?'),
        content: const Text(
          'Totes les plantes actuals passaran a l\'arxiu històric d\'aquest espai i el llenç quedarà buit per al proper cicle.\n\nAquesta acció no es pot desfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arxivar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Determine the earliest placedAt date from current plants
    DateTime earliestDate = DateTime.now();
    for (var p in _placedPlants) {
      if (p.placedAt != null && p.placedAt!.isBefore(earliestDate)) {
        earliestDate = p.placedAt!;
      }
    }

    // Group placed plants by bed index for richer history
    // Build a map: bedIndex -> list of speciesIds
    final Map<int, Set<String>> bedSpecies = {};
    final config = _espai.layoutConfig;

    for (var p in _placedPlants) {
      if (config != null) {
        double centerXCm = p.x + p.width / 2;
        double centerXM = centerXCm / 100.0;
        int? bedIdx = _getBedIndexFromX(centerXM);
        if (bedIdx != null) {
          bedSpecies.putIfAbsent(bedIdx, () => {});
          bedSpecies[bedIdx]!.add(p.speciesId);
        }
      }
    }

    // Create history entries: one per bed that had plants
    final List<PlantacioHistorica> newEntries = [];
    if (bedSpecies.isNotEmpty) {
      for (var entry in bedSpecies.entries) {
        final speciesList = entry.value.toList();
        newEntries.add(
          PlantacioHistorica.create(
            mainCropId: speciesList.isNotEmpty ? speciesList.first : null,
            auxiliaryCropIds: speciesList.length > 1
                ? speciesList.sublist(1)
                : [],
            dataPlantacio: earliestDate,
            bedIndex: entry.key,
          ),
        );
      }
    } else {
      // No layout config – archive all as a single entry
      final allSpecies = _placedPlants.map((p) => p.speciesId).toSet().toList();
      newEntries.add(
        PlantacioHistorica.create(
          mainCropId: allSpecies.isNotEmpty ? allSpecies.first : null,
          auxiliaryCropIds: allSpecies.length > 1 ? allSpecies.sublist(1) : [],
          dataPlantacio: earliestDate,
        ),
      );
    }

    // Merge with existing historic
    final updatedHistoric = List<PlantacioHistorica>.from(_espai.historic)
      ..addAll(newEntries);

    setState(() {
      _espai = _espai.copyWith(placedPlants: [], historic: updatedHistoric);
      _placedPlants.clear();
      _hasChanges = true;
    });

    await _saveChanges();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cicle arxivat amb ${newEntries.length} registre(s).'),
        ),
      );
    }
  }

  Future<void> _archiveSpeciesInBed(int bedIndex, String speciesId) async {
    String plantName = speciesId;
    try {
      plantName = _currentPlantsList
          .firstWhere((p) => p.id == speciesId)
          .nomComu;
    } catch (_) {}

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arxivar línia?'),
        content: Text(
          'Estàs segur que vols arxivar i finalitzar el cicle de $plantName d\'aquest bancal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arxivar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Find all plants of this species in this bed
    final List<PlacedPlant> remainingPlants = [];
    final List<PlacedPlant> archivedPlants = [];
    DateTime earliestDate = DateTime.now();

    for (var p in _placedPlants) {
      double centerXCm = p.x + p.width / 2;
      double centerXM = centerXCm / 100.0;
      int? currentBedIdx = _getBedIndexFromX(centerXM);

      if (currentBedIdx == bedIndex && p.speciesId == speciesId) {
        archivedPlants.add(p);
        if (p.placedAt != null && p.placedAt!.isBefore(earliestDate)) {
          earliestDate = p.placedAt!;
        }
      } else {
        remainingPlants.add(p);
      }
    }

    if (archivedPlants.isEmpty) return;

    _pushUndo();

    // Create history entry
    final newEntry = PlantacioHistorica.create(
      mainCropId: speciesId,
      auxiliaryCropIds: [],
      dataPlantacio: earliestDate,
      bedIndex: bedIndex,
    );

    // Update history
    final updatedHistoric = List<PlantacioHistorica>.from(_espai.historic)
      ..add(newEntry);

    setState(() {
      _espai = _espai.copyWith(
        placedPlants: remainingPlants,
        historic: updatedHistoric,
      );
      _placedPlants = List.from(remainingPlants);
      _hasChanges = true;
    });

    await _saveChanges();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Línia arxivada correctament.')),
      );
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
    if (_placedPlants.isEmpty || plants.isEmpty) return const SizedBox.shrink();

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
      double centerXCm = p.x + p.width / 2;
      double centerXM = centerXCm / 100.0;
      int? bedIndex = _getBedIndexFromX(centerXM);

      if (bedIndex != null) {
        final plantDef = startPlants.firstWhere(
          (sp) => sp.id == p.speciesId,
          orElse: () => startPlants.first,
        );

        final items = bedStats[bedIndex]!['items'] as Map<String, dynamic>;

        // Create a normalized date string (YYYY-MM-DD) for grouping or "planned"
        final dateStr = p.placedAt != null
            ? '${p.placedAt!.year}-${p.placedAt!.month.toString().padLeft(2, '0')}-${p.placedAt!.day.toString().padLeft(2, '0')}'
            : 'planned';
        final groupKey = '${p.speciesId}_$dateStr';

        if (!items.containsKey(groupKey)) {
          items[groupKey] = {
            'speciesId': p.speciesId,
            'placedAt': p.placedAt != null
                ? DateTime(p.placedAt!.year, p.placedAt!.month, p.placedAt!.day)
                : null,
            'value': 0.0, // used for kg or count or maxDays
          };
        }

        final groupData = items[groupKey] as Map<String, dynamic>;

        if (type == 'harvest') {
          // Add Kg
          double areaM2 = (p.width * p.height) / 10000.0;
          double kg = areaM2 * plantDef.rendiment;
          groupData['value'] = (groupData['value'] as double) + kg;
        } else if (type == 'plants') {
          // Add Count
          groupData['value'] = (groupData['value'] as double) + 1.0;
        } else if (type == 'cycle') {
          // Max Cycle
          double currentMax = groupData['value'] as double;
          if (plantDef.diesEnCamp > currentMax) {
            groupData['value'] = plantDef.diesEnCamp.toDouble();
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
                      for (var groupData in items.values) {
                        totalBedValue +=
                            (groupData as Map<String, dynamic>)['value']
                                as double;
                      }
                    } else {
                      // Max of bed
                      for (var groupData in items.values) {
                        final val =
                            (groupData as Map<String, dynamic>)['value']
                                as double;
                        if (val > totalBedValue) {
                          totalBedValue = val;
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
                              final groupData = e.value as Map<String, dynamic>;
                              final speciesId =
                                  groupData['speciesId'] as String;
                              final placedAt =
                                  groupData['placedAt'] as DateTime?;

                              final val = groupData['value'] as double;

                              final plant = startPlants.firstWhere(
                                (sp) => sp.id == speciesId,
                                orElse: () => startPlants.first,
                              );

                              // Calculate harvest progress
                              final now = DateTime.now();
                              final cycleDays = plant.diesEnCamp;
                              double progress = 0.0;
                              DateTime? estimatedHarvest;

                              if (placedAt != null && cycleDays > 0) {
                                final daysSincePlaced = now
                                    .difference(placedAt)
                                    .inDays;
                                progress = daysSincePlaced / cycleDays;
                                if (progress < 0) progress = 0;
                                if (progress > 1) progress = 1;
                                estimatedHarvest = placedAt.add(
                                  Duration(days: cycleDays),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                plant.partComestible.icon,
                                                size: 16,
                                                color: plant.color,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      plant.nomComu,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          placedAt != null
                                                              ? 'Sembrats: ${placedAt.day}/${placedAt.month}/${placedAt.year}'
                                                              : 'Estat: Planificat',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        InkWell(
                                                          onTap: () {
                                                            Navigator.pop(
                                                              context,
                                                            ); // Close stats
                                                            _editGroupDate(
                                                              bIndex,
                                                              speciesId,
                                                              placedAt,
                                                            );
                                                          },
                                                          child: const Icon(
                                                            Icons.edit_calendar,
                                                            size: 14,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                        if (placedAt !=
                                                            null) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          InkWell(
                                                            onTap: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              _clearGroupDate(
                                                                bIndex,
                                                                speciesId,
                                                                placedAt,
                                                              );
                                                            },
                                                            child: const Icon(
                                                              Icons
                                                                  .layers_clear,
                                                              size: 14,
                                                              color:
                                                                  Colors.orange,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (type == 'plants') ...[
                                          Text('${val.toInt()} u.'),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.archive,
                                              size: 20,
                                              color: Colors.deepPurple,
                                            ),
                                            tooltip:
                                                'Arxivar només aquesta planta',
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _archiveSpeciesInBed(
                                                bIndex,
                                                speciesId,
                                              );
                                            },
                                          ),
                                        ] else if (type == 'harvest') ...[
                                          Text('${val.toStringAsFixed(1)} kg'),
                                        ] else ...[
                                          Text('${val.toInt()} dies'),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (type == 'plants' &&
                                      cycleDays > 0 &&
                                      placedAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 24,
                                        bottom: 8,
                                        right: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: progress,
                                                child: Container(
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: progress >= 1.0
                                                        ? Colors.green
                                                        : Colors.lightGreen,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            progress >= 1.0
                                                ? '🟢 Llest per collir'
                                                : '⌛ Collita est: ${estimatedHarvest!.day}/${estimatedHarvest.month}/${estimatedHarvest.year}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: progress >= 1.0
                                                  ? Colors.green[700]
                                                  : Colors.black54,
                                              fontWeight: progress >= 1.0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
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

  Future<void> _editGroupDate(
    int bedIndex,
    String speciesId,
    DateTime? oldDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: oldDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      helpText: 'Selecciona la data de sembra/trasplantament',
      confirmText: 'GUARDAR',
      cancelText: 'CANCEL·LAR',
    );

    if (picked != null && picked != oldDate) {
      _pushUndo();
      setState(() {
        for (int i = 0; i < _placedPlants.length; i++) {
          final p = _placedPlants[i];
          if (p.speciesId == speciesId) {
            double centerXCm = p.x + p.width / 2;
            double centerXM = centerXCm / 100.0;
            int? currentBedIdx = _getBedIndexFromX(centerXM);

            if (currentBedIdx == bedIndex) {
              // Check if original date matches (normalized) or both are null
              bool matches = false;
              if (oldDate == null && p.placedAt == null) {
                matches = true;
              } else if (oldDate != null && p.placedAt != null) {
                if (p.placedAt!.year == oldDate.year &&
                    p.placedAt!.month == oldDate.month &&
                    p.placedAt!.day == oldDate.day) {
                  matches = true;
                }
              }

              if (matches) {
                // Keep time of day if it existed, otherwise set default time (e.g., noon)
                int hour = p.placedAt?.hour ?? 12;
                int minute = p.placedAt?.minute ?? 0;

                final newDate = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  hour,
                  minute,
                );
                _placedPlants[i] = p.copyWith(placedAt: newDate);
                _hasChanges = true;
              }
            }
          }
        }
        _espai = _espai.copyWith(placedPlants: _placedPlants);
      });
      await _saveChanges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data de sembra actualitzada correctament.'),
          ),
        );
      }
    }
  }

  Future<void> _clearGroupDate(
    int bedIndex,
    String speciesId,
    DateTime oldDate,
  ) async {
    _pushUndo();
    setState(() {
      for (int i = 0; i < _placedPlants.length; i++) {
        final p = _placedPlants[i];
        if (p.speciesId == speciesId && p.placedAt != null) {
          double centerXCm = p.x + p.width / 2;
          double centerXM = centerXCm / 100.0;
          int? currentBedIdx = _getBedIndexFromX(centerXM);

          if (currentBedIdx == bedIndex) {
            if (p.placedAt!.year == oldDate.year &&
                p.placedAt!.month == oldDate.month &&
                p.placedAt!.day == oldDate.day) {
              _placedPlants[i] = p.copyWith(clearDate: true);
              _hasChanges = true;
            }
          }
        }
      }
      _espai = _espai.copyWith(placedPlants: _placedPlants);
    });
    await _saveChanges();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('S\'ha tornat a l\'estat "Planificat".')),
      );
    }
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

    for (int i = 0; i < config.numberOfBeds; i++) {
      final start = config.getBedStartX(i);
      final end = start + config.getBedWidth(i);
      if (xMeters >= start && xMeters < end) {
        return i;
      }
    }
    return null;
  }

  void _showBedConfigDialog(int bedIndex) {
    // Current Data
    final bedData = _espai.layoutConfig!.beds[bedIndex];

    // Filter historic for this bed
    final bedHistoric =
        _espai.historic
            .where((h) => h.bedIndex == bedIndex || h.bedIndex == null)
            .toList()
          ..sort((a, b) => b.dataFinalitzacio.compareTo(a.dataFinalitzacio));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String? selectedPattern = bedData?.rotationPatternId;
        DateTime startDate = bedData?.rotationStartDate ?? DateTime.now();
        double widthOverride =
            bedData?.widthOverride ?? _espai.layoutConfig!.bedWidth;
        double cabalOverride = bedData?.cabalSistemaLitersHora ?? 10.0;
        IrrigationMethod irrigationMethod =
            bedData?.irrigationMethod ?? IrrigationMethod.manual;
        int tabIndex = 0;

        return StatefulBuilder(
          builder: (context, setState) {
            final irrigationService = ref.read(gardenIrrigationServiceProvider);
            final currentBedData =
                _espai.layoutConfig?.beds[bedIndex] ?? bedData;
            final bedAreaSqm =
                _espai.layoutConfig!.getBedWidth(bedIndex) *
                _espai.layoutConfig!.totalLength;
            final bedName = currentBedData?.name ?? 'B\${bedIndex + 1}';
            final bedDataSafe = currentBedData ?? BedData(name: bedName);
            final wateringReq = irrigationService.getWateringRecommendation(
              bedDataSafe,
              bedAreaSqm,
            );

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bancal ${bedIndex + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tab bar: Configuració | Històric
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => tabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color:
                                      tabIndex == 0
                                          ? Colors.deepPurple
                                          : Colors.grey.shade300,
                                  width: tabIndex == 0 ? 3 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'Configuració',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight:
                                    tabIndex == 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    tabIndex == 0
                                        ? Colors.deepPurple
                                        : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => tabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color:
                                      tabIndex == 1
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                  width: tabIndex == 1 ? 3 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'Reg',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight:
                                    tabIndex == 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    tabIndex == 1
                                        ? Colors.blue
                                        : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => tabIndex = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color:
                                      tabIndex == 2
                                          ? Colors.deepPurple
                                          : Colors.grey.shade300,
                                  width: tabIndex == 2 ? 3 : 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Històric',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight:
                                        tabIndex == 2
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        tabIndex == 2
                                            ? Colors.deepPurple
                                            : Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                if (bedHistoric.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.deepPurple,
                                    child: Text(
                                      '${bedHistoric.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tab content
                  Expanded(
                    child: switch (tabIndex) {
                      0 => SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                  const Text('Assignar Patró de Rotació:'),
                                  const SizedBox(height: 8),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final patternsAsync = ref.watch(
                                        rotationPatternsStreamProvider,
                                      );
                                      return patternsAsync.when(
                                        data:
                                            (patterns) =>
                                                DropdownButtonFormField<String>(
                                                  initialValue: selectedPattern,
                                                  decoration:
                                                      const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        labelText:
                                                            'Selecciona un Patró',
                                                      ),
                                                  items: [
                                                    const DropdownMenuItem(
                                                      value: null,
                                                      child: Text(
                                                        'Cap (Manual)',
                                                      ),
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
                                        loading:
                                            () =>
                                                const LinearProgressIndicator(),
                                        error:
                                            (e, s) => Text(
                                              'Error loading patterns: $e',
                                            ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Data d\'Inici de la Rotació:'),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${startDate.day}/${startDate.month}/${startDate.year}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Amplada d\'aquest bancal:'),
                                      Text(
                                        '${(widthOverride * 100).toInt()} cm',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: widthOverride,
                                    min: 0.2, // 20cm
                                    max: 2.0, // 200cm
                                    divisions: 36, // steps of 5cm
                                    label:
                                        '${(widthOverride * 100).toInt()} cm',
                                    activeColor: Colors.deepPurple,
                                    onChanged: (val) {
                                      setState(() {
                                        widthOverride = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final newBedData = (bedData ??
                                                BedData())
                                            .copyWith(
                                              rotationPatternId:
                                                  selectedPattern,
                                              rotationStartDate: startDate,
                                              widthOverride:
                                                  widthOverride ==
                                                          _espai.layoutConfig!
                                                              .bedWidth
                                                      ? null
                                                      : widthOverride,
                                              irrigationMethod:
                                                  irrigationMethod,
                                              cabalSistemaLitersHora:
                                                  cabalOverride,
                                            );

                                        final newBeds = Map<int, BedData>.from(
                                          _espai.layoutConfig!.beds,
                                        );
                                        newBeds[bedIndex] = newBedData;

                                        final newConfig = GardenLayoutConfig(
                                          totalWidth:
                                              _espai.layoutConfig!.totalWidth,
                                          totalLength:
                                              _espai.layoutConfig!.totalLength,
                                          numberOfBeds:
                                              _espai.layoutConfig!.numberOfBeds,
                                          bedWidth:
                                              _espai.layoutConfig!.bedWidth,
                                          pathWidth:
                                              _espai.layoutConfig!.pathWidth,
                                          cellSize:
                                              _espai.layoutConfig!.cellSize,
                                          beds: newBeds,
                                        );

                                        _saveBedData(newConfig);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text(
                                        'Guardar Configuració Bancal',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.auto_awesome),
                                      label: const Text(
                                        'Aplicar Gremi / Patró',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showApplyGremiDialog(bedIndex);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      1 => _buildBedIrrigationTab(
                          bedIndex,
                          bedDataSafe,
                          wateringReq,
                          irrigationMethod,
                          cabalOverride,
                          (method) => setState(() => irrigationMethod = method),
                          (cabal) => setState(() => cabalOverride = cabal),
                          (bedInfo) async {
                            final newBeds = Map<int, BedData>.from(_espai.layoutConfig!.beds);
                            newBeds[bedIndex] = bedInfo;
                            final newConfig = _espai.layoutConfig!.copyWith(beds: newBeds);
                            final tempEspai = _espai.copyWith(layoutConfig: newConfig);
                            final irrigationService = ref.read(gardenIrrigationServiceProvider);
                            final updatedEspai = await irrigationService.syncSoilBalance(tempEspai, forceSync: true);
                            setState(() {
                              _espai = updatedEspai;
                            });
                            await _saveChanges();
                          },
                        ),
                      2 => _buildBedHistoricTab(bedHistoric),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBedHistoricTab(List<PlantacioHistorica> bedHistoric) {
    if (bedHistoric.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Cap registre històric encara.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Arxiva un cicle per veure-ho aquí.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<PlantaHort>>(
      stream: ref.read(hortRepositoryProvider).getPlantsStream(),
      builder: (context, snapshot) {
        final plants = snapshot.data ?? [];
        return ListView.builder(
          itemCount: bedHistoric.length,
          itemBuilder: (context, index) {
            final h = bedHistoric[index];

            String mainName = 'Desconegut';
            if (h.mainCropId != null && plants.isNotEmpty) {
              try {
                mainName = plants
                    .firstWhere((p) => p.id == h.mainCropId)
                    .nomComu;
              } catch (_) {
                mainName = h.mainCropId!;
              }
            }

            final auxNames = h.auxiliaryCropIds
                .map((id) {
                  try {
                    return plants.firstWhere((p) => p.id == id).nomComu;
                  } catch (_) {
                    return id;
                  }
                })
                .join(', ');

            final startStr =
                '${h.dataPlantacio.day}/${h.dataPlantacio.month}/${h.dataPlantacio.year}';
            final endStr =
                '${h.dataFinalitzacio.day}/${h.dataFinalitzacio.month}/${h.dataFinalitzacio.year}';
            final durationDays = h.dataFinalitzacio
                .difference(h.dataPlantacio)
                .inDays;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  mainName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (auxNames.isNotEmpty)
                      Text(
                        'Auxiliars: $auxNames',
                        style: const TextStyle(fontSize: 12),
                      ),
                    Text(
                      '$startStr → $endStr ($durationDays dies)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                isThreeLine: auxNames.isNotEmpty,
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
  Widget _buildBedIrrigationTab(
      int bedIndex,
      BedData bedData,
      WateringRequirement wateringReq,
      IrrigationMethod irrigationMethod,
      double cabalOverride,
      Function(IrrigationMethod) onIrrigationMethodChanged,
      Function(double) onCabalChanged,
      Function(BedData) onSaveConfig) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Irrigation Banner
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: switch (wateringReq.status) {
                WateringStatus.satiated => Colors.green.withValues(alpha: 0.1),
                WateringStatus.forecast => Colors.orange.withValues(alpha: 0.1),
                WateringStatus.critical => Colors.blue.withValues(alpha: 0.1),
              },
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: switch (wateringReq.status) {
                  WateringStatus.satiated => Colors.green.withValues(alpha: 0.3),
                  WateringStatus.forecast => Colors.orange.withValues(alpha: 0.3),
                  WateringStatus.critical => Colors.blue.withValues(alpha: 0.3),
                },
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    wateringReq.actionText,
                    style: TextStyle(
                      color: switch (wateringReq.status) {
                        WateringStatus.satiated => Colors.green.shade900,
                        WateringStatus.forecast => Colors.orange.shade900,
                        WateringStatus.critical => Colors.blue.shade900,
                      },
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (wateringReq.needsWater)
                  TextButton(
                    onPressed: () {
                      final newEvents = List<WateringEvent>.from(bedData.wateringEvents ?? []);
                      newEvents.add(WateringEvent(
                        date: DateTime.now(),
                        litersApplied: wateringReq.litersNeeded,
                      ));
                      onSaveConfig(bedData.copyWith(wateringEvents: newEvents));
                    },
                    child: Text(wateringReq.buttonText),
                  ),
              ],
            ),
          ),

          // Irrigation System Settings Card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sistema de Reg',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mètode de Reg:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  SegmentedButton<IrrigationMethod>(
                    segments: const [
                      ButtonSegment(
                        value: IrrigationMethod.manual,
                        label: Text('Manual'),
                        icon: Icon(Icons.water_drop_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: IrrigationMethod.drip,
                        label: Text('Gota a Gota'),
                        icon: Icon(Icons.water, size: 18),
                      ),
                    ],
                    selected: {irrigationMethod},
                    onSelectionChanged: (Set<IrrigationMethod> newSelection) {
                      onIrrigationMethodChanged(newSelection.first);
                    },
                  ),
                  if (irrigationMethod == IrrigationMethod.drip) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cabal reg m² (L/h):'),
                        Text(
                          '${cabalOverride.toStringAsFixed(1)} L/h',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: cabalOverride,
                      min: 2.0,
                      max: 30.0,
                      divisions: 56, // steps of 0.5
                      label: '${cabalOverride.toStringAsFixed(1)} L/h',
                      activeColor: Colors.blue,
                      onChanged: onCabalChanged,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade800,
                      ),
                      onPressed: () {
                        onSaveConfig(bedData.copyWith(
                          irrigationMethod: irrigationMethod,
                          cabalSistemaLitersHora: cabalOverride,
                        ));
                      },
                      child: const Text('Guardar Sistema de Reg'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Darrers Regs List
          const Text(
            'Darrers Regs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (bedData.wateringEvents == null || bedData.wateringEvents!.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.not_interested, color: Colors.grey.shade400, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Encara no hi ha regs registrats.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else ...[
            ...((bedData.wateringEvents!.toList()..sort((a, b) => b.date.compareTo(a.date))).map((event) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.blue.shade100, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.water_drop, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}h',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${event.litersApplied.round()} L',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Esborrar Reg'),
                                content: const Text('Estàs segur que vols esborrar aquest registre de reg? Això afectarà al càlcul del balanç hídric.'),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel·lar'),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('Esborrar', style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      final newEvents = List<WateringEvent>.from(bedData.wateringEvents!);
                                      newEvents.remove(event);
                                      onSaveConfig(bedData.copyWith(wateringEvents: newEvents.isEmpty ? null : newEvents));
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            })),
          ],
        ],
      ),
    );
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
  final List<PlantacioHistorica> historic;
  final int? Function(double xMeters)? getBedIndexFromX;

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
    this.historic = const [],
    this.getBedIndexFromX,
    Listenable? repaintNotifier,
  }) : super(repaint: repaintNotifier);

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
        double bedW = layoutConfig!.getBedWidth(i);
        canvas.drawRect(
          Rect.fromLTWH(currentX * ppm, 0, bedW * ppm, totalHeightM * ppm),
          paint..color = const Color(0xFF8D6E63), // Bed Color
        );

        // Highlight pattern if exists?
        // ...
        currentX += bedW;
      }
      // Final Path?

      // Draw bed health badges
      double badgeX = 0.0;
      for (int i = 0; i < layoutConfig!.numberOfBeds; i++) {
        double pathW = layoutConfig!.pathWidth;
        badgeX += pathW;
        double bedW = layoutConfig!.getBedWidth(i);

        // Compute health for this bed
        final bedHealth = AssistentHort.saludBancal(
          historic: historic,
          bedIndex: i,
          plants: plants,
          currentPlants: placedPlants,
          getBedStartCm: (m) => m * 100,
          getBedEndCm: (m) => m * 100,
          getBedIndexFromX: getBedIndexFromX,
        );

        // Draw badge at top center of bed
        final badgeCenterX = (badgeX + bedW / 2) * ppm;
        const badgeY = 6.0; // Top offset
        const badgeRadius = 12.0;

        Color badgeColor;
        String badgeText;
        switch (bedHealth) {
          case RotacioNivell.optim:
            badgeColor = const Color(0xFF4CAF50);
            badgeText = '✓';
            break;
          case RotacioNivell.mitja:
            badgeColor = const Color(0xFFF9A825);
            badgeText = '!';
            break;
          case RotacioNivell.alt:
            badgeColor = const Color(0xFFE53935);
            badgeText = '⚠';
            break;
        }

        final badgePaint = Paint()..color = badgeColor;
        canvas.drawCircle(
          Offset(badgeCenterX, badgeY),
          badgeRadius,
          badgePaint,
        );

        // Draw text in badge
        final tp = TextPainter(
          text: TextSpan(
            text: badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(
          canvas,
          Offset(badgeCenterX - tp.width / 2, badgeY - tp.height / 2),
        );

        // EXTRA: Water Drop Icon if deficit
        final bedData = layoutConfig!.beds[i];
        if (bedData != null &&
            bedData.soilBalance != null &&
            bedData.soilBalance! <= -2.0) {
          final dropTp = TextPainter(
            text: const TextSpan(
              text: '💧',
              style: TextStyle(fontSize: 14),
            ),
            textDirection: TextDirection.ltr,
          );
          dropTp.layout();
          dropTp.paint(
            canvas,
            Offset(badgeCenterX + badgeRadius + 2, badgeY - dropTp.height / 2),
          );
        }

        badgeX += bedW;
      }
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
