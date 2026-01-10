import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/watering_event.dart';

import '../../domain/entities/ai_analysis_entry.dart';
import '../../../../core/services/ai_service.dart';
import 'species_selector.dart';

import '../providers/trees_provider.dart';
import '../../data/repositories/species_repository.dart';
import '../pages/watering_page.dart';
import '../pages/location_picker_page.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/species.dart';
import '../pages/species_library_page.dart';
import '../pages/tree_growth_timeline_page.dart';
import 'growth_entry_form_sheet.dart';
import '../../domain/entities/growth_entry.dart';

class TreeDetail extends ConsumerStatefulWidget {
  final Tree tree;

  const TreeDetail({super.key, required this.tree});

  @override
  ConsumerState<TreeDetail> createState() => _TreeDetailState();
}

class _TreeDetailState extends ConsumerState<TreeDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  bool _isAnalyzing = false;

  // Controllers
  late TextEditingController _commonNameController;
  late TextEditingController _speciesController;
  late TextEditingController _notesController;
  late TextEditingController _providerController;
  late TextEditingController _priceController;
  late TextEditingController _ecologicalFuncController;
  late TextEditingController _plantingFormatController;
  late TextEditingController _referenceController;

  // State
  late DateTime _plantingDate;
  late LatLng _location;
  late String _status;
  String? _vigor;
  String? _selectedSpeciesId; // Added for Species Library Link

  int _aiHistoryLimit = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeControllers();
  }

  void _initializeControllers() {
    _commonNameController = TextEditingController(text: widget.tree.commonName);
    _speciesController = TextEditingController(text: widget.tree.species);
    _notesController = TextEditingController(text: widget.tree.notes);
    _providerController = TextEditingController(text: widget.tree.provider);
    _priceController = TextEditingController(
      text: widget.tree.price?.toString() ?? '',
    );
    _ecologicalFuncController = TextEditingController(
      text: widget.tree.ecologicalFunction,
    );
    _plantingFormatController = TextEditingController(
      text: widget.tree.plantingFormat,
    );
    _referenceController = TextEditingController(
      text: widget.tree.reference ?? '',
    );

    _plantingDate = widget.tree.plantingDate;
    _location = LatLng(widget.tree.latitude, widget.tree.longitude);
    _status = widget.tree.status;
    _vigor = widget.tree.vigor;
    _selectedSpeciesId = widget.tree.speciesId; // Init from tree
  }

  @override
  void didUpdateWidget(TreeDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tree.id != oldWidget.tree.id) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commonNameController.dispose();
    _speciesController.dispose();
    _notesController.dispose();
    _providerController.dispose();
    _priceController.dispose();
    _ecologicalFuncController.dispose();
    _plantingFormatController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    // Check for duplicate reference
    final newRef = _referenceController.text.trim().toUpperCase();
    if (newRef.isNotEmpty) {
      final trees = await ref.read(treesStreamProvider.future);
      final isDuplicate = trees.any(
        (t) => t.reference == newRef && t.id != widget.tree.id,
      );

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Referència "$newRef" ja existeix useu-ne una altra.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final updatedTree = widget.tree.copyWith(
      commonName: _commonNameController.text,
      species: _speciesController.text,
      notes: _notesController.text,
      provider: _providerController.text,
      price: double.tryParse(_priceController.text),
      ecologicalFunction: _ecologicalFuncController.text,
      plantingFormat: _plantingFormatController.text,
      plantingDate: _plantingDate,
      latitude: _location.latitude,
      longitude: _location.longitude,
      status: _status,
      vigor: _vigor,
      speciesId: _selectedSpeciesId, // Included in update
      reference: newRef.isEmpty ? null : newRef,
    );

    await ref.read(treesRepositoryProvider).updateTree(updatedTree);

    if (mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canvis guardats correctament')),
        );
      } catch (e) {
        // Ignore context errors if widget is deactivated
        debugPrint('Error showing snackbar: $e');
      }
      setState(() {
        _isEditing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              actions: [
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add_task),
                    tooltip: 'Vincular Tasca',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vincular Tasca: Pendent d\'implementar',
                          ),
                        ),
                      );
                    },
                  ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel·lar',
                    onPressed: () {
                      setState(() {
                        _initializeControllers(); // Revert changes
                        _isEditing = false;
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit),
                  tooltip: _isEditing ? 'Guardar' : 'Editar',
                  onPressed: () {
                    if (_isEditing) {
                      _saveChanges();
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.water_drop, color: Colors.blueAccent),
                  tooltip: 'Reg Ràpid',
                  onPressed: () => _showQuickWateringSheet(context),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _isEditing
                      ? 'Editant...'
                      : '${widget.tree.commonName}\n(${widget.tree.species})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                background: GestureDetector(
                  onTap: () {
                    if (widget.tree.photoUrl != null) {
                      _showFullImage(context, widget.tree.photoUrl!);
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.tree.photoUrl != null)
                        Image.network(
                          widget.tree.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.green);
                          },
                        )
                      else
                        Container(color: Colors.green),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Resum/IA'),
                    Tab(text: 'Tècnica'),
                    Tab(text: 'Ubicació'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSummaryTab(),
            _buildTechnicalTab(),
            _buildLocationTab(),
          ],
        ),
      ),
    );
  }

  // ... (rest of methods)

  // Skip down to _showFullImage update
  // Since replace_file_content must be contiguous, and these are far apart (header at ~200, _showFullImage at ~1646),
  // I must use multi_replace_file_content.
  // Wait, I am using replace_file_content tool here. I cannot do both.
  // I'll cancel this tool call and use multi_replace_file_content.

  // --- TABS ---

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // AI Cards
          Row(
            children: [
              Expanded(
                child: _buildCompactCard(
                  'Salut',
                  _status,
                  Icons.health_and_safety,
                  _getStatusColor(_status),
                  isDropdown: _isEditing,
                  dropdownItems: ['Viable', 'Malalt', 'Mort'],
                  onChanged: (val) => setState(() => _status = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactCard(
                  'Vigor',
                  _vigor ?? 'N/A',
                  Icons.speed,
                  Colors.blue,
                  isDropdown: _isEditing,
                  dropdownItems: ['Alt', 'Mitjà', 'Baix'],
                  onChanged: (val) => setState(() => _vigor = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Analyze Button
          if (!_isAnalyzing)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _analyzeTree,
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                label: const Text('ANALITZAR AMB GEMINI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Analitzant imatge amb Gemini AI...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Notes
          TextFormField(
            controller: _notesController,
            enabled: _isEditing,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Notes i Observacions',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
            ),
          ),

          const SizedBox(height: 24),

          // Gallery (Visual Diary - Moved below notes)
          _buildEvolutionGallery(context),

          const SizedBox(height: 24),

          // AI History
          _buildAIHistory(context),
        ],
      ),
    );
  }

  // --- AI ANALYSIS ---

  Future<void> _analyzeTree() async {
    if (widget.tree.photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cal una foto per analitzar l\'arbre')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // 1. Gather Context
      String leafType = 'Desconegut';
      if (widget.tree.speciesId != null) {
        final species = await ref
            .read(speciesRepositoryProvider)
            .getSpeciesById(widget.tree.speciesId!);
        if (species != null) {
          leafType = species.leafType;
        }
      } else {
        // Fallback: Try offline lookup by name if ID missing
        final offline = ref
            .read(speciesRepositoryProvider)
            .findOfflineSpecies(widget.tree.species);
        if (offline != null) {
          leafType = offline.leafType;
        }
      }

      final ageDays = DateTime.now()
          .difference(widget.tree.plantingDate)
          .inDays;
      final ageYears = (ageDays / 365).toStringAsFixed(1);
      final ageStr = '$ageYears anys';

      final result = await ref
          .read(aiServiceProvider)
          .analyzeTree(
            photoUrl: widget.tree.photoUrl!,
            species: widget.tree.species,
            format: widget.tree.plantingFormat ?? 'Desconegut',
            locationContext: 'La Floresta, Lleida',
            date: DateTime.now(),
            leafType: leafType,
            age: ageStr,
          );

      if (!mounted) {
        return;
      }

      // Show Confirmation Dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.auto_awesome,
            color: Colors.indigoAccent,
            size: 40,
          ),
          title: const Text('Anàlisi Gemini Completat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('S\'han detectat nous indicadors:'),
              const SizedBox(height: 12),
              Text(
                '• Salut: ${result.health}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '• Vigor: ${result.vigor}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Consell de l\'IA:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              Text(
                result.advice,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text('Vols actualitzar la fitxa amb aquestes dades?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('IGNORAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('ACTUALITZAR'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Update Tree
        final updatedTree = widget.tree.copyWith(
          status: result.health,
          vigor: result.vigor,
        );

        final repo = ref.read(treesRepositoryProvider);
        await repo.updateTree(updatedTree);

        // Add History
        final entry = AIAnalysisEntry(
          id: '',
          date: DateTime.now(),
          health: result.health,
          vigor: result.vigor,
          advice: result.advice,
        );
        await repo.addAIHistoryEntry(widget.tree.id, entry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fitxa actualitzada per I.A.')),
          );
          setState(() {
            _status = result.health;
            _vigor = result.vigor;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error en l\'anàlisi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _deleteAIEntry(String entryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esborrar registre'),
        content: const Text(
          'Estàs segur que vols esborrar aquest consell de l\'històric?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL·LAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ESBORRAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(treesRepositoryProvider)
          .deleteAIHistoryEntry(widget.tree.id, entryId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registre esborrat')));
      }
    }
  }

  Widget _buildAIHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Consells de l\'IA (Històric)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<AIAnalysisEntry>>(
          stream: ref
              .watch(treesRepositoryProvider)
              .getAIHistoryStream(widget.tree.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Cap anàlisi registrada.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final visibleEntries = entries.take(_aiHistoryLimit).toList();

            return Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleEntries.length,
                  itemBuilder: (context, index) {
                    final entry = visibleEntries[index];
                    return Card(
                      elevation: 0,
                      color: Colors.indigo.shade50,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy').format(entry.date),
                                  style: TextStyle(
                                    color: Colors.indigo.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildTag(
                                      entry.health,
                                      _getStatusColor(entry.health),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildTag(entry.vigor, Colors.blue),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _deleteAIEntry(
                                        entry.id,
                                      ), // Assuming entry has ID
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.advice,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (entries.length > _aiHistoryLimit)
                  TextButton(
                    onPressed: () => setState(() => _aiHistoryLimit += 3),
                    child: const Text(
                      'VEURE MÉS',
                      style: TextStyle(color: Colors.indigo),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTechnicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!_isEditing) ...[
            if (widget.tree.reference != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  children: [
                    Text(
                      'REFERÈNCIA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade300,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.tree.reference!,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.indigo.shade900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            _buildBotanicalInfo(),
          ],
          if (_isEditing) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: TextField(
                controller: _referenceController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'REFERÈNCIA ÚNICA',
                  hintText: 'EX: OLI-005',
                  labelStyle: TextStyle(
                    color: Colors.indigo.shade400,
                    letterSpacing: 1.0,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.tag, color: Colors.indigo),
                ),
              ),
            ),
            TextField(
              controller: _commonNameController,
              decoration: const InputDecoration(labelText: 'Nom Comú'),
            ),
            const SizedBox(height: 12),
            SpeciesSelector(
              initialValue: _speciesController.text,
              onChanged: (val) {
                setState(() {
                  _speciesController.text = val;
                  _selectedSpeciesId = null; // Unlink if manual typing
                });
              },
              onSpeciesSelected: (species) {
                setState(() {
                  _speciesController.text = species.scientificName;
                  _commonNameController.text = species.commonName;
                  _selectedSpeciesId = species.id;
                  _ecologicalFuncController.text = species.fruit
                      ? 'Fruit'
                      : 'Ornamental';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Vinculat a: ${species.commonName} (Kc: ${species.kc})',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: MediaQuery.of(context).size.width > 600
                ? 2.5
                : 2.0,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildEditableGridItem(
                'Data Plantació',
                DateFormat('dd/MM/yyyy').format(_plantingDate),
                Icons.calendar_today,
                onTap: _isEditing
                    ? () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _plantingDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _plantingDate = picked);
                        }
                      }
                    : null,
              ),

              _buildEditableGridItem(
                'Preu (€)',
                _priceController.text,
                Icons.euro,
                controller: _priceController,
                isNumber: true,
              ),
              _buildEditableGridItem(
                'Proveïdor',
                _providerController.text,
                Icons.store,
                controller: _providerController,
              ),
              _buildEditableGridItem(
                'Format',
                _plantingFormatController.text,
                Icons.inventory_2,
                controller: _plantingFormatController,
                isDropdown: true,
                dropdownItems: [
                  'Alvèol forestal',
                  'Arrel nua',
                  'Contenidor',
                  'Estaca',
                ],
                onChanged: (val) =>
                    setState(() => _plantingFormatController.text = val!),
              ),
              _buildEditableGridItem(
                'Funció',
                _ecologicalFuncController.text,
                Icons.eco,
                controller: _ecologicalFuncController,
                isDropdown: true,
                dropdownItems: [
                  'Nitrogenadora',
                  'Fusta',
                  'Fruit',
                  'Ombra',
                  'Ornamental',
                ],
                onChanged: (val) =>
                    setState(() => _ecologicalFuncController.text = val!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _location,
                  initialZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ), // Static map
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://geoserveis.icgc.cat/icc_mapesmultibase/noutm/wmts/orto/GRID3857/{z}/{x}/{y}.jpeg',
                    userAgentPackageName: 'com.soca.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _location,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isEditing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black12,
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_location),
                        label: const Text('Modificar Ubicació'),
                        onPressed: () async {
                          final newLoc = await Navigator.push<LatLng>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LocationPickerPage(
                                initialLocation: _location,
                              ),
                            ),
                          );
                          if (newLoc != null) {
                            setState(() => _location = newLoc);
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('Obrir Google Maps'),
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${_location.latitude},${_location.longitude}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
            ),
          ),
        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WateringPage(initialTreeId: widget.tree.id),
                    ),
                  );
                },
                icon: const Icon(Icons.history_edu),
                label: const Text('VEURE HISTÒRIC DE REG'),
              ),
            ),
          ),
      ],
    );
  }

  // --- QUICK WATERING (Replaces Watering Tab) ---

  void _showQuickWateringSheet(BuildContext context) {
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Reg Ràpid: ${widget.tree.commonName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWaterOption(context, 2),
                  _buildWaterOption(context, 5),
                  _buildWaterOption(context, 8),
                  _buildCustomWaterOption(context),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterOption(BuildContext context, double liters) {
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
          note: 'Reg Ràpid',
        );
        await ref
            .read(treesRepositoryProvider)
            .addWateringEvent(widget.tree.id, event);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Afegits ${liters.toInt()}L a ${widget.tree.commonName}',
              ),
            ),
          );
        }
      },
      icon: const Icon(Icons.water_drop),
      label: Text('${liters.toInt()}L'),
    );
  }

  Widget _buildCustomWaterOption(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
      ),
      onPressed: () {
        Navigator.pop(context);
        _showCustomWaterDialog(context);
      },
      child: const Text('Altres...'),
    );
  }

  Future<void> _showCustomWaterDialog(BuildContext context) async {
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
                  note: 'Reg Manual',
                );
                await ref
                    .read(treesRepositoryProvider)
                    .addWateringEvent(widget.tree.id, event);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Afegits ${val.toInt()}L a ${widget.tree.commonName}',
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

  // --- EVOLUTION ---

  // --- EVOLUTION ---

  // State for comparison
  bool _isComparisonMode = false;
  final List<String> _selectedForComparison = [];

  Widget _buildEvolutionGallery(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Diari Visual (Evolució)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            if (!_isEditing)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TreeGrowthTimelinePage(tree: widget.tree),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('HISTÒRIC'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isComparisonMode = !_isComparisonMode;
                        _selectedForComparison.clear();
                      });
                    },
                    icon: Icon(_isComparisonMode ? Icons.close : Icons.compare),
                    label: Text(_isComparisonMode ? 'CANCEL·LAR' : 'COMPARAR'),
                  ),
                ],
              ),
          ],
        ),
        if (_isComparisonMode)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Selecciona 2 fotos per comparar (${_selectedForComparison.length}/2)',
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (_isComparisonMode && _selectedForComparison.length == 2)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showComparisonView,
              icon: const Icon(Icons.compare_arrows),
              label: const Text('VEURE COMPARACIÓ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 12),
        StreamBuilder<List<GrowthEntry>>(
          stream: ref
              .watch(treesRepositoryProvider)
              .getGrowthEntriesStream(widget.tree.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            var entries = snapshot.data ?? [];

            // Prepend Main Image if exists and not already in list (simple check by url)
            if (widget.tree.photoUrl != null) {
              final mainUrl = widget.tree.photoUrl!;
              final exists = entries.any((e) => e.photoUrl == mainUrl);
              if (!exists) {
                final mainEntry = GrowthEntry(
                  id: 'MAIN_PHOTO',
                  date: widget.tree.plantingDate,
                  photoUrl: mainUrl,
                  height: 0,
                  trunkDiameter: 0,
                  healthStatus: 'Inicial',
                  observations: 'Foto Principal',
                );
                entries = [mainEntry, ...entries];
              }
            }

            if (entries.isEmpty) {
              return _buildEmptyGalleryState();
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: entries.length + (_isEditing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isEditing && index == 0) {
                  // Add Button
                  return InkWell(
                    onTap: () => _takeEvolutionPhoto(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.indigo.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 30,
                            color: Colors.indigo,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Afegir',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final entry = entries[index - (_isEditing ? 1 : 0)];
                final isSelected = _selectedForComparison.contains(
                  entry.photoUrl,
                );

                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isComparisonMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedForComparison.remove(entry.photoUrl);
                            } else {
                              if (_selectedForComparison.length < 2) {
                                _selectedForComparison.add(entry.photoUrl);
                              }
                            }
                          });
                        } else {
                          _showEvolutionPhotoDetail(context, entry);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.indigo, width: 3)
                              : null,
                          image: DecorationImage(
                            image: NetworkImage(entry.photoUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yy').format(entry.date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (_isComparisonMode && isSelected)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.indigo,
                          size: 20,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showComparisonView() {
    if (_selectedForComparison.length != 2) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Comparació d\'Evolució')),
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Image.network(
                          _selectedForComparison[0],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                    Container(width: 2, color: Colors.white),
                    Expanded(
                      child: InteractiveViewer(
                        child: Image.network(
                          _selectedForComparison[1],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGalleryState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Encara no hi ha fotos.',
              style: TextStyle(color: Colors.grey),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _takeEvolutionPhoto(),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('AFEGIR PRIMERA FOTO'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _takeEvolutionPhoto() async {
    final source = await _showImageSourceActionSheet(context);
    if (source == null) {
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image != null && mounted) {
      // 1. Show Form Sheet to get details
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const GrowthEntryFormSheet(),
      );

      if (result == null) {
        return;
      }

      // Proceed with upload even if context unmounted (common on Android transitions)

      // 2. Upload Image
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pujant foto i dades...')));
      }

      final url = await ref
          .read(treesRepositoryProvider)
          .uploadEvolutionImage(image, widget.tree.id);

      if (url != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Guardant dades...')));
        }
        // 3. Create Growth Entry
        final entry = GrowthEntry(
          id: '',
          date: DateTime.now(),
          photoUrl: url,
          height: result['height'],
          trunkDiameter: result['diameter'],
          healthStatus: result['status'],
          observations: result['observations'],
        );

        await ref
            .read(treesRepositoryProvider)
            .addGrowthEntry(widget.tree.id, entry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seguiment registrat correctament!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error pujant la imatge.')),
          );
        }
      }
    }
  }

  void _showEvolutionPhotoDetail(BuildContext context, GrowthEntry entry) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 400,
              color: Colors.black, // Dark background for better contrast
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        entry.photoUrl,
                        fit: BoxFit.contain, // Ensure full image is visible
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(entry.date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (entry.observations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(entry.observations),
                    ),
                  const SizedBox(height: 16),
                  if (entry.id != 'MAIN_PHOTO')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.wallpaper),
                      label: const Text('ESTABLIR COM A FOTO PRINCIPAL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () async {
                        // Update Tree Main Photo
                        final updatedTree = widget.tree.copyWith(
                          photoUrl: entry.photoUrl,
                        );
                        await ref
                            .read(treesRepositoryProvider)
                            .updateTree(updatedTree);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Foto principal actualitzada'),
                            ),
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                  if (entry.id != 'MAIN_PHOTO')
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'ELIMINAR FOTO',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar foto?'),
                            content: const Text(
                              'Aquesta acció no es pot desfer. S\'eliminarà del diari i de l\'històric.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('CANCEL·LAR'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('ELIMINAR'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          await ref
                              .read(treesRepositoryProvider)
                              .deleteGrowthEntry(widget.tree.id, entry.id);
                          if (context.mounted) {
                            Navigator.pop(context); // Close Detail Dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Foto eliminada correctament'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildCompactCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isDropdown = false,
    List<String>? dropdownItems,
    Function(String?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isDropdown && dropdownItems != null)
            DropdownButton<String>(
              value: dropdownItems.contains(value) ? value : null,
              isExpanded: true,
              isDense: true,
              underline: Container(),
              items: dropdownItems
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            )
          else
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableGridItem(
    String label,
    String value,
    IconData icon, {
    TextEditingController? controller,
    bool isNumber = false,
    bool isDropdown = false,
    List<String>? dropdownItems,
    Function(String?)? onChanged,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_isEditing && isDropdown && dropdownItems != null)
            DropdownButton<String>(
              value: dropdownItems.contains(value) ? value : null,
              isExpanded: true,
              isDense: true,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 13,
              ),
              underline: Container(), // Remove underline
              items: dropdownItems
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            )
          else if (_isEditing && controller != null)
            TextField(
              controller: controller,
              keyboardType: isNumber
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            )
          else if (_isEditing && onTap != null)
            InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit, size: 14),
                ],
              ),
            )
          else
            Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'viable':
        return Colors.green;
      case 'mort':
        return Colors.red;
      case 'malalt':
        return Colors.orange;
      default:
        return Colors.blueGrey;
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

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: 400,
          color: Colors.black, // Dark background for better contrast
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BOTANICAL CARD ---

  Widget _buildBotanicalInfo() {
    return FutureBuilder<Species?>(
      future: _fetchSpecies(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final species = snapshot.data!;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.indigo.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SpeciesLibraryPage(
                          initialSearchQuery: species.scientificName,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    species.scientificName,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo.shade900,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.indigo.shade200,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  species.commonName,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBotIcon(
                      species.leafType == 'Perenne' ? Icons.park : Icons.nature,
                      species.leafType,
                    ),
                    _buildBotIcon(
                      _getSunIconData(species.sunNeeds),
                      species.sunNeeds,
                    ),
                    _buildBotIcon(
                      Icons.ac_unit,
                      species.frostSensitivity.split(' ').first,
                    ), // Shorten
                    _buildBotIcon(
                      species.fruit ? Icons.restaurant : Icons.no_food,
                      species.fruit
                          ? (species.fruitType?.isNotEmpty == true
                                ? species.fruitType!
                                : 'Fruit')
                          : 'No',
                    ),
                    _buildBotIcon(Icons.water, 'Kc: ${species.kc}'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimeline('Poda', species.pruningMonths, Colors.orange),
                const SizedBox(height: 8),
                _buildTimeline('Collita', species.harvestMonths, Colors.green),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Species?> _fetchSpecies() async {
    if (widget.tree.speciesId != null) {
      return ref
          .read(speciesRepositoryProvider)
          .getSpeciesById(widget.tree.speciesId!);
    }
    return ref
        .read(speciesRepositoryProvider)
        .findOfflineSpecies(widget.tree.species);
  }

  IconData _getSunIconData(String s) {
    if (s.toLowerCase().contains('alt')) return Icons.wb_sunny;
    if (s.toLowerCase().contains('baix')) return Icons.cloud;
    return Icons.wb_twilight;
  }

  Widget _buildBotIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.indigo.shade400, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTimeline(String title, List<int> months, Color color) {
    const letters = [
      'G',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
    ];
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (i) {
              final active = months.contains(i + 1);
              return Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? color : Colors.transparent,
                  border: Border.all(
                    color: active ? color : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  letters[i],
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? Colors.white : Colors.grey,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: Colors.white, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
