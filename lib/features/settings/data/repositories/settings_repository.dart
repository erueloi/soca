import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/farm_config.dart';

class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository(this._firestore);

  Stream<FarmConfig> getFarmConfigStream() {
    return _firestore
        .collection('settings')
        .doc('finca_config')
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return FarmConfig.fromMap(snapshot.data()!);
          } else {
            return FarmConfig.empty();
          }
        });
  }

  Future<void> saveFarmConfig(FarmConfig config) async {
    await _firestore
        .collection('settings')
        .doc('finca_config')
        .set(config.toMap(), SetOptions(merge: true));
  }
}
