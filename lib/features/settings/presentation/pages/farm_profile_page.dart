import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:soca/features/settings/domain/entities/farm_config.dart';
import '../providers/settings_provider.dart';

import 'package:soca/features/settings/presentation/widgets/zone_edit_dialog.dart';

class FarmProfilePage extends ConsumerStatefulWidget {
  const FarmProfilePage({super.key});

  @override
  ConsumerState<FarmProfilePage> createState() => _FarmProfilePageState();
}

class _FarmProfilePageState extends ConsumerState<FarmProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cifController;
  late TextEditingController _addressController;

  LatLng? _mapCenter;
  final MapController _mapController = MapController();

  List<FarmZone> _zones = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // No need to read provider here, waiting for build data
    _nameController = TextEditingController();
    _cifController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cifController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _updateControllers(FarmConfig config) {
    if (_nameController.text.isEmpty && config.name.isNotEmpty) {
      _nameController.text = config.name;
    }
    if (_cifController.text.isEmpty && config.cif.isNotEmpty) {
      _cifController.text = config.cif;
    }
    if (_addressController.text.isEmpty && config.address.isNotEmpty) {
      _addressController.text = config.address;
    }
    _mapCenter ??= LatLng(config.latitude, config.longitude);
    // Only load zones once or if list is empty/initial load logic if needed
    // Simple approach: if controller is "pristine", load.
    // But since this is a real-time edit form, we might not want to overwrite user edits if stream updates.
    // Ideally we track if we initialized.
    if (_zones.isEmpty && config.zones.isNotEmpty) {
      _zones = List.from(config.zones);
    }
  }

  void _addZone() async {
    final newZone = await showDialog<FarmZone>(
      context: context,
      builder: (context) => const ZoneEditDialog(),
    );
    if (newZone != null) {
      setState(() => _zones.add(newZone));
    }
  }

  void _editZone(FarmZone zone) async {
    final updatedZone = await showDialog<FarmZone>(
      context: context,
      builder: (context) => ZoneEditDialog(zone: zone),
    );
    if (updatedZone != null) {
      setState(() {
        final index = _zones.indexWhere((z) => z.id == zone.id);
        if (index != -1) {
          _zones[index] = updatedZone;
        }
      });
    }
  }

  void _deleteZone(FarmZone zone) {
    setState(() => _zones.removeWhere((z) => z.id == zone.id));
  }

  Future<void> _save(FarmConfig currentConfig) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final newConfig = currentConfig.copyWith(
        name: _nameController.text,
        cif: _cifController.text,
        address: _addressController.text,
        latitude: _mapCenter?.latitude,
        longitude: _mapCenter?.longitude,
        zoom: _mapController.camera.zoom,
        zones: _zones,
      );

      await ref.read(settingsRepositoryProvider).saveFarmConfig(newConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuració de la Finca guardada! 💾'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error guardant: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(farmConfigStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de la Finca')),
      body: configAsync.when(
        data: (config) {
          // Initialize controllers only once with data
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateControllers(config);
          });

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Dades Generals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la Finca',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => v!.isEmpty ? 'Introdueix un nom' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cifController,
                  decoration: const InputDecoration(
                    labelText: 'CIF / NIF',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adreça',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Configuració del Mapa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Mou el mapa per definir el punt central d\'inici de l\'app.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:
                                _mapCenter ??
                                LatLng(config.latitude, config.longitude),
                            initialZoom: config.zoom,
                            onPositionChanged: (pos, hasGesture) {
                              if (hasGesture) {
                                _mapCenter = pos.center;
                              }
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.soca.app',
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Zonificació',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: _addZone,
                    ),
                  ],
                ),
                if (_zones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No hi ha zones definides.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ..._zones.map((zone) {
                    final color = Color(int.parse(zone.colorHex, radix: 16));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color),
                        title: Text(zone.name),
                        subtitle: Text(zone.cropType),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editZone(zone),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteZone(zone),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _save(config),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'GUARDANT...' : 'GUARDAR CONFIGURACIÓ',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
