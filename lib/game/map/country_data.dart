import 'package:flame/components.dart';

/// Simplified country shape data for rendering.
/// Uses simplified polygons for performance.
class CountryShape {
  const CountryShape({
    required this.code,
    required this.name,
    required this.points,
    this.capital,
  });

  final String code;
  final String name;
  final List<Vector2> points; // [lng, lat] pairs
  final String? capital;
}

/// City data for low-altitude view.
class CityData {
  const CityData({
    required this.name,
    required this.countryCode,
    required this.location,
    this.isCapital = false,
  });

  final String name;
  final String countryCode;
  final Vector2 location; // [lng, lat]
  final bool isCapital;
}

/// Static country and city data.
/// Simplified shapes derived from Natural Earth (Public Domain).
abstract class CountryData {
  // Simplified country outlines (major countries only for Sprint 2)
  static const List<CountryShape> countries = [
    // North America
    CountryShape(
      code: 'US',
      name: 'United States',
      capital: 'Washington D.C.',
      points: [
        Vector2(-125, 48), Vector2(-123, 48), Vector2(-122, 49),
        Vector2(-117, 49), Vector2(-110, 49), Vector2(-104, 49),
        Vector2(-100, 49), Vector2(-95, 49), Vector2(-89, 49),
        Vector2(-84, 46), Vector2(-82, 45), Vector2(-75, 45),
        Vector2(-70, 45), Vector2(-67, 45), Vector2(-67, 44),
        Vector2(-70, 43), Vector2(-70, 41), Vector2(-74, 40),
        Vector2(-75, 39), Vector2(-75, 35), Vector2(-77, 34),
        Vector2(-80, 32), Vector2(-81, 30), Vector2(-80, 25),
        Vector2(-83, 25), Vector2(-88, 30), Vector2(-90, 29),
        Vector2(-94, 29), Vector2(-97, 26), Vector2(-100, 28),
        Vector2(-104, 29), Vector2(-106, 32), Vector2(-117, 32),
        Vector2(-120, 34), Vector2(-122, 37), Vector2(-124, 40),
        Vector2(-124, 42), Vector2(-124, 46), Vector2(-125, 48),
      ],
    ),
    CountryShape(
      code: 'CA',
      name: 'Canada',
      capital: 'Ottawa',
      points: [
        Vector2(-141, 60), Vector2(-141, 70), Vector2(-130, 70),
        Vector2(-120, 75), Vector2(-100, 75), Vector2(-85, 70),
        Vector2(-75, 65), Vector2(-60, 60), Vector2(-55, 52),
        Vector2(-60, 47), Vector2(-65, 44), Vector2(-67, 45),
        Vector2(-75, 45), Vector2(-84, 46), Vector2(-89, 49),
        Vector2(-95, 49), Vector2(-100, 49), Vector2(-110, 49),
        Vector2(-120, 49), Vector2(-123, 49), Vector2(-130, 54),
        Vector2(-135, 58), Vector2(-141, 60),
      ],
    ),
    CountryShape(
      code: 'MX',
      name: 'Mexico',
      capital: 'Mexico City',
      points: [
        Vector2(-117, 32), Vector2(-110, 31), Vector2(-108, 29),
        Vector2(-106, 29), Vector2(-104, 29), Vector2(-100, 28),
        Vector2(-97, 26), Vector2(-97, 22), Vector2(-95, 19),
        Vector2(-92, 18), Vector2(-90, 16), Vector2(-92, 15),
        Vector2(-97, 15), Vector2(-102, 18), Vector2(-105, 20),
        Vector2(-107, 22), Vector2(-110, 23), Vector2(-112, 26),
        Vector2(-115, 28), Vector2(-117, 32),
      ],
    ),
    // South America
    CountryShape(
      code: 'BR',
      name: 'Brazil',
      capital: 'Brasília',
      points: [
        Vector2(-74, 2), Vector2(-70, 4), Vector2(-65, 2),
        Vector2(-60, 5), Vector2(-52, 4), Vector2(-50, 2),
        Vector2(-44, -2), Vector2(-38, -4), Vector2(-35, -6),
        Vector2(-35, -10), Vector2(-37, -12), Vector2(-39, -15),
        Vector2(-42, -20), Vector2(-44, -23), Vector2(-48, -26),
        Vector2(-54, -28), Vector2(-56, -30), Vector2(-58, -28),
        Vector2(-58, -24), Vector2(-56, -20), Vector2(-58, -16),
        Vector2(-60, -14), Vector2(-66, -12), Vector2(-69, -10),
        Vector2(-72, -8), Vector2(-74, -4), Vector2(-74, 2),
      ],
    ),
    CountryShape(
      code: 'AR',
      name: 'Argentina',
      capital: 'Buenos Aires',
      points: [
        Vector2(-70, -22), Vector2(-65, -22), Vector2(-62, -22),
        Vector2(-58, -24), Vector2(-56, -30), Vector2(-58, -34),
        Vector2(-60, -38), Vector2(-62, -42), Vector2(-64, -46),
        Vector2(-66, -50), Vector2(-68, -54), Vector2(-70, -52),
        Vector2(-72, -48), Vector2(-74, -42), Vector2(-72, -38),
        Vector2(-70, -33), Vector2(-68, -28), Vector2(-70, -22),
      ],
    ),
    // Europe
    CountryShape(
      code: 'GB',
      name: 'United Kingdom',
      capital: 'London',
      points: [
        Vector2(-6, 58), Vector2(-3, 59), Vector2(-2, 57),
        Vector2(0, 56), Vector2(1, 53), Vector2(1, 51),
        Vector2(-1, 50), Vector2(-5, 50), Vector2(-6, 52),
        Vector2(-5, 54), Vector2(-6, 56), Vector2(-6, 58),
      ],
    ),
    CountryShape(
      code: 'FR',
      name: 'France',
      capital: 'Paris',
      points: [
        Vector2(-2, 48), Vector2(2, 51), Vector2(4, 50),
        Vector2(8, 49), Vector2(8, 47), Vector2(7, 44),
        Vector2(4, 43), Vector2(3, 42), Vector2(-2, 43),
        Vector2(-2, 46), Vector2(-5, 48), Vector2(-2, 48),
      ],
    ),
    CountryShape(
      code: 'DE',
      name: 'Germany',
      capital: 'Berlin',
      points: [
        Vector2(6, 51), Vector2(7, 54), Vector2(10, 54),
        Vector2(14, 54), Vector2(15, 51), Vector2(14, 49),
        Vector2(13, 47), Vector2(10, 47), Vector2(8, 48),
        Vector2(6, 49), Vector2(6, 51),
      ],
    ),
    CountryShape(
      code: 'IT',
      name: 'Italy',
      capital: 'Rome',
      points: [
        Vector2(7, 44), Vector2(7, 46), Vector2(10, 47),
        Vector2(13, 47), Vector2(14, 45), Vector2(13, 44),
        Vector2(15, 41), Vector2(18, 40), Vector2(16, 38),
        Vector2(12, 37), Vector2(9, 39), Vector2(8, 42),
        Vector2(7, 44),
      ],
    ),
    CountryShape(
      code: 'ES',
      name: 'Spain',
      capital: 'Madrid',
      points: [
        Vector2(-9, 43), Vector2(-2, 43), Vector2(0, 42),
        Vector2(3, 42), Vector2(3, 40), Vector2(0, 38),
        Vector2(-5, 36), Vector2(-7, 37), Vector2(-9, 38),
        Vector2(-9, 40), Vector2(-9, 43),
      ],
    ),
    // Africa
    CountryShape(
      code: 'EG',
      name: 'Egypt',
      capital: 'Cairo',
      points: [
        Vector2(25, 31), Vector2(29, 31), Vector2(35, 30),
        Vector2(35, 22), Vector2(32, 22), Vector2(25, 22),
        Vector2(25, 28), Vector2(25, 31),
      ],
    ),
    CountryShape(
      code: 'ZA',
      name: 'South Africa',
      capital: 'Pretoria',
      points: [
        Vector2(17, -29), Vector2(20, -25), Vector2(28, -23),
        Vector2(32, -24), Vector2(33, -28), Vector2(30, -32),
        Vector2(28, -34), Vector2(22, -34), Vector2(18, -32),
        Vector2(17, -29),
      ],
    ),
    // Asia
    CountryShape(
      code: 'CN',
      name: 'China',
      capital: 'Beijing',
      points: [
        Vector2(74, 40), Vector2(80, 42), Vector2(88, 48),
        Vector2(98, 42), Vector2(108, 42), Vector2(120, 42),
        Vector2(128, 42), Vector2(130, 40), Vector2(125, 38),
        Vector2(122, 32), Vector2(120, 28), Vector2(115, 23),
        Vector2(108, 22), Vector2(102, 22), Vector2(98, 25),
        Vector2(92, 28), Vector2(88, 28), Vector2(82, 30),
        Vector2(78, 32), Vector2(74, 35), Vector2(74, 40),
      ],
    ),
    CountryShape(
      code: 'IN',
      name: 'India',
      capital: 'New Delhi',
      points: [
        Vector2(68, 24), Vector2(72, 22), Vector2(73, 18),
        Vector2(77, 12), Vector2(78, 8), Vector2(80, 10),
        Vector2(84, 12), Vector2(88, 22), Vector2(92, 26),
        Vector2(88, 28), Vector2(82, 30), Vector2(76, 32),
        Vector2(72, 34), Vector2(68, 30), Vector2(68, 24),
      ],
    ),
    CountryShape(
      code: 'JP',
      name: 'Japan',
      capital: 'Tokyo',
      points: [
        Vector2(130, 32), Vector2(132, 34), Vector2(135, 35),
        Vector2(138, 35), Vector2(140, 36), Vector2(142, 40),
        Vector2(141, 42), Vector2(140, 44), Vector2(142, 45),
        Vector2(145, 44), Vector2(144, 42), Vector2(143, 38),
        Vector2(140, 35), Vector2(136, 33), Vector2(130, 32),
      ],
    ),
    CountryShape(
      code: 'RU',
      name: 'Russia',
      capital: 'Moscow',
      points: [
        Vector2(28, 70), Vector2(40, 68), Vector2(60, 70),
        Vector2(80, 72), Vector2(100, 75), Vector2(120, 72),
        Vector2(140, 70), Vector2(160, 65), Vector2(180, 65),
        Vector2(170, 60), Vector2(155, 52), Vector2(142, 50),
        Vector2(130, 52), Vector2(120, 50), Vector2(100, 52),
        Vector2(80, 55), Vector2(60, 55), Vector2(40, 52),
        Vector2(30, 55), Vector2(28, 60), Vector2(28, 70),
      ],
    ),
    // Oceania
    CountryShape(
      code: 'AU',
      name: 'Australia',
      capital: 'Canberra',
      points: [
        Vector2(114, -22), Vector2(120, -18), Vector2(130, -14),
        Vector2(140, -12), Vector2(145, -14), Vector2(150, -22),
        Vector2(153, -28), Vector2(150, -35), Vector2(145, -38),
        Vector2(138, -36), Vector2(130, -32), Vector2(124, -34),
        Vector2(116, -32), Vector2(114, -28), Vector2(114, -22),
      ],
    ),
  ];

