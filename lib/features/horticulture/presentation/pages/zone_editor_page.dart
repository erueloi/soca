import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/map/presentation/providers/map_layers_provider.dart';

import '../../domain/entities/espai_hort.dart';
import '../../domain/entities/garden_layout_config.dart';
import '../../data/repositories/hort_repository.dart';
import 'garden_designer_page.dart';
import 'espai_list_page.dart'; // For provider
import 'dart:math' as math;

// Service provider
// final rotationServiceProvider = Provider((ref) => RotationService()); // Unused now

class ZoneEditorPage extends ConsumerStatefulWidget {
  const ZoneEditorPage({super.key});

  @override
  ConsumerState<ZoneEditorPage> createState() => _ZoneEditorPageState();
}

class _ZoneEditorPageState extends ConsumerState<ZoneEditorPage> {
  final MapController _mapController = MapController();

  EspaiHort? _selectedEspai;

  // Helper to compute rectangle corners from center+dims
  List<LatLng> _computeCorners(EspaiHort espai) {
    const metersPerDegLat = 111132.92;
    final metersPerDegLng =
        metersPerDegLat * math.cos(espai.center.latitude * math.pi / 180);

    final dLat = (espai.length / 2) / metersPerDegLat;
    final dLng = (espai.width / 2) / metersPerDegLng;

    return [
      LatLng(espai.center.latitude + dLat, espai.center.longitude - dLng), // TL
      LatLng(espai.center.latitude + dLat, espai.center.longitude + dLng), // TR
      LatLng(espai.center.latitude - dLat, espai.center.longitude + dLng), // BR
      LatLng(espai.center.latitude - dLat, espai.center.longitude - dLng), // BL
    ];
  }

