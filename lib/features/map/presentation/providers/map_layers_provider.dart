import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapLayer {
  tasks,
  pendingTasksOnly, // New: Filter to show only pending tasks
  irrigationZones,
  healthStatus,
  treeLabels,
  satellite,
  useOpenStreetMap,
  permacultureZones,
  plantedTrees, // New: Show planted trees
  provisionalTrees, // New: Show ONLY planned/provisional trees (exclusive)
  adultCanopy, // New: Show "Adult" size circle for planned trees
}

class MapLayersNotifier extends Notifier<Map<MapLayer, bool>> {
  @override
  Map<MapLayer, bool> build() {
    _loadPreferences();
    return {
      MapLayer.tasks: true,
      MapLayer.pendingTasksOnly: true, // Default: show only pending
      MapLayer.irrigationZones: false,
      MapLayer.healthStatus: false,
      MapLayer.treeLabels: false,
      MapLayer.satellite: true,
      MapLayer.useOpenStreetMap: false,
      MapLayer.permacultureZones: false,
      MapLayer.plantedTrees: true, // Default: show planted trees
      MapLayer.provisionalTrees: false, // Default: hide planned trees
      MapLayer.adultCanopy: true, // Default: show adult canopy ring
    };
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = {
        MapLayer.tasks: prefs.getBool('layer_tasks') ?? true,
        MapLayer.pendingTasksOnly:
            prefs.getBool('layer_pendingTasksOnly') ?? true,
        MapLayer.irrigationZones:
            prefs.getBool('layer_irrigationZones') ?? false,
        MapLayer.healthStatus: prefs.getBool('layer_healthStatus') ?? false,
        MapLayer.treeLabels: prefs.getBool('layer_treeLabels') ?? false,
        MapLayer.satellite: prefs.getBool('layer_satellite') ?? true,
        MapLayer.useOpenStreetMap:
            prefs.getBool('layer_useOpenStreetMap') ?? false,
        MapLayer.permacultureZones:
            prefs.getBool('layer_permacultureZones') ?? false,
        MapLayer.plantedTrees: prefs.getBool('layer_plantedTrees') ?? true,
        MapLayer.provisionalTrees:
            prefs.getBool('layer_provisionalTrees') ?? false,
        MapLayer.adultCanopy: prefs.getBool('layer_adultCanopy') ?? true,
      };
    } catch (e) {
      // Gracefully handle missing plugin or other errors
      // print('Error loading map preferences: $e'); // Disabled for production rules
    }
  }

  Future<void> toggleLayer(MapLayer layer) async {
    final newState = {...state, layer: !state[layer]!};
    state = newState;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('layer_${layer.name}', newState[layer]!);
  }

  Future<void> setLayer(MapLayer layer, bool isVisible) async {
    if (state[layer] == isVisible) return;

    final newState = {...state, layer: isVisible};
    state = newState;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('layer_${layer.name}', isVisible);
  }
}

final mapLayersProvider =
    NotifierProvider<MapLayersNotifier, Map<MapLayer, bool>>(() {
      return MapLayersNotifier();
    });
