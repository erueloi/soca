import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/climate_provider.dart';
import '../../domain/climate_model.dart';
import 'package:fl_chart/fl_chart.dart';

class ClimaPage extends ConsumerWidget {
  const ClimaPage({super.key});

  Future<void> _downloadData(
    BuildContext context,
    WidgetRef ref,
    DateTime initialDate,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(2000);

    // Default Range
    final DateTime defaultStart = DateTime(
      initialDate.year,
      initialDate.month,
      1,
    );
    final DateTime defaultEnd = DateTime(
      initialDate.year,
      initialDate.month + 1,
      0,
    );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: defaultStart,
        end: defaultEnd.isAfter(now) ? now : defaultEnd,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !context.mounted) return;

    // Default to false
    bool overwrite = false;

    // ALways show confirmation dialog to allow 'Overwrite' selection
    final days = picked.end.difference(picked.start).inDays + 1;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        bool localOverwrite = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmar descàrrega'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Has seleccionat $days dies.'),
                  if (days > 31)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠️ Atenció: Rang gran, pot tardar.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Sobreescriure dades existents'),
                    subtitle: const Text(
                      'Forçar actualització (útil per avui)',
                    ),
                    value: localOverwrite,
                    onChanged: (val) {
                      setState(() => localOverwrite = val == true);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel·lar'),
                  onPressed: () => Navigator.pop(context, null),
                ),
                FilledButton(
                  child: const Text('Descarregar'),
                  onPressed: () => Navigator.pop(context, {
                    'confirmed': true,
                    'overwrite': localOverwrite,
                  }),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result['confirmed'] != true) return;
    overwrite = result['overwrite'] ?? false;

    debugPrint(
      'Climate Sync: Range ${picked.start} - ${picked.end}. Overwrite: $overwrite',
    );

    if (!context.mounted) return;

    // --- Progress UI ---
    // Use ValueNotifier to communicate progress to Dialog
    final progressNotifier = ValueNotifier<Map<String, int>>({
      'current': 0,
      'total': 1,
    }); // 1 to avoid div by zero initially

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return ValueListenableBuilder<Map<String, int>>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            final current = value['current']!;
            final total = value['total']!;
            final double percent = (total > 0) ? current / total : 0.0;

            return AlertDialog(
              title: const Text('Sincronitzant... ☁️'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: percent),
                  const SizedBox(height: 16),
                  Text('$current de $total dies completats'),
                  const SizedBox(height: 8),
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // --- Execution ---
    try {
      final count = await ref.read(climateControllerProvider).syncRange(
        picked.start,
        picked.end,
        (current, total) {
          progressNotifier.value = {'current': current, 'total': total};
        },
        overwrite: overwrite,
      );

      // Close Progress Dialog
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sincronització completada! ✅\n$count nous dies baixats.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close Progress Dialog on error too
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch Data
    final comparisonAsync = ref.watch(climateComparisonProvider);
    final selectedDate = ref.watch(selectedMonthProvider);
    final hydroTotal = ref.watch(hydroYearTotalProvider);
    final coldHours = ref.watch(coldHoursProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                ref
                    .read(selectedMonthProvider.notifier)
                    .setDate(
                      DateTime(selectedDate.year, selectedDate.month - 1, 1),
                    );
              },
            ),
            Text(
              '${_getMonthName(selectedDate.month)} ${selectedDate.year}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                ref
                    .read(selectedMonthProvider.notifier)
                    .setDate(
                      DateTime(selectedDate.year, selectedDate.month + 1, 1),
                    );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download, color: Colors.blueGrey),
            tooltip: 'Descarregar dades manualment',
            onPressed: () => _downloadData(context, ref, selectedDate),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.build_circle_outlined),
            onSelected: (value) async {
              if (value == 'mock') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  await ref
                      .read(climateControllerProvider)
                      .generateMocks(picked.start, picked.end);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mocks generats! 🧪')),
                    );
                  }
                }
              }
              if (value == 'clear_mock') {
                await ref.read(climateControllerProvider).deleteMocks();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mocks eliminats! 🗑️')),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'mock',
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Generar Mock Data'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear_mock',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar Mocks'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: comparisonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error carregant dades: $e')),
        data: (comparison) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 2. Accumulation Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildComparisonCard(
                        context,
                        'Pluja ${_getMonthName(selectedDate.month)}',
                        comparison.totalRainCurrent,
                        comparison.totalRainPrevious,
                        comparison.diffPercentage,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        'Any Hidrològic',
                        '${hydroTotal.toStringAsFixed(1)} mm',
                        Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Cold Hours Card
                _buildColdHoursCard(context, coldHours),
                const SizedBox(height: 24),

                // 4. Rain Chart Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pluviòmetre Històric',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            // Legend
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${selectedDate.year}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 12,
                                  height: 12,
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${selectedDate.year - 1}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Precipitació acumulada diària (mm)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 250,
                          child: _buildRainChart(comparison, context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Gen',
      'Feb',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Oct',
      'Nov',
      'Des',
    ];
    return months[month - 1];
  }

  Widget _buildComparisonCard(
    BuildContext context,
    String title,
    double current,
    double previous,
    double percentDiff,
    Color color,
  ) {
    final bool moreRain = current >= previous;
    final String sign = percentDiff >= 0 ? '+' : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${current.toStringAsFixed(1)} mm',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Comparison Subtitle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (moreRain ? Colors.green : Colors.red).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'vs prev: ${previous.toStringAsFixed(1)} ($sign${percentDiff.toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: moreRain ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Placeholder to align height with comparison card
            const SizedBox(height: 4),
            const Text(
              '',
              style: TextStyle(fontSize: 10, height: 1.4),
            ), // Empty space filler
          ],
        ),
      ),
    );
  }

  Widget _buildColdHoursCard(BuildContext context, double hours) {
    return Card(
      color: const Color(0xFFE0F7FA), // Light Cyan/Pastel Blue
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFB2EBF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.ac_unit, size: 48, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hores de Fred (<7°C)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Acumulat des de Novembre',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Spacer(),
            Text(
              hours.toStringAsFixed(0),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              ' h',
              style: TextStyle(
                fontSize: 20,
                color: Colors.blueGrey,
                height: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRainChart(
    ClimateMonthComparison comparison,
    BuildContext context,
  ) {
    // We assume 31 days max for simplicity of the X axis, or use actual month days.
    final daysInMonth = DateUtils.getDaysInMonth(
      comparison.month.year,
      comparison.month.month,
    );

    // Map data by day
    final Map<int, double> currentMap = {
      for (var d in comparison.currentData) d.date.day: d.rain,
    };
    final Map<int, double> prevMap = {
      for (var d in comparison.previousData) d.date.day: d.rain,
    };

    List<BarChartGroupData> bars = [];
    for (int i = 1; i <= daysInMonth; i++) {
      final valCurrent = currentMap[i] ?? 0.0;
      final valPrev = prevMap[i] ?? 0.0;

      // Only show if there's data in at least one year OR if we want to show empty days
      // Showing all days gives better context of time.

      final isHighRain = valCurrent > 5.0;

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            // Previous Year (Ghost)
            BarChartRodData(
              toY: valPrev,
              color: Colors.grey.withValues(alpha: 0.3),
              width: 6,
              borderRadius: BorderRadius.circular(2),
            ),
            // Current Year
            BarChartRodData(
              toY: valCurrent,
              color: isHighRain ? Colors.green[800] : Colors.green[400],
              width: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ],
          showingTooltipIndicators: valCurrent > 0 || valPrev > 0
              ? [1]
              : [], // Tooltip on current rod
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: bars,
        alignment: BarChartAlignment.center,
        maxY: 60,
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                Colors.transparent, // Fix deprecated tooltipBgColor if needed
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (rodIndex == 0) {
                return null; // Ignore ghost rod tooltip logic here, simpler
              }
              final currentVal = group.barRods[1].toY;
              final prevVal = group.barRods[0].toY;

              // Only show if substantial? Or always?
              // Space is tight.
              return BarTooltipItem(
                currentVal > 0 ? currentVal.toStringAsFixed(1) : '',
                const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                children: prevVal > 0
                    ? [
                        TextSpan(
                          text: '\n(${prevVal.toStringAsFixed(1)})',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 8,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ]
                    : [],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 30,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()} mm',
                style: const TextStyle(fontSize: 8, color: Colors.grey),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
