import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/nursery_models.dart';
import '../../data/repositories/nursery_repository.dart';

import '../../../settings/presentation/providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// Repository Provider — injects fincaId from the global farm config
// ---------------------------------------------------------------------------

final nurseryRepositoryProvider = Provider<NurseryRepository>((ref) {
  final configAsync = ref.watch(farmConfigStreamProvider);
  final fincaId = configAsync.value?.fincaId;
  return NurseryRepository(fincaId: fincaId);
});

// ---------------------------------------------------------------------------
// Stream Provider — real-time list of SeedTrays
// ---------------------------------------------------------------------------

final nurseryTraysStreamProvider =
    StreamProvider.autoDispose<List<SeedTray>>((ref) {
      final configAsync = ref.watch(farmConfigStreamProvider);
      final fincaId = configAsync.value?.fincaId;
      if (fincaId == null) return Stream.value([]);

      final repository = ref.watch(nurseryRepositoryProvider);
      return repository.getTraysStream(fincaId);
    });

// ---------------------------------------------------------------------------
// Notifier — exposes easy methods for the UI
// ---------------------------------------------------------------------------

final nurseryActionsProvider =
    NotifierProvider<NurseryActionsNotifier, void>(
      NurseryActionsNotifier.new,
    );

class NurseryActionsNotifier extends Notifier<void> {
  @override
  void build() {
    // No persistent state — this notifier is a pure action dispatcher.
  }

  NurseryRepository get _repository => ref.read(nurseryRepositoryProvider);

  String? get _fincaId =>
      ref.read(farmConfigStreamProvider).value?.fincaId;

  /// Adds a new seed tray.
  Future<void> addTray(SeedTray tray) async {
    try {
      await _repository.addTray(tray);
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error adding tray: $e');
      rethrow;
    }
  }

  /// Updates multiple fields of an existing tray.
  Future<void> updateTray(String trayId, Map<String, dynamic> fields) async {
    try {
      final fincaId = _fincaId;
      if (fincaId == null) throw Exception('FincaId not set');

      await _repository.updateTrayFields(fincaId, trayId, fields);
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error updating tray: $e');
      rethrow;
    }
  }

  /// Changes the status of an existing tray.
  Future<void> changeTrayStatus(String trayId, TrayStatus newStatus) async {
    try {
      final fincaId = _fincaId;
      if (fincaId == null) throw Exception('FincaId not set');

      await _repository.updateTrayFields(
        fincaId,
        trayId,
        {'status': newStatus.name},
      );
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error changing status: $e');
      rethrow;
    }
  }

  /// Archives a tray (shortcut for changeTrayStatus → archived).
  Future<void> archiveTray(String trayId) async {
    await changeTrayStatus(trayId, TrayStatus.archived);
  }

  /// Deletes a tray permanently from Firestore.
  Future<void> deleteTray(String trayId) async {
    try {
      final fincaId = _fincaId;
      if (fincaId == null) throw Exception('FincaId not set');

      await _repository.deleteTray(fincaId, trayId);
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error deleting tray: $e');
      rethrow;
    }
  }

  /// Adds a new item (seed) to an existing tray using arrayUnion.
  Future<void> addTrayItem(String trayId, TrayItem item) async {
    try {
      final fincaId = _fincaId;
      if (fincaId == null) throw Exception('FincaId not set');

      await _repository.updateTrayFields(
        fincaId,
        trayId,
        {'items': FieldValue.arrayUnion([item.toMap()])},
      );
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error adding tray item: $e');
      rethrow;
    }
  }

  /// Removes an item at a given index from a tray's items list.
  Future<void> removeTrayItem(String trayId, List<TrayItem> currentItems, int index) async {
    try {
      final fincaId = _fincaId;
      if (fincaId == null) throw Exception('FincaId not set');

      final updated = List<TrayItem>.from(currentItems)..removeAt(index);
      await _repository.updateTrayFields(
        fincaId,
        trayId,
        {'items': updated.map((e) => e.toMap()).toList()},
      );
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error removing tray item: $e');
      rethrow;
    }
  }

  /// Updates an item at a given index in a tray's items list.
  Future<void> updateTrayItem(String trayId, List<TrayItem> currentItems, int index, TrayItem newItem) async {
    try {
      final fincaId = _fincaId;
      if (fincaId == null) throw Exception('FincaId not set');

      final updated = List<TrayItem>.from(currentItems)..[index] = newItem;
      await _repository.updateTrayFields(
        fincaId,
        trayId,
        {'items': updated.map((e) => e.toMap()).toList()},
      );
    } catch (e) {
      debugPrint('NurseryActionsNotifier: Error updating tray item: $e');
      rethrow;
    }
  }
}
