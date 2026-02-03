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
import '../../../tasks/domain/entities/bucket.dart';

import '../../../tasks/presentation/widgets/task_edit_sheet.dart';

import '../providers/map_layers_provider.dart';
import '../widgets/layer_controller_sheet.dart';
import '../widgets/composite_marker.dart';
import '../providers/species_filter_provider.dart';
import '../../../trees/data/repositories/species_repository.dart';
import '../../../trees/domain/entities/species.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/sandbox_provider.dart';

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

  // Measurement mode state
  bool _isMeasuring = false;
  LatLng? _measurePointA;
  LatLng? _measurePointB;
  double _currentZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
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

  // ... (Permission and Location methods kept same, omitted for brevity if unchanged, but safely keeping in file structure)

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

  /// Handles taps in measurement mode
  void _handleMeasureTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      if (_measurePointA == null) {
        _measurePointA = point;
        _measurePointB = null;
      } else if (_measurePointB == null) {
        _measurePointB = point;
      } else {
        // Reset and start new measurement
        _measurePointA = point;
        _measurePointB = null;
      }
    });
  }

  /// Calculates distance between two points using Haversine formula
  double _calculateDistance(LatLng a, LatLng b) {
    const earthRadius = 6371000.0; // meters
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);

    final hav =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
    return earthRadius * c;
  }

  /// Returns human-readable distance string
  String _formatDistance(double meters) {
    if (meters < 1) {
      return '${(meters * 100).toStringAsFixed(0)} cm';
    } else if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Gets scale bar width for current zoom level
  double _getScaleBarWidthMeters() {
    // At zoom 18, roughly 1m per pixel. Adjust by zoom factor.
    // We want nice round numbers for the scale bar
    final metersPerPixel =
        156543.03392 *
        math.cos(_currentZoom * math.pi / 180) /
        math.pow(2, _currentZoom);

    // 100 pixels as base width for scale bar
    final targetPixels = 80.0;
    final rawMeters = targetPixels * metersPerPixel;

    // Round to nice values
    if (rawMeters < 2) return 1;
    if (rawMeters < 5) return 2;
    if (rawMeters < 10) return 5;
    if (rawMeters < 20) return 10;
    if (rawMeters < 50) return 20;
    if (rawMeters < 100) return 50;
    if (rawMeters < 200) return 100;
    if (rawMeters < 500) return 200;
    if (rawMeters < 1000) return 500;
    return 1000;
  }

  /// Gets scale bar pixel width for given meters
  double _getScaleBarPixelWidth(double meters) {
    final metersPerPixel =
        156543.03392 *
        math.cos(_currentZoom * math.pi / 180) /
        math.pow(2, _currentZoom);
    return meters / metersPerPixel;
  }

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(mapLayersProvider);
    final isSandboxMode = ref.watch(sandboxProvider); // Watch Sandbox Mode

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de la Finca'),
        actions: [
          // Sandbox Mode Toggle
          IconButton(
            icon: Icon(
              isSandboxMode ? Icons.design_services : Icons.square_foot,
              color: isSandboxMode ? Colors.orange : null,
            ),
            tooltip: isSandboxMode
                ? 'Sortir del Mode Planificador'
                : 'Entrar al Mode Planificador',
            onPressed: () {
              ref.read(sandboxProvider.notifier).toggle();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isSandboxMode
                        ? 'Mode Planificador desactivat'
                        : 'Mode Planificador activat: Capa "Projectes de Futur" visible',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // ... Existing actions if any (none in original snippet at this spot)
        ],
      ),

      body: Stack(
        children: [
          // Map content
          Consumer(
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
                      onTap: _isMeasuring ? _handleMeasureTap : null,
                      onPositionChanged: (position, hasGesture) {
                        if (position.zoom != _currentZoom) {
                          setState(() => _currentZoom = position.zoom);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            (layers[MapLayer.useOpenStreetMap] ?? false)
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
                        alignDirectionOnUpdate:
                            _followMode == MapFollowMode.compass
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

                      // Permaculture Zones Layer
                      if (layers[MapLayer.permacultureZones] == true)
                        PolygonLayer(
                          polygons: config.permacultureZones.map((zone) {
                            final color = Color(
                              int.parse(zone.colorHex, radix: 16),
                            );
                            return Polygon(
                              points: zone.polygon
                                  .map((p) => LatLng(p.latitude, p.longitude))
                                  .toList(),
                              color: color.withValues(alpha: 0.3),
                              borderStrokeWidth: 2,
                              borderColor: color,
                              label: zone.name,
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 2, color: Colors.black),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      // Task Markers Layer
                      if (layers[MapLayer.tasks] == true)
                        Consumer(
                          builder: (context, ref, child) {
                            final tasksAsyncValue = ref.watch(
                              tasksStreamProvider,
                            );
                            final bucketsAsync = ref.watch(
                              bucketsStreamProvider,
                            );
                            final configAsync = ref.watch(
                              farmConfigStreamProvider,
                            );
                            final markerSize =
                                configAsync.asData?.value.mapMarkerSize ?? 20.0;
                            final pendingOnly =
                                layers[MapLayer.pendingTasksOnly] ?? true;

                            // Get buckets map for icon lookup
                            final bucketsMap = <String, Bucket>{};
                            if (bucketsAsync.hasValue) {
                              for (final b in bucketsAsync.value!) {
                                bucketsMap[b.name] = b;
                              }
                            }

                            List<Marker> markers = [];
                            if (tasksAsyncValue.hasValue) {
                              // Filter tasks: must have location, and if pendingOnly, exclude completed
                              final filteredTasks = tasksAsyncValue.value!
                                  .where((t) {
                                    if (t.latitude == null ||
                                        t.longitude == null) {
                                      return false;
                                    }
                                    if (pendingOnly && t.isDone) {
                                      return false;
                                    }
                                    return true;
                                  });

                              markers.addAll(
                                filteredTasks.map((t) {
                                  // Get bucket icon, fallback to default
                                  final bucket = bucketsMap[t.bucket];
                                  final iconData =
                                      bucket?.icon ??
                                      IconData(
                                        Bucket.defaultIconCode,
                                        fontFamily: Bucket.defaultIconFamily,
                                      );

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
                                          iconData,
                                          color:
                                              bucket?.iconColor ??
                                              Bucket.defaultIconColor,
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
                          final treesAsyncValue = ref.watch(
                            treesStreamProvider,
                          );
                          final hiddenSpecies = ref.watch(
                            hiddenSpeciesProvider,
                          );

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

                              // Check if Future Projects layer is enabled
                              final showPlanned =
                                  layers[MapLayer.futureProjects] ?? false;

                              // Build adult canopy circles for planned trees
                              final canopyCircles = <CircleMarker>[];
                              if (showPlanned) {
                                for (final t in treesAsyncValue.value!.where(
                                  (t) =>
                                      t.status == 'Planned' &&
                                      !hiddenSpecies.contains(t.species),
                                )) {
                                  final species = speciesMap[t.speciesId];
                                  if (species != null &&
                                      species.adultDiameter > 0) {
                                    // adultDiameter is the crown diameter in meters
                                    final radiusMeters =
                                        species.adultDiameter / 2;
                                    canopyCircles.add(
                                      CircleMarker(
                                        point: LatLng(t.latitude, t.longitude),
                                        radius: radiusMeters,
                                        useRadiusInMeter: true,
                                        color: Colors.lightGreen.withValues(
                                          alpha: 0.25,
                                        ),
                                        borderColor: Colors.green.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderStrokeWidth: 2,
                                      ),
                                    );
                                  }
                                }
                              }

                              return Stack(
                                children: [
                                  // Adult canopy circles layer (behind markers)
                                  if (canopyCircles.isNotEmpty)
                                    CircleLayer(circles: canopyCircles),

                                  // Tree markers layer
                                  MarkerLayer(
                                    markers: treesAsyncValue.value!
                                        .where((t) {
                                          if (hiddenSpecies.contains(
                                            t.species,
                                          )) {
                                            return false;
                                          }
                                          if (t.status == 'Planned' &&
                                              !showPlanned) {
                                            return false;
                                          }
                                          return true;
                                        })
                                        .map((t) {
                                          final species =
                                              speciesMap[t.speciesId];
                                          Color color = Colors.green;
                                          IconData? iconData = Icons.park;
                                          String label = t.reference ?? '???';
                                          final isPlanned =
                                              t.status == 'Planned';

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
                                              layers[MapLayer.treeLabels] ??
                                              false;
                                          final configAsync = ref.watch(
                                            farmConfigStreamProvider,
                                          );
                                          final markerSize =
                                              configAsync
                                                  .asData
                                                  ?.value
                                                  .mapMarkerSize ??
                                              20.0;

                                          return Marker(
                                            point: LatLng(
                                              t.latitude,
                                              t.longitude,
                                            ),
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
                                                  isPlanned: isPlanned,
                                                ),
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ],
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

                      // Measurement Line (Polyline between A and B)
                      if (_isMeasuring &&
                          _measurePointA != null &&
                          _measurePointB != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_measurePointA!, _measurePointB!],
                              color: Colors.orange,
                              strokeWidth: 3,
                              pattern: const StrokePattern.dotted(),
                            ),
                          ],
                        ),

                      // Measurement Point Markers
                      if (_isMeasuring && _measurePointA != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _measurePointA!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_measurePointB != null)
                              Marker(
                                point: _measurePointB!,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'B',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                      // Distance Label (midpoint between A and B)
                      if (_isMeasuring &&
                          _measurePointA != null &&
                          _measurePointB != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                (_measurePointA!.latitude +
                                        _measurePointB!.latitude) /
                                    2,
                                (_measurePointA!.longitude +
                                        _measurePointB!.longitude) /
                                    2,
                              ),
                              width: 100,
                              height: 40,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 4,
                                      color: Colors.black26,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatDistance(
                                    _calculateDistance(
                                      _measurePointA!,
                                      _measurePointB!,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
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

          // Sandbox Mode Banner
          if (isSandboxMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.orange.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.design_services, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'MODE PLANIFICADOR: ON',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Fixed Scale Bar (bottom-left)
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black26),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _getScaleBarPixelWidth(
                      _getScaleBarWidthMeters(),
                    ).clamp(30.0, 150.0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDistance(_getScaleBarWidthMeters()),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Measurement mode indicator
          if (_isMeasuring)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: Text(
                    _measurePointA == null
                        ? '📍 Toca el primer punt'
                        : _measurePointB == null
                        ? '📍 Toca el segon punt'
                        : '📏 Toca per mesurar de nou',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Measurement mode toggle
          FloatingActionButton(
            heroTag: 'measure',
            mini: true,
            backgroundColor: _isMeasuring ? Colors.orange : Colors.white,
            foregroundColor: _isMeasuring ? Colors.white : Colors.black,
            onPressed: () {
              setState(() {
                _isMeasuring = !_isMeasuring;
                if (!_isMeasuring) {
                  _measurePointA = null;
                  _measurePointB = null;
                }
              });
              if (_isMeasuring) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode mesura: Toca 2 punts per mesurar'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Icon(Icons.straighten),
          ),
          const SizedBox(height: 8),
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
                            '${(tree.height! / 100).toStringAsFixed(1)}m',
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

              // Delete button for planned trees
              if (tree.status == 'Planned')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeletePlanned(context, ref, tree);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    label: const Text('ELIMINAR ARBRE PLANIFICAT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deletes a planned tree with simple confirmation
  void _confirmDeletePlanned(BuildContext context, WidgetRef ref, Tree tree) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 40),
        title: const Text('Eliminar Arbre Planificat'),
        content: Text(
          'Vols eliminar "${tree.commonName}" de la planificació?\n\n'
          'Aquesta acció no es pot desfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(treesRepositoryProvider).deleteTree(tree.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${tree.commonName}" eliminat'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('ELIMINAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
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
