// ignore_for_file: deprecated_member_use
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
import '../../domain/entities/tree_extensions.dart';
import '../../domain/entities/species.dart';
import '../pages/species_library_page.dart';
import '../pages/tree_growth_timeline_page.dart';
import 'growth_entry_form_sheet.dart';
import 'tree_photo_gallery_page.dart';
import '../../domain/entities/growth_entry.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/domain/entities/farm_config.dart';
import '../../../map/presentation/pages/map_page.dart';

class TreeDetail extends ConsumerStatefulWidget {
  // ... (start of class remains same)

  // ... (jump to the button row area)

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

  late TextEditingController _initialAgeController;
  late TextEditingController _heightController;
  late TextEditingController _diameterController;

  // State
  late DateTime _plantingDate;
  late LatLng _location;
  late String _status;
  bool _isVeteran = false; // Added state
  String? _vigor;
  String? _selectedSpeciesId; // Added for Species Library Link
  String? _selectedZoneId; // [NEW] PDC Zone

  late Tree _displayTree;

  int _aiHistoryLimit = 3;

  @override
  void initState() {
    super.initState();
    _displayTree = widget.tree;
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
    _initialAgeController = TextEditingController(
      text: widget.tree.initialAge.toString(),
    );
    _heightController = TextEditingController(
      text: widget.tree.height?.toString() ?? '',
    );
    _diameterController = TextEditingController(
      text: widget.tree.trunkDiameter?.toString() ?? '',
    );

    _plantingDate = widget.tree.plantingDate;
    _location = LatLng(widget.tree.latitude, widget.tree.longitude);
    _status = widget.tree.status;
    _isVeteran = widget.tree.isVeteran; // Init
    _vigor = widget.tree.vigor;
    _selectedSpeciesId = widget.tree.speciesId; // Init from tree
    _selectedZoneId = widget.tree.zoneId; // [NEW] Init from tree
  }

