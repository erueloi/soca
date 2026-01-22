import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DataRecoveryService {
  final FirebaseFirestore _firestore;

  DataRecoveryService(this._firestore);

  Future<Map<String, int>> revertFincaId(
    String incorrectId,
    String correctId,
    String currentUserId,
  ) async {
    final Map<String, int> results = {};

    // 1. Grant temporary access to the "incorrect" finca data
    // The security rules require the user to have the fincaId in approvedFincas
    // to read/write documents associated with it.
    try {
      debugPrint(
        'DataRecovery: Granting temp access for $incorrectId to user $currentUserId...',
      );
      await _firestore.collection('users').doc(currentUserId).update({
        'authorizedFincas': FieldValue.arrayUnion([incorrectId]),
      });

      // Verify it was actually written
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final authorized = List<String>.from(
        userDoc.data()?['authorizedFincas'] ?? [],
      );
      debugPrint('DataRecovery: Current authorizedFincas: $authorized');

      if (!authorized.contains(incorrectId)) {
        throw Exception(
          'Access grant failed: ID not found in authorizedFincas after update.',
        );
      }
      debugPrint('DataRecovery: Temp access granted successfully.');

      // Wait a moment for permissions to propagate
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Error granting temp access: $e');
      throw Exception(
        'Could not grant temporary access to data. Please explicitly deploy your Firestore Rules (firebase.rules). Original Error: $e',
      );
    }

    // List of collections to check (excluding 'users')
    final collections = [
      'trees',
      'species',
      'plantes_hort',
      'espais_hort',
      'patrons_rotacio',
      'tasks',
      'clima_historic',
      'construction_points',
      'construction_plans',
    ];

    try {
      for (final col in collections) {
        debugPrint('DataRecovery: Processing collection $col...');
        try {
          final snap = await _firestore
              .collection(col)
              .where('fincaId', isEqualTo: incorrectId)
              .get();

          debugPrint('DataRecovery: Found ${snap.docs.length} docs in $col');

          int count = 0;
          final batch = _firestore.batch();

          for (var doc in snap.docs) {
            batch.update(doc.reference, {'fincaId': correctId});
            count++;

            if (count % 400 == 0) {
              await batch.commit();
            }
          }

          if (count > 0 && count % 400 != 0) {
            await batch.commit();
          }

          results[col] = count;
          debugPrint('DataRecovery: Updated $count docs in $col');
        } catch (e) {
          debugPrint('DataRecovery: Failed processing collection $col: $e');
          // Don't rethrow, record error and continue
          results['$col (ERROR)'] = -1;
        }
      }

      // Process subcollections using CollectionGroup queries
      final subCollections = ['evolucio', 'historic_ia', 'seguiment', 'regs'];

      for (final col in subCollections) {
        debugPrint('DataRecovery: Processing subcollection (Group) $col...');
        try {
          // Use collectionGroup to find documents across all parents
          final snap = await _firestore
              .collectionGroup(col)
              .where('fincaId', isEqualTo: incorrectId)
              .get();

          debugPrint('DataRecovery: Found ${snap.docs.length} docs in $col');

          int count = 0;
          final batch = _firestore.batch();

          for (var doc in snap.docs) {
            batch.update(doc.reference, {'fincaId': correctId});
            count++;

            if (count % 400 == 0) {
              await batch.commit();
            }
          }

          if (count > 0 && count % 400 != 0) {
            await batch.commit();
          }

          results[col] = count;
          debugPrint('DataRecovery: Updated $count docs in $col');
        } catch (e) {
          debugPrint('DataRecovery: Failed processing subcollection $col: $e');
          results['$col (ERROR)'] = -1;
        }
      }

      // 2. Fix the User Document specifically
      // Remove bad ID, ensure good ID is present
      await _firestore.collection('users').doc(currentUserId).update({
        'authorizedFincas': FieldValue.arrayRemove([incorrectId]),
      });
      await _firestore.collection('users').doc(currentUserId).update({
        'authorizedFincas': FieldValue.arrayUnion([correctId]),
      });
      results['users'] = 1;
    } catch (e) {
      debugPrint(
        'DataRecovery: Error converting $incorrectId to $correctId: $e',
      );
      rethrow;
    }

    return results;
  }
}
