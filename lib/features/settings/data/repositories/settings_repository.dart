import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/farm_config.dart';

class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository(this._firestore);

  Stream<FarmConfig> getFarmConfigStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      debugPrint(
        'SettingsRepo: No authenticated user email. Returning empty config.',
      );
      return Stream.value(FarmConfig.empty());
    }

    return _firestore
        .collection('finques')
        .where('authorizedEmails', arrayContains: user.email)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'SettingsRepo: Finques Stream update. Docs found: ${snapshot.docs.length}',
          );
          if (snapshot.docs.isNotEmpty) {
            // Return the first accessible farm
            return FarmConfig.fromMap(snapshot.docs.first.data());
          } else {
            // No accessible farm found.
            return FarmConfig.empty();
          }
        })
        .handleError((e) {
          debugPrint('SettingsRepo: Error loading config from finques: $e');
          return FarmConfig.empty();
        });
  }

  Future<void> saveFarmConfig(FarmConfig config) async {
    FarmConfig configToSave = config;

    // Auto-generate fincaId if missing
    if (configToSave.fincaId == null || configToSave.fincaId!.isEmpty) {
      final slug = configToSave.name
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');

      if (slug.isEmpty) {
        // Prevent random ID generation which causes data split
        throw Exception(
          'Cannot save farm config without a valid name to generate ID.',
        );
      }
      final finalId = slug;

      configToSave = configToSave.copyWith(fincaId: finalId);
    }

    final String docId = configToSave.fincaId!;
    final data = configToSave.toMap();
    data['lastUpdatedAt'] = FieldValue.serverTimestamp();

    // Save to 'finques' collection
    await _firestore
        .collection('finques')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }
}
