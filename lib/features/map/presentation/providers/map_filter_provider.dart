import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapFilterState {
  final DateTimeRange? plantingDateRange;

  const MapFilterState({this.plantingDateRange});

  MapFilterState copyWith({
    DateTimeRange? plantingDateRange,
    bool clearDateRange = false,
  }) {
    return MapFilterState(
      plantingDateRange: clearDateRange
          ? null
          : (plantingDateRange ?? this.plantingDateRange),
    );
  }
}

class MapFilterNotifier extends Notifier<MapFilterState> {
  @override
  MapFilterState build() {
    return const MapFilterState();
  }

  void setPlantingDateRange(DateTimeRange? range) {
    state = state.copyWith(
      plantingDateRange: range,
      clearDateRange: range == null,
    );
  }
}

final mapFilterProvider = NotifierProvider<MapFilterNotifier, MapFilterState>(
  MapFilterNotifier.new,
);
