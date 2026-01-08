import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/meteocat_service.dart';
import '../../domain/climate_model.dart';
import 'package:soca/core/calculators/et0_calculator.dart';
import '../../data/repositories/climate_repository.dart';
import 'package:soca/features/settings/presentation/providers/settings_provider.dart';

// final climateRepositoryProvider = Provider((ref) => ClimateRepository());

// --- State Management for Climate View ---

// Selected Month (Defaults to Now)
// Selected Month (Defaults to Now)
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setDate(DateTime date) {
    state = date;
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

// Comparison Data Provider
final climateComparisonProvider = FutureProvider<ClimateMonthComparison>((
  ref,
) async {
  final selectedDate = ref.watch(selectedMonthProvider);
  final repository = ref.watch(climateRepositoryProvider);
  // final service = ref.watch(meteocatServiceProvider); // Unused

  // 1. Define Ranges
  // Current Month
  final startCurrent = DateTime(selectedDate.year, selectedDate.month, 1);
  final endCurrent = DateTime(
    selectedDate.year,
    selectedDate.month + 1,
    0,
  ); // Last day of month

  // Previous Year Month
  final startPrevious = DateTime(selectedDate.year - 1, selectedDate.month, 1);
  final endPrevious = DateTime(
    selectedDate.year - 1,
    selectedDate.month + 1,
    0,
  );

  // 2. Fetch Function (DRY)
  // Ensures data exists in DB, fetches from API if missing, returns loaded data.
  Future<List<ClimateDailyData>> ensureAndLoad(
    DateTime start,
    DateTime end,
  ) async {
    // Only fetch up to NOW if the range implies future
    final now = DateTime.now();
    DateTime safeEnd = end;
    if (safeEnd.isAfter(now)) safeEnd = now;

    // If start is after now (entirely future), return empty
    if (start.isAfter(now)) return [];

    // Check DB first
    // STRICT QUOTA MODE: ONLY Load from DB. No auto-fetch.
    return await repository.getHistory(start, safeEnd);
  }

  final currentList = await ensureAndLoad(startCurrent, endCurrent);
  final previousList = await ensureAndLoad(startPrevious, endPrevious);

  return ClimateMonthComparison(
    month: selectedDate,
    currentData: currentList,
    previousData: previousList,
  );
});

// Controller for Manual Data Fetching
final climateControllerProvider = Provider(
  (ref) => ManualClimateController(ref),
);

class ManualClimateController {
  final Ref _ref;
  ManualClimateController(this._ref);

  Future<int> syncRange(
    DateTime start,
    DateTime end,
    Function(int current, int total) onProgress,
  ) async {
    final service = _ref.read(meteocatServiceProvider);
    final repository = _ref.read(climateRepositoryProvider);

    // 1. Analyze what we already have
    final existingData = await repository.getHistory(start, end);
    final existingDates = existingData
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();

    // 2. Identify missing days
    final List<DateTime> missingDays = [];
    final daysDiff = end.difference(start).inDays;

    for (int i = 0; i <= daysDiff; i++) {
      final date = start.add(Duration(days: i));
      // Normalize to midnight
      final normalized = DateTime(date.year, date.month, date.day);

      // Skip future
      if (normalized.isAfter(DateTime.now())) continue;

      if (!existingDates.contains(normalized)) {
        missingDays.add(normalized);
      }
    }

    if (missingDays.isEmpty) return 0;

    int downloaded = 0;
    int total = missingDays.length;

    // 3. Fetch missing days one by one
    for (int i = 0; i < total; i++) {
      final date = missingDays[i];

      // Notify Progress (Starting this item)
      onProgress(i + 1, total);

      try {
        // Throttle slightly to be safe
        if (i > 0) await Future.delayed(const Duration(milliseconds: 300));

        final rawData = await service.fetchDailyObservation(date);

        // 0. Fetch Farm Config for Lat (Ideally fetch once outside loop, but here is fine for now or fetch above)
        final config = await _ref.read(farmConfigStreamProvider.future);

        if (rawData.isNotEmpty && rawData.containsKey('data_list')) {
          final List<dynamic> list = rawData['data_list'];
          final newItems = list.map((item) {
            final d = DateTime.parse(item['date']);

            // Create temp object to extract values easily (or parse manual)
            // We'll trust fromMeteocat to parse values, but we need those values for ET0.
            // Option A: Parse to object, then Calculate ET0, then Update object (copyWith or recreate).

            final tempObj = ClimateDailyData.fromMeteocat(d, item['data']);

            // Calculate ET0
            final et0 = ET0Calculator.calculate(
              lat: config.latitude,
              date: d,
              tMax: tempObj.maxTemp,
              tMin: tempObj.minTemp,
              rhMean: tempObj.humidity > 0 ? tempObj.humidity : null,
              windSpeed: tempObj.windSpeed > 0 ? tempObj.windSpeed : null,
              radiation: tempObj.radiation > 0 ? tempObj.radiation : null,
            );

            return ClimateDailyData(
              date: tempObj.date,
              maxTemp: tempObj.maxTemp,
              minTemp: tempObj.minTemp,
              rain: tempObj.rain,
              rainAccumulated: tempObj.rainAccumulated,
              humidity: tempObj.humidity,
              radiation: tempObj.radiation,
              windSpeed: tempObj.windSpeed,
              et0: et0,
              isMock: false,
            );
          }).toList();

          // Save immediately so partial progress is kept
          await repository.saveHistory(newItems);
          downloaded++;
        }
      } catch (e) {
        // debugPrint("Error syncing date $date: $e");
        // Continue to next day even if one fails
      }
    }

    // 4. Invalidate Providers to refresh UI
    _ref.invalidate(climateComparisonProvider);
    _ref.invalidate(climateHistoryProvider);

    return downloaded;
  }

  Future<void> generateMocks(DateTime start, DateTime end) async {
    final repository = _ref.read(climateRepositoryProvider);
    await repository.generateMockDataRange(start, end);
    _ref.invalidate(climateComparisonProvider);
    _ref.invalidate(climateHistoryProvider);
  }

  Future<void> deleteMocks() async {
    final repository = _ref.read(climateRepositoryProvider);
    await repository.deleteMocks();
    _ref.invalidate(climateComparisonProvider);
    _ref.invalidate(climateHistoryProvider);
  }
}

// --- Legacy / Dashboard Logic ---

// Syncs history ensuring local DB has up-to-date data since start of month/hydro year
final climateHistoryProvider = FutureProvider<List<ClimateDailyData>>((
  ref,
) async {
  // We can reuse the comparison provider if we select the current month?
  // But this provider logic was specific for Hydro Year context.
  // Let's keep it simple for now to avoid breaking Dashboard.

  // final service = ref.watch(meteocatServiceProvider); // Unused
  final repository = ref.watch(climateRepositoryProvider);
  final now = DateTime.now();

  // Hydro Year Start
  int hydroYear = now.year;
  if (now.month < 10) hydroYear = now.year - 1;
  final startHydroYear = DateTime(hydroYear, 10, 1);

  // STRICT QUOTA MODE:
  // We do NOT auto-fetch history for the dashboard either.
  // User must go to Clima page and download data if missing.

  return repository.getHistory(startHydroYear, now);
});

// Aggregates
final monthlyRainTotalProvider = Provider<double>((ref) {
  // Use the Comparison Logic if available?
  // Or stick to historyProvider for globally available data.
  // Let's stick to historyProvider for Dashboard compatibility.
  final history = ref.watch(climateHistoryProvider).asData?.value ?? [];
  if (history.isEmpty) return 0.0;

  final now = DateTime.now();
  final thisMonth = history.where(
    (e) => e.date.year == now.year && e.date.month == now.month,
  );
  return thisMonth.fold(0.0, (sum, e) => sum + e.rain);
});

final hydroYearTotalProvider = Provider<double>((ref) {
  final history = ref.watch(climateHistoryProvider).asData?.value ?? [];
  if (history.isEmpty) return 0.0;
  return history.fold(0.0, (sum, e) => sum + e.rain);
});

// Cold Hours Provider (Mocked/Estimated for now as agreed)
final coldHoursProvider = Provider<double>((ref) {
  return 124.5;
});

// "Yesterday Rain" provider for Irrigation Logic
final yesterdayRainProvider = FutureProvider<double>((ref) async {
  final repository = ref.read(climateRepositoryProvider);
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  // Try to get from Repository first (local)
  final history = await repository.getHistory(yesterday, yesterday);
  if (history.isNotEmpty) {
    return history.first.rain;
  }
  return 0.0;
});
