import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../../../core/utils/icon_utils.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import 'dart:async'; // StreamSubscription
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/presentation/widgets/tree_form_sheet.dart';
import '../../../trees/presentation/widgets/tree_detail.dart';
import '../../../trees/domain/entities/watering_event.dart';
import '../../../trees/domain/entities/tree.dart';
import '../../../trees/domain/entities/tree_extensions.dart';
import '../../../tasks/domain/entities/task.dart';

import '../../../tasks/presentation/widgets/task_edit_sheet.dart';

import '../providers/map_layers_provider.dart';
import '../widgets/layer_controller_sheet.dart';
import '../widgets/composite_marker.dart';
import '../providers/species_filter_provider.dart';
import '../../../trees/data/repositories/species_repository.dart';
import '../../../trees/domain/entities/species.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

enum MapFollowMode { none, centered, compass }

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();
  MapFollowMode _followMode = MapFollowMode.none;
  StreamSubscription<MapEvent>? _mapEventSubscription;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
      // If user drags or rotates manually, stop following
      if (event.source == MapEventSource.onDrag ||
          event.source == MapEventSource.onMultiFinger) {
        if (_followMode != MapFollowMode.none) {
          setState(() {
            _followMode = MapFollowMode.none;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    super.dispose();
  }

  void _toggleFollowMode() async {
    // Cycle: none -> centered -> compass -> centered
    // If none, check permissions first before going to centered
    if (_followMode == MapFollowMode.none) {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) return;

      setState(() {
        _followMode = MapFollowMode.centered;
      });
      _moveToCurrentLocation();
    } else if (_followMode == MapFollowMode.centered) {
      setState(() {
        _followMode = MapFollowMode.compass;
      });
    } else if (_followMode == MapFollowMode.compass) {
      setState(() {
        _followMode =
            MapFollowMode.centered; // Back to centered, disable compass
      });
      // Reset rotation to 0 when leaving compass mode
      _mapController.rotate(0);
    }
  }

  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permís de localització denegat')),
          );
        }
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permís de localització denegat permanentment'),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(LatLng(position.latitude, position.longitude), 18.0);
    } catch (e) {
      debugPrint('Error moving to location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(mapLayersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de la Finca')),

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
                  onLongPress: _handleLongPress,
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
                    // Align position: Always for centered/compass. Never for none.
                    alignPositionOnUpdate: _followMode != MapFollowMode.none
                        ? AlignOnUpdate.always
                        : AlignOnUpdate.never,
                    // Align direction: Always for compass. Never for others.
                    alignDirectionOnUpdate: _followMode == MapFollowMode.compass
                        ? AlignOnUpdate.always
                        : AlignOnUpdate.never,
                    headingStream: _followMode == MapFollowMode.compass
                        ? FlutterCompass.events?.map((e) {
                            return LocationMarkerHeading(
                              heading: (e.heading ?? 0) * (math.pi / 180),
                              accuracy: (e.accuracy ?? 0) * (math.pi / 180),
                            );
                          })
                        : null,
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

                  // Selected Location Marker (Long Press)
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
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
            heroTag: 'map_follow_fab',
            mini: true,
            backgroundColor: const Color(0xFF2E7D32), // Soca Green
            onPressed: _toggleFollowMode,
            child: Icon(
              _followMode == MapFollowMode.none
                  ? Icons.location_searching
                  : _followMode == MapFollowMode.centered
                  ? Icons.my_location
                  : Icons.explore,
              color: Colors.white,
            ),
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
          const SizedBox(height: 16),
          SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            overlayColor: Colors.black,
            overlayOpacity: 0.5,
            spacing: 12,
            spaceBetweenChildren: 8,
            children: [
              SpeedDialChild(
                child: const Icon(Icons.park),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                label: 'Nou Arbre',
                onTap: () {
                  final center = _mapController.camera.center;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => TreeFormSheet(
                      tree: Tree(
                        id: '',
                        species: '',
                        commonName: '',
                        latitude: center.latitude,
                        longitude: center.longitude,
                        plantingDate: DateTime.now(),
                        status: 'Viable',
                      ),
                    ),
                  );
                },
              ),
              SpeedDialChild(
                child: const Icon(Icons.assignment),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                label: 'Nova Tasca',
                onTap: () async {
                  final center = _mapController.camera.center;
                  Task? createdTask;

                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => TaskEditSheet(
                      initialBucket: 'Pendent',
                      task: Task(
                        id: const Uuid().v4(),
                        title: '',
                        bucket: 'Pendent',
                        latitude: center.latitude,
                        longitude: center.longitude,
                      ),
                      onSave: (task) {
                        createdTask = task;
                      },
                    ),
                  );

                  if (createdTask == null) return;
                  if (!context.mounted) return;

                  final selectedBucket = await _askForBucket(context);
                  if (selectedBucket == null) return;

                  final taskToSave = createdTask!.copyWith(
                    bucket: selectedBucket,
                  );
                  await ref.read(tasksRepositoryProvider).addTask(taskToSave);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tasca creada a "$selectedBucket"')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleLongPress(TapPosition tapPosition, LatLng point) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedLocation = point;
    });

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.park, color: Colors.green),
            title: const Text('Nou Arbre aquí'),
            onTap: () {
              Navigator.pop(sheetContext);
              // Clear selection after action (or keep it?)
              // Let's keep it until form opens?
              // Standard behavior: clear temporary marker when form opens.
              setState(() => _selectedLocation = null);

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => TreeFormSheet(
                  tree: Tree(
                    id: '',
                    species: '',
                    commonName: '',
                    latitude: point.latitude,
                    longitude: point.longitude,
                    plantingDate: DateTime.now(),
                    status: 'Viable',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.orange),
            title: const Text('Nova Tasca aquí'),
            onTap: () async {
              Navigator.pop(sheetContext);
              setState(() => _selectedLocation = null);

              Task? createdTask;
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => TaskEditSheet(
                  initialBucket: 'Pendent',
                  task: Task(
                    id: const Uuid().v4(),
                    title: '',
                    bucket: 'Pendent',
                    latitude: point.latitude,
                    longitude: point.longitude,
                  ),
                  onSave: (task) {
                    createdTask = task;
                  },
                ),
              );

              if (createdTask == null) return;
              if (!mounted) return;

              final selectedBucket = await _askForBucket(context);
              if (selectedBucket == null) return;

              final taskToSave = createdTask!.copyWith(bucket: selectedBucket);
              await ref.read(tasksRepositoryProvider).addTask(taskToSave);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tasca creada a "$selectedBucket"')),
              );
            },
          ),
        ],
      ),
    ).whenComplete(() {
      // If user just dismisses the sheet without picking option, clear the marker
      if (mounted) {
        setState(() => _selectedLocation = null);
      }
    });
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
                    const SizedBox(width: 12),
                    // Water Status
                    Icon(
                      Icons.water_drop,
                      size: 16,
                      color: tree.waterStatusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tree.waterStatusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tree.waterStatusColor,
                      ),
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
