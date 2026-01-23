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

    // Calculate LED Color based on status
    Color ledColor = Colors.grey;
    if (treesAsync.hasValue) {
      final trees = treesAsync.value!;
      final critical = trees
          .where((t) => t.waterStatusText == 'Estrès Hídric')
          .length;
      final optional = trees
          .where((t) => t.waterStatusText == 'Reg Opcional')
          .length;

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
              const SizedBox(height: 16),
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
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('PARADA EMERGÈNCIA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[800],
                    elevation: 0,
                    side: BorderSide(color: Colors.red[200]!),
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
    // 1. Manual Summary (Today)
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

    // 2. Deficit Check (RuralCat Model)
    // We check how many trees are in "Estrès Hídric" (Critical) or "Reg Opcional"
    return treesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox(),
      data: (allTrees) {
        final criticalCount = allTrees
            .where((t) => t.waterStatusText == 'Estrès Hídric')
            .length;
        final optionalCount = allTrees
            .where((t) => t.waterStatusText == 'Reg Opcional')
            .length;

        return Column(
          children: [
            // Today's Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reg Manual (Avui)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    '${todayLiters.toInt()} Litres',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Status Warning/Info
            if (criticalCount > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Atenció: $criticalCount arbres amb Estrès Hídric',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (optionalCount > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      color: Colors.amber.shade900,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Info: $optionalCount arbres amb Reg Opcional',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tots els arbres ben hidratats',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
