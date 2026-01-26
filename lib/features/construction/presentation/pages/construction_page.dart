import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' as import_image_picker;

import 'package:soca/features/construction/data/models/construction_point.dart';
import '../providers/construction_provider.dart';
import 'construction_floor_page.dart';
import 'pathology_detail_page.dart';

class ConstructionPage extends ConsumerStatefulWidget {
  const ConstructionPage({super.key});

  @override
  ConsumerState<ConstructionPage> createState() => _ConstructionPageState();
}

enum ConstructionView { floorPlans, interventions }

class _ConstructionPageState extends ConsumerState<ConstructionPage> {
  ConstructionView _currentView = ConstructionView.floorPlans;

  // Filter State
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;
  String _searchQuery = '';
  final Set<String> _filterStatuses = {};
  double _filterMinSeverity = 1.0;
  final Set<String> _filterTypes = {};
  final Set<String> _filterFloors = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConstructionPoint> _getFilteredPoints(
    List<ConstructionPoint> allPoints,
  ) {
    return allPoints.where((point) {
      final pathology = point.pathology;

      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final idMatch = point.id.toLowerCase().contains(_searchQuery);
        final titleMatch = (pathology?.title ?? '').toLowerCase().contains(
          _searchQuery,
        );
        final descMatch = (pathology?.description ?? '').toLowerCase().contains(
          _searchQuery,
        );
        if (!idMatch && !titleMatch && !descMatch) return false;
      }

      // 2. Status Filter
      if (_filterStatuses.isNotEmpty) {
        // Check point.status AND pathology.currentState because they might differ/sync
        // Prioritize point.status as it's the primary one for the grid
        if (!_filterStatuses.contains(point.status)) return false;
      }

      // 3. Priority (Severity) Filter
      if (pathology != null && (pathology.severity < _filterMinSeverity)) {
        return false;
      }

      // 4. Type Filter
      if (_filterTypes.isNotEmpty) {
        final typeName = pathology?.type.name.split('.').last;
        // Or handle direct enum to string mapping if user selects from string list
        if (typeName != null && !_filterTypes.contains(typeName)) return false;
      }

      // 5. Floor Filter
      if (_filterFloors.isNotEmpty) {
        if (!_filterFloors.contains(point.floorId)) return false;
      }

      return true;
    }).toList();
  }

  void _showFilterDialog(List<String> availableFloors) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtres Avançats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterStatuses.clear();
                          _filterMinSeverity = 1.0;
                          _filterTypes.clear();
                          _filterFloors.clear();
                        });
                        setModalState(() {});
                      },
                      child: const Text('Netejar tot'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'Estat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8,
                        children: ['Pendent', 'En Progrés', 'Finalitzat'].map((
                          status,
                        ) {
                          return FilterChip(
                            label: Text(status),
                            selected: _filterStatuses.contains(status),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _filterStatuses.add(status);
                                } else {
                                  _filterStatuses.remove(status);
                                }
                              });
                              setState(
                                () {},
                              ); // Update parent immediately or on close? Typically immediately for responsiveness
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Severitat Mínima',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _filterMinSeverity,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _filterMinSeverity.round().toString(),
                        onChanged: (val) {
                          setModalState(() => _filterMinSeverity = val);
                          setState(() => _filterMinSeverity = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tipus de Lesió',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8,
                        children: InjuryType.values.map((type) {
                          final typeName = type.name.split('.').last;
                          return FilterChip(
                            label: Text(typeName.toUpperCase()),
                            selected: _filterTypes.contains(typeName),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _filterTypes.add(typeName);
                                } else {
                                  _filterTypes.remove(typeName);
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      if (availableFloors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Planta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 8,
                          children: availableFloors.map((floor) {
                            return FilterChip(
                              label: Text(floor),
                              selected: _filterFloors.contains(floor),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    _filterFloors.add(floor);
                                  } else {
                                    _filterFloors.remove(floor);
                                  }
                                });
                                setState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('TANCAR'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltersBar(List<String> availableFloors) {
    int activeFiltersCount =
        _filterStatuses.length +
        _filterTypes.length +
        _filterFloors.length +
        (_filterMinSeverity > 1 ? 1 : 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cercar ID o descripció...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Badge(
                  isLabelVisible: activeFiltersCount > 0,
                  label: Text('$activeFiltersCount'),
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => _showFilterDialog(availableFloors),
                tooltip: 'Filtres',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
                tooltip: _isGridView ? 'Veure llista' : 'Veure quadrícula',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Obres de la Masia'), centerTitle: true),
      body: Column(
        children: [
          _buildToggle(),
          Expanded(
            child: _currentView == ConstructionView.floorPlans
                ? _buildFloorPlansList(ref)
                : _buildInterventionsList(ref),
          ),
        ],
      ),
      floatingActionButton: _currentView == ConstructionView.floorPlans
          ? FloatingActionButton.extended(
              onPressed: () => _showAddFloorDialog(context, ref),
              label: const Text('Afegir Planta'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: SegmentedButton<ConstructionView>(
        segments: const [
          ButtonSegment(
            value: ConstructionView.floorPlans,
            label: Text('Plànols'),
            icon: Icon(Icons.map),
          ),
          ButtonSegment(
            value: ConstructionView.interventions,
            label: Text('Actuacions'),
            icon: Icon(Icons.assignment),
          ),
        ],
        selected: {_currentView},
        onSelectionChanged: (Set<ConstructionView> newSelection) {
          setState(() {
            _currentView = newSelection.first;
          });
        },
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildFloorPlansList(WidgetRef ref) {
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);
    final floorPlans = floorPlansAsync.asData?.value ?? {};

    // Sort keys naturally or alphabetically
    final sortedFloors = floorPlans.keys.toList()..sort();

    return floorPlansAsync.when(
      // ... existing list content ...
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
      data: (_) {
        if (sortedFloors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.layers_clear, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No hi ha plantes definides.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _showAddFloorDialog(context, ref),
                  child: const Text('CREAR PRIMERA PLANTA'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: sortedFloors.length,
          itemBuilder: (context, index) {
            final floor = sortedFloors[index];
            final imageUrl = floorPlans[floor];

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: Border.all(color: Colors.transparent),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.layers_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                ),
                title: Text(
                  floor,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      _showRenameDialog(context, ref, floor);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, floor);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Canviar nom'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                children: [
                  SizedBox(
                    height: 400, // Increased height for web/desktop
                    width: double.infinity,
                    child: imageUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.5),
                                    ],
                                    stops: const [0.6, 1.0],
                                  ),
                                ),
                              ),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ConstructionFloorPage(
                                              floorId: floor,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_full),
                                  label: const Text('OBRIR PLÀNOL COMPLET'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Text('Error carregant imatge'),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? _getMostRecentImageUrl(PathologySheet? pathology) {
    if (pathology == null || pathology.photos.isEmpty) return null;

    // Create a copy to sort or reduce
    // Use reduce to find max by date
    final latest = pathology.photos.reduce((curr, next) {
      final currDate = curr.date ?? DateTime(2000);
      final nextDate = next.date ?? DateTime(2000);
      return nextDate.isAfter(currDate) ? next : curr;
    });

    return latest.url;
  }

  Widget _buildInterventionsList(WidgetRef ref) {
    final allPointsAsync = ref.watch(allConstructionPointsProvider);
    final floorPlansAsync = ref.watch(floorPlansStreamProvider);
    final availableFloors = floorPlansAsync.asData?.value.keys.toList() ?? [];
    // Sort logic handled in floorPlans keys usually but let's ensure
    availableFloors.sort();

    return allPointsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
      data: (allPoints) {
        final filteredPoints = _getFilteredPoints(allPoints);

        return Column(
          children: [
            _buildFiltersBar(availableFloors),

            // Results Counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.grey.shade100,
              width: double.infinity,
              child: Text(
                'Mostrant ${filteredPoints.length} de ${allPoints.length} actuacions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: filteredPoints.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            allPoints.isEmpty
                                ? 'No hi ha actuacions registrades.'
                                : 'Cap actuació compleix els filtres.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: filteredPoints.length,
                      itemBuilder: (context, index) {
                        final point = filteredPoints[index];
                        final pathology = point.pathology;
                        final latestImageUrl = _getMostRecentImageUrl(
                          pathology,
                        );

                        return Card(
                          elevation: 4,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PathologyCarouselPage(
                                    points: filteredPoints,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: latestImageUrl != null
                                      ? Image.network(
                                          latestImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pathology?.title ?? 'Sense Títol',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${point.id.substring(0, 4).toUpperCase()}  •  ${point.floorId}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          pathology?.type.name
                                                  .split('.')
                                                  .last
                                                  .toUpperCase() ??
                                              '-',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  point.status,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                point.status.toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            // Priority Indicator
                                            if ((pathology?.severity ?? 0) > 0)
                                              Text(
                                                'NIVELL ${pathology?.severity}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      (pathology?.severity ??
                                                              0) >=
                                                          8
                                                      ? Colors.red
                                                      : Colors.orange,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPoints.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final point = filteredPoints[index];
                        final pathology = point.pathology;
                        final latestImageUrl = _getMostRecentImageUrl(
                          pathology,
                        );

                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PathologyCarouselPage(
                                    points: filteredPoints,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey.shade200,
                                child: latestImageUrl != null
                                    ? Image.network(
                                        latestImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                      )
                                    : const Icon(
                                        Icons.image_not_supported,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                            title: Text(
                              pathology?.title ?? 'Sense Títol',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID: ${point.id.substring(0, 4).toUpperCase()}  •  ${point.floorId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pathology?.type.name
                                          .split('.')
                                          .last
                                          .toUpperCase() ??
                                      '-',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(point.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    point.status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if ((pathology?.severity ?? 0) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Nivell ${pathology?.severity}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: (pathology?.severity ?? 0) >= 8
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendent':
        return Colors.orange;
      case 'en progrés':
        return Colors.blue;
      case 'finalitzat':
        return Colors.green;
      case 'aturat':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddFloorDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddFloorDialog(ref: ref),
    );

    if (result != null && context.mounted) {
      final name = result['name'] as String;
      final file = result['file'] as import_image_picker.XFile?;

      try {
        if (file != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pujant plànol...')));
          await ref
              .read(constructionRepositoryProvider)
              .saveFloorPlan(name, file);
        } else {
          await ref.read(constructionRepositoryProvider).addEmptyFloor(name);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Planta creada correctament')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canviar nom de la planta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom de la planta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL·LAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                try {
                  Navigator.pop(context); // Close dialog first
                  await ref
                      .read(constructionRepositoryProvider)
                      .renameFloor(oldName, controller.text);
                } catch (e) {
                  debugPrint('Error renaming: $e');
                }
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String floorId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Planta?'),
        content: Text(
          'Estàs segur que vols eliminar "$floorId" i tots els seus punts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL·LAR'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // We should also implement delete of points?
      // The current deleteFloorPlan only deletes config and image. Points become orphaned (ghosts).
      // Ideally we delete points too.
      // User said "borrar-ne".
      // Let's just call deleteFloorPlan for now as per plan.
      try {
        await ref.read(constructionRepositoryProvider).deleteFloorPlan(floorId);
      } catch (e) {
        debugPrint('Error deleting: $e');
      }
    }
  }
}

class _AddFloorDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AddFloorDialog({required this.ref});

  @override
  State<_AddFloorDialog> createState() => _AddFloorDialogState();
}

class _AddFloorDialogState extends State<_AddFloorDialog> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Planta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom de la Planta (ex: Planta 3)',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Un cop creada, podràs pujar el plànol des de la opció "Canviar Plànol" o pujar-lo ara mateix.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL·LAR'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'file': null,
              });
            }
          },
          child: const Text('GUARDAR SENSE PLÀNOL'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty) {
              await _pickAndReturn(context);
            }
          },
          child: const Text('SELECCIONAR PLÀNOL'),
        ),
      ],
    );
  }

  Future<void> _pickAndReturn(BuildContext context) async {
    final navigator = Navigator.of(context);
    final picker = import_image_picker.ImagePicker();
    final file = await picker.pickImage(
      source: import_image_picker.ImageSource.gallery,
    );

    if (!mounted) return;

    if (file != null) {
      navigator.pop({'name': _nameController.text, 'file': file});
    }
  }
}
