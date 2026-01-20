import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_item.dart';
import '../../../settings/domain/entities/farm_config.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class CostDashboardPage extends ConsumerStatefulWidget {
  final String columnName;
  final List<Task> tasks;

  const CostDashboardPage({
    super.key,
    required this.columnName,
    required this.tasks,
  });

  @override
  ConsumerState<CostDashboardPage> createState() => _CostDashboardPageState();
}

class _CostDashboardPageState extends ConsumerState<CostDashboardPage> {
  String _filter = 'Tots'; // 'Tots', 'Pendents', 'Gastats'
  bool _showZeroCost = false;
  int _sortColumnIndex = 0; // Default: Data
  bool _sortAscending = true; // Default: Ascending

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... same build ...
    final configAsync = ref.watch(farmConfigStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Control de Costos: ${widget.columnName}')),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (config) {
          return _buildContent(context, config);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, FarmConfig config) {
    // ... same prep ...
    // 0. Prepare Data
    final allItems = <_DashboardItem>[];
    for (var task in widget.tasks) {
      for (var item in task.items) {
        allItems.add(_DashboardItem(task: task, item: item));
      }
    }

    // Filter
    var filteredItems = allItems.where((d) {
      if (!_showZeroCost && d.totalCost == 0) return false;
      if (_filter == 'Tots') return true;
      if (_filter == 'Pendents') return !d.isSpent;
      if (_filter == 'Gastats') return d.isSpent;
      return true;
    }).toList();

    // Sort
    filteredItems.sort((a, b) {
      int compareResult = 0;
      switch (_sortColumnIndex) {
        case 0: // Data (Due Date)
          final dateA = a.task.dueDate;
          final dateB = b.task.dueDate;
          if (dateA == null && dateB == null) {
            compareResult = 0;
          } else if (dateA == null) {
            compareResult = 1; // Put nulls at bottom
          } else if (dateB == null) {
            compareResult = -1;
          } else {
            compareResult = dateA.compareTo(dateB);
          }
          break;
        case 1: // Concepte
          compareResult = a.item.description.compareTo(b.item.description);
          break;
        case 2: // Categoria
          final catA = _getCategoryName(a.item.categoryId, config);
          final catB = _getCategoryName(b.item.categoryId, config);
          compareResult = catA.compareTo(catB);
          break;
        case 3: // Quant.
          compareResult = a.item.quantity.compareTo(b.item.quantity);
          break;
        case 4: // Preu Unit.
          compareResult = a.item.cost.compareTo(b.item.cost);
          break;
        case 5: // Total
          compareResult = a.totalCost.compareTo(b.totalCost);
          break;
        case 6: // Estat
          final statusA = a.isSpent ? 1 : 0;
          final statusB = b.isSpent ? 1 : 0;
          compareResult = statusA.compareTo(statusB);
          break;
      }
      return _sortAscending ? compareResult : -compareResult;
    });

    // Calculate Totals & Stats
    final totalBudget = allItems.fold<double>(
      0,
      (sum, i) => sum + (i.item.cost * i.item.quantity),
    );
    final totalSpent = allItems
        .where((i) => i.isSpent)
        .fold<double>(0, (sum, i) => sum + i.totalCost);

    // Group by Category (ID) for PieChart (Budget based)
    final categoryMap = <String, double>{};
    for (var d in allItems) {
      final catId = d.item.categoryId;
      final cost = d.item.cost * d.item.quantity;
      categoryMap[catId] = (categoryMap[catId] ?? 0) + cost;
    }

    // Prepare Sections (extracted for reuse)
    Widget buildSummarySection() {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Pressupost Total',
                  totalBudget,
                  Colors.blue,
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Total Gastat',
                  totalSpent,
                  Colors.green,
                  Icons.payments,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Saldo Pendent',
                  totalBudget - totalSpent,
                  (totalBudget - totalSpent) < 0 ? Colors.red : Colors.orange,
                  Icons.savings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Distribució del Pressupost per Categoria',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: categoryMap.isEmpty
                        ? const Center(child: Text('Sense dades'))
                        : PieChart(
                            PieChartData(
                              sections: categoryMap.entries.map((e) {
                                final percentage = totalBudget > 0
                                    ? (e.value / totalBudget) * 100
                                    : 0.0;
                                return PieChartSectionData(
                                  color: _getCategoryColor(e.key, config),
                                  value: e.value,
                                  title: '${percentage.toStringAsFixed(0)}%',
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: categoryMap.keys.map((catId) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: _getCategoryColor(catId, config),
                          ),
                          const SizedBox(width: 4),
                          Text(_getCategoryName(catId, config)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget buildTableSection() {
      return Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Tots', label: Text('Tots')),
              ButtonSegment(value: 'Pendents', label: Text('Pendents')),
              ButtonSegment(value: 'Gastats', label: Text('Gastats')),
            ],
            selected: {_filter},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _filter = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Mostrar sense despeses (0€)'),
              Switch(
                value: _showZeroCost,
                onChanged: (val) {
                  setState(() {
                    _showZeroCost = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  columnSpacing: 20,
                  columns: [
                    DataColumn(label: const Text('Data'), onSort: _onSort),
                    DataColumn(label: const Text('Concepte'), onSort: _onSort),
                    DataColumn(label: const Text('Categoria'), onSort: _onSort),
                    DataColumn(
                      label: const Text('Quant.'),
                      numeric: true,
                      onSort: _onSort,
                    ),
                    DataColumn(
                      label: const Text('Preu Unit.'),
                      numeric: true,
                      onSort: _onSort,
                    ),
                    DataColumn(
                      label: const Text('Total'),
                      numeric: true,
                      onSort: _onSort,
                    ),
                    DataColumn(label: const Text('Estat'), onSort: _onSort),
                  ],
                  rows: filteredItems.map((d) {
                    final isOverBudget =
                        d.item.realCost != null &&
                        d.item.realCost! > d.item.cost;
                    final dateStr = d.task.dueDate != null
                        ? DateFormat('dd/MM/yy').format(d.task.dueDate!)
                        : '-';

                    return DataRow(
                      color: WidgetStateProperty.resolveWith((states) {
                        if (isOverBudget && d.isSpent) {
                          return Colors.red.withValues(alpha: 0.1);
                        }
                        return null;
                      }),
                      cells: [
                        DataCell(
                          Text(
                            dateStr,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                d.item.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                d.task.title,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(d.item.categoryId, config),
                                color: Colors.grey[700],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(_getCategoryName(d.item.categoryId, config)),
                            ],
                          ),
                        ),
                        DataCell(Text(d.item.quantity.toString())),
                        DataCell(
                          Text(
                            '${d.item.cost.toStringAsFixed(2)}€',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${d.totalCost.toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOverBudget && d.isSpent
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                        ),
                        DataCell(
                          Icon(
                            d.isSpent
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: d.isSpent
                                ? Colors.green
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          // Two-column layout
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: buildSummarySection()),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: buildTableSection()),
                ],
              ),
            ),
          );
        } else {
          // Single-column layout
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildSummarySection(),
                  const SizedBox(height: 24),
                  buildTableSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.currency(
                locale: 'es_ES',
                symbol: '€',
                decimalDigits: 0,
              ).format(amount),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ExpenseCategory _getCategory(String id, FarmConfig config) {
    return config.expenseCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => config.expenseCategories.isNotEmpty
          ? config.expenseCategories.first
          : const ExpenseCategory(
              id: 'unknown',
              name: '?',
              colorHex: 'FF9E9E9E',
              iconCode: 0xe3e3,
            ), // Default fallback
    );
  }

  Color _getCategoryColor(String id, FarmConfig config) {
    final cat = _getCategory(id, config);
    return Color(int.parse(cat.colorHex, radix: 16));
  }

  IconData _getCategoryIcon(String id, FarmConfig config) {
    final cat = _getCategory(id, config);
    return IconData(cat.iconCode, fontFamily: 'MaterialIcons');
  }

  String _getCategoryName(String id, FarmConfig config) {
    return _getCategory(id, config).name;
  }
}

class _DashboardItem {
  final Task task;
  final TaskItem item;

  _DashboardItem({required this.task, required this.item});

  bool get isSpent => item.isDone || task.isDone;

  double get totalCost {
    // If spent, use realCost if available, else budget cost
    // If not spent, use budget cost
    if (isSpent && item.realCost != null) {
      return item.realCost! * item.quantity;
    }
    return item.cost * item.quantity;
  }
}
