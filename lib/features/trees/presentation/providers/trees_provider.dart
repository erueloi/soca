import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/watering_event.dart';
import '../../data/repositories/trees_repository.dart';

final treesRepositoryProvider = Provider<TreesRepository>((ref) {
  return TreesRepository();
});

final treesStreamProvider = StreamProvider<List<Tree>>((ref) {
  final repository = ref.watch(treesRepositoryProvider);
  return repository.getTreesStream();
});

class WateringFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? treeId;

  const WateringFilters({this.startDate, this.endDate, this.treeId});

  WateringFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? treeId,
  }) {
    return WateringFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      treeId: treeId ?? this.treeId,
    );
  }
}

final wateringFiltersProvider =
    NotifierProvider<WateringFiltersNotifier, WateringFilters>(
      WateringFiltersNotifier.new,
    );

class WateringFiltersNotifier extends Notifier<WateringFilters> {
  @override
  WateringFilters build() {
    final now = DateTime.now();
    return WateringFilters(
      startDate: now.subtract(const Duration(days: 6)),
      endDate: now,
      treeId: null,
    );
  }

  void updateFilters({DateTime? start, DateTime? end, String? treeId}) {
    state = state.copyWith(startDate: start, endDate: end, treeId: treeId);
  }

  void reset() {
    final now = DateTime.now();
    state = WateringFilters(
      startDate: now.subtract(const Duration(days: 6)),
      endDate: now,
      treeId: null,
    );
  }

  void setDates(DateTimeRange range) {
    state = state.copyWith(startDate: range.start, endDate: range.end);
  }

  void setTreeId(String? id) {
    state = state.copyWith(treeId: id);
  }
}

final globalWateringEventsProvider =
    StreamProvider.autoDispose<List<WateringEvent>>((ref) {
      final repository = ref.watch(treesRepositoryProvider);
      final filters = ref.watch(wateringFiltersProvider);

      return repository.getGlobalWateringEvents(
        startDate: filters.startDate,
        endDate: filters.endDate,
        treeId: filters.treeId,
      );
    });

final selectedTreeProvider = NotifierProvider<SelectedTreeNotifier, Tree?>(
  SelectedTreeNotifier.new,
);

class SelectedTreeNotifier extends Notifier<Tree?> {
  @override
  Tree? build() => null;

  void selectTree(Tree? tree) {
    state = tree;
  }
}