  // Major cities for low-altitude view
  static const List<CityData> majorCities = [
    // North America
    CityData(name: 'New York', countryCode: 'US', location: Vector2(-74, 40.7)),
    CityData(name: 'Los Angeles', countryCode: 'US', location: Vector2(-118.2, 34)),
    CityData(name: 'Chicago', countryCode: 'US', location: Vector2(-87.6, 41.9)),
    CityData(name: 'Washington D.C.', countryCode: 'US', location: Vector2(-77, 38.9), isCapital: true),
    CityData(name: 'Toronto', countryCode: 'CA', location: Vector2(-79.4, 43.7)),
    CityData(name: 'Ottawa', countryCode: 'CA', location: Vector2(-75.7, 45.4), isCapital: true),
    CityData(name: 'Mexico City', countryCode: 'MX', location: Vector2(-99.1, 19.4), isCapital: true),
    // South America
    CityData(name: 'São Paulo', countryCode: 'BR', location: Vector2(-46.6, -23.5)),
    CityData(name: 'Rio de Janeiro', countryCode: 'BR', location: Vector2(-43.2, -22.9)),
    CityData(name: 'Brasília', countryCode: 'BR', location: Vector2(-47.9, -15.8), isCapital: true),
    CityData(name: 'Buenos Aires', countryCode: 'AR', location: Vector2(-58.4, -34.6), isCapital: true),
    // Europe
    CityData(name: 'London', countryCode: 'GB', location: Vector2(-0.1, 51.5), isCapital: true),
    CityData(name: 'Paris', countryCode: 'FR', location: Vector2(2.3, 48.9), isCapital: true),
    CityData(name: 'Berlin', countryCode: 'DE', location: Vector2(13.4, 52.5), isCapital: true),
    CityData(name: 'Rome', countryCode: 'IT', location: Vector2(12.5, 41.9), isCapital: true),
    CityData(name: 'Madrid', countryCode: 'ES', location: Vector2(-3.7, 40.4), isCapital: true),
    CityData(name: 'Moscow', countryCode: 'RU', location: Vector2(37.6, 55.8), isCapital: true),
    // Africa
    CityData(name: 'Cairo', countryCode: 'EG', location: Vector2(31.2, 30), isCapital: true),
    CityData(name: 'Cape Town', countryCode: 'ZA', location: Vector2(18.4, -33.9)),
    CityData(name: 'Johannesburg', countryCode: 'ZA', location: Vector2(28, -26.2)),
    // Asia
    CityData(name: 'Beijing', countryCode: 'CN', location: Vector2(116.4, 39.9), isCapital: true),
    CityData(name: 'Shanghai', countryCode: 'CN', location: Vector2(121.5, 31.2)),
    CityData(name: 'Tokyo', countryCode: 'JP', location: Vector2(139.7, 35.7), isCapital: true),
    CityData(name: 'New Delhi', countryCode: 'IN', location: Vector2(77.2, 28.6), isCapital: true),
    CityData(name: 'Mumbai', countryCode: 'IN', location: Vector2(72.9, 19.1)),
    // Oceania
    CityData(name: 'Sydney', countryCode: 'AU', location: Vector2(151.2, -33.9)),
    CityData(name: 'Melbourne', countryCode: 'AU', location: Vector2(145, -37.8)),
    CityData(name: 'Canberra', countryCode: 'AU', location: Vector2(149.1, -35.3), isCapital: true),
  ];

  /// Get country by code
  static CountryShape? getCountry(String code) {
    try {
      return countries.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get random country
  static CountryShape getRandomCountry() {
    return countries[DateTime.now().millisecondsSinceEpoch % countries.length];
  }

  /// Get cities for a country
  static List<CityData> getCitiesForCountry(String code) {
    return majorCities.where((c) => c.countryCode == code).toList();
  }

  /// Get capital city for a country
  static CityData? getCapital(String code) {
    try {
      return majorCities.firstWhere((c) => c.countryCode == code && c.isCapital);
    } catch (_) {
      return null;
    }
  }
}
