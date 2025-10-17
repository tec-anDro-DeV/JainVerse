import 'dart:math';

/// Panchang Calculator - Hindu Calendar System
/// Calculates the five essential elements of Hindu Panchang:
/// Tithi, Nakshatra, Yoga, Karana, and Rashi
class PanchangService {
  final DateTime date;
  final double latitude;
  final double longitude;
  final double timezone;

  PanchangService({
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  /// Calculate Julian Day Number
  double getJulianDay() {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    if (month <= 2) {
      year -= 1;
      month += 12;
    }

    int a = (year / 100).floor();
    int b = 2 - a + (a / 4).floor();

    double jd =
        (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;

    // For sunrise/sunset calculations, use noon UTC (12:00)
    // This gives us the middle of the day for accurate calculations
    return jd;
  }

  /// Calculate Sun's longitude (tropical position)
  double getSunLongitude() {
    double jd = getJulianDay();
    double t = (jd - 2451545.0) / 36525.0;

    // Mean longitude of the Sun
    double l0 = (280.46646 + 36000.76983 * t + 0.0003032 * t * t) % 360;

    // Mean anomaly of the Sun
    double m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) % 360;
    double mRad = m * pi / 180;

    // Equation of center
    double c =
        (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(mRad) +
        (0.019993 - 0.000101 * t) * sin(2 * mRad) +
        0.000289 * sin(3 * mRad);

    // True longitude
    double sunLong = (l0 + c) % 360;
    return sunLong;
  }

  /// Calculate Moon's longitude with corrections
  double getMoonLongitude() {
    double jd = getJulianDay();
    double t = (jd - 2451545.0) / 36525.0;

    // Mean longitude of the Moon
    double l = (218.3164477 + 481267.88123421 * t) % 360;

    // Mean elongation of the Moon
    double d = (297.8501921 + 445267.1114034 * t) % 360;

    // Mean anomaly of the Sun
    double m = (357.5291092 + 35999.0502909 * t) % 360;

    // Mean anomaly of the Moon
    double mPrime = (134.9633964 + 477198.8675055 * t) % 360;

    // Moon's argument of latitude (calculated for astronomical completeness)
    // double f = (93.2720950 + 483202.0175233 * t) % 360;

    // Convert to radians
    double dRad = d * pi / 180;
    double mRad = m * pi / 180;
    double mPrimeRad = mPrime * pi / 180;
    // fRad is calculated for completeness but not used in main correction formula
    // double fRad = f * pi / 180;

    // Main corrections
    double correction =
        6.288774 * sin(mPrimeRad) +
        1.274027 * sin(2 * dRad - mPrimeRad) +
        0.658314 * sin(2 * dRad) +
        0.213618 * sin(2 * mPrimeRad) -
        0.185116 * sin(mRad);

    double moonLong = (l + correction) % 360;
    return moonLong;
  }

  /// Calculate Tithi (Lunar day) with Shukla/Krishna Paksha
  Map<String, dynamic> getTithi() {
    double sunLong = getSunLongitude();
    double moonLong = getMoonLongitude();

    double diff = (moonLong - sunLong + 360) % 360;
    int tithiNum = (diff / 12).floor();
    double tithiProgress = (diff % 12) / 12;

    List<String> tithiNames = [
      'Pratipada',
      'Dwitiya',
      'Tritiya',
      'Chaturthi',
      'Panchami',
      'Shashthi',
      'Saptami',
      'Ashtami',
      'Navami',
      'Dashami',
      'Ekadashi',
      'Dwadashi',
      'Trayodashi',
      'Chaturdashi',
      'Purnima/Amavasya',
    ];

    String paksha = tithiNum < 15 ? 'Shukla' : 'Krishna';
    int tithiIndex = tithiNum % 15;

    return {
      'number': tithiNum + 1,
      'name': tithiNames[tithiIndex],
      'paksha': paksha,
      'progress': tithiProgress,
    };
  }

  /// Calculate Nakshatra (27 lunar mansions) with ruling deities
  Map<String, dynamic> getNakshatra() {
    double moonLong = getMoonLongitude();
    int nakshatraNum = (moonLong / 13.333333).floor();
    double nakshatraProgress = (moonLong % 13.333333) / 13.333333;

    List<String> nakshatraNames = [
      'Ashwini',
      'Bharani',
      'Krittika',
      'Rohini',
      'Mrigashira',
      'Ardra',
      'Punarvasu',
      'Pushya',
      'Ashlesha',
      'Magha',
      'Purva Phalguni',
      'Uttara Phalguni',
      'Hasta',
      'Chitra',
      'Swati',
      'Vishakha',
      'Anuradha',
      'Jyeshtha',
      'Mula',
      'Purva Ashadha',
      'Uttara Ashadha',
      'Shravana',
      'Dhanishta',
      'Shatabhisha',
      'Purva Bhadrapada',
      'Uttara Bhadrapada',
      'Revati',
    ];

    // Lords of Nakshatras
    List<String> lords = [
      'Ketu',
      'Venus',
      'Sun',
      'Moon',
      'Mars',
      'Rahu',
      'Jupiter',
      'Saturn',
      'Mercury',
      'Ketu',
      'Venus',
      'Sun',
      'Moon',
      'Mars',
      'Rahu',
      'Jupiter',
      'Saturn',
      'Mercury',
      'Ketu',
      'Venus',
      'Sun',
      'Moon',
      'Mars',
      'Rahu',
      'Jupiter',
      'Saturn',
      'Mercury',
    ];

    return {
      'number': nakshatraNum + 1,
      'name': nakshatraNames[nakshatraNum % 27],
      'lord': lords[nakshatraNum % 27],
      'progress': nakshatraProgress,
    };
  }

  /// Calculate Yoga (27 auspicious/inauspicious combinations)
  Map<String, dynamic> getYoga() {
    double sunLong = getSunLongitude();
    double moonLong = getMoonLongitude();

    double yogaValue = (sunLong + moonLong) % 360;
    int yogaNum = (yogaValue / 13.333333).floor();
    double yogaProgress = (yogaValue % 13.333333) / 13.333333;

    List<String> yogaNames = [
      'Vishkambha',
      'Priti',
      'Ayushman',
      'Saubhagya',
      'Shobhana',
      'Atiganda',
      'Sukarma',
      'Dhriti',
      'Shula',
      'Ganda',
      'Vriddhi',
      'Dhruva',
      'Vyaghata',
      'Harshana',
      'Vajra',
      'Siddhi',
      'Vyatipata',
      'Variyana',
      'Parigha',
      'Shiva',
      'Siddha',
      'Sadhya',
      'Shubha',
      'Shukla',
      'Brahma',
      'Indra',
      'Vaidhriti',
    ];

    return {
      'number': yogaNum + 1,
      'name': yogaNames[yogaNum % 27],
      'progress': yogaProgress,
    };
  }

  /// Calculate Karana (Half of a Tithi - 60 total)
  Map<String, dynamic> getKarana() {
    double sunLong = getSunLongitude();
    double moonLong = getMoonLongitude();

    double diff = (moonLong - sunLong + 360) % 360;
    int karanaNum = (diff / 6).floor();
    double karanaProgress = (diff % 6) / 6;

    List<String> karanaNames = [
      'Bava',
      'Balava',
      'Kaulava',
      'Taitila',
      'Garaja',
      'Vanija',
      'Vishti',
      'Shakuni',
      'Chatushpada',
      'Naga',
      'Kimstughna',
    ];

    String karanaName;
    if (karanaNum < 57) {
      karanaName = karanaNames[karanaNum % 7];
    } else {
      karanaName = karanaNames[7 + (karanaNum - 57)];
    }

    return {
      'number': karanaNum + 1,
      'name': karanaName,
      'progress': karanaProgress,
    };
  }

  /// Calculate Rashi (Zodiac signs) for Sun and Moon
  Map<String, String> getRashi() {
    double sunLong = getSunLongitude();
    double moonLong = getMoonLongitude();

    List<String> rashiNames = [
      'Mesha (Aries)',
      'Vrishabha (Taurus)',
      'Mithuna (Gemini)',
      'Karka (Cancer)',
      'Simha (Leo)',
      'Kanya (Virgo)',
      'Tula (Libra)',
      'Vrishchika (Scorpio)',
      'Dhanu (Sagittarius)',
      'Makara (Capricorn)',
      'Kumbha (Aquarius)',
      'Meena (Pisces)',
    ];

    int sunRashi = (sunLong / 30).floor();
    int moonRashi = (moonLong / 30).floor();

    return {
      'sun': rashiNames[sunRashi % 12],
      'moon': rashiNames[moonRashi % 12],
    };
  }

  /// Calculate sunrise time with accurate algorithm for India
  String getSunrise() {
    // For India-specific calculation
    bool isIndianRegion =
        (latitude >= 8.0 &&
            latitude <= 37.0 &&
            longitude >= 68.0 &&
            longitude <= 98.0);

    if (isIndianRegion) {
      return _getIndianSunriseTime();
    }

    // Fallback to original calculation for non-Indian regions
    double jd = getJulianDay();
    double n = jd - 2451545.0 + 0.0008;
    double jStar = n - longitude / 360.0;
    double m = (357.5291 + 0.98560028 * jStar) % 360;
    double mRad = m * pi / 180;
    double c =
        1.9148 * sin(mRad) + 0.0200 * sin(2 * mRad) + 0.0003 * sin(3 * mRad);
    double lambda = (m + c + 180 + 102.9372) % 360;
    double lambdaRad = lambda * pi / 180;
    double jTransit =
        2451545.0 + jStar + 0.0053 * sin(mRad) - 0.0069 * sin(2 * lambdaRad);

    double delta = asin(sin(lambdaRad) * sin(23.44 * pi / 180));
    double latRad = latitude * pi / 180;
    double cosH0 =
        (sin(-0.83 * pi / 180) - sin(latRad) * sin(delta)) /
        (cos(latRad) * cos(delta));

    if (cosH0.abs() > 1) {
      return "N/A";
    }

    double h0 = acos(cosH0) * 180 / pi;
    double jRise = jTransit - h0 / 360.0;

    // Convert Julian day to local time
    double utcTime = (jRise - jd.floor() + 0.5) * 24;
    double localTime = utcTime + timezone;

    // Handle day overflow
    while (localTime >= 24) localTime -= 24;
    while (localTime < 0) localTime += 24;

    int hours = localTime.floor();
    int minutes = ((localTime - hours) * 60).round();

    // Format with AM/PM indicator
    String period = hours >= 12 ? 'PM' : 'AM';
    int displayHour = hours % 12;
    if (displayHour == 0) displayHour = 12;

    return '${displayHour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// Calculate sunset time with accurate algorithm for India
  String getSunset() {
    // For India-specific calculation
    bool isIndianRegion =
        (latitude >= 8.0 &&
            latitude <= 37.0 &&
            longitude >= 68.0 &&
            longitude <= 98.0);

    if (isIndianRegion) {
      return _getIndianSunsetTime();
    }

    // Fallback to original calculation for non-Indian regions
    double jd = getJulianDay();
    double n = jd - 2451545.0 + 0.0008;
    double jStar = n - longitude / 360.0;
    double m = (357.5291 + 0.98560028 * jStar) % 360;
    double mRad = m * pi / 180;
    double c =
        1.9148 * sin(mRad) + 0.0200 * sin(2 * mRad) + 0.0003 * sin(3 * mRad);
    double lambda = (m + c + 180 + 102.9372) % 360;
    double lambdaRad = lambda * pi / 180;
    double jTransit =
        2451545.0 + jStar + 0.0053 * sin(mRad) - 0.0069 * sin(2 * lambdaRad);

    double delta = asin(sin(lambdaRad) * sin(23.44 * pi / 180));
    double latRad = latitude * pi / 180;
    double cosH0 =
        (sin(-0.83 * pi / 180) - sin(latRad) * sin(delta)) /
        (cos(latRad) * cos(delta));

    if (cosH0.abs() > 1) {
      return "N/A";
    }

    double h0 = acos(cosH0) * 180 / pi;
    double jSet = jTransit + h0 / 360.0;

    // Convert Julian day to local time
    double utcTime = (jSet - jd.floor() + 0.5) * 24;
    double localTime = utcTime + timezone;

    // Handle day overflow
    while (localTime >= 24) localTime -= 24;
    while (localTime < 0) localTime += 24;

    int hours = localTime.floor();
    int minutes = ((localTime - hours) * 60).round();

    // Format with AM/PM indicator
    String period = hours >= 12 ? 'PM' : 'AM';
    int displayHour = hours % 12;
    if (displayHour == 0) displayHour = 12;

    return '${displayHour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// More accurate sunrise calculation for Indian region
  String _getIndianSunriseTime() {
    // Get day of year
    int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;

    // Calculate sunrise time - algorithm specific for Indian latitudes
    double B = 2 * pi * (dayOfYear - 81) / 365;

    // Equation of time (in minutes)
    double eqTime = 9.87 * sin(2 * B) - 7.53 * cos(B) - 1.5 * sin(B);

    // Solar declination angle
    double decl = 23.45 * sin(B);

    double latRad = latitude * pi / 180;
    double declRad = decl * pi / 180;

    // Calculate sunrise hour angle
    double ha =
        acos(sin(-0.83 * pi / 180) - sin(latRad) * sin(declRad)) /
        (cos(latRad) * cos(declRad));
    ha = ha * 180 / pi; // Convert to degrees

    // Calculate sunrise time (in decimal hours)
    double sunriseTime =
        12.0 - ha / 15.0 - eqTime / 60.0 - longitude / 15.0 + timezone;

    // Handle day crossover
    while (sunriseTime < 0) sunriseTime += 24;
    while (sunriseTime >= 24) sunriseTime -= 24;

    // Convert to hours and minutes
    int hours = sunriseTime.floor();
    int minutes = ((sunriseTime - hours) * 60).round();

    // Format with AM indicator (sunrise is always AM in India)
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} AM';
  }

  /// More accurate sunset calculation for Indian region
  String _getIndianSunsetTime() {
    // Get day of year
    int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;

    // Calculate sunset time - algorithm specific for Indian latitudes
    double B = 2 * pi * (dayOfYear - 81) / 365;

    // Equation of time (in minutes)
    double eqTime = 9.87 * sin(2 * B) - 7.53 * cos(B) - 1.5 * sin(B);

    // Solar declination angle
    double decl = 23.45 * sin(B);

    double latRad = latitude * pi / 180;
    double declRad = decl * pi / 180;

    // Calculate sunset hour angle
    double ha =
        acos(sin(-0.83 * pi / 180) - sin(latRad) * sin(declRad)) /
        (cos(latRad) * cos(declRad));
    ha = ha * 180 / pi; // Convert to degrees

    // Calculate sunset time (in decimal hours)
    double sunsetTime =
        12.0 + ha / 15.0 - eqTime / 60.0 - longitude / 15.0 + timezone;

    // Handle day crossover
    while (sunsetTime < 0) sunsetTime += 24;
    while (sunsetTime >= 24) sunsetTime -= 24;

    // Convert to hours and minutes
    int hours = sunsetTime.floor();
    int minutes = ((sunsetTime - hours) * 60).round();

    // Format with PM indicator (sunset is always PM in India)
    String period = hours >= 12 ? 'PM' : 'AM';
    int displayHour = hours % 12;
    if (displayHour == 0) displayHour = 12;

    return '${displayHour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// Get complete Panchang data
  Map<String, dynamic> getPanchang() {
    return {
      'date': date.toString().split(' ')[0],
      'tithi': getTithi(),
      'nakshatra': getNakshatra(),
      'yoga': getYoga(),
      'karana': getKarana(),
      'rashi': getRashi(),
      'sunrise': getSunrise(),
      'sunset': getSunset(),
    };
  }

  /// Display formatted Panchang (for debugging/logging)
  String displayPanchang() {
    Map<String, dynamic> panchang = getPanchang();

    StringBuffer sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('         PANCHANG CALENDAR');
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('Date: ${panchang['date']}');
    sb.writeln('Location: Lat ${latitude}°, Long ${longitude}°');
    sb.writeln('Sunrise: ${panchang['sunrise']}');
    sb.writeln('Sunset: ${panchang['sunset']}');
    sb.writeln('');
    sb.writeln('TITHI (Lunar Day):');
    sb.writeln(
      '  ${panchang['tithi']['paksha']} Paksha - ${panchang['tithi']['name']}',
    );
    sb.writeln(
      '  Progress: ${(panchang['tithi']['progress'] * 100).toStringAsFixed(1)}%',
    );
    sb.writeln('');
    sb.writeln('NAKSHATRA (Lunar Mansion):');
    sb.writeln('  ${panchang['nakshatra']['name']}');
    sb.writeln('  Lord: ${panchang['nakshatra']['lord']}');
    sb.writeln(
      '  Progress: ${(panchang['nakshatra']['progress'] * 100).toStringAsFixed(1)}%',
    );
    sb.writeln('');
    sb.writeln('YOGA:');
    sb.writeln('  ${panchang['yoga']['name']}');
    sb.writeln(
      '  Progress: ${(panchang['yoga']['progress'] * 100).toStringAsFixed(1)}%',
    );
    sb.writeln('');
    sb.writeln('KARANA:');
    sb.writeln('  ${panchang['karana']['name']}');
    sb.writeln(
      '  Progress: ${(panchang['karana']['progress'] * 100).toStringAsFixed(1)}%',
    );
    sb.writeln('');
    sb.writeln('RASHI (Zodiac):');
    sb.writeln('  Sun: ${panchang['rashi']['sun']}');
    sb.writeln('  Moon: ${panchang['rashi']['moon']}');
    sb.writeln('═══════════════════════════════════════════');

    return sb.toString();
  }
}
