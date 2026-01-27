import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/climate_provider.dart';
import '../../domain/climate_model.dart';

import '../../presentation/widgets/climate_analytics_widgets.dart';
import 'package:soca/features/settings/presentation/providers/settings_provider.dart';
import 'package:soca/features/trees/presentation/providers/trees_provider.dart';
import 'package:soca/features/trees/data/repositories/species_repository.dart';

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

    // --- Progress UI ---
    if (!context.mounted) return;

    final progressNotifier = ValueNotifier<Map<String, int>>({
      'current': 0,
      'total': 1,
    });

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
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recalculateData(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) async {
    final progressNotifier = ValueNotifier<Map<String, dynamic>>({
      'status': 'Calculant Balanç Hídric... 🚜',
      'current': 0,
      'total': 0,
    });

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            final status = value['status'] as String;
            final current = value['current'] as int;
            final total = value['total'] as int;
            final percent = total > 0 ? current / total : 0.0;

            return AlertDialog(
              title: const Text('Recalculant...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status),
                  const SizedBox(height: 16),
                  if (total > 0) ...[
                    LinearProgressIndicator(value: percent),
                    const SizedBox(height: 8),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}% ($current/$total)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ] else
                    const LinearProgressIndicator(),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      // 1. Recalculate Climate Balance (Simulated Progress)
      final config = await ref.read(farmConfigStreamProvider.future);

      await ref
          .read(climateRepositoryProvider)
          .recalculateSoilBalance(selectedDate, config.latitude);

      if (selectedDate.month != DateTime.now().month) {
        await ref
            .read(climateRepositoryProvider)
            .recalculateSoilBalance(DateTime.now(), config.latitude);
      }

      // 2. Prepare Tree Recalculation
      progressNotifier.value = {
        'status': 'Actualitzant arbres... 🌳',
        'current': 0,
        'total': 1, // Dummy total to start
      };

      final historyStart = DateTime.now().subtract(const Duration(days: 60));
      final historyEnd = DateTime.now();
      final climateHistory = await ref
          .read(climateRepositoryProvider)
          .getHistory(historyStart, historyEnd);

      final speciesList = await ref
          .read(speciesRepositoryProvider)
          .getSpecies()
          .first;

      // 3. Recalculate Trees with Progress
      await ref
          .read(treesRepositoryProvider)
          .recalculateAllTreesBalance(
            climateHistory,
            speciesList,
            onProgress: (current, total) {
              progressNotifier.value = {
                'status': 'Actualitzant arbres... 🌳',
                'current': current,
                'total': total,
              };
            },
          );

      // Invalidate Providers to refresh UI
      ref.invalidate(climateComparisonProvider);
      ref.invalidate(climateHistoryProvider);

      // Close Dialog
      if (context.mounted) Navigator.pop(context);

      // Success Message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Càlcul completat correctament! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recalculant: $e'),
            backgroundColor: Colors.red,
          ),
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
        actions: _buildActions(context, ref, selectedDate),
      ),
      body: comparisonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error carregant dades: $e')),
        data: (comparison) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 2. Header Grid (KPIs)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double spacing = 16.0;
                        // Desktop splits: 3 cards.
                        final bool isDesktop =
                            constraints.maxWidth >
                            800; // > 800 for 3 nice cards

                        // Use fixed height for desktop grid items to ensure equality
                        // Decreased from 220 to 170 to 150 for compactness
                        final double fixedHeight = 150.0;

                        if (isDesktop) {
                          final double itemWidth =
                              (constraints.maxWidth - (spacing * 2)) / 3;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                height: fixedHeight,
                                child: _buildComparisonCard(
                                  context,
                                  'Pluja ${_getMonthName(selectedDate.month)}',
                                  comparison.currentData,
                                  comparison.totalRainPrevious,
                                  comparison.diffPercentage,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                height: fixedHeight,
                                child: _buildInfoCard(
                                  context,
                                  'Any Hidrològic',
                                  '${hydroTotal.toStringAsFixed(1)} mm',
                                  Colors.teal,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                height: fixedHeight,
                                child: _buildColdHoursCard(
                                  context,
                                  coldHours,
                                  isVertical: true,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Mobile: Vertical Stack
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildComparisonCard(
                                context,
                                'Pluja ${_getMonthName(selectedDate.month)}',
                                comparison.currentData,
                                comparison.totalRainPrevious,
                                comparison.diffPercentage,
                                Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoCard(
                                context,
                                'Any Hidrològic',
                                '${hydroTotal.toStringAsFixed(1)} mm',
                                Colors.teal,
                              ),
                              const SizedBox(height: 12),
                              _buildColdHoursCard(
                                context,
                                coldHours,
                                isVertical: false,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3. Main Content (Analytics Section)
                    ClimateAnalyticsSection(
                      days: comparison.currentData,
                      previousDays: comparison.previousData,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) {
    final isCompact = MediaQuery.of(context).size.width < 600;

    if (isCompact) {
      return [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            if (value == 'download') {
              _downloadData(context, ref, selectedDate);
            } else if (value == 'recalc') {
              _recalculateData(context, ref, selectedDate);
            } else if (value == 'mock') {
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
            } else if (value == 'clear_mock') {
              await ref.read(climateControllerProvider).deleteMocks();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mocks eliminats! 🗑️')),
                );
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.cloud_download, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text('Descarregar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'recalc',
              child: Row(
                children: [
                  Icon(Icons.calculate, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text('Recalcular'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'mock',
              child: Row(
                children: [
                  Icon(Icons.science, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Generar Mock Data'),
                ],
              ),
            ),
            const PopupMenuItem(
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
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.cloud_download, color: Colors.blueGrey),
          tooltip: 'Descarregar dades manualment',
          onPressed: () => _downloadData(context, ref, selectedDate),
        ),
        IconButton(
          icon: const Icon(Icons.calculate, color: Colors.blueGrey),
          tooltip: 'Recalcular model de reg (RuralCat)',
          onPressed: () => _recalculateData(context, ref, selectedDate),
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
      ];
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Gener',
      'Febrer',
      'Març',
      'Abril',
      'Maig',
      'Juny',
      'Juliol',
      'Agost',
      'Setembre',
      'Octubre',
      'Novembre',
      'Desembre',
    ];
    return months[month - 1];
  }

  Widget _buildComparisonCard(
    BuildContext context,
    String title,
    List<ClimateDailyData> data,
    double previousTotal,
    double percentDiff,
    Color color,
  ) {
    final double currentTotal = data.fold(0.0, (sum, e) => sum + e.rain);
    final bool moreRain = currentTotal >= previousTotal;
    final String sign = percentDiff >= 0 ? '+' : '';

    // Stats
    final int rainyDays = data.where((d) => d.rain >= 0.1).length;
    final double maxDaily = data.fold(
      0.0,
      (max, e) => e.rain > max ? e.rain : max,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                // Bigger Title
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${currentTotal.toStringAsFixed(1)} mm',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 26, // Compact but readable
              ),
            ),
            const SizedBox(height: 2),
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
                'vs prev: ${previousTotal.toStringAsFixed(1)} mm ($sign${percentDiff.toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: moreRain ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Extra Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Dies Pluja',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '$rainyDays',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Màx Diari',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '${maxDaily.toStringAsFixed(1)} mm',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
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
    // Hydro Year Date Range Logic
    final now = DateTime.now();
    final int startYear = (now.month >= 10) ? now.year : now.year - 1;
    final int endYear = startYear + 1;
    final String range = "1 oct. $startYear - 30 set. $endYear";

    // Health Logic
    final startDate = DateTime(startYear, 10, 1);
    final daysPassed = now.difference(startDate).inDays + 1;
    final expected = 550.0 * (daysPassed / 365.0);

    // Parse current value
    double current = 0.0;
    try {
      final numericPart = value.split(' ').first;
      current = double.parse(numericPart);
    } catch (_) {}

    final bool healthy = current > expected;
    final Color displayColor = healthy ? Colors.green.shade600 : color;
    final Color bgColor = healthy
        ? Colors.green.shade50
        : color.withValues(alpha: 0.05);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: displayColor.withValues(alpha: 0.3)),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center Vertically
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                // Bigger Title
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(range, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: displayColor,
                fontWeight: FontWeight.bold,
                fontSize: 26, // Consistent size
              ),
            ),
            const SizedBox(height: 4),
            if (healthy)
              const Text(
                'Bon ritme! 🌿',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text('', style: TextStyle(fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildColdHoursCard(
    BuildContext context,
    double hours, {
    bool isVertical = false,
  }) {
    // Config
    final Color cardColor = const Color(0xFFE0F7FA);
    final Color borderColor = const Color(0xFFB2EBF2);
    final Color textColor = Colors.blueGrey;

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: isVertical
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hores de Fred (<7°C)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      // Change to match other titles
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nov - Mar',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hours.toStringAsFixed(0)} h',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 26, // Consistent size
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.ac_unit, size: 20, color: Colors.blueGrey),
                ],
              )
            : Row(
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      // Reduced from DisplayMedium
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
}
