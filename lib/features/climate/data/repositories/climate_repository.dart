import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/climate_model.dart';

class ClimateRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'clima_historic';
  final String? fincaId;

  ClimateRepository({this.fincaId});

  /// Save or update a list of daily data entries
  Future<void> saveHistory(List<ClimateDailyData> data) async {
    if (fincaId == null) throw Exception('FincaId not set');

    final batch = _firestore.batch();
    for (var item in data) {
      // Use date string YYYY-MM-DD as ID to avoid duplicates
      final String id = item.date.toIso8601String().split('T').first;
      final docRef = _firestore.collection(_collection).doc(id);

      final map = item.toMap();
      map['fincaId'] = fincaId;

      batch.set(docRef, map, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Generates mock data for a specific range [Mock 2.0]
  Future<void> generateMockDataRange(DateTime start, DateTime end) async {
    final List<ClimateDailyData> mocks = [];
    final days = end.difference(start).inDays + 1;

    for (int i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      // Random-ish data
      final rand = (i % 5) * 1.0;
      mocks.add(
        ClimateDailyData(
          date: date,
          maxTemp: 22.0 + rand,
          minTemp: 12.0 - (i % 2),
          rain: (i % 7 == 0) ? 12.5 : 0.0, // Rain every week
          rainAccumulated: 0.0,
          humidity: 60.0 + rand * 2,
          radiation: 15.0 + rand,
          windSpeed: 5.0 + rand,
          et0: 3.5 + (rand / 5), // Fake ET0
          isMock: true,
          fincaId: fincaId,
        ),
      );
    }
    await saveHistory(mocks);
  }

  /// Deletes all mock data
  Future<void> deleteMocks() async {
    if (fincaId == null) return;
    final snapshot = await _firestore
        .collection(_collection)
        .where('fincaId', isEqualTo: fincaId)
        .where('isMock', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Get history between two dates (inclusive)
  Future<List<ClimateDailyData>> getHistory(
    DateTime start,
    DateTime end,
  ) async {
    // Firestore doesn't support complex range on string IDs easily unless we store a real Timestamp field.
    // However, since we used ISO strings for IDs, we can query if we store 'date' as field too which we did.
    // Let's rely on the 'date' field in the document body.

    // Normalize to start of day
    final startStr = start.toIso8601String();
    final endStr = end
        .add(const Duration(days: 1))
        .toIso8601String(); // Exclusive upper bound approx

    if (fincaId == null) return [];

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('fincaId', isEqualTo: fincaId)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThan: endStr)
          .get();

      return snapshot.docs
          .map((doc) => ClimateDailyData.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('ClimateRepository: Error getting history: $e');
      return [];
    }
  }

  /// Get the latest recorded date
  Future<DateTime?> getLastEntryDate() async {
    if (fincaId == null) return null;

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('fincaId', isEqualTo: fincaId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DateTime.parse(snapshot.docs.first.data()['date']);
      }
    } catch (e) {
      debugPrint('ClimateRepository: Error getting last date: $e');
    }
    return null;
  }

  /// Deletes ALL history. Use with caution/debug only.
  Future<void> clearHistory() async {
    if (fincaId == null) return;

    final snapshot = await _firestore
        .collection(_collection)
        .where('fincaId', isEqualTo: fincaId)
        .get();

    // Firestore batch limit is 500. We must loop.
    const int batchSize = 500;
    for (int i = 0; i < snapshot.docs.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < snapshot.docs.length)
          ? i + batchSize
          : snapshot.docs.length;

      for (var j = i; j < end; j++) {
        batch.delete(snapshot.docs[j].reference);
      }
      await batch.commit();
    }
  }
}
