import 'dart:math';

class ET0Calculator {
  /// Constants
  // Constants
  static const double _sigma =
      4.903e-9; // Stefan-Boltzmann constant [MJ K-4 m-2 day-1]
  // Specific heat of air Cp = 1.013e-3 MJ kg-1 C-1
  // Epsilon = 0.622 ratio molecular weight water vapour/dry air

  /// Adaptive ET0 Calculation
  /// Prioritizes Penman-Monteith if all data is available.
  /// Fallbacks to Hargreaves-Samani if Wind/Humidity are missing.
  ///
  /// Params:
  /// - lat: Latitude in degrees
  /// - date: Date of measurement
  /// - tMax: Max Temperature (C)
  /// - tMin: Min Temperature (C)
  /// - altitude: Altitude in meters (default 200m approx for region)
  /// - rhMax: Max Relative Humidity (%) (Optional)
  /// - rhMin: Min Relative Humidity (%) (Optional)
  /// - windSpeed: Wind Speed at 2m height (m/s) (Optional)
  /// - radiation: Solar Radiation (MJ/m2/day) (Optional)
  static double calculate({
    required double lat,
    required DateTime date,
    required double tMax,
    required double tMin,
    double altitude = 200.0,
    double? rhMax,
    double? rhMin,
    double? rhMean,
    double? windSpeed,
    double? radiation, // Rs
  }) {
    // Basic validations
    if (tMax < tMin) {
      final temp = tMax;
      tMax = tMin;
      tMin = temp;
    }

    final tMean = (tMax + tMin) / 2.0;

    // Estimate Radiation if missing (Hargreaves Radiation Formula could be used, but for now we assume we might have it)
    // If radiation is NULL, we can try to estimate Ra (Extraterrestrial) and use Hargreaves for Rs.

    // 1. Calculate Ra (Extraterrestrial Radiation)
    final ra = _calculateRa(lat, date);

    // Check Data Availability for Penman-Monteith
    // We need: Radiation (Rs), Humidity, Wind.
    bool hasRad = radiation != null;
    bool hasHum = (rhMax != null && rhMin != null) || rhMean != null;
    bool hasWind = windSpeed != null;

    if (hasRad && hasHum && hasWind) {
      // Use Penman-Monteith FAO-56
      // Need to process humidity to e_s - e_a
      double meanHum = rhMean ?? ((rhMax! + rhMin!) / 2.0);

      // If we only have mean humidity, es-ea estimation is less accurate but doable.
      // Ideally use rhMax/min to calc esMax/min

      return _calculatePenmanMonteith(
        tMean: tMean,
        tMax: tMax,
        tMin: tMin,
        rhMean: meanHum,
        windSpeed: windSpeed,
        radiation: radiation,
        ra: ra,
        altitude: altitude,
        lat: lat, // used for other internal calcs if needed
      );
    } else {
      // Fallback: Hargreaves-Samani
      // Requires: Tmax, Tmin, Ra. (Radiation Rs is optional/estimated by T diff)
      // ET0 = 0.0023 * (Tmean + 17.8) * (Tmax - Tmin)^0.5 * Ra

      // If we have actual Radiation, Hargreaves can be modified to use it instead of Ra?
      // Actually pure Hargreaves uses Ra.

      // Let's use standard Hargreaves with Ra.
      return _calculateHargreaves(tMean, tMax, tMin, ra);
    }
  }

  /// Extraterrestrial Radiation (Ra) Calculation
  /// [lat] in degrees.
  static double _calculateRa(double lat, DateTime date) {
    // Day of year (J)
    final int j = int.parse(Helpers.dayOfYear(date));

    // Latitude in radians
    final double phi = lat * (pi / 180.0);

    // Inverse relative distance Earth-Sun (dr)
    final double dr = 1 + 0.033 * cos((2 * pi * j) / 365.0);

    // Solar declination (delta)
    final double delta = 0.409 * sin(((2 * pi * j) / 365.0) - 1.39);

    // Sunset hour angle (ws)
    // ws = arccos(-tan(phi)*tan(delta))
    final double tanPhiDelta = -tan(phi) * tan(delta);

    // Safety for polar zones (unlikely for usage, but good practice)
    double ws = 0.0;
    if (tanPhiDelta >= 1.0) {
      ws = 0.0;
    } else if (tanPhiDelta <= -1.0) {
      ws = pi;
    } else {
      ws = acos(tanPhiDelta);
    }

    // Ra calculation
    // Ra = (24(60)/pi) * Gsc * dr * [ws sin(phi) sin(delta) + cos(phi) cos(delta) sin(ws)]
    // (24*60)/pi ~ 458.366

    final double ra =
        37.586 *
        dr *
        ((ws * sin(phi) * sin(delta)) + (cos(phi) * cos(delta) * sin(ws)));

    // Note: 37.586 comes from converting Gsc to daily MJ?
    // Gsc = 0.0820 MJ m-2 min-1.
    // Factor = 24 * 60 / pi * 0.0820 = 37.586. Correct.

    return max(0.0, ra);
  }

