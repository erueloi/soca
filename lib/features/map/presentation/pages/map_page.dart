import 'package:flutter/material.dart';
import '../../../../core/utils/icon_utils.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/presentation/widgets/tree_detail.dart';
import '../../../trees/domain/entities/watering_event.dart';
import '../../../trees/domain/entities/tree.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/widgets/task_edit_sheet.dart';

import '../providers/map_layers_provider.dart';
import '../widgets/layer_controller_sheet.dart';
import '../widgets/composite_marker.dart';
import '../providers/species_filter_provider.dart';
import '../../../trees/data/repositories/species_repository.dart';
import '../../../trees/domain/entities/species.dart';
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
                  CurrentLocationLayer(
                    style: const LocationMarkerStyle(
                      marker: DefaultLocationMarker(
                        color: Color(0xFF2E7D32), // Soca Green
                        child: Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      markerSize: Size(40, 40),
                      accuracyCircleColor: Color(0x332E7D32),
                    ),
                  ),
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
                        final configAsync = ref.watch(farmConfigStreamProvider);
                        final markerSize =
                            configAsync.asData?.value.mapMarkerSize ?? 20.0;

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
                                    // Use consistent container size for stability
                                    width: 120.0,
                                    height: 120.0,
                                    alignment: Alignment.center,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showTaskOptions(context, ref, t),
                                        child: Icon(
                                          isReforest
                                              ? Icons.forest
                                              : Icons.check_circle,
                                          color: isReforest
                                              ? Colors.green[800]
                                              : Colors.orange,
                                          size: markerSize * 0.9,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 5,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
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
                      final hiddenSpecies = ref.watch(hiddenSpeciesProvider);

                      // We need species data. Let's assume a provider exists or fetch it.
                      // Since we don't have a stream provider for ALL species handy in the context (maybe),
                      // let's try to find it or optimize.
                      // Ideally: ref.watch(speciesListProvider).
                      // If not found, I'll assume we can add it or just fetch once.
                      // Let's use FutureBuilder or similar if no provider?
                      // Wait, usually there's a provider. I'll check `trees_provider.dart` content first?
                      // Actually, for now, let's assume I can get the repository and fetch.
                      // BUT `ref.watch` inside build is better.
                      // Let's assume `speciesListStreamProvider` exists in `species_repository.dart`?
                      // I need to find the provider.

                      // For this step, I will use a simple Future/Stream interaction or a placeholder
                      // if I can't find the provider immediately.
                      // Let's check imports.

                      final speciesStream = ref
                          .watch(speciesRepositoryProvider)
                          .getSpecies();

                      if (!treesAsyncValue.hasValue) {
                        return const SizedBox.shrink();
                      }

                      return StreamBuilder<List<Species>>(
                        stream: speciesStream,
                        builder: (context, speciesSnapshot) {
                          if (!speciesSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final speciesList = speciesSnapshot.data!;
                          final speciesMap = {
                            for (var s in speciesList) s.id: s,
                          };

                          return MarkerLayer(
                            markers: treesAsyncValue.value!
                                .where(
                                  (t) => !hiddenSpecies.contains(t.species),
                                )
                                .map((t) {
                                  final species = speciesMap[t.speciesId];
                                  // Fallback
                                  Color color = Colors.green;
                                  IconData? iconData = Icons.park;
                                  String label = t.reference ?? '???';

                                  if (species != null) {
                                    if (species.color.isNotEmpty) {
                                      try {
                                        color = Color(
                                          int.parse(
                                            '0xFF${species.color.replaceAll('#', '')}',
                                          ),
                                        );
                                      } catch (_) {}
                                    }
                                    if (species.iconCode != null) {
                                      iconData = IconUtils.resolveIcon(
                                        species.iconCode!,
                                        species.iconFamily,
                                      );
                                    }
                                  }

                                  final showLabels =
                                      layers[MapLayer.treeLabels] ?? false;
                                  final configAsync = ref.watch(
                                    farmConfigStreamProvider,
                                  );
                                  final markerSize =
                                      configAsync.asData?.value.mapMarkerSize ??
                                      20.0;

                                  return Marker(
                                    point: LatLng(t.latitude, t.longitude),
                                    // Use a fixed extensive container to ensure stability
                                    // The visual marker (icon) is centered in this container
                                    width: 120.0,
                                    height: 120.0,
                                    alignment: Alignment.center,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showTreeOptions(
                                          context,
                                          ref,
                                          t,
                                          species,
                                        ),
                                        child: CompositeMarker(
                                          color: color,
                                          iconData: iconData,
                                          label: label,
                                          size: markerSize,
                                          showLabel: showLabels,
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          );
                        },
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

  void _showTaskOptions(BuildContext context, WidgetRef ref, Task task) {
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
                leading: Icon(
                  task.bucket == 'Reforestació'
                      ? Icons.forest
                      : Icons.check_circle,
                  color: task.bucket == 'Reforestació'
                      ? Colors.green[800]
                      : Colors.orange,
                  size: 40,
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.bucket,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => TaskEditSheet(
                        task: task,
                        initialBucket: task.bucket,
                        onSave: (updatedTask) {
                          ref
                              .read(tasksRepositoryProvider)
                              .updateTask(updatedTask);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tasca actualitzada!'),
                            ),
                          );
                        },
                        onDelete: () {
                          ref.read(tasksRepositoryProvider).deleteTask(task.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tasca eliminada 🗑️'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTreeOptions(
    BuildContext context,
    WidgetRef ref,
    Tree tree,
    Species? species,
  ) {
    final currentMonth = DateTime.now().month;
    final isPruning = species?.pruningMonths.contains(currentMonth) ?? false;
    final isHarvest = species?.harvestMonths.contains(currentMonth) ?? false;
    final isPlanting = species?.plantingMonths.contains(currentMonth) ?? false;

    // Age Calculation
    final now = DateTime.now();
    final ageYears =
        (now.difference(tree.plantingDate).inDays / 365.25) + tree.initialAge;
    String ageText = ageYears < 1
        ? '${(ageYears * 12).round()} mesos'
        : '${ageYears.toStringAsFixed(1)} anys';

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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: tree.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(tree.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: tree.photoUrl == null
                      ? Icon(
                          IconUtils.resolveIcon(
                            species?.iconCode ?? Icons.park.codePoint,
                            species?.iconFamily,
                          ),
                          color: Colors.green.shade700,
                          size: 30,
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        tree.commonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${tree.species}${tree.reference != null ? ' • ${tree.reference}' : ''}',
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    // Metrics Row
                    Row(
                      children: [
                        Icon(Icons.cake, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          ageText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (tree.height != null && tree.height! > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.height, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${tree.height!.toStringAsFixed(1)}m',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                        if (tree.trunkDiameter != null &&
                            tree.trunkDiameter! > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.circle_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ø ${tree.trunkDiameter!.toStringAsFixed(1)}cm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusBadge(tree.status),
                          const SizedBox(width: 8),
                          if (tree.vigor != null) ...[
                            _buildVigorBadge(tree.vigor!),
                            const SizedBox(width: 8),
                          ],
                          if (isPruning)
                            _buildTaskBadge('Poda', Icons.cut, Colors.orange),
                          if (isHarvest)
                            _buildTaskBadge(
                              'Collita',
                              Icons.agriculture,
                              Colors.purple,
                            ),
                          if (isPlanting)
                            _buildTaskBadge(
                              'Plantació',
                              Icons.spa,
                              Colors.lightGreen,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Reg Ràpid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (species != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Kc: ${species.kc}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildWaterOption(context, ref, tree, 2),
                    _buildWaterOption(context, ref, tree, 5),
                    _buildWaterOption(context, ref, tree, 8),
                    _buildCustomWaterOption(context, ref, tree),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'mort':
        color = Colors.grey;
        icon = Icons.sentiment_very_dissatisfied;
        break;
      case 'malalt':
        color = Colors.orange;
        icon = Icons.healing;
        break;
      default:
        color = Colors.green;
        icon = Icons.check_circle_outline;
    }
    return _buildMiniBadge(status, icon, color);
  }

  Widget _buildVigorBadge(String vigor) {
    Color color;
    IconData icon;
    switch (vigor.toLowerCase()) {
      case 'baix':
        color = Colors.red;
        icon = Icons.battery_alert;
        break;
      case 'mitjà':
        color = Colors.orange;
        icon = Icons.battery_5_bar;
        break;
      default: // Alt
        color = Colors.green;
        icon = Icons.battery_full;
    }
    return _buildMiniBadge('Vigor $vigor', icon, color);
  }

  Widget _buildTaskBadge(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
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
