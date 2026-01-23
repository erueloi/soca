import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/tree_extensions.dart';
import '../../domain/entities/watering_event.dart';
import '../providers/trees_provider.dart';

class WateringPage extends ConsumerStatefulWidget {
  final String? initialTreeId;

  const WateringPage({super.key, this.initialTreeId});

  @override
  ConsumerState<WateringPage> createState() => _WateringPageState();
}

class _WateringPageState extends ConsumerState<WateringPage> {
  late TextEditingController _referenceController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController();
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
    var filteredTrees = trees;

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

    // 2. Prepare Data Structure
    final Map<String, Map<String, List<WateringEvent>>> data = {};

    // Sticky Header Scroll Controllers
    final horizontalControllers = LinkedScrollControllerGroup();
    final headerScroll = horizontalControllers.addAndGet();
    final bodyScroll = horizontalControllers.addAndGet();

    final double colTreeWidth = 160;
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
        // Filter Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              ),
              const SizedBox(height: 8),
              // Quick Filters Row
              Row(
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
                ],
              ),
              // Active Filters Chips (Breadcrumbs)
              if (filters.treeId != null ||
                  filters.species != null ||
                  (filters.reference != null && filters.reference!.isNotEmpty))
                Padding(
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
                ),
            ],
          ),
        ),

        // 4. Custom Sticky Header Table Implementation
        // STICKY HEADER
        Container(
          color: Colors.blue.shade50,
          child: SingleChildScrollView(
            controller: headerScroll,
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
                  child: Row(
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
              controller: bodyScroll,
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

                    // Needs Calculation
                    final balance = tree.soilBalance ?? 0.0;
                    final area = tree.calculatedRegArea ?? 1.0;
                    double litersNeeded = 0;
                    Color statusColor = tree.waterStatusColor;

                    if (balance < 0) {
                      litersNeeded = (balance.abs() * area);
                    }

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tree.commonName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
                              vertical: 12,
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
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
}
