import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/nursery_models.dart';

class NurseryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? fincaId;

  NurseryRepository({this.fincaId});

  /// Reference to the nursery_trays sub-collection for the current finca.
  CollectionReference _traysRef(String fincaId) {
    return _firestore
        .collection('finques')
        .doc(fincaId)
        .collection('nursery_trays');
  }

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  Stream<List<SeedTray>> getTraysStream(String fincaId) {
    return _traysRef(fincaId)
        .orderBy('plantedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'NurseryRepository: Got snapshot with ${snapshot.docs.length} trays.',
          );
          return snapshot.docs.map((doc) {
            return SeedTray.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        })
        .handleError((error) {
          debugPrint('NurseryRepository: Error in getTraysStream: $error');
          return <SeedTray>[];
        });
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<void> addTray(SeedTray tray) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final trayToSave = tray.copyWith(fincaId: fincaId);
    if (tray.id.isEmpty) {
      await _traysRef(fincaId!).add(trayToSave.toMap());
    } else {
      await _traysRef(fincaId!).doc(tray.id).set(trayToSave.toMap());
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateTray(SeedTray tray) async {
    if (fincaId == null) throw Exception('FincaId not set');
    final trayToSave = tray.copyWith(fincaId: fincaId);
    await _traysRef(fincaId!).doc(tray.id).update(trayToSave.toMap());
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteTray(String fincaId, String trayId) async {
    await _traysRef(fincaId).doc(trayId).delete();
  }

  /// Updates specific fields on a tray document without overwriting the rest.
  Future<void> updateTrayFields(
    String fincaId,
    String trayId,
    Map<String, dynamic> data,
  ) async {
    await _traysRef(fincaId).doc(trayId).update(data);
  }
}
