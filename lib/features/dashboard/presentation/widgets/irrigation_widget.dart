import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../trees/presentation/providers/trees_provider.dart';
import '../../../trees/domain/entities/watering_event.dart';
import '../../../trees/domain/entities/tree.dart';
import '../../../trees/domain/entities/tree_extensions.dart';
import '../../../trees/presentation/pages/watering_page.dart';

class IrrigationWidget extends ConsumerWidget {
  const IrrigationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need two streams:
    // 1. Global Watering Events (for daily summary) -> But the default provider filters by date!
    //    We need to ensure we get TODAY's events.
    //    The default 'wateringFiltersProvider' is Last 7 Days, which INCLUDES today. So we can use it,
    //    but we must filter the list manually for 'today'.

    // 2. Trees (for deficit check) -> To see last watering date.
    //    Wait, we don't have 'lastWateringDate' on the Tree entity directly updated in real-time unless we query subcollections.
    //    Actually, we do have 'timeline' but that's generic.
    //    The most efficient way for "Deficit" without reading 300 subcollections is expensive.
    //    Constraint: The user asked for it.
    //    Optimization: For now, we can only check the 'regs' collection group if we have all data? No.
    //    Alternative: We can't easily check 'last 3 days' for ALL trees without reading all their subcollections.
    //    COMPROMISE: We will check the 'Global Watering Events' from the last 7 days.
    //    Any tree NOT in that list has a deficit (if we assume deficit = >7 days).
    //    User asked for "> 3 days".
    //    So, we get watering events for last 3 days. Any tree ID NOT present = deficit.
    //    This is approximations but much cheaper than reading all subcollections.

    final wateringAsync = ref.watch(globalWateringEventsProvider);
    final treesAsync = ref.watch(treesStreamProvider);

    final activeTrees = (treesAsync.asData?.value ?? [])
            .where((t) =>
                t.status != 'Planned' &&
                t.status != 'Existent' &&
                !t.isVeteran)
            .toList();
    final treesNeedingWater =
        activeTrees.where((t) => t.needsWater).toList();
    final critical = activeTrees
        .where((t) => t.waterStatusText == 'Estrès Hídric')
        .length;
    final optional = activeTrees
        .where((t) => t.waterStatusText == 'Reg Opcional')
        .length;

    // Calculate LED Color based on status
    Color ledColor = Colors.grey;
    if (treesAsync.hasValue) {
      if (critical > 0) {
        ledColor = Colors.red;
      } else if (optional > 0) {
        ledColor = Colors.amber;
      } else {
        ledColor = Colors.green;
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WateringPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.water_drop, color: Colors.blue[600], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Gestió de Reg',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BlinkingLed(color: ledColor),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: wateringAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                  data: (events) =>
                      _buildLiveContent(context, events, treesAsync),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: treesNeedingWater.isNotEmpty
                    ? ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(wateringFiltersProvider.notifier)
                              .updateFilters(onlyNeedsWater: true);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WateringPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.water_drop, size: 18),
                        label: Text('REGAR ARA (${treesNeedingWater.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WateringPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: const Text('GESTIONAR REG'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade800,
                          side: BorderSide(color: Colors.blue.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveContent(
    BuildContext context,
    List<WateringEvent> recentEvents,
    AsyncValue<List<Tree>> treesAsync,
  ) {
    // 1. Summary (Today)
    final now = DateTime.now();
    final todayEvents = recentEvents
        .where(
          (e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day,
        )
        .toList();

    final todayLiters = todayEvents.fold<double>(
      0,
      (sum, e) => sum + (e.liters),
    );

    return treesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox(),
      data: (allTrees) {
        final activeTrees = allTrees
            .where((t) =>
                t.status != 'Planned' &&
                t.status != 'Existent' &&
                !t.isVeteran)
            .toList();
        final treesNeedingWater =
            activeTrees.where((t) => t.needsWater).toList();
        final criticalCount = activeTrees
            .where((t) => t.waterStatusText == 'Estrès Hídric')
            .length;

        final totalLitersNeeded = treesNeedingWater.fold<int>(
          0,
          (sum, t) => sum + t.waterNeedLiters,
        );
        final double maxHours = treesNeedingWater.isEmpty
            ? 0.0
            : treesNeedingWater
                .map((t) => t.recommendedWateringHours)
                .fold<double>(0.0, (max, h) => h > max ? h : max);
        final double neededHours = maxHours > 0.0
            ? maxHours
            : (treesNeedingWater.isNotEmpty ? 2.0 : 0.0);
        final double ibcTanks = totalLitersNeeded / 1000.0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Today's Stats
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Regat Avui',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${todayLiters.toInt()} L',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Status Warning/Info
              if (treesNeedingWater.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: criticalCount > 0
                        ? Colors.red.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: criticalCount > 0
                          ? Colors.red.shade200
                          : Colors.amber.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            criticalCount > 0
                                ? Icons.warning_amber_rounded
                                : Icons.water_drop_outlined,
                            color: criticalCount > 0
                                ? Colors.red.shade800
                                : Colors.amber.shade900,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              criticalCount > 0
                                  ? '$criticalCount arbres amb Estrès Hídric'
                                  : '${treesNeedingWater.length} arbres amb Reg Opcional',
                              style: TextStyle(
                                color: criticalCount > 0
                                    ? Colors.red.shade900
                                    : Colors.amber.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.opacity,
                                  size: 14, color: Colors.blueGrey.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '$totalLitersNeeded L necessaris',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 14, color: Colors.blueGrey.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '~${neededHours.toStringAsFixed(1)} h',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (totalLitersNeeded >= 500) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.propane_tank_outlined,
                                size: 13, color: Colors.blueGrey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '${ibcTanks.toStringAsFixed(1)} dipòsits IBC (1.000 L)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Tots els arbres ben hidratats (${activeTrees.length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BlinkingLed extends StatefulWidget {
  final Color color;
  const _BlinkingLed({this.color = Colors.green});

  @override
  State<_BlinkingLed> createState() => _BlinkingLedState();
}

class _BlinkingLedState extends State<_BlinkingLed>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