  @override
  Widget build(BuildContext context) {
    final espaisAsync = ref.watch(espaiListStreamProvider);
    final layers = ref.watch(mapLayersProvider);
    // Rotation logic mostly moved to Designer/Details, but showing status on Map popup is cool.

    return espaisAsync.when(
      data: (espais) {
        // Center on first if available and map not moved?
        // simple logic

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // Center on selected zone if possible, else farm center
                // Default center
                initialCenter: espais.isNotEmpty
                    ? espais.first.center
                    : const LatLng(41.5126, 0.9186),
                initialZoom: 20.0,
                maxZoom: 22.0,
                onTap: (pos, latlng) {
                  setState(() => _selectedEspai = null);
                },
                onLongPress: (pos, latlng) {
                  _showCreateDialogAt(context, latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: (layers[MapLayer.useOpenStreetMap] ?? false)
                      ? ((layers[MapLayer.satellite] ?? false)
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png')
                      : ((layers[MapLayer.satellite] ?? false)
                            ? 'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg'
                            : 'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/topo/GRID3857/{z}/{x}/{y}.jpeg'),
                  userAgentPackageName: 'com.molicaljeroni.soca',
                ),
                PolygonLayer(
                  polygons: espais.map((espai) {
                    final points = _computeCorners(espai);
                    final isSelected = _selectedEspai?.id == espai.id;
                    return Polygon(
                      points: points,
                      color: isSelected
                          ? Colors.blue.withValues(alpha: 0.4)
                          : Colors.green.withValues(alpha: 0.2),
                      borderColor: isSelected ? Colors.blue : Colors.green,
                      borderStrokeWidth: 2,
                      label: espai.nom,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        backgroundColor: Colors.black45,
                      ),
                    );
                  }).toList(),
                  // Handling Hit Test manually? Flutter Map usually handles tap on polygon?
                  // Wait, PolygonLayer in newer versions doesn't always have onTap.
                  // If onTap missing, we check bounds in Map onTap. But checking bounds of rotated rects/polygons is mathy.
                  // Let's assume user taps the polygon.
                  // Version check: Flutter map 6/7?
                  // Checking imports... 'flutter_map'.
                  // Let's trust older hit testing or add a transparent marker?
                  // EASIER: Display Markers at center of Espai?
                  // OR: Compute distance to center in Map OnTap.
                ),
                MarkerLayer(
                  markers: espais
                      .map(
                        (e) => Marker(
                          point: e.center,
                          width: 120,
                          height: 60,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedEspai = e);
                              _showEspaiDetails(context, e);
                            },
                            child: Container(
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.transparent,
                                size: 50,
                              ), // Invisible hit target
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _showEspaiDetails(BuildContext context, EspaiHort espai) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    espai.nom,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${espai.width}m x ${espai.length}m'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit),
                    label: Text(isLoading ? 'Obrint...' : 'Obrir Dissenyador'),
                    onPressed: isLoading
                        ? null
                        : () async {
                            setModalState(() => isLoading = true);
                            await Future.delayed(Duration.zero);

                            if (!context.mounted) return;

                            // Keep modal open while generating/pushing route to show spinner
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GardenDesignerPage(espai: espai),
                              ),
                            );

                            // Close modal when returning from Designer
                            if (context.mounted) Navigator.pop(context);
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

  void _showCreateDialogAt(BuildContext context, LatLng position) {
    // Controllers for Layout Wizard
    final nameCtrl = TextEditingController();
    final widthCtrl = TextEditingController(text: '7');
    final lengthCtrl = TextEditingController(text: '5');
    final numBedsCtrl = TextEditingController(text: '4');
    final pathWidthCtrl = TextEditingController(text: '0.5');
    final cellSizeCtrl = TextEditingController(text: '0.2');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Validation Logic
          bool isValid =
              nameCtrl.text.isNotEmpty &&
              (double.tryParse(widthCtrl.text) ?? 0) > 0 &&
              (double.tryParse(lengthCtrl.text) ?? 0) > 0 &&
              (int.tryParse(numBedsCtrl.text) ?? 0) > 0 &&
              (double.tryParse(pathWidthCtrl.text) ?? 0) >= 0;

          // Calculation
          Widget feedbackWidget = const SizedBox.shrink();
          final w = double.tryParse(widthCtrl.text) ?? 0;
          final n = int.tryParse(numBedsCtrl.text) ?? 0;
          final p = double.tryParse(pathWidthCtrl.text) ?? 0;

          if (w > 0 && n > 0 && p >= 0) {
            final totalPath = (n + 1) * p;
            final totalBed = w - totalPath;
            if (totalBed <= 0) {
              isValid = false;
              feedbackWidget = Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                color: Colors.red[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Massa estret! No hi caben els bancals.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
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

          return AlertDialog(
            title: const Text('Nou Espai en Ubicació'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ubicació: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'Espai',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dimensions Totals',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 16),
                    const Text(
                      'Distribució de Bancals',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
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
                            controller: numBedsCtrl,
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
                            controller: pathWidthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amplada Passadís',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cellSizeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mida Cel·la Grid (m) - Def: 0.2',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    feedbackWidget,
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel·lar'),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () {
                        final nom = nameCtrl.text;
                        final w = double.tryParse(widthCtrl.text) ?? 0;
                        final l = double.tryParse(lengthCtrl.text) ?? 5;
                        final n = int.tryParse(numBedsCtrl.text) ?? 0;
                        final p = double.tryParse(pathWidthCtrl.text) ?? 0;
                        final cSize = double.tryParse(cellSizeCtrl.text) ?? 0.2;

                        final totalPath = (n + 1) * p;
                        final totalBedSpace = w - totalPath;
                        final bedWidth = totalBedSpace / n;

                        final layoutConfig = GardenLayoutConfig(
                          totalWidth: w,
                          totalLength: l,
                          numberOfBeds: n,
                          bedWidth: bedWidth,
                          pathWidth: p,
                          cellSize: cSize,
                        );

                        final newEspai = EspaiHort(
                          id: '',
                          nom: nom,
                          center: position,
                          width: w,
                          length: l,
                          gridCellSize: cSize,
                          layoutConfig: layoutConfig,
                        );

                        ref
                            .read(hortRepositoryProvider)
                            .saveEspai(newEspai)
                            .then((_) {
                              if (context.mounted) Navigator.pop(context);
                            })
                            .catchError((e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error guardant l\'espai: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            });
                      }
                    : null,
                child: const Text('Crear Espai'),
              ),
            ],
          );
        },
      ),
    );
  }
}
