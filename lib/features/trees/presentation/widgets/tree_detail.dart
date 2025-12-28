import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/watering_event.dart';
import '../../domain/entities/evolution_entry.dart';
import '../../domain/entities/ai_analysis_entry.dart';
import '../../../../core/services/ai_service.dart';

import '../providers/trees_provider.dart';
import '../../domain/entities/tree.dart';

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

  // State
  late DateTime _plantingDate;
  late LatLng _location;
  late String _status;
  String? _vigor;

  int _aiHistoryLimit = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

    _plantingDate = widget.tree.plantingDate;
    _location = LatLng(widget.tree.latitude, widget.tree.longitude);
    _status = widget.tree.status;
    _vigor = widget.tree.vigor;
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
    super.dispose();
  }

  Future<void> _saveChanges() async {
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
    );

    await ref.read(treesRepositoryProvider).updateTree(updatedTree);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvis guardats correctament')),
      );
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
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.tree.photoUrl != null)
                      GestureDetector(
                        onTap: () =>
                            _showFullImage(context, widget.tree.photoUrl!),
                        child: Image.network(
                          widget.tree.photoUrl!,
                          fit: BoxFit.cover,
                        ),
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
                    Tab(text: 'Reg'),
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
            _buildWateringTab(),
          ],
        ),
      ),
    );
  }

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
      final result = await ref
          .read(aiServiceProvider)
          .analyzeTree(
            photoUrl: widget.tree.photoUrl!,
            species: widget.tree.species,
            format: widget.tree.plantingFormat ?? 'Desconegut',
            locationContext: 'La Floresta, Lleida',
          );

      if (!mounted) return;

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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error en l\'anàlisi: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registre esborrat')));
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
        color: color.withOpacity(0.2),
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
          if (_isEditing) ...[
            TextField(
              controller: _commonNameController,
              decoration: const InputDecoration(labelText: 'Nom Comú'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _speciesController,
              decoration: const InputDecoration(labelText: 'Espècie'),
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
                        if (picked != null)
                          setState(() => _plantingDate = picked);
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
                              builder: (_) => _LocationPickerPage(
                                initialLocation: _location,
                              ),
                            ),
                          );
                          if (newLoc != null)
                            setState(() => _location = newLoc);
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
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWateringTab() {
    return StreamBuilder<List<WateringEvent>>(
      stream: ref
          .watch(treesRepositoryProvider)
          .getWateringEventsStream(widget.tree.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data ?? [];

        // Calculate Totals
        final now = DateTime.now();
        final currentMonthEvents = events.where(
          (e) => e.date.year == now.year && e.date.month == now.month,
        );
        final totalLiters = currentMonthEvents.fold(
          0.0,
          (sum, e) => sum + e.liters,
        );
        final lastRegDate = events.isNotEmpty ? events.first.date : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary Section
              Row(
                children: [
                  Expanded(
                    child: _buildCompactCard(
                      'Total Mes',
                      '${totalLiters.toStringAsFixed(1)} L',
                      Icons.water_drop,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactCard(
                      'Últim Reg',
                      lastRegDate != null
                          ? DateFormat('dd/MM').format(lastRegDate)
                          : 'Mai',
                      Icons.calendar_today,
                      Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Add Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('AFEGIR REG MANUAL'),
                  onPressed: () => _showAddWateringDialog(context),
                ),
              ),

              const SizedBox(height: 24),

              // History List
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Darrers Regs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.take(5).length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.water_drop, color: Colors.blue),
                      ),
                      title: Text(
                        '${event.liters} Litres',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(event.date),
                          ),
                          if (event.note != null && event.note!.isNotEmpty)
                            Text(
                              event.note!,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteWatering(context, event),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteWatering(
    BuildContext context,
    WateringEvent event,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esborrar Reg'),
        content: const Text(
          'Estàs segur que vols esborrar aquest registre de reg?',
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
          .deleteWateringEvent(widget.tree.id, event.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reg esborrat correctament')),
        );
      }
    }
  }

  // --- EVOLUTION ---

  Widget _buildEvolutionGallery(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Diari Visual (Evolució)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: StreamBuilder<List<EvolutionEntry>>(
            stream: ref
                .watch(treesRepositoryProvider)
                .getEvolutionStream(widget.tree.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data ?? [];

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length + 1, // +1 for Add Button
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Add Button
                    return Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade400,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _takeEvolutionPhoto(context),
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(
                          Icons.add_a_photo,
                          size: 32,
                          color: Colors.blueGrey,
                        ),
                      ),
                    );
                  }

                  final entry = entries[index - 1]; // Offset by 1
                  return GestureDetector(
                    onTap: () => _showEvolutionPhotoDetail(context, entry),
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(entry.photoUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _takeEvolutionPhoto(BuildContext context) async {
    final source = await _showImageSourceActionSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image != null && context.mounted) {
      // Show Note Dialog? Or just upload?
      // Simple flow: Dialog to confirm/add note
      final noteController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nova Foto Evolució'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                image.path,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image),
              ), // For web/io compatibility issues, Image.file is usually generic
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL·LAR'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Upload and Save
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pujant foto...')));
        final repo = ref.read(treesRepositoryProvider);
        final url = await repo.uploadEvolutionImage(image, widget.tree.id);

        if (url != null) {
          final entry = EvolutionEntry(
            id: '', // Generated
            photoUrl: url,
            date: DateTime.now(),
            note: noteController.text,
          );
          await repo.addEvolutionEntry(widget.tree.id, entry);
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto guardada correctament')),
            );
        } else {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al pujar la foto')),
            );
        }
      }
    }
  }

  void _showEvolutionPhotoDetail(BuildContext context, EvolutionEntry entry) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Image.network(
                  entry.photoUrl,
                  fit: BoxFit.cover,
                  height: 300,
                  width: double.infinity,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
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
                  if (entry.note != null && entry.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(entry.note!),
                    ),
                  const SizedBox(height: 16),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWateringDialog(BuildContext context) {
    final litersController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nou Reg Manual',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: litersController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Litres',
                border: OutlineInputBorder(),
                suffixText: 'L',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Comentari (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final liters = double.tryParse(litersController.text);
                if (liters != null) {
                  final event = WateringEvent(
                    id: '', // Generated by Firestore or ignored on add
                    date: DateTime.now(),
                    liters: liters,
                    note: noteController.text,
                  );
                  await ref
                      .read(treesRepositoryProvider)
                      .addWateringEvent(widget.tree.id, event);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('GUARDAR REG'),
            ),
            const SizedBox(height: 24),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
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

class _LocationPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  const _LocationPickerPage({required this.initialLocation});
  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  late LatLng _currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moure el marcador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _currentLocation),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 19,
              onTap: (_, point) {
                setState(() => _currentLocation = point);
              },
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
                    point: _currentLocation,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _currentLocation),
              child: const Text('CONFIRMAR POSICIÓ'),
            ),
          ),
        ],
      ),
    );
  }
}
