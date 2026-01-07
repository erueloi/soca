import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:soca/features/settings/domain/entities/farm_config.dart';
import '../../../../core/services/meteocat_service.dart';
import '../../../climate/data/repositories/climate_repository.dart';
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
  String? _stationCode; // Hoist state

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
    // Init station code if not set locally
    if (_stationCode == null && config.meteocatStationCode != null) {
      _stationCode = config.meteocatStationCode;
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
        meteocatStationCode: _stationCode ?? currentConfig.meteocatStationCode,
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

                // --- Meteocat Integration Section ---
                const Text(
                  'Integració Meteocat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _MeteocatSection(
                  latitude: _mapCenter?.latitude ?? config.latitude,
                  longitude: _mapCenter?.longitude ?? config.longitude,
                  initialStationCode: config.meteocatStationCode,
                  onStationChanged: (code) {
                    setState(() => _stationCode = code);
                  },
                ),

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

class _MeteocatSection extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;
  final String? initialStationCode;
  final Function(String) onStationChanged;

  const _MeteocatSection({
    required this.latitude,
    required this.longitude,
    this.initialStationCode,
    required this.onStationChanged,
  });

  @override
  ConsumerState<_MeteocatSection> createState() => _MeteocatSectionState();
}

class _MeteocatSectionState extends ConsumerState<_MeteocatSection> {
  String? _stationCode;
  Map<String, dynamic>? _quota;
  bool _loading = false;
  bool _quotaSaverEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(meteocatServiceProvider);

    // Load Station - Prefer prop if fresh load, else cache
    // Actually, local cache is "source of truth for this device until save"
    // BUT we want to show what's in Config if provided.
    // Let's use service cache as base, but if widget prop is set, maybe that?
    // Let's stick to: Service finds it.

    String? code = await service.getCachedStationCode();
    // If cache matches initial, good. If initial is different (from Firestore), show initial?
    if (widget.initialStationCode != null &&
        widget.initialStationCode != code) {
      code = widget.initialStationCode;
      // Also sync service locally
      await service.setCachedStation(code!);
    }

    // Load Quota
    final quota = await service.getQuota();

    // Load Saver Status
    final saver = await service.isQuotaSaverEnabled;

    if (mounted) {
      setState(() {
        _stationCode = code;
        _quota = quota;
        _quotaSaverEnabled = saver;
      });
      // Notify parent of initial load
      if (code != null) widget.onStationChanged(code);
    }
  }

  Future<void> _refreshStation() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(meteocatServiceProvider);
      final newCode = await service.refreshStation(
        widget.latitude,
        widget.longitude,
      );

      if (mounted) {
        setState(() => _stationCode = newCode);
        widget.onStationChanged(newCode!); // Notify Parent
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estació actualitzada: $newCode')),
        );
        // Refresh quota too just in case
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error actualitzant estació: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Estació Meteocat: ${_stationCode ?? "Desconeguda"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Basada en: ${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _refreshStation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualitzar estació (segons mapa)'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final repo = ref.read(climateRepositoryProvider);
                      await repo.generateMockData();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dades Mock Generades! 🧪'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.science, color: Colors.orange),
                    label: const Text('Generar Dades Test (Mock)'),
                  ),
                ],
              ),
            const Divider(height: 24),
            const Text(
              'Consum API',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_quota == null)
              const Text('Carregant quota...')
            else if (_quota!.containsKey('error'))
              Text(
                'Error: ${_quota!['error']}',
                style: const TextStyle(color: Colors.red),
              )
            else ...[
              _buildQuotaInfo(_quota!),
            ],
            const SizedBox(height: 16),
            // Quota Saver Toggle
            SwitchListTile(
              title: const Text('Mode Estalvi de Quota'),
              subtitle: const Text(
                'Si s\'activa, no es descarregaran dades històriques per estalviar API.',
              ),
              value: _quotaSaverEnabled,
              secondary: Icon(
                _quotaSaverEnabled ? Icons.savings : Icons.history,
                color: _quotaSaverEnabled ? Colors.green : Colors.grey,
              ),
              onChanged: (val) {
                _toggleQuotaSaver(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleQuotaSaver(bool enabled) async {
    final service = ref.read(meteocatServiceProvider);
    await service.setQuotaSaver(enabled);
    setState(() => _quotaSaverEnabled = enabled);

    // Show simplified value (don't refresh quota as user might be saving)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Mode Estalvi Activat 🛡️' : 'Mode Estalvi Desactivat 🌍',
          ),
        ),
      );
    }
  }

  Widget _buildQuotaInfo(Map<String, dynamic> data) {
    try {
      final plans = data['plans'] as List;
      if (plans.isEmpty) return const Text('Sense plans actius');

      // Assume first plan is the relevant one or look for one with limits
      final plan = plans.firstWhere(
        (p) => p.containsKey('maxConsultes'),
        orElse: () => plans.first,
      );

      final max = plan['maxConsultes'] ?? 0;
      final remaining = plan['consultesRestants'] ?? 0;
      final used = max - remaining;
      final percent = max > 0 ? (used / max) : 0.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pla: ${plan['nom'] ?? "Desconegut"}'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percent.toDouble(),
            backgroundColor: Colors.grey[200],
            color: (percent > 0.9) ? Colors.red : Colors.green,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '$used / $max consultes (${(percent * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    } catch (e) {
      return const Text('Format de quota desconegut');
    }
  }
}
