import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_provider.dart';
import 'package:intl/intl.dart';

class FinancesPage extends ConsumerStatefulWidget {
  const FinancesPage({super.key});

  @override
  ConsumerState<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends ConsumerState<FinancesPage> {
  String _groupBy = 'Phase'; // 'Phase' or 'Bucket'

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finances i Costos')),
      body: tasksAsync.when(
        data: (tasks) {
          // 1. Filter tasks with financial data
          final financeTasks = tasks
              .where((t) => t.totalBudget > 0 || t.totalSpent > 0)
              .toList();

          if (financeTasks.isEmpty) {
            return const Center(
              child: Text('No hi ha dades financeres disponibles.'),
            );
          }

          // 2. Grouping Logic
          final Map<String, List<Task>> groupedTasks = {};
          for (var task in financeTasks) {
            String key;
            if (_groupBy == 'Phase') {
              key = task.phase.isEmpty ? 'Sense Fase' : task.phase;
            } else {
              key = task.bucket.isEmpty ? 'Sense Estat' : task.bucket;
            }

            if (!groupedTasks.containsKey(key)) {
              groupedTasks[key] = [];
            }
            groupedTasks[key]!.add(task);
          }

          // 3. Sort Keys
          final sortedKeys = groupedTasks.keys.toList()
            ..sort((a, b) {
              if (a.startsWith('Sense')) return 1;
              if (b.startsWith('Sense')) return -1;
              return a.compareTo(b);
            });

          // Global Totals
          final globalBudget = financeTasks.fold<double>(
            0,
            (sum, t) => sum + t.totalBudget,
          );
          final globalSpent = financeTasks.fold<double>(
            0,
            (sum, t) => sum + t.totalSpent,
          );

          return Column(
            children: [
              // Global Summary Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildGlobalStat(
                        context,
                        'Pressupost Total',
                        globalBudget,
                        Colors.blue,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      _buildGlobalStat(
                        context,
                        'Total Gastat',
                        globalSpent,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              // View Mode Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Phase',
                      label: Text('Per Fase'),
                      icon: Icon(Icons.label_outline),
                    ),
                    ButtonSegment(
                      value: 'Bucket',
                      label: Text('Per Estat'),
                      icon: Icon(Icons.view_column),
                    ),
                  ],
                  selected: {_groupBy},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _groupBy = newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final groupKey = sortedKeys[index];
                    final tasksInGroup = groupedTasks[groupKey]!;

                    // Group Totals
                    final groupBudget = tasksInGroup.fold<double>(
                      0,
                      (sum, t) => sum + t.totalBudget,
                    );
                    final groupSpent = tasksInGroup.fold<double>(
                      0,
                      (sum, t) => sum + t.totalSpent,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(
                          groupKey,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              'Pres: ${groupBudget.toStringAsFixed(0)}€',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Gastat: ${groupSpent.toStringAsFixed(0)}€',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          // Header Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Tasca',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Press.',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Gastat',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...tasksInGroup.map(
                            (task) => _buildTaskRow(context, task),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, Task task) {
    return InkWell(
      onTap: () {
        // Optional: Navigate to task details or expand
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: const TextStyle(fontSize: 14)),
                  if (task.isDone)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'Completada',
                        style: TextStyle(fontSize: 9, color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${task.totalBudget.toStringAsFixed(0)}€',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${task.totalSpent.toStringAsFixed(0)}€',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color:
                      task.totalSpent > task.totalBudget && task.totalBudget > 0
                      ? Colors.red
                      : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStat(
    BuildContext context,
    String label,
    double amount,
    MaterialColor color,
  ) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          NumberFormat.currency(
            locale: 'es_ES',
            symbol: '€',
            decimalDigits: 0,
          ).format(amount),
          style: TextStyle(
            color: color.shade700,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
