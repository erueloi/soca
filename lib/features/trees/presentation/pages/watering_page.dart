// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/tree_extensions.dart';
import '../../domain/entities/watering_event.dart';
import '../providers/trees_provider.dart';
import 'package:soca/features/climate/presentation/providers/climate_provider.dart';
import '../../../map/presentation/pages/map_page.dart';

class WateringPage extends ConsumerStatefulWidget {
  final String? initialTreeId;

  const WateringPage({super.key, this.initialTreeId});

  @override
  ConsumerState<WateringPage> createState() => _WateringPageState();
}

class _WateringPageState extends ConsumerState<WateringPage> {
  late TextEditingController _referenceController;
  late LinkedScrollControllerGroup _horizontalControllers;
  late ScrollController _headerScroll;
  late ScrollController _bodyScroll;
  Timer? _debounce;
  final Set<String> _selectedTreeIds = {};

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController();
    _horizontalControllers = LinkedScrollControllerGroup();
    _headerScroll = _horizontalControllers.addAndGet();
    _bodyScroll = _horizontalControllers.addAndGet();
    // Handle Deep Link
    if (widget.initialTreeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(wateringFiltersProvider.notifier)
            .setTreeId(widget.initialTreeId);
      });
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _headerScroll.dispose();
    _bodyScroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treesAsync = ref.watch(treesStreamProvider);
    final wateringAsync = ref.watch(globalWateringEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reg'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: treesAsync.maybeWhen(
        data: (trees) {
          final count = _selectedTreeIds.isNotEmpty
              ? _selectedTreeIds.length
              : trees
                  .where((t) =>
                      t.status != 'Planned' &&
                      t.status != 'Existent' &&
                      !t.isVeteran &&
                      t.needsWater)
                  .length;
          if (count == 0) return null;
          return FloatingActionButton.extended(
            onPressed: () {
              if (_selectedTreeIds.isEmpty) {
                final needingIds = trees
                    .where((t) =>
                        t.status != 'Planned' &&
                        t.status != 'Existent' &&
                        !t.isVeteran &&
                        t.needsWater)
                    .map((t) => t.id)
                    .toSet();
                setState(() => _selectedTreeIds.addAll(needingIds));
              }
              _handleBatchWatering(trees);
            },
            label: Text(
              _selectedTreeIds.isNotEmpty
                  ? 'Regar ${_selectedTreeIds.length} arbres'
                  : 'Regar $count arbres en estrès',
            ),
            icon: const Icon(Icons.water_drop),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          );
        },
        orElse: () => null,
      ),
      body: treesAsync.when(
        data: (trees) {
          return wateringAsync.when(
            data: (events) {
              return _buildMatrix(trees, events);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  'Error regs: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error arbres: $e')),
      ),
    );
  }

  Widget _buildMatrix(List<Tree> trees, List<WateringEvent> events) {
    // 0. Initialize Deep Link (once)
    // logic moved to initState.

    // 1. Filter Trees
    final filters = ref.watch(wateringFiltersProvider);
    // Base filter: Exclude Planned, Existent, and Veteran trees
    final activeTrees = trees.where((t) => t.status != 'Planned' && t.status != 'Existent' && !t.isVeteran).toList();
    var filteredTrees = activeTrees;

    // Filter by Species
    if (filters.species != null) {
      filteredTrees = filteredTrees
          .where((t) => t.species == filters.species)
          .toList();
    }

    // Filter by Reference
    if (filters.reference != null && filters.reference!.isNotEmpty) {
      filteredTrees = filteredTrees
          .where(
            (t) =>
                t.reference != null &&
                t.reference!.toLowerCase().contains(
                  filters.reference!.toLowerCase(),
                ),
          )
          .toList();
    }

    // Filter by Tree ID (Deep Link / Specific Filter)
    if (filters.treeId != null) {
      filteredTrees = filteredTrees
          .where((t) => t.id == filters.treeId)
          .toList();
    }

    // Filter by Needs Water
    if (filters.onlyNeedsWater) {
      filteredTrees = filteredTrees.where((t) => t.needsWater).toList();
    }

    // Filter by Drip / Manual
    if (filters.dripFilter == DripFilter.drip) {
      filteredTrees = filteredTrees.where((t) => t.dripEmitters > 0).toList();
    } else if (filters.dripFilter == DripFilter.manual) {
      filteredTrees = filteredTrees.where((t) => t.dripEmitters == 0).toList();
    }

    // Calculate current irrigation requirements:
    final targetTreesForNeed = (filters.species != null ||
            (filters.reference != null && filters.reference!.isNotEmpty) ||
            filters.treeId != null ||
            filters.dripFilter != DripFilter.all)
        ? activeTrees.where((t) {
            if (filters.species != null && t.species != filters.species) return false;
            if (filters.reference != null &&
                filters.reference!.isNotEmpty &&
                !(t.reference?.toLowerCase().contains(filters.reference!.toLowerCase()) ?? false)) {
              return false;
            }
            if (filters.treeId != null && t.id != filters.treeId) return false;
            if (filters.dripFilter == DripFilter.drip && t.dripEmitters == 0) return false;
            if (filters.dripFilter == DripFilter.manual && t.dripEmitters > 0) return false;
            return true;
          }).toList()
        : activeTrees;

    final treesNeedingWater = targetTreesForNeed.where((t) => t.needsWater).toList();
    final totalLitersNeeded = treesNeedingWater.fold<int>(0, (sum, t) => sum + t.waterNeedLiters);
    final double maxHours = treesNeedingWater.isEmpty
        ? 0.0
        : treesNeedingWater.map((t) => t.recommendedWateringHours).fold<double>(0.0, (max, h) => h > max ? h : max);
    final double neededHours = maxHours > 0.0 ? maxHours : (treesNeedingWater.isNotEmpty ? 2.0 : 0.0);

    // 2. Prepare Data Structure
    final Map<String, Map<String, List<WateringEvent>>> data = {};

    final double colTreeWidth = 200;
    final double colDateWidth = 90;
    final double colTotalWidth = 110;
    final double colNeedsWidth = 180;

    // Initialize dates based on provider
    final start =
        filters.startDate ?? DateTime.now().subtract(const Duration(days: 6));
    final end = filters.endDate ?? DateTime.now();
    final daysDifference = end.difference(start).inDays + 1;
    final dates = List.generate(
      daysDifference,
      (i) => end.subtract(Duration(days: i)),
    );

    for (var tree in filteredTrees) {
      data[tree.id] = {};
      for (var date in dates) {
        final key = DateFormat('yyyyMMdd').format(date);
        data[tree.id]![key] = [];
      }
    }

    // Fill with events
    for (var event in events) {
      if (event.treeId != null && data.containsKey(event.treeId)) {
        final key = DateFormat('yyyyMMdd').format(event.date);
        if (data[event.treeId]!.containsKey(key)) {
          data[event.treeId]![key]!.add(event);
        }
      }
    }

    // 3. Extract Unique Species for Filter
    final speciesList = trees.map((t) => t.species).toSet().toList()..sort();

    return Column(
      children: [
        // Filter Header with Water Tank / Irrigation Needs Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 920;

              final filterInputs = Row(
                children: [
                  // Date Filter
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Dates',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        isDense: true,
                        prefixIcon: Icon(Icons.date_range, size: 20),
                      ),
                      controller: TextEditingController(
                        text:
                            '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM').format(end)}',
                      ),
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: DateTimeRange(
                            start: start,
                            end: end,
                          ),
                        );
                        if (range != null) {
                          ref
                              .read(wateringFiltersProvider.notifier)
                              .setDates(range);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Species Filter
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Espècie',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        isDense: true,
                        prefixIcon: Icon(Icons.forest, size: 20),
                      ),
                      key: ValueKey(filters.species),
                      initialValue: filters.species,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Totes'),
                        ),
                        ...speciesList.map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        ref
                            .read(wateringFiltersProvider.notifier)
                            .setSpecies(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reference Filter
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Ref',
                        hintText: 'Cercar...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        isDense: true,
                        prefixIcon: Icon(Icons.tag, size: 20),
                      ),
                      onChanged: (v) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            ref
                                .read(wateringFiltersProvider.notifier)
                                .setReference(v.isEmpty ? null : v);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );

              final quickFiltersRow = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('⚠️ Necessiten Reg'),
                    selected: filters.onlyNeedsWater,
                    onSelected: (bool selected) {
                      ref
                          .read(wateringFiltersProvider.notifier)
                          .toggleNeedsWater();
                    },
                    selectedColor: Colors.orange.shade100,
                    checkmarkColor: Colors.orange.shade900,
                    labelStyle: TextStyle(
                      color: filters.onlyNeedsWater
                          ? Colors.orange.shade900
                          : Colors.grey.shade700,
                      fontWeight: filters.onlyNeedsWater
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  FilterChip(
                    avatar: Icon(
                      Icons.water,
                      size: 16,
                      color: filters.dripFilter == DripFilter.drip
                          ? Colors.blue.shade900
                          : Colors.grey.shade600,
                    ),
                    label: const Text('Gota a Gota'),
                    selected: filters.dripFilter == DripFilter.drip,
                    onSelected: (bool selected) {
                      ref
                          .read(wateringFiltersProvider.notifier)
                          .toggleDripFilter(DripFilter.drip);
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade900,
                    labelStyle: TextStyle(
                      color: filters.dripFilter == DripFilter.drip
                          ? Colors.blue.shade900
                          : Colors.grey.shade700,
                      fontWeight: filters.dripFilter == DripFilter.drip
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  FilterChip(
                    avatar: Icon(
                      Icons.water_drop_outlined,
                      size: 16,
                      color: filters.dripFilter == DripFilter.manual
                          ? Colors.teal.shade900
                          : Colors.grey.shade600,
                    ),
                    label: const Text('Manual'),
                    selected: filters.dripFilter == DripFilter.manual,
                    onSelected: (bool selected) {
                      ref
                          .read(wateringFiltersProvider.notifier)
                          .toggleDripFilter(DripFilter.manual);
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal.shade900,
                    labelStyle: TextStyle(
                      color: filters.dripFilter == DripFilter.manual
                          ? Colors.teal.shade900
                          : Colors.grey.shade700,
                      fontWeight: filters.dripFilter == DripFilter.manual
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (filteredTrees.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          final allFilteredIds = filteredTrees.map((t) => t.id).toSet();
                          if (_selectedTreeIds.containsAll(allFilteredIds)) {
                            _selectedTreeIds.removeAll(allFilteredIds);
                          } else {
                            _selectedTreeIds.addAll(allFilteredIds);
                          }
                        });
                      },
                      icon: Icon(
                        _selectedTreeIds.containsAll(filteredTrees.map((t) => t.id))
                            ? Icons.deselect
                            : Icons.select_all,
                      ),
                      label: Text(
                        _selectedTreeIds.containsAll(filteredTrees.map((t) => t.id))
                            ? 'Deseleccionar'
                            : 'Seleccionar Tots',
                      ),
                    ),
                  if (_selectedTreeIds.isNotEmpty) ...[
                    FilledButton.icon(
                      onPressed: () => _handleBatchWatering(trees),
                      icon: const Icon(Icons.water_drop, size: 18),
                      label: Text('Regar (${_selectedTreeIds.length})'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showBatchDripConfigDialog(trees),
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text('Degoters (${_selectedTreeIds.length})'),
                    ),
                  ],
                ],
              );

              final activeChips = (filters.treeId != null ||
                      filters.species != null ||
                      filters.dripFilter != DripFilter.all ||
                      (filters.reference != null && filters.reference!.isNotEmpty))
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        children: [
                          // Tree Chip
                          if (filters.treeId != null)
                            InputChip(
                              label: Text(
                                'Arbre: ${trees.any((t) => t.id == filters.treeId) ? trees.firstWhere((t) => t.id == filters.treeId).commonName : "Desconegut"}',
                              ),
                              onDeleted: () {
                                ref
                                    .read(wateringFiltersProvider.notifier)
                                    .setTreeId(null);
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                              backgroundColor: Colors.blue.shade100,
                            ),
                          // Species Chip
                          if (filters.species != null)
                            InputChip(
                              label: Text('Espècie: ${filters.species}'),
                              onDeleted: () {
                                ref
                                    .read(wateringFiltersProvider.notifier)
                                    .setSpecies(null);
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                              backgroundColor: Colors.green.shade100,
                            ),
                          // Drip / Manual Chip
                          if (filters.dripFilter != DripFilter.all)
                            InputChip(
                              label: Text(filters.dripFilter == DripFilter.drip
                                  ? 'Reg: Gota a Gota'
                                  : 'Reg: Manual'),
                              onDeleted: () {
                                ref
                                    .read(wateringFiltersProvider.notifier)
                                    .setDripFilter(DripFilter.all);
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                              backgroundColor: filters.dripFilter == DripFilter.drip
                                  ? Colors.blue.shade100
                                  : Colors.teal.shade100,
                            ),
                          // Reference Chip
                          if (filters.reference != null &&
                              filters.reference!.isNotEmpty)
                            InputChip(
                              label: Text('Ref: "${filters.reference}"'),
                              onDeleted: () {
                                _referenceController.clear();
                                ref
                                    .read(wateringFiltersProvider.notifier)
                                    .setReference(null);
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                              backgroundColor: Colors.orange.shade100,
                            ),
                        ],
                      ),
                    )
                  : null;

              final waterTankCard = _buildWaterTankNeedWidget(
                treesNeedingWaterCount: treesNeedingWater.length,
                totalTreesCount: targetTreesForNeed.length,
                totalLiters: totalLitersNeeded,
                neededHours: neededHours,
                isNeedsOnlyActive: filters.onlyNeedsWater,
                onTap: () {
                  ref.read(wateringFiltersProvider.notifier).toggleNeedsWater();
                },
                onWaterPressed: treesNeedingWater.isNotEmpty
                    ? () {
                        setState(() {
                          _selectedTreeIds.clear();
                          _selectedTreeIds.addAll(treesNeedingWater.map((t) => t.id));
                        });
                        _handleBatchWatering(trees);
                      }
                    : null,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          filterInputs,
                          const SizedBox(height: 8),
                          quickFiltersRow,
                          if (activeChips != null) activeChips,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390, minWidth: 320),
                      child: waterTankCard,
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    waterTankCard,
                    const SizedBox(height: 10),
                    filterInputs,
                    const SizedBox(height: 8),
                    quickFiltersRow,
                    if (activeChips != null) activeChips,
                  ],
                );
              }
            },
          ),
        ),

        // 4. Custom Sticky Header Table Implementation
        // STICKY HEADER
        Container(
          color: Colors.blue.shade50,
          child: SingleChildScrollView(
            controller: _headerScroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHeaderCell('Arbre', colTreeWidth),
                ...dates.map(
                  (d) => _buildHeaderCell(
                    DateFormat('EEE dd/MM', 'ca_ES').format(d),
                    colDateWidth,
                    alignRight: true,
                  ),
                ),
                _buildHeaderCell(
                  'Total Setmana',
                  colTotalWidth,
                  alignRight: true,
                ),
                Container(
                  width: colNeedsWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Necessitat Actual',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message:
                                "Indicador d'estat hídric:\n"
                                "🔴 Vermell (< -15mm): Estrès Hídric. Reserva esgotada. (URGENT)\n"
                                "🟡 Ambre (-15 a -5mm): Reg Opcional. Humitat descendent.\n"
                                "🟢 Verd (> -5mm): No regar. Terra saciada.\n\n"
                                "Si surt un valor en L, és la quantitat recomanada per regar avui.",
                            triggerMode: TooltipTriggerMode.tap,
                            child: const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final asyncVal = ref.watch(
                            latestCalculationTimestampProvider,
                          );
                          return asyncVal.when(
                            data: (date) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  date != null
                                      ? 'Recàlcul: ${DateFormat('dd/MM HH:mm').format(date)}'
                                      : 'Recàlcul: (Pendent)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // SCROLLABLE BODY
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: _bodyScroll,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...filteredTrees.map((tree) {
                    final treeData = data[tree.id]!;
                    double treeTotal = 0;
                    final cells = dates.map((d) {
                      final key = DateFormat('yyyyMMdd').format(d);
                      final eventsList = treeData[key] ?? [];
                      final liters = eventsList.fold<double>(
                        0,
                        (sum, e) => sum + e.liters,
                      );
                      treeTotal += liters;

                      return Container(
                        width: colDateWidth,
                        padding: const EdgeInsets.all(4),
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: liters > 0
                              ? () => _showEditDeleteDialog(
                                  context,
                                  tree.id,
                                  eventsList.first,
                                )
                              : null,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: liters > 0 ? Colors.blue.shade100 : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              liters > 0 ? '${liters.toInt()}' : '-',
                              style: TextStyle(
                                color: liters > 0
                                    ? Colors.blue.shade900
                                    : Colors.grey.shade300,
                                fontWeight: liters > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList();

                    // Needs Calculation (Dosi de suport real gota a gota: 8L / 16L)
                    final litersNeeded = tree.waterNeedLiters.toDouble();
                    Color statusColor = tree.waterStatusColor;

                    return Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black12),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Tree Name Column
                          Container(
                            width: colTreeWidth,
                            // Remove inner padding to allow InkWell to fill cell
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selectedTreeIds.contains(tree.id),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedTreeIds.add(tree.id);
                                      } else {
                                        _selectedTreeIds.remove(tree.id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MapPage(initialTreeId: tree.id),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            tree.commonName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.indigo,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (tree.reference != null &&
                                        tree.reference!.isNotEmpty)
                                      Text(
                                        tree.reference!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.indigo.shade400,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                          Text(
                                            tree.species,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Date Cells
                          ...cells,
                          // Total Column
                          Container(
                            width: colTotalWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${treeTotal.toInt()}L',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Needs Column
                          Container(
                            width: colNeedsWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => _showSingleTreeDripDialog(tree),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        litersNeeded > 0
                                            ? '${litersNeeded.toInt()} L'
                                            : 'OK',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: litersNeeded > 0
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tree.dripEmitters > 0
                                        ? '${tree.dripEmitters} deg. (${tree.totalDripRate.toInt()}L/h)'
                                        : 'Manual (sense deg.)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Totals Row
                  Container(
                    color: Colors.blue.shade100,
                    child: Row(
                      children: [
                        _buildHeaderCell(
                          'TOTAL DIARI',
                          colTreeWidth,
                          isBold: true,
                          color: Colors.indigo,
                        ),
                        ...dates.map((d) {
                          final key = DateFormat('yyyyMMdd').format(d);
                          double dayTotal = 0;
                          for (var t in filteredTrees) {
                            dayTotal +=
                                data[t.id]?[key]?.fold<double>(
                                  0,
                                  (sum, e) => sum + e.liters,
                                ) ??
                                0;
                          }
                          return Container(
                            width: colDateWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${dayTotal.toInt()}L',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.indigo,
                              ),
                            ),
                          );
                        }),
                        // Grand Total
                        Container(
                          width: colTotalWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${filteredTrees.fold<double>(0, (sum, t) {
                              return sum + dates.fold<double>(0, (s, d) {
                                    final key = DateFormat('yyyyMMdd').format(d);
                                    return s + (data[t.id]?[key]?.fold<double>(0, (sum, e) => sum + e.liters) ?? 0);
                                  });
                            }).toInt()}L',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        // Empty Needs
                        SizedBox(width: colNeedsWidth),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDeleteDialog(
    BuildContext context,
    String treeId,
    WateringEvent event,
  ) async {
    final controller = TextEditingController(text: event.liters.toString());
    DateTime selectedDate = event.date;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Modificar Reg'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );

                      if (pickedTime != null) {
                        setState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      } else {
                        // Keep old time if time picker cancelled
                        setState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Litres',
                    suffixText: 'L',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              // DELETE BUTTON
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  // Confirm Delete
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar Reg?'),
                      content: const Text('Aquesta acció no es pot desfer.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL·LAR'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('ELIMINAR'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref
                        .read(treesRepositoryProvider)
                        .deleteWateringEvent(treeId, event.id);
                    if (context.mounted) {
                      Navigator.pop(context); // Close Edit Dialog
                    }
                  }
                },
                child: const Text('ELIMINAR'),
              ),
              // SAVE BUTTON
              ElevatedButton(
                onPressed: () async {
                  final newVal = double.tryParse(controller.text);
                  if (newVal != null && newVal >= 0) {
                    final updatedEvent = event.copyWith(
                      liters: newVal,
                      date: selectedDate,
                    );
                    await ref
                        .read(treesRepositoryProvider)
                        .updateWateringEvent(treeId, updatedEvent);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('GUARDAR CANVIS'),
              ),
            ],
          );
        },
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

  Future<void> _showSingleTreeDripDialog(Tree tree) async {
    int mode = 1;
    if (tree.dripEmitters == 0) {
      mode = 0;
    } else if (tree.dripEmitters == 1 && (tree.dripFlowRate - 4.0).abs() < 0.01) {
      mode = 1;
    } else if (tree.dripEmitters == 2 && (tree.dripFlowRate - 4.0).abs() < 0.01) {
      mode = 2;
    } else {
      mode = -1;
    }

    int selectedEmitters = tree.dripEmitters;
    double selectedRate = tree.dripFlowRate > 0 ? tree.dripFlowRate : 4.0;
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
                    'Configurar Reg: ${tree.commonName}',
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
                    if (tree.reference != null && tree.reference!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ref: ${tree.reference} • ${tree.species}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                      subtitle: 'Arbres grans (reg de 2h = 16 L)',
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
                            ? 'Cabal total resultant: ${(selectedEmitters * selectedRate).toStringAsFixed(1).replaceAll(".0", "")} L/h ($selectedEmitters degoters)'
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
                    [tree.id],
                    dripEmitters: selectedEmitters,
                    dripFlowRate: selectedRate,
                  );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selectedEmitters > 0
                              ? 'Reg actualitzat per a ${tree.commonName}: $selectedEmitters deg. (${(selectedEmitters * selectedRate).toStringAsFixed(1).replaceAll(".0", "")} L/h)'
                              : 'Reg actualitzat a Manual per a ${tree.commonName}',
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

  Future<void> _showBatchDripConfigDialog(List<Tree> allTrees) async {
    final selectedTrees = allTrees.where((t) => _selectedTreeIds.contains(t.id)).toList();
    if (selectedTrees.isEmpty) return;

    int mode = 1;
    int selectedEmitters = 1;
    double selectedRate = 4.0;
    final customEmittersController = TextEditingController(text: '3');
    final customRateController = TextEditingController(text: '4.0');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.tune, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Configurar Reg (${selectedTrees.length} arbres)'),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aplica la configuració de reg a tots els ${selectedTrees.length} arbres seleccionats:',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                      subtitle: 'Arbres grans (reg de 2h = 16 L)',
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
                            ? 'Cabal resultant: ${(selectedEmitters * selectedRate).toStringAsFixed(1).replaceAll(".0", "")} L/h per arbre ($selectedEmitters degoters)'
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
                    selectedTrees.map((t) => t.id).toList(),
                    dripEmitters: selectedEmitters,
                    dripFlowRate: selectedRate,
                  );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selectedEmitters > 0
                              ? 'S\'ha actualitzat el reg de ${selectedTrees.length} arbres a $selectedEmitters degoters (${(selectedEmitters * selectedRate).toStringAsFixed(1).replaceAll(".0", "")} L/h).'
                              : 'S\'ha actualitzat el reg de ${selectedTrees.length} arbres a Manual.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('APLICAR A TOTS'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleBatchWatering(List<Tree> allTrees) async {
    final treesToWater = allTrees.where((t) => _selectedTreeIds.contains(t.id)).toList();

    if (treesToWater.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hi ha cap arbre seleccionat.')),
      );
      return;
    }

    // 1. Pick Date & Time
    DateTime selectedDate = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDate),
    );
    if (pickedTime == null || !mounted) return;

    selectedDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 2. Select Watering Mode (Temps vs Litres)
    bool isTimeMode = true;
    double wateringHours = 2.0; // Default 2 hours of drip irrigation
    bool includeManualTrees = true;
    const double manualLitersDose = 8.0;
    final fixedLitersController = TextEditingController(text: '8');

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate summary based on current values
          int count1Deg = 0;
          int count2Deg = 0;
          int countManual = 0;
          double totalLiters = 0;

          for (final t in treesToWater) {
            if (t.dripEmitters == 1) {
              count1Deg++;
            } else if (t.dripEmitters >= 2) {
              count2Deg++;
            } else {
              countManual++;
            }

            double litersForTree = 0;
            if (isTimeMode) {
              if (t.dripEmitters > 0) {
                final rate = t.totalDripRate > 0 ? t.totalDripRate : 4.0;
                litersForTree = rate * wateringHours;
              } else {
                litersForTree = includeManualTrees ? manualLitersDose : 0.0;
              }
            } else {
              litersForTree = double.tryParse(fixedLitersController.text) ?? 8.0;
            }
            totalLiters += litersForTree;
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Regar ${treesToWater.length} arbres'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mètode de registre:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.timer_outlined),
                        label: Text('Per Temps (Gota a gota)'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.format_color_fill),
                        label: Text('Litres fixos'),
                      ),
                    ],
                    selected: {isTimeMode},
                    onSelectionChanged: (set) {
                      setDialogState(() {
                        isTimeMode = set.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isTimeMode) ...[
                    const Text('Hores de funcionament del sector:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1.0, 1.5, 2.0, 2.5, 3.0].map((h) {
                        final isSelected = wateringHours == h;
                        return ChoiceChip(
                          label: Text('${h % 1 == 0 ? h.toInt() : h}h'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => wateringHours = h);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    TextField(
                      controller: fixedLitersController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Litres per cada arbre',
                        suffixText: 'L',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // WATER TANK & TOTAL CONSUMPTION CARD
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100.withValues(alpha: 0.5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTimeMode) ...[
                          Row(
                            children: [
                              Icon(Icons.tune, size: 16, color: Colors.blue.shade800),
                              const SizedBox(width: 6),
                              Text(
                                'Càlcul segons degoters (${wateringHours % 1 == 0 ? wateringHours.toInt() : wateringHours}h de reg):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (count1Deg > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text(
                                '• $count1Deg arbres (1 deg. 4L/h) → ${(wateringHours * 4).toInt()} L/arbre (${(count1Deg * wateringHours * 4).toInt()} L)',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                              ),
                            ),
                          if (count2Deg > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text(
                                '• $count2Deg arbres (2 deg. 4L/h) → ${(wateringHours * 8).toInt()} L/arbre (${(count2Deg * wateringHours * 8).toInt()} L)',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                              ),
                            ),
                          if (countManual > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: includeManualTrees ? Colors.amber.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: includeManualTrees ? Colors.amber.shade300 : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pan_tool_alt_outlined,
                                    size: 18,
                                    color: includeManualTrees ? Colors.amber.shade900 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$countManual ${countManual == 1 ? "arbre de reg manual" : "arbres de reg manual"} (sense degoters)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: includeManualTrees ? Colors.amber.shade900 : Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          includeManualTrees
                                              ? 'Regar a mà amb garrafa (${manualLitersDose.toInt()}L) durant la sessió'
                                              : 'Ometre (no regar manuals, només obrir gota a gota)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: includeManualTrees ? Colors.brown.shade800 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: includeManualTrees,
                                    activeColor: Colors.amber.shade800,
                                    onChanged: (val) {
                                      setDialogState(() => includeManualTrees = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Divider(height: 16, color: Colors.blue.shade200),
                        ],

                        // Water Tank & Consumption Totals
                        Row(
                          children: [
                            // Styled visual Water Tank / Cistern icon
                            Container(
                              width: 44,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade300, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade200,
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.water_drop,
                                    size: 22,
                                    color: Colors.blue.shade900,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CONSUM TOTAL ESTIMAT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${totalLiters.toInt()}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Litres',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${(totalLiters / 1000.0).toStringAsFixed(2)} m³)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueGrey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (totalLiters >= 500) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 13, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Aprox. ${(totalLiters / 1000.0).toStringAsFixed(1)} dipòsits IBC (1.000 L)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL·LAR'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check),
                label: const Text('REGAR ARA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    // 3. Execute with Progress
    final progressNotifier = ValueNotifier<int>(0);
    final total = treesToWater.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (context, value, child) {
                return Text('Registrant reg arbre $value de $total...');
              },
            ),
          ],
        ),
      ),
    );

    int count = 0;
    for (var tree in treesToWater) {
      double liters = 0.0;
      String note = '';

      if (isTimeMode) {
        if (tree.dripEmitters > 0) {
          final rate = tree.totalDripRate > 0 ? tree.totalDripRate : 4.0;
          liters = rate * wateringHours;
          note = 'Reg Gota a gota (${wateringHours % 1 == 0 ? wateringHours.toInt() : wateringHours}h - ${tree.dripEmitters} deg.)';
        } else {
          if (!includeManualTrees) continue; // Skip manual trees when excluded
          liters = manualLitersDose;
          note = 'Reg Manual (garrafa/mànega - ${manualLitersDose.toInt()}L)';
        }
      } else {
        liters = double.tryParse(fixedLitersController.text) ?? 8.0;
        note = 'Reg Manual (${liters.toInt()}L)';
      }

      final event = WateringEvent(
        id: '',
        date: selectedDate,
        liters: liters,
        note: note,
        treeId: tree.id,
      );

      await ref.read(treesRepositoryProvider).addWateringEvent(tree.id, event);
      count++;
      progressNotifier.value = count;
    }

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      setState(() {
        _selectedTreeIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('S\'han registrat $count regs correctament!')),
      );
    }
  }

  Widget _buildHeaderCell(
    String text,
    double width, {
    bool alignRight = false,
    bool isBold = true,
    Color? color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Widget _buildWaterTankNeedWidget({
    required int treesNeedingWaterCount,
    required int totalTreesCount,
    required int totalLiters,
    required double neededHours,
    required bool isNeedsOnlyActive,
    required VoidCallback onTap,
    VoidCallback? onWaterPressed,
  }) {
    final hasNeed = totalLiters > 0;
    final ibcTanks = (totalLiters / 1000.0).toStringAsFixed(1);
    final m3 = (totalLiters / 1000.0).toStringAsFixed(2);
    final hoursFormatted = neededHours % 1 == 0
        ? '${neededHours.toInt()}h'
        : '${neededHours.toStringAsFixed(1)}h';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.blue.shade50.withValues(alpha: 0.6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasNeed
                  ? [
                      Colors.blue.shade50,
                      const Color(0xFFE3F2FD),
                    ]
                  : [
                      Colors.grey.shade50,
                      Colors.grey.shade100,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNeedsOnlyActive
                  ? Colors.blue.shade700
                  : (hasNeed ? Colors.blue.shade300 : Colors.grey.shade300),
              width: isNeedsOnlyActive ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: hasNeed
                    ? Colors.blue.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Styled Water Tank Graphic
              _buildWaterTankGraphic(hasNeed: hasNeed, totalLiters: totalLiters),
              const SizedBox(width: 12),

              // Summary details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title and status tag
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop,
                          size: 13,
                          color: hasNeed ? Colors.blue.shade700 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'NECESSITAT ACTUAL DE REG',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: hasNeed ? Colors.blue.shade900 : Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (isNeedsOnlyActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FILTRAT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (hasNeed)
                          Tooltip(
                            message: 'Clica per filtrar aquests arbres',
                            child: Icon(
                              Icons.filter_alt_outlined,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Big numbers: Litres + m³
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          NumberFormat.decimalPattern('ca_ES').format(totalLiters),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: hasNeed ? Colors.blue.shade900 : Colors.grey.shade800,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Litres',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasNeed ? Colors.blue.shade800 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '($m3 m³)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasNeed ? Colors.blueGrey.shade700 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Hours of watering & IBC equivalence
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasNeed ? Colors.indigo.shade50 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasNeed ? Colors.indigo.shade200 : Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 13,
                                color: hasNeed ? Colors.indigo.shade800 : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasNeed ? 'Reg: $hoursFormatted' : 'Reg: 0h',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: hasNeed ? Colors.indigo.shade900 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasNeed)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 12,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '~$ibcTanks dipòsits IBC',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Subtitle count of trees + Action Button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasNeed
                                ? '$treesNeedingWaterCount arbres amb estrès hídric'
                                : 'Tots els arbres estan sans o regats',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: hasNeed ? Colors.blueGrey.shade800 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (hasNeed && onWaterPressed != null) ...[
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            onPressed: onWaterPressed,
                            icon: const Icon(Icons.water_drop, size: 14),
                            label: Text('Regar ($treesNeedingWaterCount)'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildWaterTankGraphic({required bool hasNeed, required int totalLiters}) {
    final double fillPercent = hasNeed ? (totalLiters / 2000.0).clamp(0.25, 0.95) : 0.1;

    return Container(
      width: 44,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasNeed ? Colors.blue.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasNeed
                ? Colors.blue.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Water level fill
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fillPercent,
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: hasNeed
                        ? [Colors.blue.shade200, Colors.blue.shade500]
                        : [Colors.grey.shade300, Colors.grey.shade400],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          // IBC Tank Cage markings
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(height: 1, color: Colors.blueGrey.withValues(alpha: 0.18)),
              Container(height: 1, color: Colors.blueGrey.withValues(alpha: 0.18)),
              Container(height: 1, color: Colors.blueGrey.withValues(alpha: 0.18)),
            ],
          ),
          // Water icon
          Icon(
            hasNeed ? Icons.water_drop : Icons.water_drop_outlined,
            size: 20,
            color: hasNeed ? Colors.blue.shade900 : Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}
