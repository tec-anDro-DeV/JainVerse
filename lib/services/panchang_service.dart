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

    // Add time of day component for accurate Tithi calculation
    // Convert local time to UTC, then to fraction of day
    double hour = date.hour.toDouble();
    double minute = date.minute.toDouble();
    double second = date.second.toDouble();

    // Convert to UTC by subtracting timezone offset
    double utcHour = hour - timezone;

    // Convert time to fraction of day (0.0 to 1.0)
    double dayFraction = (utcHour + minute / 60.0 + second / 3600.0) / 24.0;

    return jd + dayFraction;
  }

  /// Calculate Ayanamsa (precession correction) using Lahiri method
  double getAyanamsa() {
    double jd = getJulianDay();

    // Lahiri Ayanamsa formula
    double ayanamsa = 23.85 + 0.013888889 * (jd - 2451545.0) / 365.25;

    return ayanamsa;
  }

  /// Calculate Sun's longitude (sidereal position with Ayanamsa)
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

    // True tropical longitude
    double sunLongTropical = (l0 + c) % 360;

    // Convert to sidereal by subtracting Ayanamsa
    double ayanamsa = getAyanamsa();
    double sunLong = (sunLongTropical - ayanamsa + 360) % 360;

    return sunLong;
  }

  /// Calculate Moon's longitude with corrections (sidereal)
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

    // Tropical longitude
    double moonLongTropical = (l + correction) % 360;

    // Convert to sidereal by subtracting Ayanamsa
    double ayanamsa = getAyanamsa();
    double moonLong = (moonLongTropical - ayanamsa + 360) % 360;

    return moonLong;
  }

  /// Calculate Tithi (Lunar day) with Shukla/Krishna Paksha
  /// Note: In traditional Panchang, Tithi at sunrise determines the Tithi for the day
  Map<String, dynamic> getTithi({bool atSunrise = false}) {
    DateTime calculationDate = date;

    if (atSunrise) {
      // Calculate Tithi at sunrise time
      String sunriseStr = getSunrise();
      if (sunriseStr != "N/A") {
        // Parse sunrise time (format: "HH:MM AM/PM")
        List<String> parts = sunriseStr.split(' ');
        List<String> timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);

        // Convert to 24-hour format
        if (parts[1] == 'PM' && hour != 12) {
          hour += 12;
        } else if (parts[1] == 'AM' && hour == 12) {
          hour = 0;
        }

        calculationDate = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
      }
    }

    // Create a temporary service with sunrise time if needed
    final service = atSunrise
        ? PanchangService(
            date: calculationDate,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone,
          )
        : this;

    double sunLong = service.getSunLongitude();
    double moonLong = service.getMoonLongitude();

    double diff = (moonLong - sunLong + 360) % 360;
    int tithiNum = (diff / 12).floor();
    double tithiProgress = (diff % 12) / 12;

    // Traditional Panchang: Use the Tithi that is active at sunrise,
    // regardless of when it will transition. The Tithi at sunrise
    // determines the Tithi for the entire day.
    // Note: We removed the 99% threshold rule as it was causing incorrect
    // displays when Tithi transitions shortly after sunrise.

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
      'Purnima', // 15th of Shukla Paksha
    ];

    String paksha = tithiNum < 15 ? 'Shukla' : 'Krishna';
    int tithiIndex = tithiNum % 15;

    // Special handling for the 15th tithi
    String tithiName;
    if (tithiIndex == 14) {
      // 15th tithi - distinguish between Purnima and Amavasya
      tithiName = paksha == 'Shukla' ? 'Purnima' : 'Amavasya';
    } else {
      tithiName = tithiNames[tithiIndex];
    }

    return {
      'number': tithiNum + 1,
      'name': tithiName,
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
    // Calculate Julian Day at midnight (not using time component from date)
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

    // Julian century
    double T = (jd - 2451545.0) / 36525.0;

    // Geometric Mean Longitude of Sun (degrees)
    double L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) % 360;

    // Geometric Mean Anomaly of Sun (degrees)
    double M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) % 360;
    double MRad = M * pi / 180;

    // Eccentricity of Earth's orbit
    double e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T;

    // Sun's Equation of Center
    double C =
        (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(MRad) +
        (0.019993 - 0.000101 * T) * sin(2 * MRad) +
        0.000289 * sin(3 * MRad);

    // Sun's True Longitude
    double sunTrueLong = L0 + C;

    // Sun's Apparent Longitude
    double omega = 125.04 - 1934.136 * T;
    double lambda = sunTrueLong - 0.00569 - 0.00478 * sin(omega * pi / 180);
    double lambdaRad = lambda * pi / 180;

    // Obliquity of the Ecliptic
    double epsilon0 =
        23.0 +
        26.0 / 60 +
        21.448 / 3600 -
        (46.8150 * T + 0.00059 * T * T - 0.001813 * T * T * T) / 3600;
    double epsilonRad = epsilon0 * pi / 180;

    // Sun's Declination
    double declination = asin(sin(epsilonRad) * sin(lambdaRad));

    // Equation of Time (in minutes)
    double y = tan(epsilonRad / 2) * tan(epsilonRad / 2);
    double L0Rad = L0 * pi / 180;
    double eqTime =
        4 *
        (y * sin(2 * L0Rad) -
            2 * e * sin(MRad) +
            4 * e * y * sin(MRad) * cos(2 * L0Rad) -
            0.5 * y * y * sin(4 * L0Rad) -
            1.25 * e * e * sin(2 * MRad)) *
        180 /
        pi;

    // Hour Angle for sunrise (accounting for atmospheric refraction)
    double latRad = latitude * pi / 180;
    double cosHA =
        (sin(-0.833 * pi / 180) - sin(latRad) * sin(declination)) /
        (cos(latRad) * cos(declination));

    if (cosHA.abs() > 1) {
      return "N/A"; // Sun never rises or sets
    }

    double HA = acos(cosHA) * 180 / pi;

    // Solar Noon (in minutes from midnight UTC)
    double solarNoonUTC = 720 - 4 * longitude - eqTime;

    // Sunrise time (in minutes from midnight UTC)
    double sunriseUTC = solarNoonUTC - 4 * HA;

    // Convert to local time
    double sunriseLocal = sunriseUTC + timezone * 60;

    // Normalize to 0-1440 minutes
    while (sunriseLocal < 0) sunriseLocal += 1440;
    while (sunriseLocal >= 1440) sunriseLocal -= 1440;

    int hours = (sunriseLocal / 60).floor();
    int minutes = (sunriseLocal % 60).round();

    // Handle minute overflow
    if (minutes >= 60) {
      hours += 1;
      minutes -= 60;
    }

    // Format with AM indicator
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} AM';
  }

  /// More accurate sunset calculation for Indian region
  String _getIndianSunsetTime() {
    // Calculate Julian Day at midnight (not using time component from date)
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

    // Julian century
    double T = (jd - 2451545.0) / 36525.0;

    // Geometric Mean Longitude of Sun (degrees)
    double L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) % 360;

    // Geometric Mean Anomaly of Sun (degrees)
    double M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) % 360;
    double MRad = M * pi / 180;

    // Eccentricity of Earth's orbit
    double e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T;

    // Sun's Equation of Center
    double C =
        (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(MRad) +
        (0.019993 - 0.000101 * T) * sin(2 * MRad) +
        0.000289 * sin(3 * MRad);

    // Sun's True Longitude
    double sunTrueLong = L0 + C;

    // Sun's Apparent Longitude
    double omega = 125.04 - 1934.136 * T;
    double lambda = sunTrueLong - 0.00569 - 0.00478 * sin(omega * pi / 180);
    double lambdaRad = lambda * pi / 180;

    // Obliquity of the Ecliptic
    double epsilon0 =
        23.0 +
        26.0 / 60 +
        21.448 / 3600 -
        (46.8150 * T + 0.00059 * T * T - 0.001813 * T * T * T) / 3600;
    double epsilonRad = epsilon0 * pi / 180;

    // Sun's Declination
    double declination = asin(sin(epsilonRad) * sin(lambdaRad));

    // Equation of Time (in minutes)
    double y = tan(epsilonRad / 2) * tan(epsilonRad / 2);
    double L0Rad = L0 * pi / 180;
    double eqTime =
        4 *
        (y * sin(2 * L0Rad) -
            2 * e * sin(MRad) +
            4 * e * y * sin(MRad) * cos(2 * L0Rad) -
            0.5 * y * y * sin(4 * L0Rad) -
            1.25 * e * e * sin(2 * MRad)) *
        180 /
        pi;

    // Hour Angle for sunset (accounting for atmospheric refraction)
    double latRad = latitude * pi / 180;
    double cosHA =
        (sin(-0.833 * pi / 180) - sin(latRad) * sin(declination)) /
        (cos(latRad) * cos(declination));

    if (cosHA.abs() > 1) {
      return "N/A"; // Sun never rises or sets
    }

    double HA = acos(cosHA) * 180 / pi;

    // Solar Noon (in minutes from midnight UTC)
    double solarNoonUTC = 720 - 4 * longitude - eqTime;

    // Sunset time (in minutes from midnight UTC)
    double sunsetUTC = solarNoonUTC + 4 * HA;

    // Convert to local time
    double sunsetLocal = sunsetUTC + timezone * 60;

    // Normalize to 0-1440 minutes
    while (sunsetLocal < 0) sunsetLocal += 1440;
    while (sunsetLocal >= 1440) sunsetLocal -= 1440;

    int hours = (sunsetLocal / 60).floor();
    int minutes = (sunsetLocal % 60).round();

    // Handle minute overflow
    if (minutes >= 60) {
      hours += 1;
      minutes -= 60;
    }

    // Format with PM indicator
    String period = hours >= 12 ? 'PM' : 'AM';
    int displayHour = hours % 12;
    if (displayHour == 0) displayHour = 12;

    return '${displayHour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// Parse time string in format "HH:MM AM/PM" to DateTime
  DateTime _parseTimeString(String timeStr) {
    List<String> parts = timeStr.split(' ');
    List<String> timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Convert to 24-hour format
    if (parts[1] == 'PM' && hour != 12) {
      hour += 12;
    } else if (parts[1] == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Format DateTime to "HH:MM AM/PM" string
  String _formatTimeString(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;

    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;

    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Calculate Navkarsi start time (Sunrise + 48 minutes)
  String getNavkarsiStartTime() {
    String sunriseStr = getSunrise();
    if (sunriseStr == "N/A") return "N/A";

    DateTime sunrise = _parseTimeString(sunriseStr);
    DateTime navkarsiStart = sunrise.add(const Duration(minutes: 48));

    return _formatTimeString(navkarsiStart);
  }

  /// Calculate Chauvihar end time (Sunset)
  String getChauviharEndTime() {
    return getSunset();
  }

  /// Calculate Choghadiya (8 auspicious/inauspicious time periods in day and night)
  Map<String, dynamic> getChoghadiya() {
    // Planet sequence
    final planets = [
      'Sun',
      'Venus',
      'Mercury',
      'Moon',
      'Saturn',
      'Jupiter',
      'Mars',
    ];

    // Planet to Choghadiya mapping
    final planetToChog = {
      'Sun': 'Udveg',
      'Venus': 'Chal',
      'Mercury': 'Labh',
      'Moon': 'Amrit',
      'Saturn': 'Kaal',
      'Jupiter': 'Shubh',
      'Mars': 'Rog',
    };

    // Weekday to first planet mapping
    final weekdayFirstPlanet = {
      7: 'Sun', // Sunday
      1: 'Moon', // Monday
      2: 'Mars', // Tuesday
      3: 'Mercury', // Wednesday
      4: 'Jupiter', // Thursday
      5: 'Venus', // Friday
      6: 'Saturn', // Saturday
    };

    // Get sunrise, sunset times for current day and next sunrise
    DateTime sunrise = _parseTimeString(getSunrise());
    DateTime sunset = _parseTimeString(getSunset());

    // Get next day's sunrise
    DateTime nextDay = date.add(const Duration(days: 1));
    PanchangService nextDayService = PanchangService(
      date: nextDay,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );
    DateTime nextSunrise = _parseTimeString(nextDayService.getSunrise());
    // Adjust next sunrise to be on the next day
    nextSunrise = DateTime(
      nextDay.year,
      nextDay.month,
      nextDay.day,
      nextSunrise.hour,
      nextSunrise.minute,
    );

    // Calculate durations in minutes
    int dayDuration = sunset.difference(sunrise).inMinutes;
    double daySlotMinutes = dayDuration / 8;

    int nightDuration = nextSunrise.difference(sunset).inMinutes;
    double nightSlotMinutes = nightDuration / 8;

    // Get weekday (1 = Monday, 7 = Sunday)
    int weekday = date.weekday;

    // Get first planet for the day
    String firstDayPlanet = weekdayFirstPlanet[weekday]!;
    int startIdx = planets.indexOf(firstDayPlanet);

    // Calculate day slots
    List<Map<String, dynamic>> daySlots = [];
    DateTime currentTime = sunrise;

    for (int i = 0; i < 8; i++) {
      int planetIdx = (startIdx + i) % 7;
      String planet = planets[planetIdx];
      String chog = planetToChog[planet]!;

      DateTime endTime = sunrise.add(
        Duration(minutes: ((i + 1) * daySlotMinutes).round()),
      );

      daySlots.add({
        'start': _formatTimeString(currentTime),
        'end': _formatTimeString(endTime),
        'planet': planet,
        'choghadiya': chog,
      });

      currentTime = endTime;
    }

    // Calculate night slots
    // Night starts with the 5th planet from the day's starting planet
    // and increments by 5 positions (not 1) in the planet sequence
    int nightStartIdx =
        (startIdx + 5) %
        7; // +5 to get to the correct starting planet for night
    List<Map<String, dynamic>> nightSlots = [];
    currentTime = sunset;

    for (int i = 0; i < 8; i++) {
      int planetIdx = (nightStartIdx + (i * 5)) % 7; // Increment by 5 for night
      String planet = planets[planetIdx];
      String chog = planetToChog[planet]!;

      DateTime endTime = sunset.add(
        Duration(minutes: ((i + 1) * nightSlotMinutes).round()),
      );

      nightSlots.add({
        'start': _formatTimeString(currentTime),
        'end': _formatTimeString(endTime),
        'planet': planet,
        'choghadiya': chog,
      });

      currentTime = endTime;
    }

    return {'day': daySlots, 'night': nightSlots};
  }

  /// Get complete Panchang data
  Map<String, dynamic> getPanchang() {
    return {
      'date': date.toString().split(' ')[0],
      'tithi': getTithi(atSunrise: true), // Use sunrise-based Tithi
      'nakshatra': getNakshatra(),
      'yoga': getYoga(),
      'karana': getKarana(),
      'rashi': getRashi(),
      'sunrise': getSunrise(),
      'sunset': getSunset(),
      'navkarsi_start': getNavkarsiStartTime(),
      'chauvihar_end': getChauviharEndTime(),
      'choghadiya': getChoghadiya(),
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
