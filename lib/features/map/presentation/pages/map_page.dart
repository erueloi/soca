import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  // Approximate center of Molí de Cal Jeroni (generic fallback if not set)
  // Replaced with a generic Catalonia location or user's specific location if known.
  // Using a sample coordinate near Montserrat for now as a default.
  // Molí de Cal Jeroni
  static const LatLng _initialCenter = LatLng(41.5126017, 0.9185921);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de la Finca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // TODO: Center on user location
            },
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 16.0,
          maxZoom: 20.0,
        ),
        children: [
          TileLayer(
            // ICGC Orthophoto
            // URL Template: https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg
            urlTemplate:
                'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg',
            userAgentPackageName: 'com.soca.app',
            maxZoom: 20,
            subdomains: const [], // ICGC doesn't use subdomains like {s}
          ),
          // Task Markers Layer
          Consumer(
            builder: (context, ref, child) {
              final tasksAsyncValue = ref.watch(tasksStreamProvider);

              return tasksAsyncValue.when(
                data: (tasks) {
                  final markers = tasks
                      .where((t) => t.latitude != null && t.longitude != null)
                      .map((t) {
                        final isTree = t.bucket == 'Reforestació';
                        return Marker(
                          point: LatLng(t.latitude!, t.longitude!),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              // Show tiny info window or navigate to task?
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${t.title} (${t.bucket})'),
                                ),
                              );
                            },
                            child: Icon(
                              // If 'Reforestació' bucket -> Tree Icon, else generic Pin
                              isTree ? Icons.forest : Icons.location_on,
                              color: isTree ? Colors.green[800] : Colors.red,
                              size: 40,
                              shadows: const [
                                Shadow(blurRadius: 5, color: Colors.black54),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList();

                  return MarkerLayer(markers: markers);
                },
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              );
            },
          ),
        ],
      ),
    );
  }
}