  @override
  void didUpdateWidget(TreeDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tree.id != oldWidget.tree.id) {
      _displayTree = widget.tree;
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
    _initialAgeController.dispose();
    _heightController.dispose();
    _diameterController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    // Cache messenger before async gaps
    final messenger = ScaffoldMessenger.of(context);

    // Check for duplicate reference
    final newRef = _referenceController.text.trim().toUpperCase();
    if (newRef.isNotEmpty) {
      final trees = await ref.read(treesStreamProvider.future);
      final isDuplicate = trees.any(
        (t) => t.reference == newRef && t.id != widget.tree.id,
      );

      if (isDuplicate) {
        if (mounted) {
          messenger.showSnackBar(
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
      initialAge: double.tryParse(_initialAgeController.text) ?? 0.0,
      height: double.tryParse(_heightController.text),
      trunkDiameter: double.tryParse(_diameterController.text),
      ecologicalFunction: _ecologicalFuncController.text,
      plantingFormat: _plantingFormatController.text,
      plantingDate: _plantingDate,
      latitude: _location.latitude,
      longitude: _location.longitude,
      status: _status,
      vigor: _vigor,
      isVeteran: _isVeteran, // Save state
      speciesId: _selectedSpeciesId, // Included in update
      zoneId: _selectedZoneId, // [NEW] Save zone
      reference: newRef.isEmpty ? null : newRef,
    );

    await ref.read(treesRepositoryProvider).updateTree(updatedTree);

    if (mounted) {
      try {
        messenger.showSnackBar(
          const SnackBar(content: Text('Canvis guardats correctament')),
        );
      } catch (e) {
        debugPrint('Error showing snackbar: $e');
      }
      setState(() {
        _isEditing = false;
        _displayTree = updatedTree;
      });
    }
  }

  /// Shows a dialog to confirm planting with date and price, then updates tree status
  Future<void> _confirmPlanting() async {
    DateTime selectedDate = DateTime.now();
    final priceController = TextEditingController(
      text: widget.tree.price?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
          title: const Text('Confirmar Plantació'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estàs a punt de convertir aquest arbre planificat en un arbre real.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    helpText: 'Data de Plantació',
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Plantació',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Preu de compra (€)',
                  hintText: 'Opcional',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL·LAR'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('CONFIRMAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final price = double.tryParse(priceController.text);
    priceController.dispose();

    // Update tree in Firestore
    final updatedTree = widget.tree.copyWith(
      status: 'Viable',
      plantingDate: selectedDate,
      price: price,
    );

    await ref.read(treesRepositoryProvider).updateTree(updatedTree);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arbre confirmat com a plantat!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _status = 'Viable';
        _plantingDate = selectedDate;
        _displayTree = updatedTree;
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
                      : '${_displayTree.commonName}\n(${_displayTree.species})',
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
                    if (_displayTree.photoUrl != null) {
                      _openHeaderPhotoGallery();
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_displayTree.photoUrl != null)
                        Image.network(
                          _displayTree.photoUrl!,
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
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Planned Tree Banner
          if (_displayTree.status == 'Planned')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.withValues(alpha: 0.15),
                    Colors.deepPurple.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.deepPurple,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Arbre Planificat',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.deepPurple,
                              ),
                            ),
                            Text(
                              'Aquest arbre és provisional i no afecta les estadístiques',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // CONFIRM PLANTING
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _confirmPlanting,
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                          ),
                          label: const Text('PLANTAR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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

          _buildAgeCard(),
          _buildDimensionsCard(),
          _buildIrrigationCard(),
          const SizedBox(height: 24),

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

    // Show optional question dialog
    final questionController = TextEditingController();
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, color: Colors.indigoAccent),
        title: const Text('Analitzar amb Gemini'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pots afegir una pregunta específica per a l\'IA (opcional):',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: questionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'p.ex. "El podem podar?", "Estan bé les fulles?"',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('ANALITZAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    final userQuestion = questionController.text.trim();
    questionController.dispose();

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
            height: widget.tree.height,
            diameter: widget.tree.trunkDiameter,
            userQuestion: userQuestion.isNotEmpty ? userQuestion : null,
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
              if (result.estimatedAgeYears != null) ...[
                Text(
                  '• Edat Visual (IA): ${result.estimatedAgeYears} anys',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.tree.initialAge > 0)
                  const Text(
                    '(Ja té edat definida, no s\'actualitzarà)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
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
        // Update Tree
        // Only update initialAge if it was 0 (undefined)
        double initialAgeToSave = widget.tree.initialAge;
        if (initialAgeToSave == 0.0 &&
            result.estimatedAgeYears != null &&
            result.estimatedAgeYears! > 0) {
          // Calculate initialAge offset: Gemini Age - Time Since Planting
          // If tree planted today, initialAge = Gemini Age.
          // If planted 2 years ago, initialAge = Gemini Age - 2.
          final yearsPlanted =
              DateTime.now().difference(widget.tree.plantingDate).inDays /
              365.25;

          double calculatedInitial = result.estimatedAgeYears! - yearsPlanted;
          if (calculatedInitial < 0) calculatedInitial = 0;

          initialAgeToSave = calculatedInitial;
        }

        final updatedTree = widget.tree.copyWith(
          status: result.health,
          vigor: result.vigor,
          initialAge: initialAgeToSave,
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
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!_isEditing) ...[
            if (widget.tree.reference != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapPage(initialTreeId: widget.tree.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                        const SizedBox(height: 4),
                        Text(
                          '(Veure al Mapa)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                : 1.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              if (_isEditing)
                if (_isEditing)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Veterà / Pre-existent',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isVeteran,
                            onChanged: (val) {
                              setState(() {
                                _isVeteran = val;
                                if (val) {
                                  _plantingFormatController.text = 'Existent';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  'Existent',
                  'Alvèol forestal',
                  'Contenidor 3L',
                  'Contenidor 10L',
                  'Contenidor 20L',
                  'Arrel nua',
                  'Estaca',
                  'Llavor',
                ],
                onChanged: (val) =>
                    setState(() => _plantingFormatController.text = val!),
              ),
              _buildEditableGridItem(
                'Edat Inicial',
                '${_initialAgeController.text} anys',
                Icons.history,
                controller: _initialAgeController,
                isNumber: true,
              ),
              _buildEditableGridItem(
                'Alçada (cm)',
                '${_heightController.text} cm',
                Icons.height,
                controller: _heightController,
                isNumber: true,
              ),
              _buildEditableGridItem(
                'Diàmetre (cm)',
                '${_diameterController.text} cm',
                Icons.circle_outlined,
                controller: _diameterController,
                isNumber: true,
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

        // [NEW] Zone PDC Section (Promoted above buttons)
        Consumer(
          builder: (context, ref, child) {
            final configAsync = ref.watch(farmConfigStreamProvider);
            return configAsync.when(
              data: (config) {
                if (config.permacultureZones.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (_isEditing) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('zone_$_selectedZoneId'),
                      decoration: const InputDecoration(
                        labelText: 'Zona PDC',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.grid_view, color: Colors.blue),
                      ),
                      initialValue: _selectedZoneId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Cap (Sense zona)'),
                        ),
                        ...config.permacultureZones.map((zone) {
                          return DropdownMenuItem<String?>(
                            value: zone.id,
                            child: Text(zone.name),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedZoneId = v),
                    ),
                  );
                } else {
                  // View mode
                  final zone = config.permacultureZones
                      .cast<PermacultureZone?>()
                      .firstWhere(
                        (z) => z?.id == _selectedZoneId,
                        orElse: () => null,
                      );

                  final hasZone = zone != null;
                  // Fix: add 0x prefix for hex parsing
                  Color color;
                  try {
                    color = hasZone
                        ? Color(int.parse('0x${zone.colorHex}'))
                        : Colors.grey.shade400;
                  } catch (e) {
                    color = Colors.grey.shade400;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0,
                      left: 16.0,
                      right: 16.0,
                    ),
                    child: Card(
                      elevation: 0,
                      color: color.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          radius: 12,
                          child: Icon(
                            hasZone ? Icons.grid_view : Icons.grid_off,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          hasZone ? zone.name : 'Sense zona PDC',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        subtitle: const Text('Zona de Permacultura PDC'),
                      ),
                    ),
                  );
                }
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            );
          },
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
        const SizedBox(height: 24),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildWaterOption(context, 2),
                    _buildWaterOption(context, 5),
                    _buildWaterOption(context, 8),
                    if (widget.tree.waterNeedLiters > 0 && ![2, 5, 8].contains(widget.tree.waterNeedLiters))
                      _buildWaterOption(context, widget.tree.waterNeedLiters.toDouble()),
                    _buildCustomWaterOption(context),
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

  Widget _buildWaterOption(BuildContext context, double liters) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade800,
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
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

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Afegits ${liters.toInt()}L a ${widget.tree.commonName}',
            ),
          ),
        );
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              final valStr = controller.text.replaceAll(',', '.');
              final val = double.tryParse(valStr);
              if (val != null && val > 0) {
                final messenger = ScaffoldMessenger.of(dialogContext);
                Navigator.pop(dialogContext);
                final event = WateringEvent(
                  id: '',
                  date: DateTime.now(),
                  liters: val,
                  note: 'Reg Manual',
                );
                await ref
                    .read(treesRepositoryProvider)
                    .addWateringEvent(widget.tree.id, event);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Afegits ${val.toInt()}L a ${widget.tree.commonName}',
                    ),
                  ),
                );
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
                          final adjustedIndex = index - (_isEditing ? 1 : 0);
                          _showEvolutionPhotoDetail(
                            context,
                            entries,
                            adjustedIndex,
                          );
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

      // 2. Show blocking loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Pujant foto...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      try {
        // 3. Upload Image
        final url = await ref
            .read(treesRepositoryProvider)
            .uploadEvolutionImage(image, widget.tree.id);

        if (url != null) {
          // 4. Create Growth Entry
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

          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Seguiment registrat correctament!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Close loading dialog and show error
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error pujant la imatge.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        // Close loading dialog on error
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showEvolutionPhotoDetail(
    BuildContext context,
    List<GrowthEntry> allEntries,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TreePhotoGalleryPage(
          entries: allEntries,
          initialIndex: initialIndex,
          tree: widget.tree,
        ),
      ),
    );
  }

  Future<void> _openHeaderPhotoGallery() async {
    final currentMainUrl = _displayTree.photoUrl ?? widget.tree.photoUrl;
    if (currentMainUrl == null) return;

    List<GrowthEntry> entries = [];
    try {
      final streamEntries = await ref
          .read(treesRepositoryProvider)
          .getGrowthEntriesStream(widget.tree.id)
          .first
          .timeout(const Duration(seconds: 2));
      entries = List<GrowthEntry>.from(streamEntries);
    } catch (_) {
      entries = [];
    }

    final exists = entries.any((e) => e.photoUrl == currentMainUrl);
    if (!exists) {
      final mainEntry = GrowthEntry(
        id: 'MAIN_PHOTO',
        date: widget.tree.plantingDate,
        photoUrl: currentMainUrl,
        height: 0,
        trunkDiameter: 0,
        healthStatus: 'Inicial',
        observations: 'Foto Principal',
      );
      entries = [mainEntry, ...entries];
    }

    if (mounted) {
      int targetIndex = entries.indexWhere((e) => e.photoUrl == currentMainUrl);
      if (targetIndex < 0) targetIndex = 0;

      _showEvolutionPhotoDetail(context, entries, targetIndex);
    }
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
                const SizedBox(height: 16),
                // Row 1: General Needs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBotIcon(
                      species.leafType == 'Perenne' ? Icons.park : Icons.nature,
                      species.leafType,
                      'Tipus de Fulla',
                    ),
                    _buildBotIcon(
                      _getSunIconData(species.sunNeeds),
                      species.sunNeeds,
                      'Necessitat de Sol',
                    ),
                    _buildBotIcon(
                      Icons.ac_unit,
                      species.frostSensitivity.split(' ').first,
                      'Sensibilitat a Gelades',
                    ),
                    _buildBotIcon(
                      Icons.water,
                      'Kc: ${species.kc}',
                      'Coeficient de cultiu (Kc)',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Row 2: Growth & Dimensions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBotIcon(
                      Icons.height,
                      '${species.adultHeight}m',
                      'Alçada Adulta',
                    ),
                    _buildBotIcon(
                      Icons.circle_outlined,
                      'Ø ${species.adultDiameter}m',
                      'Diàmetre Adult',
                    ),
                    _buildBotIcon(
                      Icons.speed,
                      species.growthRate,
                      'Ritme de Creixement',
                    ),
                    _buildBotIcon(
                      Icons.water_drop,
                      List.generate(
                        species.droughtResistance,
                        (_) => '💧',
                      ).join(),
                      'Resistència Sequera',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTimeline(
                  'Plant.',
                  species.plantingMonths,
                  Colors.green.shade700,
                ),
                const SizedBox(height: 8),
                _buildTimeline('Poda', species.pruningMonths, Colors.orange),
                const SizedBox(height: 8),
                _buildTimeline('Collita', species.harvestMonths, Colors.green),
                const SizedBox(height: 8),
                _buildTimeline(
                  'Flor.',
                  species.floweringMonths,
                  Colors.pinkAccent,
                ),
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

  Widget _buildBotIcon(IconData icon, String label, [String? tooltip]) {
    return Tooltip(
      message: tooltip ?? label,
      child: Column(
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
      ),
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

  Widget _buildAgeCard() {
    final now = DateTime.now();
    final planted = _displayTree.plantingDate;
    final yearsSincePlanting = now.difference(planted).inDays / 365.25;
    final totalAge = yearsSincePlanting + _displayTree.initialAge;

    // Formatting helper
    String formatAge(double years) {
      if (years < 1) {
        final months = (years * 12).round();
        return '$months mesos';
      } else {
        return '${years.toStringAsFixed(1)} anys';
      }
    }

    if (_displayTree.isVeteran) {
      return Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.history_edu, size: 40, color: Colors.amber),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ARBRE VETERÀ (Pre-existent)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  Text(
                    'Edat Estimada: ${formatAge(_displayTree.initialAge)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.timer, color: Colors.blue),
                const SizedBox(height: 4),
                const Text(
                  'Temps a finca',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  formatAge(yearsSincePlanting),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (!_displayTree.isVeteran)
                  Text(
                    'Des de: ${planted.day}/${planted.month}/${planted.year}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            Column(
              children: [
                const Icon(Icons.cake, color: Colors.green),
                const SizedBox(height: 4),
                const Text(
                  'Edat Biològica',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  formatAge(totalAge),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_displayTree.initialAge > 0)
                  Text(
                    '(Initial: ${formatAge(_displayTree.initialAge)})',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ), // Row
      ), // Padding
    ); // Card
  }

  Widget _buildDimensionsCard() {
    if ((_displayTree.height == null || _displayTree.height == 0) &&
        (_displayTree.trunkDiameter == null ||
            _displayTree.trunkDiameter == 0)) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (_displayTree.height != null && _displayTree.height! > 0)
              Column(
                children: [
                  const Icon(Icons.height, color: Colors.blue),
                  const SizedBox(height: 4),
                  const Text(
                    'Alçada',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${_displayTree.height!.toStringAsFixed(1)} cm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            if (_displayTree.height != null &&
                _displayTree.height! > 0 &&
                _displayTree.trunkDiameter != null &&
                _displayTree.trunkDiameter! > 0)
              Container(width: 1, height: 40, color: Colors.grey.shade300),
            if (_displayTree.trunkDiameter != null &&
                _displayTree.trunkDiameter! > 0)
              Column(
                children: [
                  const Icon(Icons.circle_outlined, color: Colors.brown),
                  const SizedBox(height: 4),
                  const Text(
                    'Diàmetre',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${_displayTree.trunkDiameter!.toStringAsFixed(1)} cm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIrrigationCard() {
    final hasDrip = _displayTree.dripEmitters > 0;
    final totalRate = _displayTree.totalDripRate;
    final needLiters = _displayTree.waterNeedLiters;
    final hours = _displayTree.recommendedWateringHours;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasDrip ? Icons.water_drop : Icons.pan_tool_alt_outlined,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        hasDrip
                            ? 'Gota a gota: ${_displayTree.dripEmitters} ${_displayTree.dripEmitters == 1 ? "degoter" : "degoters"} (${_displayTree.dripFlowRate.toStringAsFixed(1).replaceAll(".0", "")} L/h)'
                            : 'Manual (garrafa / mànega)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.blue),
                  tooltip: 'Configurar reg',
                  onPressed: () => _showDripConfigSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Balanced 3-column stats row (same aesthetic as dimensions and age cards)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Col 1: Installation
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          hasDrip ? Icons.opacity : Icons.water_outlined,
                          size: 20,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Instal·lació',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDrip ? '${_displayTree.dripEmitters} degoters' : 'Manual',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.grey.shade300),

                  // Col 2: Flow Rate
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.speed,
                          size: 20,
                          color: hasDrip ? Colors.orange.shade600 : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cabal total',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDrip
                              ? '${totalRate.toStringAsFixed(1).replaceAll(".0", "")} L/h'
                              : 'Sense degoters',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasDrip ? Colors.black87 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.grey.shade300),

                  // Col 3: Recommended support dose
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          size: 20,
                          color: needLiters > 0 ? Colors.blue.shade700 : Colors.green.shade600,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Necessitat',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          needLiters > 0
                              ? (hasDrip
                                  ? '$needLiters L (${hours.toStringAsFixed(1).replaceAll(".0", "")}h)'
                                  : '$needLiters L')
                              : '0 L (Òptim)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: needLiters > 0 ? Colors.blue.shade800 : Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action: Single full-width REGAR ARA button (config is accessed via top-right icon)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showQuickWateringSheet(context),
                icon: const Icon(Icons.water_drop, size: 18),
                label: const Text('REGAR ARA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDripCardOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.blue.shade900 : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showDripConfigSheet(BuildContext context) async {
    int mode = 1;
    if (_displayTree.dripEmitters == 0) {
      mode = 0;
    } else if (_displayTree.dripEmitters == 1 && (_displayTree.dripFlowRate - 4.0).abs() < 0.01) {
      mode = 1;
    } else if (_displayTree.dripEmitters == 2 && (_displayTree.dripFlowRate - 4.0).abs() < 0.01) {
      mode = 2;
    } else {
      mode = -1;
    }

    int selectedEmitters = _displayTree.dripEmitters;
    double selectedRate = _displayTree.dripFlowRate > 0 ? _displayTree.dripFlowRate : 4.0;
    final customEmittersController = TextEditingController(
      text: selectedEmitters > 0 ? selectedEmitters.toString() : '3',
    );
    final customRateController = TextEditingController(
      text: selectedRate > 0 ? selectedRate.toStringAsFixed(1).replaceAll('.0', '') : '4.0',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.tune, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Configurar Reg: ${_displayTree.commonName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tria el tipus d\'instal·lació de reg:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _buildDripCardOption(
                      icon: Icons.water_drop,
                      title: '1 degoter (4 L/h)',
                      subtitle: 'Arbres petits o joves (reg de 2h = 8 L)',
                      isSelected: mode == 1,
                      onTap: () {
                        setDialogState(() {
                          mode = 1;
                          selectedEmitters = 1;
                          selectedRate = 4.0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDripCardOption(
                      icon: Icons.opacity,
                      title: '2 degoters (8 L/h)',
                      subtitle: 'Arbres grans o fruiters (reg de 2h = 16 L)',
                      isSelected: mode == 2,
                      onTap: () {
                        setDialogState(() {
                          mode = 2;
                          selectedEmitters = 2;
                          selectedRate = 4.0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDripCardOption(
                      icon: Icons.pan_tool_alt_outlined,
                      title: 'Sense degoter (Manual)',
                      subtitle: 'Reg amb garrafa o mànega',
                      isSelected: mode == 0,
                      onTap: () {
                        setDialogState(() {
                          mode = 0;
                          selectedEmitters = 0;
                          selectedRate = 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDripCardOption(
                      icon: Icons.tune,
                      title: 'Personalitzat (Lliure)',
                      subtitle: 'Defineix nombre de degoters i cabal lliurement',
                      isSelected: mode == -1,
                      onTap: () {
                        setDialogState(() {
                          mode = -1;
                          selectedEmitters = int.tryParse(customEmittersController.text) ?? 3;
                          selectedRate = double.tryParse(customRateController.text) ?? 4.0;
                        });
                      },
                    ),
                    if (mode == -1) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: customEmittersController,
                                decoration: const InputDecoration(
                                  labelText: 'Nº Degoters',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedEmitters = int.tryParse(val) ?? 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: customRateController,
                                decoration: const InputDecoration(
                                  labelText: 'Cabal (L/h)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  suffixText: 'L/h',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedRate = double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedEmitters > 0 ? Colors.blue.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedEmitters > 0
                            ? 'Cabal resultant: ${(selectedEmitters * selectedRate).toStringAsFixed(1).replaceAll(".0", "")} L/h ($selectedEmitters degoters)'
                            : 'Reg Manual (Sense degoters instal·lats)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selectedEmitters > 0 ? Colors.blue.shade800 : Colors.grey.shade800,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL·LAR'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(treesRepositoryProvider).updateTreesDripConfig(
                    [_displayTree.id],
                    dripEmitters: selectedEmitters,
                    dripFlowRate: selectedRate,
                  );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() {
                      _displayTree = _displayTree.copyWith(
                        dripEmitters: selectedEmitters,
                        dripFlowRate: selectedRate,
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selectedEmitters > 0
                              ? 'Reg actualitzat: $selectedEmitters deg. (${(selectedEmitters * selectedRate).toStringAsFixed(1).replaceAll(".0", "")} L/h)'
                              : 'Reg actualitzat a Manual per a ${_displayTree.commonName}',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        },
      ),
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

