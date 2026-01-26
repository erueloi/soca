import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:soca/core/calculators/et0_calculator.dart';
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

      batch.set(docRef, map);
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
          lastUpdated: DateTime.now(),
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

    // Normalize to start of day (Midnight)
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    final startStr = startDay.toIso8601String();
    final endStr = endDay
        .add(const Duration(days: 1))
        .toIso8601String(); // Exclusive upper bound (Next Day 00:00)

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

  Future<DateTime?> getLastCalculationTimestamp() async {
    if (fincaId == null) return null;
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('fincaId', isEqualTo: fincaId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = ClimateDailyData.fromMap(snapshot.docs.first.data());
        return data.calculatedAt;
      }
    } catch (e) {
      debugPrint('Error getting calc timestamp: $e');
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

  /// Recalculates RuralCat Soil Balance for a given month
  /// [latitude] is required to repair ET0 if missing (legacy data)
  Future<void> recalculateSoilBalance(DateTime month, double latitude) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    // Fetch existing data
    List<ClimateDailyData> days = await getHistory(start, end);
    if (days.isEmpty) return; // Nothing to calculate

    // Sort by date ascending to ensure correct accumulation
    days.sort((a, b) => a.date.compareTo(b.date));

    double currentBalance = 0.0;
    // Possible Improvement: Fetch previous month's last day balance to carry over.
    // For now, assuming start of month = 0 or just calculating relative to start.

    List<ClimateDailyData> updatedDays = [];

    for (var day in days) {
      // 0. Repair ET0 if missing (Legacy Data Fix)
      double et0 = day.et0;
      if (et0 == 0.0) {
        et0 = ET0Calculator.calculate(
          lat: latitude,
          date: day.date,
          tMax: day.maxTemp,
          tMin: day.minTemp,
          rhMean: day.humidity > 0 ? day.humidity : null,
          windSpeed: day.windSpeed > 0 ? day.windSpeed : null,
          radiation: day.radiation > 0 ? day.radiation : null,
        );
      }

      // 1. Effective Rain (Pef)
      // Check RuralCat logic:
      // If P < 4mm -> Pef = 0
      // If P >= 4mm -> Pef = P * 0.75
      double pef = 0.0;
      if (day.rain >= 4.0) {
        pef = day.rain * 0.75;
      }

      // 2. Crop Evapotranspiration (ETc)
      // ETc = ET0 * Kc
      // Kc = 0.6 (Standard for finca mol-cal-jeroni trees)
      double kc = 0.6;
      double etc = et0 * kc;

      // 3. Balance Update
      // Balance = PrevBalance + Pef - ETc
      // Cap at 35.0 (Runoff/Deep Drainage simulation)
      double rawBalance = currentBalance + pef - etc;
      currentBalance = rawBalance > 35.0 ? 35.0 : rawBalance;

      // Create updated copy
      updatedDays.add(
        ClimateDailyData(
          date: day.date,
          maxTemp: day.maxTemp,
          minTemp: day.minTemp,
          rain: day.rain,
          rainAccumulated: day.rainAccumulated,
          humidity: day.humidity,
          radiation: day.radiation,
          windSpeed: day.windSpeed,
          et0: et0, // Save repaired ET0
          isMock: day.isMock,
          fincaId: day.fincaId,
          soilBalance: currentBalance,
          lastUpdated: day.lastUpdated,
          calculatedAt: DateTime.now(), // Mark as recalculated now
        ),
      );
    }

    // Save updated data
    await saveHistory(updatedDays);
  }
}
