import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/tree.dart';
import '../providers/trees_provider.dart';
import '../pages/location_picker_page.dart';
import '../../../../core/services/ai_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

import 'species_selector.dart';

class TreeFormSheet extends ConsumerStatefulWidget {
  final Tree? tree;

  const TreeFormSheet({super.key, this.tree});

  @override
  ConsumerState<TreeFormSheet> createState() => _TreeFormSheetState();
}

class _TreeFormSheetState extends ConsumerState<TreeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _speciesController;
  late TextEditingController _commonNameController;
  late TextEditingController _notesController;
  late TextEditingController _providerController;
  late TextEditingController _priceController;
  late TextEditingController _padrinoController;

  late TextEditingController _maintenanceTipsController;
  late TextEditingController _referenceController;

  late DateTime _plantingDate;
  late String _status;
  String? _ecologicalFunction;
  String? _plantingFormat;
  String? _vigor;
  String? _selectedSpeciesId; // For Species Library Link
  String? _selectedZoneId;

  bool _isVeteran = false;
  late TextEditingController _initialAgeController;
  late TextEditingController _heightController;
  late TextEditingController _diameterController;

  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  XFile? _imageFile; // Changed to XFile
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isAnalyzing = false;

  Future<void> _identifyTree() async {
    if (_imageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Primer fes una foto.')));
      }
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final info = await ref.read(aiServiceProvider).identifyTree(_imageFile!);

      if (mounted) {
        setState(() {
          if (info['species'] != null) {
            _speciesController.text = info['species'];
          }
          if (info['commonName'] != null) {
            _commonNameController.text = info['commonName'];
          }

          final status = info['status'];
          if (['Viable', 'Malalt', 'Mort'].contains(status)) {
            _status = status;
          } else if (status == 'Desconegut') {
            _status = 'Desconegut';
          }

          if (info['notes'] != null) _notesController.text = info['notes'];

          if (info['ecologicalFunction'] != null) {
            final eco = info['ecologicalFunction'];
            if ([
              'Nitrogenadora',
              'Fusta',
              'Fruit',
              'Tallavent/Visual',
              'Biomassa',
              'Ornamental',
            ].contains(eco)) {
              _ecologicalFunction = eco;
            }
          }

          if (info['vigor'] != null) {
            final vig = info['vigor'];
            if (['Alt', 'Mitjà', 'Baix'].contains(vig)) {
              _vigor = vig;
            }
          }

          if (info['maintenanceTips'] != null) {
            _maintenanceTipsController.text = info['maintenanceTips'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identificació completada!')),
        );
      }
    } catch (e) {
      debugPrint('AI Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error IA: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _speciesController = TextEditingController(
      text: widget.tree?.species ?? '',
    );
    _commonNameController = TextEditingController(
      text: widget.tree?.commonName ?? '',
    );
    _notesController = TextEditingController(text: widget.tree?.notes ?? '');
    _providerController = TextEditingController(
      text: widget.tree?.provider ?? '',
    );
    _priceController = TextEditingController(
      text: widget.tree?.price?.toString() ?? '',
    );
    _padrinoController = TextEditingController(
      text: widget.tree?.padrino ?? '',
    );
    _maintenanceTipsController = TextEditingController(
      text: widget.tree?.maintenanceTips ?? '',
    );
    _referenceController = TextEditingController(
      text: widget.tree?.reference ?? '',
    );
    _initialAgeController = TextEditingController(
      text: widget.tree?.initialAge.toString() ?? '0.0',
    );
    _heightController = TextEditingController(
      text: widget.tree?.height?.toString() ?? '',
    );
    _diameterController = TextEditingController(
      text: widget.tree?.trunkDiameter?.toString() ?? '',
    );

    _plantingDate = widget.tree?.plantingDate ?? DateTime.now();
    _status = widget.tree?.status ?? 'Viable';
    _ecologicalFunction = widget.tree?.ecologicalFunction;
    _plantingFormat = widget.tree?.plantingFormat;
    _vigor = widget.tree?.vigor;
    _latitude = widget.tree?.latitude;
    _longitude = widget.tree?.longitude;
    _selectedSpeciesId = widget.tree?.speciesId;
    _selectedZoneId = widget.tree?.zoneId;
    _isVeteran = widget.tree?.isVeteran ?? false;

    if (widget.tree == null) {
      _fetchLocation();
    }
  }

  @override
  void dispose() {
    _speciesController.dispose();
    _initialAgeController.dispose();
    _heightController.dispose();
    _diameterController.dispose();
    _commonNameController.dispose();
    _notesController.dispose();
    _providerController.dispose();
    _priceController.dispose();
    _padrinoController.dispose();

    _maintenanceTipsController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error obtenint GPS: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final source = await _showImageSourceActionSheet(context);
      if (source == null) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionant imatge: $e')),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceActionSheet(BuildContext context) async {
    if (kIsWeb) return ImageSource.gallery;
    return await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fer Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Triar de la Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Falta la ubicació GPS')));
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(treesRepositoryProvider);

    // Generate ID directly here if new (or if passed with empty ID)
    final String id;
    if (widget.tree != null && widget.tree!.id.isNotEmpty) {
      id = widget.tree!.id;
    } else {
      id = DateTime.now().millisecondsSinceEpoch.toString();
    }

    String? photoUrl = widget.tree?.photoUrl;
    if (_imageFile != null) {
      photoUrl = await repo.uploadTreeImage(_imageFile!, id);
    }

    final tree = Tree(
      id: id,
      species: _speciesController.text,
      commonName: _commonNameController.text,
      photoUrl: photoUrl,
      latitude: _latitude!,
      longitude: _longitude!,
      plantingDate: _plantingDate,
      status: _status,
      notes: _notesController.text,
      ecologicalFunction: _ecologicalFunction,
      plantingFormat: _plantingFormat,
      provider: _providerController.text.isEmpty
          ? null
          : _providerController.text,
      price: double.tryParse(_priceController.text),
      padrino: _padrinoController.text.isEmpty ? null : _padrinoController.text,
      maintenanceTips: _maintenanceTipsController.text.isEmpty
          ? null
          : _maintenanceTipsController.text,
      vigor: _vigor,
      speciesId: _selectedSpeciesId,
      zoneId: _selectedZoneId,
      reference: _referenceController.text.isEmpty
          ? null
          : _referenceController.text,
      isVeteran: _isVeteran,
      initialAge: double.tryParse(_initialAgeController.text) ?? 0.0,
      height: double.tryParse(_heightController.text),
      trunkDiameter: double.tryParse(_diameterController.text),
    );

    if (widget.tree == null || widget.tree!.id.isEmpty) {
      await repo.addTree(tree);
    } else {
      await repo.updateTree(tree);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.park,
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.tree == null ? 'Nou Arbre' : 'Editar Arbre',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),

              Expanded(
                child: ListView(
                  children: [
                    // Photo
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imageFile != null
                              ? kIsWeb
                                    ? Image.network(
                                        _imageFile!.path,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                      )
                                    : Image.file(
                                        File(_imageFile!.path),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                      )
                              : (widget.tree?.photoUrl != null)
                              ? Image.network(
                                  widget.tree!.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                        Text(
                                          'Error carregant imatge',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    Text(
                                      'Clica per fer foto',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_imageFile != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_isSaving || _isAnalyzing)
                              ? null
                              : _identifyTree,
                          icon: _isAnalyzing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.purple,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.purple,
                                ),
                          label: Text(
                            _isAnalyzing
                                ? 'ANALITZANT...'
                                : 'IDENTIFICAR AMB IA',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.purple),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // GPS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed, color: Colors.blue),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ubicació GPS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                if (_isLoadingLocation)
                                  const Text(
                                    'Obtenint coordenades...',
                                    style: TextStyle(fontSize: 12),
                                  )
                                else if (_latitude != null)
                                  Text(
                                    '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 12),
                                  )
                                else
                                  const Text(
                                    'Sense ubicació',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            onPressed: _fetchLocation,
                            tooltip: 'Actualitzar posició',
                          ),
                          IconButton(
                            icon: const Icon(Icons.map, color: Colors.blue),
                            onPressed: () async {
                              final initial =
                                  (_latitude != null && _longitude != null)
                                  ? LatLng(_latitude!, _longitude!)
                                  : const LatLng(
                                      41.561580,
                                      0.931707,
                                    ); // Default La Floresta

                              final picked = await Navigator.push<LatLng>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LocationPickerPage(
                                    initialLocation: initial,
                                  ),
                                ),
                              );

                              if (picked != null) {
                                setState(() {
                                  _latitude = picked.latitude;
                                  _longitude = picked.longitude;
                                });
                              }
                            },
                            tooltip: 'Triar al mapa',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _commonNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom Comú (ex: Alzina)',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v!.isEmpty ? 'Cal posar un nom' : null,
                    ),
                    const SizedBox(height: 16),
                    // Species Autocomplete
                    // Species Autocomplete
                    SpeciesSelector(
                      initialValue: _speciesController.text,
                      onChanged: (val) {
                        _speciesController.text = val;
                        _selectedSpeciesId = null; // Unlink
                      },
                      onSpeciesSelected: (species) async {
                        setState(() {
                          _speciesController.text = species.scientificName;
                          _commonNameController.text = species.commonName;
                          _selectedSpeciesId = species.id;
                          _ecologicalFunction ??= species.fruit
                              ? 'Fruit'
                              : 'Ornamental';
                        });

                        // Generate Reference automatically
                        final refStr = await ref
                            .read(treesRepositoryProvider)
                            .generateTreeReference(species.prefix);

                        if (context.mounted) {
                          // Only update if empty (don't overwrite custom input)
                          if (_referenceController.text.isEmpty) {
                            _referenceController.text = refStr;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Referència suggerida: $refStr'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Referència (ex: OLI-005)',
                        border: OutlineInputBorder(),
                        helperText: 'Codi únic per etiqueta',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),

                    const SizedBox(height: 16),
                    // Zone Dropdown (Dynamic from FarmConfig)
                    Consumer(
                      builder: (context, ref, child) {
                        final configAsync = ref.watch(farmConfigStreamProvider);
                        return configAsync.when(
                          data: (config) {
                            if (config.permacultureZones.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String?>(
                                  key: ValueKey('zone_$_selectedZoneId'),
                                  decoration: const InputDecoration(
                                    labelText: 'Zona PDC',
                                    border: OutlineInputBorder(),
                                  ),
                                  initialValue: _selectedZoneId,
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Cap (Sense zona)'),
                                    ),
                                    ...config.permacultureZones.map((zone) {
                                      Color color;
                                      try {
                                        color = Color(int.parse(zone.colorHex));
                                      } catch (_) {
                                        color = Colors.grey;
                                      }
                                      return DropdownMenuItem<String?>(
                                        value: zone.id,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color,
                                              radius: 8,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(zone.name),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _selectedZoneId = v);
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, s) => const SizedBox.shrink(),
                        );
                      },
                    ),

                    // AGE LOGIC
                    SwitchListTile(
                      title: const Text('Arbre Pre-existent (Veterà)'),
                      subtitle: const Text(
                        'Si marques això, s\'ignora la data de plantació.',
                      ),
                      value: _isVeteran,
                      onChanged: (val) => setState(() => _isVeteran = val),
                    ),
                    const SizedBox(height: 8),

                    if (!_isVeteran) ...[
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _plantingDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _plantingDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data de Plantació',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _initialAgeController,
                        decoration: const InputDecoration(
                          labelText: 'Edat Inicial a la plantació (anys)',
                          helperText:
                              'Quants anys tenia l\'arbre quan el vas plantar? (ex: 0.5, 2)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _initialAgeController,
                        decoration: const InputDecoration(
                          labelText: 'Edat Estimada (anys)',
                          helperText:
                              'Edat aproximada actual de l\'arbre veterà.',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // END AGE LOGIC
                    const SizedBox(height: 16),

                    // END AGE LOGIC
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Alçada (cm)',
                              border: OutlineInputBorder(),
                              suffixText: 'cm',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _diameterController,
                            decoration: const InputDecoration(
                              labelText: 'Diàmetre Tronc (cm)',
                              border: OutlineInputBorder(),
                              suffixText: 'cm',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('status_$_status'),
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Estat',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Viable', 'Malalt', 'Mort', 'Desconegut']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // Forestry Data
                    DropdownButtonFormField<String>(
                      key: ValueKey('eco_$_ecologicalFunction'),
                      initialValue: _ecologicalFunction,
                      decoration: const InputDecoration(
                        labelText: 'Funció Ecològica',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                                'Nitrogenadora',
                                'Fusta',
                                'Fruit',
                                'Ombra',
                                'Ornamental',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _ecologicalFunction = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('format_$_plantingFormat'),
                      initialValue: _plantingFormat,
                      decoration: const InputDecoration(
                        labelText: 'Format de Plantació',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                                'Existent',
                                'Alvèol forestal',
                                'Contenidor 3L',
                                'Contenidor 10L',
                                'Contenidor 20L',
                                'Arrel nua',
                                'Estaca',
                                'Llavor',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _plantingFormat = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('vigor_$_vigor'),
                      initialValue: _vigor,
                      decoration: const InputDecoration(
                        labelText: 'Vigor',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Alt', 'Mitjà', 'Baix']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _vigor = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _providerController,
                            decoration: const InputDecoration(
                              labelText: 'Proveïdor',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Preu (€)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _padrinoController,
                      decoration: const InputDecoration(
                        labelText: 'Padrí (Responsable)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maintenanceTipsController,
                      decoration: const InputDecoration(
                        labelText: 'Consells Manteniment (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || _isAnalyzing) ? null : _save,
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
                  label: Text(_isSaving ? 'GUARDANT...' : 'GUARDAR ARBRE'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
