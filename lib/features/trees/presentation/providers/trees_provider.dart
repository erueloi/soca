import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/watering_event.dart';
import '../../data/repositories/trees_repository.dart';

import '../../../settings/presentation/providers/settings_provider.dart';

final treesRepositoryProvider = Provider<TreesRepository>((ref) {
  final configAsync = ref.watch(farmConfigStreamProvider);
  final fincaId = configAsync.value?.fincaId;
  return TreesRepository(fincaId: fincaId);
});

final treesStreamProvider = StreamProvider<List<Tree>>((ref) {
  final repository = ref.watch(treesRepositoryProvider);
  return repository.getTreesStream();
});

class _Sentinel {
  const _Sentinel();
}

const _sentinel = _Sentinel();

class WateringFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? treeId;
  final String? species;
  final String? reference;

  const WateringFilters({
    this.startDate,
    this.endDate,
    this.treeId,
    this.species,
    this.reference,
  });

  WateringFilters copyWith({
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    Object? treeId = _sentinel,
    Object? species = _sentinel,
    Object? reference = _sentinel,
  }) {
    return WateringFilters(
      startDate: startDate == _sentinel
          ? this.startDate
          : startDate as DateTime?,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      treeId: treeId == _sentinel ? this.treeId : treeId as String?,
      species: species == _sentinel ? this.species : species as String?,
      reference: reference == _sentinel ? this.reference : reference as String?,
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
      species: null,
      reference: null,
    );
  }

  void updateFilters({
    DateTime? start,
    DateTime? end,
    String? treeId,
    String? species,
    String? reference,
  }) {
    state = state.copyWith(
      startDate: start,
      endDate: end,
      treeId: treeId,
      species: species,
      reference: reference,
    );
  }

  void reset() {
    final now = DateTime.now();
    state = WateringFilters(
      startDate: now.subtract(const Duration(days: 6)),
      endDate: now,
      treeId: null,
      species: null,
      reference: null,
    );
  }

  void setDates(DateTimeRange range) {
    state = state.copyWith(startDate: range.start, endDate: range.end);
  }

  void setTreeId(String? id) {
    state = state.copyWith(treeId: id);
  }

  void setSpecies(String? species) {
    state = state.copyWith(species: species);
  }

  void setReference(String? reference) {
    state = state.copyWith(reference: reference);
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
