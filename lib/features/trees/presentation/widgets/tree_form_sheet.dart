import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/tree.dart';
import '../providers/trees_provider.dart';

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

  late DateTime _plantingDate;
  late String _status;
  String? _ecologicalFunction;
  String? _plantingFormat;
  String? _vigor;

  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  XFile? _imageFile; // Changed to XFile
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  Future<void> _identifyTree() async {
    if (_imageFile == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Primer fes una foto.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final result = await FirebaseFunctions.instance
          .httpsCallable('identifyTree')
          .call({'image': base64Image, 'mimeType': 'image/jpeg'});

      final data = result.data as Map;
      final info = Map<String, dynamic>.from(data);

      if (mounted) {
        setState(() {
          if (info['species'] != null)
            _speciesController.text = info['species'];
          if (info['commonName'] != null)
            _commonNameController.text = info['commonName'];

          final status = info['status'];
          if (['Viable', 'Malalt', 'Mort'].contains(status)) {
            _status = status;
          } else if (status == 'Desconegut') {
            _status = 'Desconegut';
          }

          if (info['notes'] != null) _notesController.text = info['notes'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identificació completada!')),
        );
      }
    } catch (e) {
      debugPrint('AI Error: $e');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error IA: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    _plantingDate = widget.tree?.plantingDate ?? DateTime.now();
    _status = widget.tree?.status ?? 'Viable';
    _ecologicalFunction = widget.tree?.ecologicalFunction;
    _plantingFormat = widget.tree?.plantingFormat;
    _vigor = widget.tree?.vigor;
    _latitude = widget.tree?.latitude;
    _longitude = widget.tree?.longitude;

    if (widget.tree == null) {
      _fetchLocation();
    }
  }

  @override
  void dispose() {
    _speciesController.dispose();
    _commonNameController.dispose();
    _notesController.dispose();
    _providerController.dispose();
    _priceController.dispose();
    _padrinoController.dispose();
    _maintenanceTipsController.dispose();
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
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
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

    // Generate ID directly here if new
    final id =
        widget.tree?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

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
    );

    if (widget.tree == null) {
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
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(_imageFile!.path)
                                      : FileImage(File(_imageFile!.path))
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : (widget.tree?.photoUrl != null)
                              ? DecorationImage(
                                  image: NetworkImage(widget.tree!.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            _imageFile == null && widget.tree?.photoUrl == null
                            ? const Column(
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
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_imageFile != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _identifyTree,
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.purple,
                          ),
                          label: const Text(
                            'IDENTIFICAR AMB IA',
                            style: TextStyle(
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
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                    TextFormField(
                      controller: _speciesController,
                      decoration: const InputDecoration(
                        labelText: 'Espècie (Científic)',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v!.isEmpty ? 'Cal posar l\'espècie' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _status,
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
                      value: _ecologicalFunction,
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
                      value: _plantingFormat,
                      decoration: const InputDecoration(
                        labelText: 'Format de Plantació',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                                'Alvèol forestal',
                                'Contenidor 3L',
                                'Arrel nua',
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
                      value: _vigor,
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
                  onPressed: _isSaving ? null : _save,
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
