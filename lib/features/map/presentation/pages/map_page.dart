import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/presentation/widgets/tree_detail.dart';
import '../../../trees/domain/entities/watering_event.dart';
import '../../../trees/domain/entities/tree.dart';

import '../providers/map_layers_provider.dart';
import '../widgets/layer_controller_sheet.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(mapLayersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de la Finca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              try {
                // Check permissions
                LocationPermission permission =
                    await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Permís de localització denegat'),
                        ),
                      );
                    }
                    return;
                  }
                }

                if (permission == LocationPermission.deniedForever) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Permís de localització denegat permanentment',
                        ),
                      ),
                    );
                  }
                  return;
                }

                // Get location
                final position = await Geolocator.getCurrentPosition();
                _mapController.move(
                  LatLng(position.latitude, position.longitude),
                  18.0, // Zoom in for user location
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error obtenint localització: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final configAsync = ref.watch(farmConfigStreamProvider);

          return configAsync.when(
            data: (config) {
              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(config.latitude, config.longitude),
                  initialZoom: config.zoom,
                  maxZoom: 20.0,
                ),
                children: [
                  child!, // TileLayer
                  // Irrigation Zones Layer (Dynamic from FarmConfig)
                  if (layers[MapLayer.irrigationZones] == true)
                    PolygonLayer(
                      polygons: [
                        // For now, only mock zones that have real points or rely on matching
                        // If we want to use the config zones, we would need points in FarmZone
                        // Since we don't have them yet, keeping the Demo polygons if name matches, or just Demo polygons.
                        // Given the user request was Metadata-focused, I'll keep the Demo polygons for "Zona A" and "Zona B".
                        // In future, we can add `points` to FarmZone and map `config.zones`.
                        Polygon(
                          points: [
                            LatLng(41.512800, 0.918400),
                            LatLng(41.512800, 0.918800),
                            LatLng(41.512500, 0.918800),
                            LatLng(41.512500, 0.918400),
                          ],
                          color: Colors.blue.withValues(alpha: 0.3),
                          borderStrokeWidth: 2,
                          borderColor: Colors.blue,
                          label: 'Zona A',
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Polygon(
                          points: [
                            LatLng(41.512500, 0.918800),
                            LatLng(41.512500, 0.919200),
                            LatLng(41.512200, 0.919200),
                            LatLng(41.512200, 0.918800),
                          ],
                          color: Colors.teal.withValues(alpha: 0.3),
                          borderStrokeWidth: 2,
                          borderColor: Colors.teal,
                          label: 'Zona B',
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  // Task Markers Layer
                  if (layers[MapLayer.tasks] == true)
                    Consumer(
                      builder: (context, ref, child) {
                        final tasksAsyncValue = ref.watch(tasksStreamProvider);
                        List<Marker> markers = [];
                        if (tasksAsyncValue.hasValue) {
                          markers.addAll(
                            tasksAsyncValue.value!
                                .where(
                                  (t) =>
                                      t.latitude != null && t.longitude != null,
                                )
                                .map((t) {
                                  final isReforest = t.bucket == 'Reforestació';
                                  return Marker(
                                    point: LatLng(t.latitude!, t.longitude!),
                                    width: 40,
                                    height: 40,
                                    child: GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${t.title} (${t.bucket})',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        isReforest
                                            ? Icons.forest
                                            : Icons.check_circle,
                                        color: isReforest
                                            ? Colors.green[800]
                                            : Colors.orange,
                                        size: 40,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 5,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                          );
                        }
                        return MarkerLayer(markers: markers);
                      },
                    ),

                  // Tree Markers Layer
                  Consumer(
                    builder: (context, ref, child) {
                      final treesAsyncValue = ref.watch(treesStreamProvider);
                      final useHealthColor =
                          layers[MapLayer.healthStatus] == true;

                      if (!treesAsyncValue.hasValue) {
                        return const SizedBox.shrink();
                      }

                      return MarkerLayer(
                        markers: treesAsyncValue.value!.map((t) {
                          return Marker(
                            point: LatLng(t.latitude, t.longitude),
                            width: 45,
                            height: 45,
                            child: GestureDetector(
                              onTap: () => _showTreeOptions(context, ref, t),
                              child: Icon(
                                Icons.park,
                                color: useHealthColor
                                    ? _getHealthColor(t)
                                    : Colors.greenAccent[700],
                                size: 45,
                                shadows: const [
                                  Shadow(blurRadius: 5, color: Colors.black54),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        child: TileLayer(
          // ICGC Orthophoto
          urlTemplate:
              'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg',
          userAgentPackageName: 'com.soca.app',
          maxZoom: 20,
          subdomains: const [],
        ),
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'layers',
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => const LayerControllerSheet(),
              );
            },
            child: const Icon(Icons.layers),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom + 1,
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom - 1,
              );
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(Tree t) {
    // Basic heuristic based on strings I recall.
    // Replace with actual field 'state' or 'health'
    // If 'state' is the field:
    // 'Viable' -> Green
    // 'Malalt' -> Red
    // 'Mort' -> Grey
    // 'Mitjà' -> Yellow (if added)

    // I'll try to access `t.state` if it exists.
    // Since I can't be 100% sure without reading Tree entity, I'll read it first to be safe.
    return Colors.green; // Skeleton, will fix after reading Tree.
  }

  void _showTreeOptions(BuildContext context, WidgetRef ref, Tree tree) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: tree.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(tree.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey[200],
                  ),
                  child: tree.photoUrl == null
                      ? const Icon(Icons.park, color: Colors.green)
                      : null,
                ),
                title: Text(
                  tree.commonName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(tree.species),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TreeDetail(tree: tree),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Reg Ràpid',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWaterOption(context, ref, tree, 2),
                  _buildWaterOption(context, ref, tree, 5),
                  _buildWaterOption(context, ref, tree, 8),
                  _buildCustomWaterOption(context, ref, tree),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterOption(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
    double liters,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade800,
      ),
      onPressed: () async {
        Navigator.pop(context);
        final event = WateringEvent(
          id: '',
          date: DateTime.now(),
          liters: liters,
          note: 'Reg Ràpid (Mapa)',
          treeId: tree.id,
        );
        await ref
            .read(treesRepositoryProvider)
            .addWateringEvent(tree.id, event);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Afegits ${liters.toInt()}L a ${tree.commonName}'),
            ),
          );
        }
      },
      icon: const Icon(Icons.water_drop),
      label: Text('${liters.toInt()}L'),
    );
  }

  Widget _buildCustomWaterOption(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
      ),
      onPressed: () {
        Navigator.pop(context);
        _showCustomWaterDialog(context, ref, tree);
      },
      child: const Text('Altres...'),
    );
  }

  Future<void> _showCustomWaterDialog(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
  ) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quantitat Personalitzada'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Litres',
            suffixText: 'L',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                final event = WateringEvent(
                  id: '',
                  date: DateTime.now(),
                  liters: val,
                  note: 'Reg Manual (Mapa)',
                  treeId: tree.id,
                );
                await ref
                    .read(treesRepositoryProvider)
                    .addWateringEvent(tree.id, event);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Afegits ${val.toInt()}L a ${tree.commonName}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
}
