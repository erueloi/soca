import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/home_widget_service.dart';
import '../../features/tasks/presentation/providers/tasks_provider.dart';
import '../../features/dashboard/presentation/providers/weather_provider.dart';
import '../../features/trees/presentation/providers/trees_provider.dart';

class WidgetSyncManager extends ConsumerWidget {
  final Widget child;
  const WidgetSyncManager({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to Tasks
    ref.listen(tasksStreamProvider, (previous, next) {
      next.whenData((tasks) {
        ref.read(homeWidgetServiceProvider).updateAgenda(tasks);
      });
    });

    // Listen to Weather
    ref.listen(weatherProvider, (previous, next) {
      next.whenData((weather) {
        ref.read(homeWidgetServiceProvider).updateStatus(weather);
      });
    });

    // Listen to Trees for irrigation status
    ref.listen(treesStreamProvider, (previous, next) {
      next.whenData((trees) {
        ref.read(homeWidgetServiceProvider).updateTreeIrrigationStatus(trees);
      });
    });

    return child;
  }
}