  static double _calculateHargreaves(
    double tMean,
    double tMax,
    double tMin,
    double ra,
  ) {
    // ET0 = 0.0023 * (Tmean + 17.8) * (Tmax - Tmin)^0.5 * Ra
    final double diffT = max(0.0, tMax - tMin); // Prevent SQRT negative
    return 0.0023 * (tMean + 17.8) * sqrt(diffT) * ra;
  }

  static double _calculatePenmanMonteith({
    required double tMean,
    required double tMax,
    required double tMin,
    required double rhMean, // %
    required double windSpeed, // u2 [m/s]
    required double radiation, // Rs [MJ m-2 day-1]
    required double ra,
    required double altitude,
    required double lat,
  }) {
    // Slope of vapour pressure curve (Delta) [kPa C-1]
    // Delta = 4098 * [0.6108 * exp(17.27 T / (T + 237.3))] / (T + 237.3)^2
    final double delta =
        (4098 * (0.6108 * exp((17.27 * tMean) / (tMean + 237.3)))) /
        pow((tMean + 237.3), 2);

    // Psychrometric constant (Gamma) [kPa C-1]
    // P = 101.3 * ((293 - 0.0065*z) / 293)^5.26
    final double p = 101.3 * pow(((293 - 0.0065 * altitude) / 293), 5.26);
    final double gamma = 0.000665 * p;

    // Saturation Vapour Pressure (es)
    // es = (e°(Tmax) + e°(Tmin)) / 2
    double eT(double t) => 0.6108 * exp((17.27 * t) / (t + 237.3));
    final double es = (eT(tMax) + eT(tMin)) / 2.0;

    // Actual Vapour Pressure (ea)
    // ea = es * RH / 100
    final double ea = es * (rhMean / 100.0);

    // Soil Heat Flux (G). Assumed 0 for daily steps.
    const double g = 0.0;

    // Net Radiation (Rn) = Rns - Rnl
    // Rns = (1-alpha) * Rs. Alpha=0.23 for hypothesis grass.
    final double rns = (1 - 0.23) * radiation;

    // Rnl (Net Longwave) requires Clear Sky Rad (Rso) etc.
    // Rso = (0.75 + 2e-5 * z) * Ra
    final double rso = (0.75 + (2e-5 * altitude)) * ra;
    // Rnl formula involves TmaxK, TminK, ea, Rs/Rso
    // This part is complex without simpler approximations.
    // FAO56 Eq 39.

    // Simplify for now: If we provided 'Radiation' from Meteocat, is it Net or Solar?
    // It's usually Solar Global (Rs).
    // Let's implement full Rnl just to be safe.
    final double tMaxK = tMax + 273.16;
    final double tMinK = tMin + 273.16;
    final double rsRsoRatio = (rso == 0) ? 1.0 : (radiation / rso);
    // Limit ratio 0.3-1.0
    final double limitedRatio = min(1.0, max(0.3, rsRsoRatio));

    final double rnl =
        _sigma *
        ((pow(tMaxK, 4) + pow(tMinK, 4)) / 2) *
        (0.34 - 0.14 * sqrt(ea)) *
        (1.35 * limitedRatio - 0.35);

    final double rn = rns - rnl;

    // Penman-Monteith Equation
    // ET0 = [0.408 Delta (Rn - G) + Gamma (900/(T+273)) u2 (es - ea)] / [Delta + Gamma (1 + 0.34 u2)]

    final double num1 = 0.408 * delta * (rn - g);
    final double num2 =
        gamma * (900.0 / (tMean + 273.0)) * windSpeed * (es - ea);
    final double den = delta + (gamma * (1.0 + 0.34 * windSpeed));

    return max(0.0, (num1 + num2) / den);
  }
}

class Helpers {
  static String dayOfYear(DateTime d) {
    // Simple calc
    final start = DateTime(d.year, 1, 1);
    return (d.difference(start).inDays + 1).toString();
  }
}
