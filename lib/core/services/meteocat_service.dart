import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeteocatService {
  static const String _apiKey = 'R5F8gNLcUw7Hr6KIiIS6w8INP3juJpjn6SxavYBB';
  static const String _baseUrl = 'https://api.meteo.cat';
  static const String _laFlorestaMunCode = '250925';

  // La Floresta coords
  static const double _targetLat = 41.5117;
  static const double _targetLon = 0.9208;

  // Rate Limiting Keys
  static const String _keyCachedStation = 'meteocat_cached_station_id';
  static const String _keyLastObsUpdate = 'meteocat_last_obs_update';
  static const String _keyCachedObs = 'meteocat_cached_obs';
  static const String _keyLastForecastUpdate = 'meteocat_last_forecast_update';
  static const String _keyCachedForecast = 'meteocat_cached_forecast';

  final Duration _obsRateLimit = const Duration(
    hours: 4,
  ); // Reduce costs (750 limit) -> Now 4h (max 6/day)
  final Duration _forecastRateLimit = const Duration(
    hours: 12,
  ); // 100 limit/month = ~3/day. 12h cache = 2/day (60/month). Safe.

  // Preference Keys
  static const String _keyQuotaSaver = 'meteocat_quota_saver_enabled';

  Future<bool> get isQuotaSaverEnabled async {
    final prefs = await SharedPreferences.getInstance();
    // Default to TRUE to be safe during current crisis
    return prefs.getBool(_keyQuotaSaver) ?? true;
  }

  Future<void> setQuotaSaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyQuotaSaver, enabled);
  }

  Future<Map<String, dynamic>> getWeatherData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Get Station (Cached if possible)
      String? stationCode = prefs.getString(_keyCachedStation);
      if (stationCode == null) {
        // Fetch station (Allowed even in emergency? Maybe fallback)
        if (await isQuotaSaverEnabled) {
          stationCode = 'X1'; // Fallback strictly
        } else {
          stationCode = await _findNearestStation();
        }

        if (stationCode != null) {
          await prefs.setString(_keyCachedStation, stationCode);
        }
      }

      if (stationCode == null) throw Exception('No station found');

      // 2. Get Observations (Rate Limited - 3h)
      Map<String, dynamic> observation = {};
      try {
        observation = await _getOrFetchCachedData(
          prefs,
          _keyLastObsUpdate,
          _keyCachedObs,
          () => _fetchObservations(stationCode!),
          _obsRateLimit,
        );
      } catch (e) {
        // print("Meteocat Obs Error: $e");
        // Fallback: Try to load cached data ignoring expiry if available
        final cachedObs = prefs.getString(_keyCachedObs);
        if (cachedObs != null) {
          observation = jsonDecode(cachedObs);
        }
      }

      // 3. Get Forecast (Rate Limited - 1h)
      Map<String, dynamic> forecast = {};
      try {
        forecast = await _getOrFetchCachedData(
          prefs,
          _keyLastForecastUpdate,
          _keyCachedForecast,
          () => _fetchForecast(_laFlorestaMunCode),
          _forecastRateLimit,
        );
      } catch (e) {
        // print("Meteocat Forecast Error: $e");
        final cachedForecast = prefs.getString(_keyCachedForecast);
        if (cachedForecast != null) {
          forecast = jsonDecode(cachedForecast);
        }
      }

      return {
        'observation': observation,
        'forecast': forecast,
        'station': stationCode,
      };
    } catch (e) {
      // print('Meteocat Error: $e');
      // Return cached data if available even if expired, or rethrow
      return {};
    }
  }

  Future<Map<String, dynamic>> _getOrFetchCachedData(
    SharedPreferences prefs,
    String timeKey,
    String dataKey,
    Future<Map<String, dynamic>> Function() fetcher,
    Duration limit,
  ) async {
    final lastUpdateStr = prefs.getString(timeKey);
    final cachedDataStr = prefs.getString(dataKey);

    if (lastUpdateStr != null && cachedDataStr != null) {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      if (DateTime.now().difference(lastUpdate) < limit) {
        // print('Returning cached data for $dataKey');
        return jsonDecode(cachedDataStr);
      }
    }

    // Fetch new
    // print('Fetching new data for $dataKey');
    final data = await fetcher();
    await prefs.setString(dataKey, jsonEncode(data));
    await prefs.setString(timeKey, DateTime.now().toIso8601String());
    return data;
  }

  Future<String?> _findNearestStation({
    double? latOverride,
    double? lonOverride,
  }) async {
    final url = Uri.parse('$_baseUrl/xema/v1/estacions/metadades');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        final List<dynamic> stations = jsonDecode(response.body);
        String? bestStation;
        double minDistance = double.infinity;

        final targetLat = latOverride ?? _targetLat;
        final targetLon = lonOverride ?? _targetLon;

        for (var s in stations) {
          final coords = s['coordenades'];
          if (coords == null) continue;

          final latVal = coords['latitud'];
          final lonVal = coords['longitud'];

          if (latVal == null || lonVal == null) continue;

          final double lat = (latVal as num).toDouble();
          final double lon = (lonVal as num).toDouble();

          final dist = _calculateDistance(targetLat, targetLon, lat, lon);

          // Filter: Must be operational? Assuming API returns active stations.
          if (dist < minDistance) {
            minDistance = dist;
            bestStation = s['codi'];
          }
        }
        return bestStation;
      } else {
        // throw Exception('Failed to load stations: ${response.statusCode}');
        // Fallback instead of crashing
        // print(
        //   'Failed to load stations: ${response.statusCode}. Using Fallback.',
        // );
        return 'X1'; // Les Borges Blanques
      }
    } catch (e) {
      // print('Meteocat Lookup Error: $e. Using Fallback Station X1.');
      return 'X1'; // Les Borges Blanques (Fallback)
    }
  }

  Future<Map<String, dynamic>> _fetchObservations(String stationCode) async {
    final now = DateTime.now();
    final String y = now.year.toString();
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');

    // Endpoint: /estacions/mesurades/{codiEstacio}/{any}/{mes}/{dia}
    final url = Uri.parse(
      '$_baseUrl/xema/v1/estacions/mesurades/$stationCode/$y/$m/$d',
    );
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return {};
      // Wrap in a map to match expected cached structure
      return {'data_list': data};
    } else {
      throw Exception('Failed to load observations: ${response.statusCode}');
    }
  }

  /// Fetches daily measured variables for a specific date range.
  /// Useful for historical charts and cold hours estimation.
  Future<List<dynamic>> getDailyHistory(DateTime from, DateTime to) async {
    if (await isQuotaSaverEnabled) {
      // print(
      //   '⚠️ Quota Saver Mode Active: Skipping XEMA API call for $from - $to',
      // );
      return []; // Return empty to force usage of local DB only
    }

    // We will fetch the provided stationID or rely on cached station.
    Map<String, dynamic> station = await _getStationForCoordenates();
    String code = station['codi'] ?? "UNKNOWN";

    List<dynamic> allReadings = [];

    // Iterate day by day from 'from' to 'to'
    final daysDiff = to.difference(from).inDays;
    int limit = daysDiff + 1;
    if (limit > 31) limit = 31; // Increased safety cap to 31 (full month)

    // Safety check if from > to
    if (limit < 0) return [];

    for (int i = 0; i < limit; i++) {
      DateTime target = from.add(Duration(days: i));
      // Don't fetch future
      if (target.isAfter(DateTime.now())) break;

      // Throttle to avoid 429 (Too Many Requests)
      // Meteocat limits can be tight. 250ms delay = ~4 req/sec max.
      if (i > 0) await Future.delayed(const Duration(milliseconds: 250));

      // Reuse _fetchObservations logic but for specific date
      try {
        Map<String, dynamic> dailyData = await _fetchDailyData(code, target);
        if (dailyData.isNotEmpty) {
          allReadings.add({
            'date': target.toIso8601String(),
            'data': dailyData,
          });
        }
      } catch (e) {
        if (e.toString().contains('429')) {
          // print("Rate Limit Hit (429). Aborting batch fetch.");
          break; // Stop loop to protect quota
        }
        // Continue for other errors
      }
    }

    return allReadings;
  }

  // Helper to get cached station or find new one
  Future<Map<String, dynamic>> _getStationForCoordenates() async {
    final prefs = await SharedPreferences.getInstance();
    String? stationCode = prefs.getString(_keyCachedStation);
    if (stationCode == null) {
      stationCode = await _findNearestStation();
      if (stationCode != null) {
        await prefs.setString(_keyCachedStation, stationCode);
      }
    }
    return {'codi': stationCode};
  }

  /// Public wrapper to fetch a single day's data (used for smart sync)
  Future<Map<String, dynamic>> fetchDailyObservation(DateTime date) async {
    // Ensure we have a station code
    final station = await _getStationForCoordenates();
    final code = station['codi'] ?? "UNKNOWN";
    return _fetchDailyData(code, date);
  }

  Future<Map<String, dynamic>> _fetchDailyData(
    String code,
    DateTime date,
  ) async {
    final String y = date.year.toString();
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    final url = Uri.parse(
      '$_baseUrl/xema/v1/estacions/mesurades/$code/$y/$m/$d',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return {'data_list': data};
      } else if (response.statusCode == 429) {
        throw Exception('429 Too Many Requests');
      }
    } catch (e) {
      // Rethrow 429 so loop can catch it
      if (e.toString().contains('429')) rethrow;
      // print("Error fetching date $date: $e");
    }
    return {};
  }

  Future<Map<String, dynamic>> _fetchForecast(String munCode) async {
    // Current day forecast
    // /pronostic/v1/municipal/{codi}
    final url = Uri.parse('$_baseUrl/pronostic/v1/municipal/$munCode');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load forecast: ${response.statusCode}');
    }
  }

  // Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
  // --- Quota & Station Management ---

  /// Fetches current API quota usage
  Future<Map<String, dynamic>> getQuota() async {
    final url = Uri.parse('$_baseUrl/quotes/v1/consum-actual');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-Api-Key': _apiKey},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Status ${response.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Returns currently cached station code (or null)
  Future<String?> getCachedStationCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCachedStation);
  }

  /// Manually sets the station code (e.g. from Firestore sync)
  Future<void> setCachedStation(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_keyCachedStation);
    if (current != code) {
      await prefs.setString(_keyCachedStation, code);
      // Clear specific caches since station changed
      await prefs.remove(_keyLastObsUpdate);
      await prefs.remove(_keyCachedObs);
    }
  }

  /// Forces a re-calculation of the nearest station based on new coords.
  /// Call this when Farm Location changes in Settings.
  Future<String?> refreshStation(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();

    // We temporarily override the internal target coords for the calculation
    // Note: ideally _calculateDistance should take args, which it does.
    // But _findNearestStation uses static _targetLat/_targetLon constants.
    // I will refactor _findNearestStation to accept optional overrides.

    // For now, let's just clear the cache and let the next call find it?
    // No, the user wants to see it change explicitly.
    // Let's refactor _findNearestStation to take optional coords.

    final code = await _findNearestStation(latOverride: lat, lonOverride: lon);
    if (code != null) {
      await prefs.setString(_keyCachedStation, code);
      // Clear other caches since station changed
      await prefs.remove(_keyLastObsUpdate);
      await prefs.remove(_keyCachedObs);
    }
    return code;
  }
}

final meteocatServiceProvider = Provider((ref) => MeteocatService());
