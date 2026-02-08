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
  // Simplified country outlines (~100 countries)
  static final List<CountryShape> countries = [
    // =========================================================
    // NORTH AMERICA
    // =========================================================
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
        Vector2(-117.1, 32.5), Vector2(-115.0, 31.0), Vector2(-111.0, 31.3), Vector2(-108.2, 31.8),
        Vector2(-106.5, 31.8), Vector2(-105.0, 30.0), Vector2(-104.0, 29.3), Vector2(-101.5, 29.5),
        Vector2(-99.5, 27.5), Vector2(-97.0, 26.0), Vector2(-97.5, 22.5), Vector2(-95.0, 19.0),
        Vector2(-92.0, 18.5), Vector2(-90.5, 16.0), Vector2(-92.0, 15.0), Vector2(-94.0, 16.0),
        Vector2(-97.0, 15.5), Vector2(-100.0, 17.5), Vector2(-102.0, 19.0), Vector2(-105.0, 20.0),
        Vector2(-107.0, 22.5), Vector2(-109.5, 23.0), Vector2(-112.0, 26.5), Vector2(-115.0, 28.5),
        Vector2(-117.1, 32.5),
      ],
    ),
    CountryShape(
      code: 'CU',
      name: 'Cuba',
      capital: 'Havana',
      points: [
        Vector2(-84.9, 21.9), Vector2(-84.2, 22.1), Vector2(-83.0, 22.3), Vector2(-81.8, 22.9),
        Vector2(-80.5, 22.9), Vector2(-79.3, 22.4), Vector2(-78.2, 22.4), Vector2(-77.2, 21.6),
        Vector2(-76.2, 21.2), Vector2(-75.2, 20.7), Vector2(-74.5, 20.3), Vector2(-75.5, 20.0),
        Vector2(-77.0, 19.9), Vector2(-78.5, 20.2), Vector2(-80.5, 21.5), Vector2(-82.5, 21.5),
        Vector2(-84.0, 21.9), Vector2(-84.9, 21.9),
      ],
    ),
    CountryShape(
      code: 'GT',
      name: 'Guatemala',
      capital: 'Guatemala City',
      points: [
        Vector2(-92, 18), Vector2(-91, 18), Vector2(-89, 17.5),
        Vector2(-89, 16), Vector2(-89, 15), Vector2(-90, 14),
        Vector2(-91, 14.5), Vector2(-92, 15), Vector2(-92, 16),
        Vector2(-92, 18),
      ],
    ),
    CountryShape(
      code: 'PA',
      name: 'Panama',
      capital: 'Panama City',
      points: [
        Vector2(-83, 9), Vector2(-82, 10), Vector2(-80, 9.5),
        Vector2(-78, 9), Vector2(-77, 8), Vector2(-78, 7.5),
        Vector2(-80, 7.5), Vector2(-82, 8), Vector2(-83, 8.5),
        Vector2(-83, 9),
      ],
    ),

    // =========================================================
    // SOUTH AMERICA
    // =========================================================
    CountryShape(
      code: 'BR',
      name: 'Brazil',
      capital: 'Brasilia',
      points: [
        Vector2(-73.9, -7.3), Vector2(-73.0, -4.0), Vector2(-70.1, -4.0), Vector2(-69.9, -1.0),
        Vector2(-69.6, 0.6), Vector2(-70.0, 2.8), Vector2(-69.5, 4.2), Vector2(-67.3, 5.7),
        Vector2(-64.0, 5.2), Vector2(-60.7, 5.2), Vector2(-59.0, 5.0), Vector2(-57.5, 5.0),
        Vector2(-55.0, 5.0), Vector2(-52.5, 3.2), Vector2(-51.7, 4.0), Vector2(-51.0, 3.0),
        Vector2(-50.0, 1.8), Vector2(-49.0, 1.7), Vector2(-47.8, 0.7), Vector2(-46.5, -1.0),
        Vector2(-44.6, -2.1), Vector2(-41.5, -3.0), Vector2(-38.5, -3.7), Vector2(-35.5, -5.5),
        Vector2(-35.0, -9.0), Vector2(-36.5, -10.5), Vector2(-37.0, -11.0), Vector2(-38.5, -13.0),
        Vector2(-39.0, -14.2), Vector2(-39.7, -17.8), Vector2(-40.5, -20.5), Vector2(-42.0, -22.9),
        Vector2(-43.2, -22.9), Vector2(-44.6, -23.3), Vector2(-46.6, -24.0), Vector2(-48.5, -25.9),
        Vector2(-51.5, -27.0), Vector2(-53.4, -27.5), Vector2(-54.6, -27.5), Vector2(-55.1, -27.0),
        Vector2(-56.0, -28.5), Vector2(-57.6, -30.2), Vector2(-58.2, -27.3), Vector2(-57.8, -25.1),
        Vector2(-58.0, -24.0), Vector2(-57.5, -22.0), Vector2(-56.5, -20.0), Vector2(-57.8, -18.0),
        Vector2(-59.0, -16.3), Vector2(-60.0, -13.5), Vector2(-61.5, -13.5), Vector2(-64.0, -12.5),
        Vector2(-66.3, -10.0), Vector2(-68.8, -10.0), Vector2(-69.6, -10.9), Vector2(-70.6, -11.0),
        Vector2(-72.0, -10.0), Vector2(-73.2, -9.4), Vector2(-73.9, -7.3),
      ],
    ),
    CountryShape(
      code: 'AR',
      name: 'Argentina',
      capital: 'Buenos Aires',
      points: [
        Vector2(-70.0, -22.5), Vector2(-66.5, -22.0), Vector2(-64.5, -22.5), Vector2(-62.0, -22.0),
        Vector2(-59.0, -24.0), Vector2(-57.0, -28.0), Vector2(-55.5, -30.0), Vector2(-56.0, -32.0),
        Vector2(-57.5, -34.5), Vector2(-59.0, -36.5), Vector2(-61.5, -39.5), Vector2(-63.0, -42.0),
        Vector2(-65.5, -46.5), Vector2(-67.0, -50.0), Vector2(-68.5, -54.0), Vector2(-70.0, -52.0),
        Vector2(-72.0, -48.5), Vector2(-73.5, -44.0), Vector2(-72.5, -40.0), Vector2(-71.5, -36.0),
        Vector2(-70.0, -30.0), Vector2(-68.5, -27.0), Vector2(-70.0, -22.5),
      ],
    ),
    CountryShape(
      code: 'CO',
      name: 'Colombia',
      capital: 'Bogota',
      points: [
        Vector2(-77.4, 8.0), Vector2(-76.8, 9.5), Vector2(-75.5, 11.0), Vector2(-73.5, 12.5),
        Vector2(-72.0, 12.0), Vector2(-70.0, 11.0), Vector2(-67.5, 7.5), Vector2(-67.0, 5.5),
        Vector2(-67.5, 3.5), Vector2(-68.0, 2.0), Vector2(-70.0, 0.0), Vector2(-72.0, -2.0),
        Vector2(-74.0, -1.5), Vector2(-76.5, -1.0), Vector2(-77.5, 0.5), Vector2(-78.5, 2.0),
        Vector2(-78.0, 4.0), Vector2(-77.5, 6.0), Vector2(-77.4, 8.0),
      ],
    ),
    CountryShape(
      code: 'PE',
      name: 'Peru',
      capital: 'Lima',
      points: [
        Vector2(-81.2, -4.0), Vector2(-79.5, -3.5), Vector2(-77.5, -2.5), Vector2(-75.5, -1.5),
        Vector2(-73.5, -1.5), Vector2(-70.0, -2.0), Vector2(-70.0, -4.5), Vector2(-69.5, -7.0),
        Vector2(-70.0, -9.5), Vector2(-70.5, -12.5), Vector2(-69.5, -15.5), Vector2(-69.0, -17.5),
        Vector2(-71.5, -18.0), Vector2(-75.5, -15.5), Vector2(-77.5, -12.5), Vector2(-79.5, -8.0),
        Vector2(-80.5, -6.0), Vector2(-81.2, -4.0),
      ],
    ),
    CountryShape(
      code: 'CL',
      name: 'Chile',
      capital: 'Santiago',
      points: [
        Vector2(-69.5, -17.5), Vector2(-69.0, -19.5), Vector2(-69.5, -22.0), Vector2(-70.0, -25.0),
        Vector2(-71.0, -28.0), Vector2(-71.5, -30.0), Vector2(-72.0, -33.0), Vector2(-73.0, -36.0),
        Vector2(-73.5, -38.0), Vector2(-74.0, -40.0), Vector2(-74.5, -43.0), Vector2(-75.0, -46.0),
        Vector2(-74.5, -49.0), Vector2(-73.5, -51.0), Vector2(-71.5, -52.0), Vector2(-70.0, -50.0),
        Vector2(-71.0, -44.5), Vector2(-71.0, -40.0), Vector2(-70.5, -36.0), Vector2(-70.0, -30.0),
        Vector2(-69.0, -24.0), Vector2(-68.5, -20.0), Vector2(-69.5, -17.5),
      ],
    ),
    CountryShape(
      code: 'VE',
      name: 'Venezuela',
      capital: 'Caracas',
      points: [
        Vector2(-73.0, 12.0), Vector2(-71.5, 12.5), Vector2(-68.5, 12.0), Vector2(-66.0, 11.0),
        Vector2(-63.5, 10.5), Vector2(-61.5, 10.0), Vector2(-60.0, 8.5), Vector2(-61.0, 7.5),
        Vector2(-62.0, 7.0), Vector2(-64.0, 6.0), Vector2(-66.0, 4.5), Vector2(-67.0, 2.5),
        Vector2(-67.5, 3.0), Vector2(-69.5, 4.0), Vector2(-71.5, 6.5), Vector2(-72.0, 8.0),
        Vector2(-72.5, 10.0), Vector2(-73.0, 12.0),
      ],
    ),
    CountryShape(
      code: 'EC',
      name: 'Ecuador',
      capital: 'Quito',
      points: [
        Vector2(-75.2, -0.1), Vector2(-75.6, 0.0), Vector2(-76.0, 0.3), Vector2(-76.9, 0.4),
        Vector2(-77.8, 0.8), Vector2(-78.8, 1.4), Vector2(-79.5, 1.0), Vector2(-80.1, 0.8),
        Vector2(-80.0, -0.5), Vector2(-80.3, -2.5), Vector2(-79.9, -3.4), Vector2(-78.5, -3.4),
        Vector2(-77.8, -3.0), Vector2(-76.6, -2.4), Vector2(-75.6, -1.5), Vector2(-75.2, -0.6),
        Vector2(-75.2, -0.1),
      ],
    ),
    CountryShape(
      code: 'UY',
      name: 'Uruguay',
      capital: 'Montevideo',
      points: [
        Vector2(-58.4, -30.2), Vector2(-57.6, -30.2), Vector2(-56.0, -30.1), Vector2(-54.6, -31.5),
        Vector2(-53.8, -32.0), Vector2(-53.4, -33.0), Vector2(-53.2, -33.7), Vector2(-53.4, -34.4),
        Vector2(-54.9, -34.9), Vector2(-55.7, -34.8), Vector2(-56.8, -34.9), Vector2(-57.6, -34.5),
        Vector2(-58.4, -34.0), Vector2(-58.5, -33.7), Vector2(-58.2, -32.5), Vector2(-58.1, -31.3),
        Vector2(-58.0, -30.8), Vector2(-58.4, -30.2),
      ],
    ),
    CountryShape(
      code: 'PY',
      name: 'Paraguay',
      capital: 'Asuncion',
      points: [
        Vector2(-62.6, -22.2), Vector2(-62.0, -21.0), Vector2(-61.8, -20.0), Vector2(-60.0, -19.3),
        Vector2(-58.2, -20.0), Vector2(-57.8, -20.7), Vector2(-57.5, -22.1), Vector2(-56.5, -22.3),
        Vector2(-55.7, -22.5), Vector2(-55.1, -23.8), Vector2(-54.9, -24.5), Vector2(-54.6, -25.5),
        Vector2(-54.6, -26.5), Vector2(-55.0, -27.0), Vector2(-56.3, -27.4), Vector2(-58.0, -27.1),
        Vector2(-60.0, -26.7), Vector2(-62.6, -22.2),
      ],
    ),

    // =========================================================
    // EUROPE
    // =========================================================
    CountryShape(
      code: 'GB',
      name: 'United Kingdom',
      capital: 'London',
      points: [
        // Scotland north coast
        Vector2(-5.0, 58.5), Vector2(-3.4, 58.6), Vector2(-1.8, 57.7),
        // East coast Scotland
        Vector2(-2.1, 57.1), Vector2(-1.8, 56.3), Vector2(-2.9, 56.0),
        // East coast England
        Vector2(-1.6, 55.0), Vector2(-1.2, 54.0), Vector2(-0.2, 53.7),
        Vector2(0.4, 53.0), Vector2(1.8, 52.8), Vector2(1.5, 52.0),
        // Thames and south-east
        Vector2(1.4, 51.4), Vector2(0.3, 51.3), Vector2(1.4, 51.1),
        // South coast
        Vector2(0.0, 50.8), Vector2(-1.3, 50.8), Vector2(-2.0, 50.7),
        Vector2(-3.5, 50.3), Vector2(-5.1, 50.1), Vector2(-5.7, 50.1),
        // West coast: Cornwall to Wales
        Vector2(-5.3, 51.0), Vector2(-5.0, 51.6), Vector2(-4.3, 51.7),
        Vector2(-3.2, 51.4), Vector2(-3.0, 52.0),
        // Wales and NW England
        Vector2(-4.5, 52.8), Vector2(-4.1, 53.2), Vector2(-3.0, 53.4),
        Vector2(-3.1, 54.0), Vector2(-3.4, 54.8),
        // Scotland west coast
        Vector2(-5.1, 55.3), Vector2(-5.6, 56.2), Vector2(-6.2, 57.5),
        Vector2(-5.0, 58.5),
      ],
    ),
    CountryShape(
      code: 'FR',
      name: 'France',
      capital: 'Paris',
      points: [
        // North coast (Channel)
        Vector2(2.5, 51.1), Vector2(1.6, 50.9), Vector2(0.2, 49.5),
        // Brittany peninsula
        Vector2(-1.2, 48.6), Vector2(-3.0, 48.8), Vector2(-4.8, 48.4),
        Vector2(-3.5, 47.7), Vector2(-2.8, 47.3),
        // Atlantic coast
        Vector2(-1.5, 46.9), Vector2(-1.2, 46.2), Vector2(-1.1, 45.5),
        Vector2(-1.8, 43.4),
        // Pyrenees to Mediterranean
        Vector2(0.7, 42.7), Vector2(3.0, 42.4), Vector2(3.1, 43.2),
        // Côte d'Azur
        Vector2(4.4, 43.4), Vector2(5.4, 43.3), Vector2(6.2, 43.1),
        Vector2(7.0, 43.5), Vector2(7.5, 43.8),
        // Eastern and northern borders
        Vector2(8.2, 49.0), Vector2(7.5, 48.1), Vector2(6.2, 49.3),
        Vector2(5.9, 49.5), Vector2(4.3, 50.1), Vector2(3.2, 50.3),
        Vector2(2.5, 51.1),
      ],
    ),
    CountryShape(
      code: 'DE',
      name: 'Germany',
      capital: 'Berlin',
      points: [
        // North Sea coast
        Vector2(6.1, 53.5), Vector2(7.0, 53.8), Vector2(8.6, 54.0),
        // Baltic coast
        Vector2(9.9, 54.8), Vector2(11.0, 54.4), Vector2(13.4, 54.3),
        Vector2(14.2, 53.9),
        // Eastern border (Poland)
        Vector2(14.7, 52.9), Vector2(14.6, 51.8), Vector2(15.0, 51.1),
        // Czech border
        Vector2(14.3, 50.9), Vector2(12.9, 50.3), Vector2(12.1, 50.3),
        // Austrian border
        Vector2(13.0, 47.5), Vector2(12.7, 47.6), Vector2(10.5, 47.3),
        // Swiss border
        Vector2(8.6, 47.5), Vector2(7.6, 47.6),
        // French border (Rhine)
        Vector2(7.5, 48.1), Vector2(8.2, 49.0),
        // Luxembourg/Belgium border
        Vector2(6.1, 50.1), Vector2(6.0, 50.8),
        // Netherlands border
        Vector2(6.7, 51.9), Vector2(7.0, 52.2), Vector2(7.2, 53.2),
        Vector2(6.1, 53.5),
      ],
    ),
    CountryShape(
      code: 'IT',
      name: 'Italy',
      capital: 'Rome',
      points: [
        // Ligurian coast
        Vector2(6.6, 44.1), Vector2(8.2, 44.0), Vector2(9.5, 44.3),
        // Tuscan coast
        Vector2(10.5, 42.9), Vector2(11.1, 42.4), Vector2(12.3, 41.8),
        // West coast south
        Vector2(13.8, 41.2), Vector2(14.4, 40.6), Vector2(15.6, 40.1),
        // Calabria (toe)
        Vector2(16.5, 39.1), Vector2(15.6, 38.0), Vector2(16.5, 38.2),
        // East coast up the boot
        Vector2(17.1, 39.0), Vector2(17.9, 40.0),
        // Heel (Apulia)
        Vector2(18.5, 40.3), Vector2(18.3, 40.8), Vector2(17.0, 41.0),
        // Adriatic coast
        Vector2(16.0, 41.4), Vector2(15.5, 42.0), Vector2(14.2, 42.5),
        Vector2(13.6, 43.6), Vector2(12.6, 44.0),
        // North-east
        Vector2(12.3, 45.0), Vector2(13.8, 45.6), Vector2(13.4, 46.5),
        // Northern border
        Vector2(11.4, 47.0), Vector2(10.5, 46.9), Vector2(9.0, 46.0),
        Vector2(7.7, 45.9), Vector2(6.6, 44.1),
      ],
    ),
    CountryShape(
      code: 'ES',
      name: 'Spain',
      capital: 'Madrid',
      points: [
        // North coast (Cantabrian)
        Vector2(-9.3, 43.2), Vector2(-8.0, 43.7), Vector2(-5.8, 43.4),
        Vector2(-3.8, 43.4), Vector2(-1.8, 43.4),
        // Pyrenees
        Vector2(0.7, 42.7), Vector2(3.2, 42.4),
        // Mediterranean coast
        Vector2(3.3, 41.7), Vector2(2.2, 41.4), Vector2(0.3, 40.7),
        Vector2(-0.1, 39.5), Vector2(-0.4, 38.4),
        // South-east
        Vector2(-0.7, 37.6), Vector2(-1.6, 37.0), Vector2(-2.4, 36.7),
        // Gibraltar area
        Vector2(-5.3, 36.1), Vector2(-6.3, 36.5),
        // Atlantic south
        Vector2(-7.4, 37.2), Vector2(-8.9, 37.0),
        // Portuguese border / west coast
        Vector2(-9.5, 38.8), Vector2(-8.9, 41.2), Vector2(-8.7, 42.1),
        Vector2(-9.3, 43.2),
      ],
    ),
    CountryShape(
      code: 'PT',
      name: 'Portugal',
      capital: 'Lisbon',
      points: [
        Vector2(-9.5, 42.0), Vector2(-8.9, 42.1), Vector2(-8.5, 42.0), Vector2(-8.2, 41.9),
        Vector2(-7.0, 42.0), Vector2(-6.8, 41.9), Vector2(-6.7, 41.5), Vector2(-6.9, 40.5),
        Vector2(-7.0, 39.7), Vector2(-7.4, 39.4), Vector2(-7.5, 38.5), Vector2(-7.9, 37.8),
        Vector2(-8.7, 37.0), Vector2(-8.9, 36.9), Vector2(-9.0, 37.0), Vector2(-9.4, 38.7),
        Vector2(-9.3, 39.5), Vector2(-8.8, 40.6), Vector2(-9.0, 41.5), Vector2(-9.5, 42.0),
      ],
    ),
    CountryShape(
      code: 'NL',
      name: 'Netherlands',
      capital: 'Amsterdam',
      points: [
        Vector2(3.4, 51.4), Vector2(4.2, 51.4), Vector2(4.8, 51.6), Vector2(5.4, 51.3),
        Vector2(6.0, 51.8), Vector2(6.9, 51.9), Vector2(7.2, 52.4), Vector2(7.1, 53.2),
        Vector2(6.9, 53.5), Vector2(6.2, 53.4), Vector2(5.5, 53.2), Vector2(5.0, 53.4),
        Vector2(4.8, 53.5), Vector2(4.3, 53.2), Vector2(4.1, 52.8), Vector2(3.9, 52.4),
        Vector2(3.6, 51.8), Vector2(3.4, 51.4),
      ],
    ),
    CountryShape(
      code: 'BE',
      name: 'Belgium',
      capital: 'Brussels',
      points: [
        Vector2(2.5, 49.5), Vector2(3.0, 49.5), Vector2(3.5, 49.5), Vector2(4.2, 49.9),
        Vector2(4.8, 50.0), Vector2(5.6, 50.4), Vector2(5.9, 49.8), Vector2(6.1, 50.1),
        Vector2(6.0, 50.7), Vector2(5.8, 51.1), Vector2(5.0, 51.5), Vector2(4.5, 51.5),
        Vector2(3.8, 51.4), Vector2(3.2, 51.4), Vector2(2.9, 51.2), Vector2(2.6, 50.8),
        Vector2(2.5, 50.2), Vector2(2.5, 49.5),
      ],
    ),
    CountryShape(
      code: 'PL',
      name: 'Poland',
      capital: 'Warsaw',
      points: [
        Vector2(14.1, 53.9), Vector2(16.2, 54.5), Vector2(18.3, 54.8), Vector2(19.8, 54.4),
        Vector2(22.8, 54.4), Vector2(23.9, 52.3), Vector2(24.1, 50.9), Vector2(23.5, 50.4),
        Vector2(22.1, 49.1), Vector2(20.1, 49.2), Vector2(18.8, 49.5), Vector2(17.0, 50.2),
        Vector2(16.0, 50.6), Vector2(14.8, 50.9), Vector2(14.6, 51.7), Vector2(14.7, 52.9),
        Vector2(14.1, 53.9),
      ],
    ),
    CountryShape(
      code: 'CZ',
      name: 'Czech Republic',
      capital: 'Prague',
      points: [
        Vector2(12.1, 50.3), Vector2(12.9, 50.4), Vector2(14.3, 50.9), Vector2(15.0, 51.1),
        Vector2(16.0, 50.6), Vector2(16.9, 50.4), Vector2(17.7, 50.1), Vector2(18.6, 49.8),
        Vector2(18.8, 49.5), Vector2(18.2, 48.9), Vector2(17.2, 48.8), Vector2(16.1, 48.7),
        Vector2(15.0, 48.9), Vector2(14.1, 48.6), Vector2(13.0, 48.7), Vector2(12.5, 49.0),
        Vector2(12.1, 49.6), Vector2(12.1, 50.3),
      ],
    ),
    CountryShape(
      code: 'AT',
      name: 'Austria',
      capital: 'Vienna',
      points: [
        Vector2(9.5, 47.3), Vector2(10.5, 47.3), Vector2(11.4, 47.0), Vector2(12.1, 47.0),
        Vector2(12.7, 47.6), Vector2(13.0, 47.5), Vector2(14.5, 47.5), Vector2(15.5, 47.0),
        Vector2(16.1, 46.9), Vector2(16.5, 47.5), Vector2(17.1, 48.0), Vector2(16.9, 48.6),
        Vector2(15.5, 48.8), Vector2(14.7, 48.6), Vector2(13.7, 48.5), Vector2(12.5, 48.1),
        Vector2(11.0, 47.4), Vector2(10.1, 47.6), Vector2(9.5, 47.3),
      ],
    ),
    CountryShape(
      code: 'CH',
      name: 'Switzerland',
      capital: 'Bern',
      points: [
        Vector2(6.0, 46.4), Vector2(6.5, 46.5), Vector2(7.0, 45.9), Vector2(7.6, 47.6),
        Vector2(8.2, 47.6), Vector2(8.6, 47.5), Vector2(9.0, 47.5), Vector2(9.5, 47.5),
        Vector2(10.1, 47.6), Vector2(10.5, 47.3), Vector2(10.3, 46.8), Vector2(9.5, 46.3),
        Vector2(9.0, 46.0), Vector2(8.5, 46.3), Vector2(7.6, 45.9), Vector2(7.0, 45.9),
        Vector2(6.2, 46.3), Vector2(6.0, 46.4),
      ],
    ),
    CountryShape(
      code: 'SE',
      name: 'Sweden',
      capital: 'Stockholm',
      points: [
        Vector2(11.1, 55.4), Vector2(12.4, 56.1), Vector2(14.3, 55.4), Vector2(16.5, 56.7),
        Vector2(18.6, 57.8), Vector2(19.1, 57.6), Vector2(18.3, 59.3), Vector2(18.5, 60.1),
        Vector2(17.4, 61.7), Vector2(17.3, 63.0), Vector2(19.1, 63.5), Vector2(20.3, 63.5),
        Vector2(21.6, 64.6), Vector2(22.2, 65.7), Vector2(23.2, 66.1), Vector2(20.5, 67.5),
        Vector2(18.1, 68.5), Vector2(16.5, 67.0), Vector2(14.5, 65.8), Vector2(13.2, 64.0),
        Vector2(12.5, 60.5), Vector2(11.1, 55.4),
      ],
    ),
    CountryShape(
      code: 'NO',
      name: 'Norway',
      capital: 'Oslo',
      points: [
        Vector2(4.6, 58.1), Vector2(5.7, 58.1), Vector2(7.0, 58.0), Vector2(8.6, 58.2),
        Vector2(11.0, 59.0), Vector2(12.0, 60.3), Vector2(11.5, 61.5), Vector2(12.3, 62.2),
        Vector2(13.5, 63.8), Vector2(14.0, 65.1), Vector2(15.5, 65.8), Vector2(14.7, 67.8),
        Vector2(16.0, 68.8), Vector2(18.0, 69.6), Vector2(20.5, 69.8), Vector2(25.0, 70.8),
        Vector2(30.0, 71.4), Vector2(31.0, 70.0), Vector2(28.0, 69.0), Vector2(22.0, 67.5),
        Vector2(16.0, 64.5), Vector2(10.0, 62.0), Vector2(7.5, 59.5), Vector2(4.6, 58.1),
      ],
    ),
    CountryShape(
      code: 'FI',
      name: 'Finland',
      capital: 'Helsinki',
      points: [
        Vector2(20.7, 59.8), Vector2(22.5, 60.0), Vector2(24.0, 59.8), Vector2(25.5, 60.0),
        Vector2(27.0, 60.5), Vector2(28.6, 61.4), Vector2(29.7, 62.5), Vector2(30.0, 63.5),
        Vector2(30.5, 64.8), Vector2(29.5, 66.5), Vector2(28.5, 68.0), Vector2(28.0, 69.0),
        Vector2(27.0, 70.0), Vector2(25.5, 70.0), Vector2(24.0, 68.5), Vector2(23.5, 67.0),
        Vector2(23.0, 65.5), Vector2(22.0, 63.5), Vector2(21.5, 62.0), Vector2(20.7, 59.8),
      ],
    ),
    CountryShape(
      code: 'DK',
      name: 'Denmark',
      capital: 'Copenhagen',
      points: [
        Vector2(8.1, 54.8), Vector2(8.6, 55.0), Vector2(9.0, 55.5), Vector2(9.6, 56.0),
        Vector2(10.1, 56.5), Vector2(10.6, 57.0), Vector2(10.9, 57.4), Vector2(11.1, 57.1),
        Vector2(11.7, 57.0), Vector2(12.2, 56.1), Vector2(12.7, 56.0), Vector2(12.6, 55.6),
        Vector2(12.2, 55.4), Vector2(11.8, 55.0), Vector2(11.0, 55.4), Vector2(10.5, 55.2),
        Vector2(10.0, 55.0), Vector2(9.5, 54.8), Vector2(9.0, 54.5), Vector2(8.6, 54.6),
        Vector2(8.3, 54.9), Vector2(8.1, 54.8),
      ],
    ),
    CountryShape(
      code: 'IE',
      name: 'Ireland',
      capital: 'Dublin',
      points: [
        Vector2(-10.5, 51.4), Vector2(-9.5, 51.5), Vector2(-8.5, 51.9), Vector2(-7.5, 52.0),
        Vector2(-6.9, 52.2), Vector2(-6.0, 52.2), Vector2(-6.0, 53.0), Vector2(-6.2, 53.8),
        Vector2(-6.5, 54.5), Vector2(-7.3, 55.0), Vector2(-8.2, 55.3), Vector2(-8.7, 55.1),
        Vector2(-9.5, 54.5), Vector2(-10.0, 54.0), Vector2(-10.2, 53.4), Vector2(-10.0, 52.8),
        Vector2(-9.8, 52.2), Vector2(-10.2, 51.8), Vector2(-10.5, 51.6), Vector2(-10.5, 51.4),
      ],
    ),
    CountryShape(
      code: 'GR',
      name: 'Greece',
      capital: 'Athens',
      points: [
        Vector2(20.0, 40.9), Vector2(20.6, 41.1), Vector2(21.5, 40.9), Vector2(22.5, 41.1),
        Vector2(23.5, 41.0), Vector2(24.5, 41.4), Vector2(25.5, 41.3), Vector2(26.0, 41.3),
        Vector2(26.6, 40.9), Vector2(26.5, 40.0), Vector2(26.3, 39.2), Vector2(25.8, 38.5),
        Vector2(25.0, 38.0), Vector2(24.5, 37.5), Vector2(23.7, 37.9), Vector2(23.5, 38.3),
        Vector2(23.0, 38.8), Vector2(22.5, 38.2), Vector2(22.8, 37.5), Vector2(22.5, 37.0),
        Vector2(21.7, 37.6), Vector2(21.0, 38.3), Vector2(20.5, 39.6), Vector2(20.0, 40.9),
      ],
    ),
    CountryShape(
      code: 'TR',
      name: 'Turkey',
      capital: 'Ankara',
      points: [
        Vector2(26.0, 42.0), Vector2(28.0, 41.7), Vector2(29.3, 41.2), Vector2(31.0, 41.0),
        Vector2(33.0, 42.0), Vector2(35.0, 42.0), Vector2(36.5, 41.7), Vector2(38.5, 40.5),
        Vector2(40.5, 40.5), Vector2(43.5, 41.1), Vector2(44.8, 39.7), Vector2(44.0, 38.5),
        Vector2(42.5, 37.0), Vector2(39.0, 36.7), Vector2(36.5, 36.5), Vector2(33.0, 36.0),
        Vector2(30.5, 36.2), Vector2(29.0, 36.7), Vector2(27.0, 37.7), Vector2(26.0, 38.5),
        Vector2(26.0, 40.0), Vector2(26.0, 42.0),
      ],
    ),
    CountryShape(
      code: 'UA',
      name: 'Ukraine',
      capital: 'Kyiv',
      points: [
        Vector2(22.2, 48.4), Vector2(24.0, 49.0), Vector2(26.6, 50.4), Vector2(30.0, 51.4),
        Vector2(33.0, 52.3), Vector2(36.0, 52.1), Vector2(38.0, 51.5), Vector2(40.0, 50.0),
        Vector2(40.2, 48.0), Vector2(39.8, 47.2), Vector2(38.0, 46.5), Vector2(36.5, 46.2),
        Vector2(35.0, 46.4), Vector2(33.5, 46.1), Vector2(31.5, 46.5), Vector2(29.5, 45.5),
        Vector2(28.2, 46.5), Vector2(25.0, 47.5), Vector2(24.0, 48.0), Vector2(22.2, 48.4),
      ],
    ),
    CountryShape(
      code: 'RO',
      name: 'Romania',
      capital: 'Bucharest',
      points: [
        Vector2(22.4, 48.0), Vector2(23.5, 48.0), Vector2(24.9, 47.7), Vector2(26.5, 48.3),
        Vector2(27.8, 47.8), Vector2(28.2, 46.8), Vector2(29.7, 46.5), Vector2(29.7, 45.3),
        Vector2(28.8, 44.9), Vector2(28.6, 43.8), Vector2(27.0, 44.0), Vector2(25.5, 43.7),
        Vector2(24.0, 43.6), Vector2(22.4, 44.0), Vector2(21.5, 44.8), Vector2(21.4, 45.5),
        Vector2(22.0, 46.3), Vector2(22.4, 47.0), Vector2(22.4, 48.0),
      ],
    ),
    CountryShape(
      code: 'HU',
      name: 'Hungary',
      capital: 'Budapest',
      points: [
        Vector2(16.1, 47.0), Vector2(16.5, 47.5), Vector2(17.5, 48.0), Vector2(18.8, 48.5),
        Vector2(19.5, 48.4), Vector2(20.5, 48.5), Vector2(21.5, 48.3), Vector2(22.1, 48.1),
        Vector2(22.4, 47.7), Vector2(22.2, 47.0), Vector2(21.2, 46.2), Vector2(20.0, 46.0),
        Vector2(18.8, 45.9), Vector2(17.5, 45.7), Vector2(16.5, 46.2), Vector2(16.1, 46.6),
        Vector2(16.1, 47.0),
      ],
    ),
    CountryShape(
      code: 'BG',
      name: 'Bulgaria',
      capital: 'Sofia',
      points: [
        Vector2(22.4, 44.0), Vector2(23.0, 44.0), Vector2(24.5, 43.7), Vector2(25.5, 43.7),
        Vector2(27.0, 44.0), Vector2(28.0, 43.8), Vector2(28.6, 43.0), Vector2(28.5, 42.5),
        Vector2(27.5, 42.0), Vector2(26.3, 41.5), Vector2(25.5, 41.3), Vector2(24.0, 41.6),
        Vector2(23.0, 41.5), Vector2(22.4, 42.0), Vector2(22.0, 42.8), Vector2(22.4, 44.0),
      ],
    ),
    CountryShape(
      code: 'HR',
      name: 'Croatia',
      capital: 'Zagreb',
      points: [
        Vector2(13.5, 45.5), Vector2(14.0, 45.5), Vector2(14.4, 45.2), Vector2(15.2, 45.3),
        Vector2(15.8, 46.1), Vector2(16.6, 46.4), Vector2(17.5, 45.8), Vector2(18.5, 45.2),
        Vector2(19.0, 45.0), Vector2(18.5, 44.5), Vector2(17.6, 43.5), Vector2(17.0, 43.0),
        Vector2(16.3, 43.0), Vector2(15.5, 43.5), Vector2(14.8, 44.0), Vector2(14.0, 44.5),
        Vector2(13.5, 45.5),
      ],
    ),
    CountryShape(
      code: 'RS',
      name: 'Serbia',
      capital: 'Belgrade',
      points: [
        Vector2(19.0, 45.0), Vector2(19.8, 46.2), Vector2(20.3, 46.3), Vector2(21.4, 45.5),
        Vector2(22.4, 44.6), Vector2(22.7, 44.2), Vector2(22.5, 43.6), Vector2(22.0, 43.2),
        Vector2(21.5, 42.8), Vector2(20.7, 42.7), Vector2(20.2, 43.0), Vector2(19.5, 43.5),
        Vector2(19.2, 44.0), Vector2(19.0, 44.5), Vector2(19.0, 45.0),
      ],
    ),

    // =========================================================
    // AFRICA
    // =========================================================
    CountryShape(
      code: 'EG',
      name: 'Egypt',
      capital: 'Cairo',
      points: [
        Vector2(25.0, 31.5), Vector2(29.0, 31.5), Vector2(32.5, 31.2), Vector2(34.2, 31.2),
        Vector2(34.9, 29.5), Vector2(34.3, 27.7), Vector2(33.2, 25.5), Vector2(33.8, 24.0),
        Vector2(35.8, 23.8), Vector2(36.9, 22.0), Vector2(33.0, 22.0), Vector2(31.4, 22.0),
        Vector2(25.0, 22.0), Vector2(25.0, 25.5), Vector2(25.0, 28.0), Vector2(25.0, 31.5),
      ],
    ),
    CountryShape(
      code: 'ZA',
      name: 'South Africa',
      capital: 'Pretoria',
      points: [
        Vector2(17.0, -28.6), Vector2(17.6, -24.3), Vector2(20.0, -24.8), Vector2(22.0, -23.0),
        Vector2(25.3, -22.5), Vector2(27.6, -23.6), Vector2(29.4, -22.1), Vector2(31.2, -22.4),
        Vector2(32.0, -23.5), Vector2(32.8, -25.8), Vector2(32.0, -26.8), Vector2(30.8, -29.8),
        Vector2(29.0, -32.0), Vector2(27.6, -33.5), Vector2(25.5, -34.0), Vector2(22.5, -34.1),
        Vector2(20.0, -33.8), Vector2(18.3, -32.5), Vector2(17.9, -30.5), Vector2(17.0, -28.6),
      ],
    ),
    CountryShape(
      code: 'NG',
      name: 'Nigeria',
      capital: 'Abuja',
      points: [
        Vector2(2.7, 6.4), Vector2(3.5, 6.4), Vector2(5.0, 6.0), Vector2(7.5, 5.5),
        Vector2(9.5, 6.0), Vector2(12.0, 7.5), Vector2(13.5, 8.5), Vector2(14.5, 10.0),
        Vector2(14.0, 11.5), Vector2(13.5, 13.0), Vector2(12.0, 13.5), Vector2(10.0, 13.5),
        Vector2(7.5, 13.0), Vector2(5.0, 12.0), Vector2(3.5, 11.0), Vector2(3.0, 9.0),
        Vector2(2.7, 6.4),
      ],
    ),
    CountryShape(
      code: 'KE',
      name: 'Kenya',
      capital: 'Nairobi',
      points: [
        Vector2(34.0, 4.5), Vector2(35.5, 5.0), Vector2(37.5, 3.5), Vector2(39.0, 3.5),
        Vector2(41.0, 2.0), Vector2(41.5, 0.0), Vector2(41.5, -2.5), Vector2(40.0, -4.5),
        Vector2(38.0, -4.5), Vector2(36.0, -4.0), Vector2(34.0, -1.5), Vector2(34.0, 0.0),
        Vector2(34.0, 1.5), Vector2(33.8, 3.5), Vector2(34.0, 4.5),
      ],
    ),
    CountryShape(
      code: 'ET',
      name: 'Ethiopia',
      capital: 'Addis Ababa',
      points: [
        Vector2(33.0, 8.0), Vector2(34.5, 8.5), Vector2(36.0, 11.5), Vector2(37.5, 13.5),
        Vector2(39.5, 14.5), Vector2(40.5, 14.5), Vector2(42.0, 12.5), Vector2(43.5, 11.0),
        Vector2(46.0, 8.0), Vector2(47.5, 7.5), Vector2(46.0, 5.0), Vector2(44.0, 4.5),
        Vector2(42.0, 4.0), Vector2(40.0, 4.0), Vector2(38.0, 3.5), Vector2(36.0, 5.0),
        Vector2(34.5, 6.5), Vector2(33.0, 8.0),
      ],
    ),
    CountryShape(
      code: 'GH',
      name: 'Ghana',
      capital: 'Accra',
      points: [
        Vector2(-3.2, 4.7), Vector2(-2.9, 5.1), Vector2(-1.2, 5.0), Vector2(-0.5, 5.4),
        Vector2(0.0, 5.6), Vector2(0.9, 6.0), Vector2(1.2, 6.0), Vector2(1.2, 7.0),
        Vector2(1.1, 8.0), Vector2(0.9, 9.2), Vector2(0.5, 10.0), Vector2(-0.5, 10.7),
        Vector2(-1.2, 11.0), Vector2(-2.0, 11.0), Vector2(-2.8, 10.4), Vector2(-2.9, 9.5),
        Vector2(-3.1, 7.0), Vector2(-3.2, 4.7),
      ],
    ),
    CountryShape(
      code: 'TZ',
      name: 'Tanzania',
      capital: 'Dodoma',
      points: [
        Vector2(29.3, -1.0), Vector2(30.5, -1.0), Vector2(33.0, -1.0), Vector2(34.5, -1.5),
        Vector2(37.0, -3.0), Vector2(39.5, -5.0), Vector2(40.0, -7.5), Vector2(40.0, -10.0),
        Vector2(38.5, -11.0), Vector2(36.0, -11.0), Vector2(33.5, -10.5), Vector2(31.0, -10.0),
        Vector2(30.0, -8.5), Vector2(29.5, -6.0), Vector2(29.3, -3.5), Vector2(29.3, -1.0),
      ],
    ),
    CountryShape(
      code: 'MA',
      name: 'Morocco',
      capital: 'Rabat',
      points: [
        Vector2(-13.2, 35.8), Vector2(-11.0, 35.8), Vector2(-7.5, 35.8), Vector2(-5.0, 35.8),
        Vector2(-2.0, 35.3), Vector2(-1.0, 34.8), Vector2(-1.2, 32.5), Vector2(-1.5, 30.5),
        Vector2(-3.0, 29.0), Vector2(-5.5, 28.5), Vector2(-8.5, 28.0), Vector2(-12.0, 28.5),
        Vector2(-13.0, 29.0), Vector2(-13.2, 30.0), Vector2(-13.0, 32.0), Vector2(-13.2, 35.8),
      ],
    ),
    CountryShape(
      code: 'DZ',
      name: 'Algeria',
      capital: 'Algiers',
      points: [
        Vector2(-1.0, 35.0), Vector2(1.0, 36.0), Vector2(3.0, 36.8), Vector2(5.0, 37.0),
        Vector2(7.0, 37.0), Vector2(9.0, 37.0), Vector2(9.5, 35.0), Vector2(9.5, 32.0),
        Vector2(9.0, 28.0), Vector2(8.5, 24.0), Vector2(6.0, 21.0), Vector2(3.5, 19.5),
        Vector2(1.0, 19.5), Vector2(-1.5, 21.5), Vector2(-3.0, 25.0), Vector2(-3.0, 28.5),
        Vector2(-2.0, 30.5), Vector2(-1.5, 33.0), Vector2(-1.0, 35.0),
      ],
    ),
    CountryShape(
      code: 'TN',
      name: 'Tunisia',
      capital: 'Tunis',
      points: [
        Vector2(8.0, 37.0), Vector2(8.6, 37.1), Vector2(9.2, 37.3), Vector2(9.8, 37.0),
        Vector2(10.2, 37.2), Vector2(10.8, 36.8), Vector2(11.1, 36.5), Vector2(10.8, 35.5),
        Vector2(10.5, 34.5), Vector2(10.1, 34.2), Vector2(9.5, 33.0), Vector2(8.5, 32.6),
        Vector2(7.5, 33.2), Vector2(7.7, 34.0), Vector2(8.0, 35.0), Vector2(8.0, 37.0),
      ],
    ),
    CountryShape(
      code: 'LY',
      name: 'Libya',
      capital: 'Tripoli',
      points: [
        Vector2(9.5, 33.0), Vector2(11.0, 33.5), Vector2(13.5, 33.0), Vector2(16.0, 32.5),
        Vector2(19.0, 32.0), Vector2(22.0, 32.5), Vector2(25.0, 32.0), Vector2(25.0, 29.0),
        Vector2(25.0, 26.0), Vector2(24.0, 23.5), Vector2(22.0, 21.0), Vector2(18.5, 21.0),
        Vector2(15.0, 23.0), Vector2(12.0, 24.0), Vector2(10.0, 26.0), Vector2(9.5, 29.0),
        Vector2(9.5, 33.0),
      ],
    ),
    CountryShape(
      code: 'SD',
      name: 'Sudan',
      capital: 'Khartoum',
      points: [
        Vector2(22.0, 22.0), Vector2(25.0, 22.0), Vector2(29.0, 22.0), Vector2(33.0, 22.0),
        Vector2(36.0, 22.0), Vector2(37.5, 20.0), Vector2(38.5, 18.0), Vector2(37.5, 15.5),
        Vector2(36.0, 13.0), Vector2(34.0, 10.5), Vector2(32.0, 9.5), Vector2(29.0, 9.5),
        Vector2(26.5, 10.0), Vector2(24.0, 10.5), Vector2(23.5, 12.5), Vector2(22.5, 15.5),
        Vector2(22.0, 18.0), Vector2(22.0, 22.0),
      ],
    ),
    CountryShape(
      code: 'CD',
      name: 'Democratic Republic of the Congo',
      capital: 'Kinshasa',
      points: [
        Vector2(18.0, 5.0), Vector2(20.0, 5.0), Vector2(23.5, 5.0), Vector2(27.0, 5.0),
        Vector2(29.5, 4.0), Vector2(30.5, 2.5), Vector2(30.5, 0.0), Vector2(30.0, -1.0),
        Vector2(29.0, -3.0), Vector2(28.5, -5.5), Vector2(27.0, -8.0), Vector2(26.0, -10.5),
        Vector2(24.0, -11.0), Vector2(22.0, -10.5), Vector2(20.0, -8.0), Vector2(17.5, -5.5),
        Vector2(15.0, -5.0), Vector2(13.5, -4.5), Vector2(12.5, -2.0), Vector2(14.0, 0.5),
        Vector2(16.0, 3.0), Vector2(18.0, 5.0),
      ],
    ),
    CountryShape(
      code: 'AO',
      name: 'Angola',
      capital: 'Luanda',
      points: [
        Vector2(12.0, -4.5), Vector2(13.0, -5.0), Vector2(15.0, -5.0), Vector2(17.5, -5.5),
        Vector2(20.0, -8.0), Vector2(22.0, -10.5), Vector2(24.0, -12.5), Vector2(24.0, -14.0),
        Vector2(23.5, -16.5), Vector2(22.0, -17.5), Vector2(19.5, -17.8), Vector2(16.0, -17.5),
        Vector2(13.5, -16.5), Vector2(12.0, -15.0), Vector2(12.0, -11.0), Vector2(12.0, -7.5),
        Vector2(12.0, -4.5),
      ],
    ),
    CountryShape(
      code: 'MZ',
      name: 'Mozambique',
      capital: 'Maputo',
      points: [
        Vector2(34.0, -11.0), Vector2(36.5, -11.5), Vector2(40.0, -11.5), Vector2(40.5, -14.0),
        Vector2(40.5, -17.0), Vector2(38.0, -20.0), Vector2(36.5, -22.5), Vector2(35.5, -24.0),
        Vector2(34.0, -25.5), Vector2(32.5, -26.0), Vector2(31.5, -25.0), Vector2(31.0, -22.5),
        Vector2(30.5, -18.0), Vector2(30.5, -15.5), Vector2(31.0, -13.0), Vector2(33.0, -11.5),
        Vector2(34.0, -11.0),
      ],
    ),
    CountryShape(
      code: 'MG',
      name: 'Madagascar',
      capital: 'Antananarivo',
      points: [
        Vector2(44.5, -12.0), Vector2(46.0, -12.5), Vector2(48.0, -14.0), Vector2(49.5, -15.5),
        Vector2(50.0, -17.5), Vector2(50.0, -19.5), Vector2(49.5, -21.5), Vector2(48.0, -24.0),
        Vector2(46.0, -25.5), Vector2(44.5, -25.0), Vector2(43.5, -22.5), Vector2(43.5, -20.0),
        Vector2(44.0, -17.5), Vector2(43.5, -15.5), Vector2(44.0, -13.5), Vector2(44.5, -12.0),
      ],
    ),
    CountryShape(
      code: 'CI',
      name: "Cote d'Ivoire",
      capital: 'Yamoussoukro',
      points: [
        Vector2(-8.5, 5.0), Vector2(-7.5, 4.5), Vector2(-5.5, 5.0), Vector2(-3.5, 5.0),
        Vector2(-3.0, 5.5), Vector2(-3.0, 7.0), Vector2(-3.5, 8.5), Vector2(-4.5, 10.0),
        Vector2(-5.5, 10.5), Vector2(-7.0, 10.5), Vector2(-8.0, 10.0), Vector2(-8.5, 8.5),
        Vector2(-8.5, 7.0), Vector2(-7.5, 5.5), Vector2(-8.5, 5.0),
      ],
    ),
    CountryShape(
      code: 'SN',
      name: 'Senegal',
      capital: 'Dakar',
      points: [
        Vector2(-17.5, 12.5), Vector2(-16.5, 12.5), Vector2(-16.0, 13.0), Vector2(-16.5, 14.5),
        Vector2(-16.5, 16.0), Vector2(-15.0, 16.5), Vector2(-13.5, 16.5), Vector2(-12.5, 15.5),
        Vector2(-12.0, 14.5), Vector2(-12.0, 13.0), Vector2(-12.0, 12.5), Vector2(-13.5, 12.0),
        Vector2(-15.0, 11.5), Vector2(-16.0, 12.0), Vector2(-17.0, 12.5), Vector2(-17.5, 12.5),
      ],
    ),
    CountryShape(
      code: 'CM',
      name: 'Cameroon',
      capital: 'Yaounde',
      points: [
        Vector2(8.5, 4.5), Vector2(9.5, 4.0), Vector2(11.0, 3.5), Vector2(13.0, 4.0),
        Vector2(14.0, 5.5), Vector2(14.5, 7.0), Vector2(15.0, 8.5), Vector2(15.5, 10.0),
        Vector2(15.0, 11.5), Vector2(14.5, 12.5), Vector2(13.5, 13.0), Vector2(12.5, 12.0),
        Vector2(11.5, 10.5), Vector2(10.5, 9.0), Vector2(9.5, 7.0), Vector2(9.0, 5.5),
        Vector2(8.5, 4.5),
      ],
    ),
    CountryShape(
      code: 'UG',
      name: 'Uganda',
      capital: 'Kampala',
      points: [
        Vector2(29.6, 4.4), Vector2(30.0, 3.5), Vector2(30.5, 3.8), Vector2(30.8, 3.5),
        Vector2(31.2, 3.8), Vector2(31.9, 3.8), Vector2(32.7, 3.8), Vector2(33.9, 3.8),
        Vector2(34.0, 4.2), Vector2(34.6, 3.0), Vector2(34.7, 1.2), Vector2(34.0, 0.0),
        Vector2(33.9, -1.0), Vector2(31.9, -1.0), Vector2(30.8, -1.0), Vector2(29.9, -0.6),
        Vector2(29.6, 0.5), Vector2(29.6, 4.4),
      ],
    ),
    CountryShape(
      code: 'ZW',
      name: 'Zimbabwe',
      capital: 'Harare',
      points: [
        Vector2(25.0, -15.5), Vector2(27.0, -15.0), Vector2(29.5, -15.5), Vector2(31.0, -16.0),
        Vector2(32.5, -18.5), Vector2(33.0, -20.5), Vector2(33.0, -22.0), Vector2(30.5, -22.0),
        Vector2(28.5, -22.0), Vector2(26.5, -22.0), Vector2(25.5, -21.5), Vector2(25.0, -19.5),
        Vector2(25.0, -17.5), Vector2(25.0, -15.5),
      ],
    ),
    CountryShape(
      code: 'NA',
      name: 'Namibia',
      capital: 'Windhoek',
      points: [
        Vector2(11.7, -17.0), Vector2(13.5, -17.0), Vector2(17.0, -17.0), Vector2(20.0, -18.0),
        Vector2(21.0, -20.0), Vector2(21.0, -22.5), Vector2(20.0, -25.0), Vector2(20.0, -28.0),
        Vector2(18.5, -29.0), Vector2(17.0, -29.0), Vector2(15.5, -28.0), Vector2(14.0, -26.0),
        Vector2(12.5, -23.0), Vector2(12.0, -20.0), Vector2(11.7, -17.0),
      ],
    ),

    // =========================================================
    // ASIA
    // =========================================================
    CountryShape(
      code: 'CN',
      name: 'China',
      capital: 'Beijing',
      points: [
        Vector2(73.5, 39.5), Vector2(75.9, 40.0), Vector2(78.5, 41.0), Vector2(80.2, 42.0),
        Vector2(82.0, 42.9), Vector2(86.0, 44.0), Vector2(90.0, 45.5), Vector2(94.0, 46.5),
        Vector2(97.4, 42.7), Vector2(100.0, 42.6), Vector2(103.0, 41.9), Vector2(106.0, 42.1),
        Vector2(109.5, 42.5), Vector2(112.0, 42.8), Vector2(116.0, 42.5), Vector2(119.7, 42.0),
        Vector2(121.0, 42.4), Vector2(123.5, 42.9), Vector2(125.7, 43.2), Vector2(127.3, 41.5),
        Vector2(128.0, 41.0), Vector2(128.2, 38.4), Vector2(127.0, 36.7), Vector2(124.9, 33.0),
        Vector2(122.0, 30.5), Vector2(120.7, 28.0), Vector2(119.7, 25.5), Vector2(118.0, 24.5),
        Vector2(116.5, 23.4), Vector2(114.3, 22.5), Vector2(111.5, 21.5), Vector2(109.0, 21.5),
        Vector2(106.5, 21.9), Vector2(104.5, 22.8), Vector2(102.7, 22.4), Vector2(101.5, 22.3),
        Vector2(99.9, 22.0), Vector2(99.0, 23.0), Vector2(97.7, 24.0), Vector2(97.4, 27.5),
        Vector2(98.7, 28.2), Vector2(98.7, 29.5), Vector2(97.3, 29.5), Vector2(96.3, 29.4),
        Vector2(95.2, 29.0), Vector2(94.2, 29.3), Vector2(92.1, 27.7), Vector2(91.7, 27.7),
        Vector2(88.8, 27.9), Vector2(88.0, 27.7), Vector2(86.9, 28.0), Vector2(85.8, 28.3),
        Vector2(84.2, 28.9), Vector2(83.2, 29.6), Vector2(82.2, 30.1), Vector2(81.1, 30.2),
        Vector2(79.8, 30.9), Vector2(79.0, 32.5), Vector2(78.7, 34.3), Vector2(78.0, 35.5),
        Vector2(76.0, 35.8), Vector2(75.9, 36.0), Vector2(73.8, 36.7), Vector2(73.5, 39.5),
      ],
    ),
    CountryShape(
      code: 'IN',
      name: 'India',
      capital: 'New Delhi',
      points: [
        // Pakistan border / NW
        Vector2(68.5, 23.5), Vector2(70.0, 22.0), Vector2(72.0, 21.5),
        // Gujarat coast
        Vector2(72.5, 20.0), Vector2(72.0, 18.5), Vector2(73.0, 16.0),
        // Goa / Karnataka coast
        Vector2(74.0, 15.5), Vector2(74.8, 14.5), Vector2(75.0, 12.5),
        // Kerala / tip
        Vector2(76.3, 10.0), Vector2(77.5, 8.1), Vector2(78.0, 8.5),
        // Tamil Nadu / east coast
        Vector2(79.5, 10.0), Vector2(80.0, 11.5), Vector2(80.3, 13.0),
        // Andhra Pradesh / Odisha
        Vector2(81.5, 16.0), Vector2(83.0, 17.5), Vector2(84.5, 18.5),
        Vector2(86.0, 20.0), Vector2(87.0, 21.5),
        // Bengal / Bangladesh border
        Vector2(88.0, 22.0), Vector2(89.0, 22.5), Vector2(92.0, 26.0),
        // NE India / northern border
        Vector2(88.0, 28.0), Vector2(84.0, 28.5), Vector2(80.5, 30.5),
        Vector2(76.0, 32.5), Vector2(73.8, 34.5),
        // Kashmir / Pakistan border
        Vector2(72.0, 34.0), Vector2(68.5, 30.0), Vector2(68.5, 23.5),
      ],
    ),
    CountryShape(
      code: 'JP',
      name: 'Japan',
      capital: 'Tokyo',
      points: [
        // Kyushu
        Vector2(130.0, 31.5), Vector2(131.0, 33.0),
        // Shikoku gap / Seto Inland Sea area
        Vector2(132.5, 34.0), Vector2(134.5, 34.5),
        // Honshu south coast
        Vector2(135.5, 34.8), Vector2(137.0, 34.5), Vector2(138.5, 35.0),
        // Tokyo Bay area
        Vector2(140.0, 35.7), Vector2(140.5, 37.0),
        // Honshu north coast
        Vector2(140.0, 39.5), Vector2(140.2, 40.5),
        // Hokkaido
        Vector2(141.5, 41.5), Vector2(141.0, 43.0),
        Vector2(142.5, 44.5), Vector2(145.0, 43.5),
        Vector2(144.5, 42.0), Vector2(143.5, 41.5),
        // Back down east coast
        Vector2(142.0, 39.0), Vector2(141.0, 37.5),
        Vector2(140.5, 36.5), Vector2(139.0, 35.5),
        // South back to Kyushu
        Vector2(136.0, 33.5), Vector2(133.0, 32.0), Vector2(130.0, 31.5),
      ],
    ),
    CountryShape(
      code: 'RU',
      name: 'Russia',
      capital: 'Moscow',
      points: [
        Vector2(27.0, 69.0), Vector2(30.0, 69.8), Vector2(35.0, 69.5), Vector2(40.0, 67.5),
        Vector2(50.0, 67.7), Vector2(60.0, 68.5), Vector2(70.0, 68.0), Vector2(80.0, 72.0),
        Vector2(90.0, 72.0), Vector2(100.0, 75.0), Vector2(110.0, 74.0), Vector2(120.0, 72.5),
        Vector2(130.0, 71.0), Vector2(140.0, 70.0), Vector2(150.0, 69.0), Vector2(160.0, 65.0),
        Vector2(169.0, 64.0), Vector2(180.0, 65.0), Vector2(180.0, 64.5), Vector2(175.0, 62.0),
        Vector2(170.0, 59.0), Vector2(165.0, 55.0), Vector2(160.0, 52.5), Vector2(155.0, 50.0),
        Vector2(145.0, 48.5), Vector2(135.0, 48.0), Vector2(130.0, 42.8), Vector2(125.0, 43.0),
        Vector2(120.0, 50.0), Vector2(110.0, 50.0), Vector2(100.0, 51.5), Vector2(90.0, 53.0),
        Vector2(80.0, 55.0), Vector2(70.0, 55.0), Vector2(60.0, 55.0), Vector2(50.0, 55.0),
        Vector2(40.0, 52.5), Vector2(27.0, 69.0),
      ],
    ),
    CountryShape(
      code: 'KR',
      name: 'South Korea',
      capital: 'Seoul',
      points: [
        Vector2(126.0, 37.6), Vector2(126.5, 37.8), Vector2(127.0, 38.0), Vector2(127.5, 38.5),
        Vector2(128.0, 38.6), Vector2(128.7, 38.3), Vector2(129.5, 37.5), Vector2(129.5, 36.8),
        Vector2(129.4, 36.0), Vector2(129.2, 35.5), Vector2(128.8, 35.0), Vector2(128.2, 34.8),
        Vector2(127.5, 34.7), Vector2(126.8, 34.4), Vector2(126.5, 34.3), Vector2(126.2, 34.8),
        Vector2(126.0, 35.5), Vector2(126.1, 36.3), Vector2(126.3, 37.0), Vector2(126.0, 37.6),
      ],
    ),
    CountryShape(
      code: 'TH',
      name: 'Thailand',
      capital: 'Bangkok',
      points: [
        Vector2(97.5, 20.0), Vector2(99.0, 20.5), Vector2(100.5, 20.0), Vector2(101.5, 19.5),
        Vector2(103.0, 18.5), Vector2(105.0, 16.0), Vector2(105.0, 14.5), Vector2(103.5, 12.5),
        Vector2(102.0, 11.0), Vector2(100.5, 9.5), Vector2(99.5, 7.5), Vector2(99.0, 7.0),
        Vector2(98.5, 8.0), Vector2(98.3, 10.0), Vector2(99.0, 12.5), Vector2(98.5, 14.0),
        Vector2(97.5, 16.5), Vector2(97.5, 18.0), Vector2(97.5, 20.0),
      ],
    ),
    CountryShape(
      code: 'VN',
      name: 'Vietnam',
      capital: 'Hanoi',
      points: [
        Vector2(102.5, 22.5), Vector2(104.0, 22.5), Vector2(106.0, 22.0), Vector2(107.5, 21.0),
        Vector2(108.5, 18.5), Vector2(109.0, 16.0), Vector2(109.5, 14.0), Vector2(109.0, 12.5),
        Vector2(108.0, 11.0), Vector2(107.0, 10.0), Vector2(106.5, 8.5), Vector2(105.5, 9.5),
        Vector2(106.0, 11.0), Vector2(106.5, 13.0), Vector2(106.0, 15.5), Vector2(105.5, 18.0),
        Vector2(104.5, 20.5), Vector2(102.5, 22.5),
      ],
    ),
    CountryShape(
      code: 'ID',
      name: 'Indonesia',
      capital: 'Jakarta',
      points: [
        Vector2(95.0, 5.5), Vector2(97.5, 4.0), Vector2(99.5, 3.0), Vector2(102.0, 1.0),
        Vector2(104.0, -1.0), Vector2(105.5, -3.5), Vector2(106.0, -6.0), Vector2(108.0, -7.0),
        Vector2(110.0, -7.5), Vector2(112.5, -7.5), Vector2(115.0, -8.0), Vector2(117.5, -8.5),
        Vector2(120.0, -8.5), Vector2(123.0, -8.0), Vector2(126.0, -8.0), Vector2(129.0, -5.5),
        Vector2(132.0, -3.5), Vector2(136.0, -2.5), Vector2(140.7, -2.5), Vector2(141.0, -5.5),
        Vector2(141.0, -8.0), Vector2(137.0, -8.0), Vector2(131.0, -8.5), Vector2(124.0, -9.5),
        Vector2(116.0, -8.5), Vector2(110.0, -8.0), Vector2(105.0, -7.5), Vector2(102.0, -5.0),
        Vector2(99.5, -1.5), Vector2(96.5, 2.0), Vector2(95.0, 5.5),
      ],
    ),
    CountryShape(
      code: 'PH',
      name: 'Philippines',
      capital: 'Manila',
      points: [
        Vector2(117.0, 18.0), Vector2(118.0, 18.5), Vector2(119.5, 18.3), Vector2(121.0, 18.5),
        Vector2(122.0, 17.0), Vector2(123.5, 14.5), Vector2(124.0, 12.5), Vector2(125.5, 10.5),
        Vector2(126.5, 8.0), Vector2(126.0, 6.5), Vector2(124.5, 7.0), Vector2(123.0, 8.0),
        Vector2(121.5, 9.5), Vector2(120.0, 11.5), Vector2(119.5, 13.5), Vector2(118.5, 15.5),
        Vector2(117.0, 18.0),
      ],
    ),
    CountryShape(
      code: 'MY',
      name: 'Malaysia',
      capital: 'Kuala Lumpur',
      points: [
        Vector2(99.7, 6.4), Vector2(100.5, 6.0), Vector2(101.0, 5.5), Vector2(101.5, 4.5),
        Vector2(102.5, 3.5), Vector2(103.0, 2.5), Vector2(103.5, 1.5), Vector2(104.0, 1.4),
        Vector2(103.6, 1.3), Vector2(103.0, 1.5), Vector2(102.0, 2.0), Vector2(101.5, 3.0),
        Vector2(100.5, 4.5), Vector2(100.0, 5.5), Vector2(99.7, 6.4),
      ],
    ),
    CountryShape(
      code: 'PK',
      name: 'Pakistan',
      capital: 'Islamabad',
      points: [
        Vector2(61.0, 25.0), Vector2(62.5, 25.5), Vector2(65.0, 25.0), Vector2(67.0, 24.5),
        Vector2(68.5, 24.0), Vector2(70.0, 25.5), Vector2(71.0, 28.5), Vector2(72.5, 31.0),
        Vector2(74.0, 33.5), Vector2(75.5, 35.5), Vector2(76.0, 36.0), Vector2(75.0, 37.0),
        Vector2(73.0, 37.0), Vector2(71.0, 36.0), Vector2(69.5, 37.5), Vector2(67.0, 37.0),
        Vector2(64.5, 33.0), Vector2(62.0, 29.0), Vector2(61.0, 25.0),
      ],
    ),
    CountryShape(
      code: 'BD',
      name: 'Bangladesh',
      capital: 'Dhaka',
      points: [
        Vector2(88, 26), Vector2(89, 26), Vector2(91, 26),
        Vector2(92, 25), Vector2(92, 23), Vector2(91, 22),
        Vector2(89, 21), Vector2(88, 22), Vector2(88, 24),
        Vector2(88, 26),
      ],
    ),
    CountryShape(
      code: 'SA',
      name: 'Saudi Arabia',
      capital: 'Riyadh',
      points: [
        Vector2(36.5, 29.0), Vector2(37.5, 29.4), Vector2(38.5, 30.0), Vector2(40.0, 31.5),
        Vector2(42.0, 31.5), Vector2(44.5, 29.4), Vector2(47.0, 29.0), Vector2(50.0, 26.5),
        Vector2(51.0, 24.5), Vector2(55.5, 22.0), Vector2(55.0, 20.0), Vector2(52.0, 17.5),
        Vector2(48.0, 15.5), Vector2(45.0, 13.0), Vector2(43.5, 14.5), Vector2(42.0, 16.5),
        Vector2(41.0, 18.0), Vector2(39.5, 20.5), Vector2(37.5, 23.5), Vector2(36.5, 26.0),
        Vector2(36.5, 29.0),
      ],
    ),
    CountryShape(
      code: 'AE',
      name: 'United Arab Emirates',
      capital: 'Abu Dhabi',
      points: [
        Vector2(51.0, 24.5), Vector2(51.6, 25.0), Vector2(52.6, 25.2), Vector2(53.8, 25.7),
        Vector2(55.0, 26.0), Vector2(56.0, 26.0), Vector2(56.4, 25.5), Vector2(56.3, 24.5),
        Vector2(56.0, 24.0), Vector2(55.5, 23.0), Vector2(55.0, 22.5), Vector2(54.0, 22.8),
        Vector2(52.5, 23.0), Vector2(51.5, 23.5), Vector2(51.0, 24.0), Vector2(51.0, 24.5),
      ],
    ),
    CountryShape(
      code: 'IR',
      name: 'Iran',
      capital: 'Tehran',
      points: [
        Vector2(44.0, 39.5), Vector2(45.5, 39.5), Vector2(48.0, 39.5), Vector2(49.0, 38.0),
        Vector2(51.0, 38.5), Vector2(53.5, 37.5), Vector2(55.0, 37.0), Vector2(57.5, 37.5),
        Vector2(60.5, 36.0), Vector2(61.2, 35.0), Vector2(61.5, 31.5), Vector2(60.5, 29.5),
        Vector2(57.8, 27.0), Vector2(56.2, 26.0), Vector2(54.0, 26.5), Vector2(52.0, 27.5),
        Vector2(50.0, 29.0), Vector2(48.5, 30.5), Vector2(47.5, 32.0), Vector2(46.0, 34.0),
        Vector2(44.5, 36.5), Vector2(44.0, 39.5),
      ],
    ),
    CountryShape(
      code: 'IQ',
      name: 'Iraq',
      capital: 'Baghdad',
      points: [
        Vector2(38.8, 36.5), Vector2(40.0, 37.0), Vector2(42.0, 37.0), Vector2(44.5, 37.5),
        Vector2(46.0, 35.0), Vector2(47.5, 34.0), Vector2(48.5, 30.5), Vector2(48.0, 29.5),
        Vector2(46.5, 29.5), Vector2(45.5, 29.5), Vector2(44.0, 30.0), Vector2(42.0, 31.5),
        Vector2(40.0, 33.5), Vector2(39.0, 35.0), Vector2(38.8, 36.5),
      ],
    ),
    CountryShape(
      code: 'IL',
      name: 'Israel',
      capital: 'Jerusalem',
      points: [
        Vector2(34.3, 33.3), Vector2(34.6, 33.3), Vector2(35.6, 33.3), Vector2(35.8, 32.7),
        Vector2(35.5, 32.0), Vector2(35.5, 31.5), Vector2(35.4, 31.0), Vector2(35.0, 30.5),
        Vector2(34.9, 29.5), Vector2(34.5, 29.5), Vector2(34.3, 30.0), Vector2(34.3, 31.0),
        Vector2(34.3, 32.0), Vector2(34.3, 33.3),
      ],
    ),
    CountryShape(
      code: 'SG',
      name: 'Singapore',
      capital: 'Singapore',
      points: [
        Vector2(103.6, 1.5), Vector2(103.8, 1.5), Vector2(104, 1.4),
        Vector2(104, 1.2), Vector2(103.8, 1.15), Vector2(103.6, 1.2),
        Vector2(103.6, 1.5),
      ],
    ),
    CountryShape(
      code: 'KZ',
      name: 'Kazakhstan',
      capital: 'Astana',
      points: [
        Vector2(50.0, 41.5), Vector2(51.0, 42.0), Vector2(52.5, 41.8), Vector2(54.5, 42.5),
        Vector2(56.0, 45.0), Vector2(58.0, 46.0), Vector2(59.5, 47.5), Vector2(61.0, 50.0),
        Vector2(64.5, 51.5), Vector2(67.5, 53.0), Vector2(70.0, 54.0), Vector2(73.5, 53.5),
        Vector2(76.5, 54.0), Vector2(79.0, 52.0), Vector2(80.2, 50.8), Vector2(83.0, 47.0),
        Vector2(86.5, 48.0), Vector2(87.3, 45.0), Vector2(82.0, 42.0), Vector2(79.0, 42.5),
        Vector2(75.0, 40.0), Vector2(71.0, 39.5), Vector2(67.5, 40.0), Vector2(63.5, 43.0),
        Vector2(58.0, 43.5), Vector2(54.0, 42.0), Vector2(51.5, 40.5), Vector2(50.0, 41.5),
      ],
    ),

    // =========================================================
    // OCEANIA
    // =========================================================
    CountryShape(
      code: 'AU',
      name: 'Australia',
      capital: 'Canberra',
      points: [
        // WA north coast
        Vector2(114.0, -22.0), Vector2(117.0, -20.0), Vector2(121.0, -18.0),
        // NT / Top End
        Vector2(126.0, -14.5), Vector2(129.5, -15.0), Vector2(130.0, -12.5),
        Vector2(132.0, -11.5), Vector2(136.0, -12.0),
        // Gulf of Carpentaria
        Vector2(137.5, -16.0), Vector2(139.5, -17.5), Vector2(141.0, -12.5),
        // Cape York
        Vector2(142.5, -10.5), Vector2(145.5, -14.5),
        // Queensland coast
        Vector2(146.0, -19.0), Vector2(148.5, -20.5), Vector2(150.0, -23.0),
        Vector2(153.0, -27.5),
        // NSW / VIC
        Vector2(153.5, -28.5), Vector2(151.5, -33.5), Vector2(150.0, -37.0),
        // Bass Strait / Victoria
        Vector2(147.0, -38.5), Vector2(144.5, -38.0),
        // SA coast / Great Australian Bight
        Vector2(141.0, -38.0), Vector2(137.0, -36.0), Vector2(134.0, -33.5),
        Vector2(131.0, -32.0), Vector2(127.0, -34.0),
        // WA south coast
        Vector2(124.0, -34.5), Vector2(120.0, -34.0), Vector2(116.0, -32.0),
        Vector2(114.5, -28.0), Vector2(114.0, -22.0),
      ],
    ),
    CountryShape(
      code: 'NZ',
      name: 'New Zealand',
      capital: 'Wellington',
      points: [
        Vector2(166.5, -46.0), Vector2(167.5, -45.5), Vector2(169.0, -44.5), Vector2(170.5, -43.5),
        Vector2(172.0, -42.0), Vector2(173.0, -41.5), Vector2(174.0, -41.0), Vector2(175.5, -39.5),
        Vector2(177.0, -38.0), Vector2(178.0, -37.5), Vector2(177.5, -38.0), Vector2(176.0, -39.0),
        Vector2(175.0, -40.0), Vector2(174.5, -41.0), Vector2(173.0, -42.5), Vector2(171.0, -44.0),
        Vector2(169.5, -45.5), Vector2(168.0, -46.5), Vector2(166.5, -46.0),
      ],
    ),
    CountryShape(
      code: 'PG',
      name: 'Papua New Guinea',
      capital: 'Port Moresby',
      points: [
        Vector2(141, -3), Vector2(143, -3), Vector2(146, -4),
        Vector2(148, -5), Vector2(150, -6), Vector2(152, -6),
        Vector2(155, -6), Vector2(155, -8), Vector2(152, -9),
        Vector2(148, -8), Vector2(145, -7), Vector2(142, -8),
        Vector2(141, -7), Vector2(141, -5), Vector2(141, -3),
      ],
    ),
    CountryShape(
      code: 'FJ',
      name: 'Fiji',
      capital: 'Suva',
      points: [
        Vector2(177, -16), Vector2(178, -16), Vector2(179, -17),
        Vector2(180, -18), Vector2(179, -19), Vector2(178, -18.5),
        Vector2(177, -18), Vector2(177, -17), Vector2(177, -16),
      ],
    ),
  ];

  // Major cities for low-altitude view
  static final List<CityData> majorCities = [
    // =========================================================
    // NORTH AMERICA
    // =========================================================
    CityData(name: 'New York', countryCode: 'US', location: Vector2(-74, 40.7)),
    CityData(name: 'Los Angeles', countryCode: 'US', location: Vector2(-118.2, 34)),
    CityData(name: 'Chicago', countryCode: 'US', location: Vector2(-87.6, 41.9)),
    CityData(name: 'Washington D.C.', countryCode: 'US', location: Vector2(-77, 38.9), isCapital: true),
    CityData(name: 'Toronto', countryCode: 'CA', location: Vector2(-79.4, 43.7)),
    CityData(name: 'Ottawa', countryCode: 'CA', location: Vector2(-75.7, 45.4), isCapital: true),
    CityData(name: 'Mexico City', countryCode: 'MX', location: Vector2(-99.1, 19.4), isCapital: true),
    CityData(name: 'Havana', countryCode: 'CU', location: Vector2(-82.4, 23.1), isCapital: true),
    CityData(name: 'Santiago de Cuba', countryCode: 'CU', location: Vector2(-75.8, 20)),
    CityData(name: 'Guatemala City', countryCode: 'GT', location: Vector2(-90.5, 14.6), isCapital: true),
    CityData(name: 'Panama City', countryCode: 'PA', location: Vector2(-79.5, 9), isCapital: true),
    CityData(name: 'Colon', countryCode: 'PA', location: Vector2(-79.9, 9.4)),

    // =========================================================
    // SOUTH AMERICA
    // =========================================================
    CityData(name: 'Sao Paulo', countryCode: 'BR', location: Vector2(-46.6, -23.5)),
    CityData(name: 'Rio de Janeiro', countryCode: 'BR', location: Vector2(-43.2, -22.9)),
    CityData(name: 'Brasilia', countryCode: 'BR', location: Vector2(-47.9, -15.8), isCapital: true),
    CityData(name: 'Buenos Aires', countryCode: 'AR', location: Vector2(-58.4, -34.6), isCapital: true),
    CityData(name: 'Bogota', countryCode: 'CO', location: Vector2(-74.1, 4.6), isCapital: true),
    CityData(name: 'Medellin', countryCode: 'CO', location: Vector2(-75.6, 6.2)),
    CityData(name: 'Lima', countryCode: 'PE', location: Vector2(-77, -12.1), isCapital: true),
    CityData(name: 'Cusco', countryCode: 'PE', location: Vector2(-72, -13.5)),
    CityData(name: 'Santiago', countryCode: 'CL', location: Vector2(-70.7, -33.4), isCapital: true),
    CityData(name: 'Valparaiso', countryCode: 'CL', location: Vector2(-71.6, -33)),
    CityData(name: 'Caracas', countryCode: 'VE', location: Vector2(-66.9, 10.5), isCapital: true),
    CityData(name: 'Maracaibo', countryCode: 'VE', location: Vector2(-71.6, 10.6)),
    CityData(name: 'Quito', countryCode: 'EC', location: Vector2(-78.5, -0.2), isCapital: true),
    CityData(name: 'Guayaquil', countryCode: 'EC', location: Vector2(-79.9, -2.2)),
    CityData(name: 'Montevideo', countryCode: 'UY', location: Vector2(-56.2, -34.9), isCapital: true),
    CityData(name: 'Asuncion', countryCode: 'PY', location: Vector2(-57.6, -25.3), isCapital: true),
    CityData(name: 'Ciudad del Este', countryCode: 'PY', location: Vector2(-54.6, -25.5)),

    // =========================================================
    // EUROPE
    // =========================================================
    CityData(name: 'London', countryCode: 'GB', location: Vector2(-0.1, 51.5), isCapital: true),
    CityData(name: 'Paris', countryCode: 'FR', location: Vector2(2.3, 48.9), isCapital: true),
    CityData(name: 'Marseille', countryCode: 'FR', location: Vector2(5.4, 43.3)),
    CityData(name: 'Berlin', countryCode: 'DE', location: Vector2(13.4, 52.5), isCapital: true),
    CityData(name: 'Munich', countryCode: 'DE', location: Vector2(11.6, 48.1)),
    CityData(name: 'Rome', countryCode: 'IT', location: Vector2(12.5, 41.9), isCapital: true),
    CityData(name: 'Milan', countryCode: 'IT', location: Vector2(9.2, 45.5)),
    CityData(name: 'Madrid', countryCode: 'ES', location: Vector2(-3.7, 40.4), isCapital: true),
    CityData(name: 'Barcelona', countryCode: 'ES', location: Vector2(2.2, 41.4)),
    CityData(name: 'Lisbon', countryCode: 'PT', location: Vector2(-9.1, 38.7), isCapital: true),
    CityData(name: 'Porto', countryCode: 'PT', location: Vector2(-8.6, 41.2)),
    CityData(name: 'Amsterdam', countryCode: 'NL', location: Vector2(4.9, 52.4), isCapital: true),
    CityData(name: 'Rotterdam', countryCode: 'NL', location: Vector2(4.5, 51.9)),
    CityData(name: 'Brussels', countryCode: 'BE', location: Vector2(4.4, 50.8), isCapital: true),
    CityData(name: 'Antwerp', countryCode: 'BE', location: Vector2(4.4, 51.2)),
    CityData(name: 'Warsaw', countryCode: 'PL', location: Vector2(21, 52.2), isCapital: true),
    CityData(name: 'Krakow', countryCode: 'PL', location: Vector2(19.9, 50.1)),
    CityData(name: 'Prague', countryCode: 'CZ', location: Vector2(14.4, 50.1), isCapital: true),
    CityData(name: 'Brno', countryCode: 'CZ', location: Vector2(16.6, 49.2)),
    CityData(name: 'Vienna', countryCode: 'AT', location: Vector2(16.4, 48.2), isCapital: true),
    CityData(name: 'Salzburg', countryCode: 'AT', location: Vector2(13, 47.8)),
    CityData(name: 'Bern', countryCode: 'CH', location: Vector2(7.4, 46.9), isCapital: true),
    CityData(name: 'Zurich', countryCode: 'CH', location: Vector2(8.5, 47.4)),
    CityData(name: 'Stockholm', countryCode: 'SE', location: Vector2(18.1, 59.3), isCapital: true),
    CityData(name: 'Gothenburg', countryCode: 'SE', location: Vector2(12, 57.7)),
    CityData(name: 'Oslo', countryCode: 'NO', location: Vector2(10.8, 59.9), isCapital: true),
    CityData(name: 'Bergen', countryCode: 'NO', location: Vector2(5.3, 60.4)),
    CityData(name: 'Helsinki', countryCode: 'FI', location: Vector2(25, 60.2), isCapital: true),
    CityData(name: 'Tampere', countryCode: 'FI', location: Vector2(23.8, 61.5)),
    CityData(name: 'Copenhagen', countryCode: 'DK', location: Vector2(12.6, 55.7), isCapital: true),
    CityData(name: 'Aarhus', countryCode: 'DK', location: Vector2(10.2, 56.2)),
    CityData(name: 'Dublin', countryCode: 'IE', location: Vector2(-6.3, 53.3), isCapital: true),
    CityData(name: 'Cork', countryCode: 'IE', location: Vector2(-8.5, 51.9)),
    CityData(name: 'Athens', countryCode: 'GR', location: Vector2(23.7, 38), isCapital: true),
    CityData(name: 'Thessaloniki', countryCode: 'GR', location: Vector2(22.9, 40.6)),
    CityData(name: 'Ankara', countryCode: 'TR', location: Vector2(32.9, 39.9), isCapital: true),
    CityData(name: 'Istanbul', countryCode: 'TR', location: Vector2(29, 41)),
    CityData(name: 'Kyiv', countryCode: 'UA', location: Vector2(30.5, 50.5), isCapital: true),
    CityData(name: 'Kharkiv', countryCode: 'UA', location: Vector2(36.2, 50)),
    CityData(name: 'Bucharest', countryCode: 'RO', location: Vector2(26.1, 44.4), isCapital: true),
    CityData(name: 'Cluj-Napoca', countryCode: 'RO', location: Vector2(23.6, 46.8)),
    CityData(name: 'Budapest', countryCode: 'HU', location: Vector2(19.1, 47.5), isCapital: true),
    CityData(name: 'Debrecen', countryCode: 'HU', location: Vector2(21.6, 47.5)),
    CityData(name: 'Sofia', countryCode: 'BG', location: Vector2(23.3, 42.7), isCapital: true),
    CityData(name: 'Plovdiv', countryCode: 'BG', location: Vector2(24.7, 42.1)),
    CityData(name: 'Zagreb', countryCode: 'HR', location: Vector2(16, 45.8), isCapital: true),
    CityData(name: 'Split', countryCode: 'HR', location: Vector2(16.4, 43.5)),
    CityData(name: 'Belgrade', countryCode: 'RS', location: Vector2(20.5, 44.8), isCapital: true),
    CityData(name: 'Novi Sad', countryCode: 'RS', location: Vector2(19.8, 45.3)),
    CityData(name: 'Moscow', countryCode: 'RU', location: Vector2(37.6, 55.8), isCapital: true),
    CityData(name: 'Saint Petersburg', countryCode: 'RU', location: Vector2(30.3, 59.9)),

    // =========================================================
    // AFRICA
    // =========================================================
    CityData(name: 'Cairo', countryCode: 'EG', location: Vector2(31.2, 30), isCapital: true),
    CityData(name: 'Alexandria', countryCode: 'EG', location: Vector2(29.9, 31.2)),
    CityData(name: 'Cape Town', countryCode: 'ZA', location: Vector2(18.4, -33.9)),
    CityData(name: 'Johannesburg', countryCode: 'ZA', location: Vector2(28, -26.2)),
    CityData(name: 'Pretoria', countryCode: 'ZA', location: Vector2(28.2, -25.7), isCapital: true),
    CityData(name: 'Abuja', countryCode: 'NG', location: Vector2(7.5, 9.1), isCapital: true),
    CityData(name: 'Lagos', countryCode: 'NG', location: Vector2(3.4, 6.5)),
    CityData(name: 'Nairobi', countryCode: 'KE', location: Vector2(36.8, -1.3), isCapital: true),
    CityData(name: 'Mombasa', countryCode: 'KE', location: Vector2(39.7, -4)),
    CityData(name: 'Addis Ababa', countryCode: 'ET', location: Vector2(38.7, 9), isCapital: true),
    CityData(name: 'Dire Dawa', countryCode: 'ET', location: Vector2(41.9, 9.6)),
    CityData(name: 'Accra', countryCode: 'GH', location: Vector2(-0.2, 5.6), isCapital: true),
    CityData(name: 'Kumasi', countryCode: 'GH', location: Vector2(-1.6, 6.7)),
    CityData(name: 'Dodoma', countryCode: 'TZ', location: Vector2(35.7, -6.2), isCapital: true),
    CityData(name: 'Dar es Salaam', countryCode: 'TZ', location: Vector2(39.3, -6.8)),
    CityData(name: 'Rabat', countryCode: 'MA', location: Vector2(-6.8, 34), isCapital: true),
    CityData(name: 'Casablanca', countryCode: 'MA', location: Vector2(-7.6, 33.6)),
    CityData(name: 'Algiers', countryCode: 'DZ', location: Vector2(3.1, 36.8), isCapital: true),
    CityData(name: 'Oran', countryCode: 'DZ', location: Vector2(-0.6, 35.7)),
    CityData(name: 'Tunis', countryCode: 'TN', location: Vector2(10.2, 36.8), isCapital: true),
    CityData(name: 'Sfax', countryCode: 'TN', location: Vector2(10.8, 34.7)),
    CityData(name: 'Tripoli', countryCode: 'LY', location: Vector2(13.2, 32.9), isCapital: true),
    CityData(name: 'Benghazi', countryCode: 'LY', location: Vector2(20.1, 32.1)),
    CityData(name: 'Khartoum', countryCode: 'SD', location: Vector2(32.5, 15.6), isCapital: true),
    CityData(name: 'Port Sudan', countryCode: 'SD', location: Vector2(37.2, 19.6)),
    CityData(name: 'Kinshasa', countryCode: 'CD', location: Vector2(15.3, -4.3), isCapital: true),
    CityData(name: 'Lubumbashi', countryCode: 'CD', location: Vector2(27.5, -11.7)),
    CityData(name: 'Luanda', countryCode: 'AO', location: Vector2(13.2, -8.8), isCapital: true),
    CityData(name: 'Huambo', countryCode: 'AO', location: Vector2(15.7, -12.8)),
    CityData(name: 'Maputo', countryCode: 'MZ', location: Vector2(32.6, -25.9), isCapital: true),
    CityData(name: 'Beira', countryCode: 'MZ', location: Vector2(34.9, -19.8)),
    CityData(name: 'Antananarivo', countryCode: 'MG', location: Vector2(47.5, -18.9), isCapital: true),
    CityData(name: 'Toamasina', countryCode: 'MG', location: Vector2(49.4, -18.2)),
    CityData(name: 'Yamoussoukro', countryCode: 'CI', location: Vector2(-5.3, 6.8), isCapital: true),
    CityData(name: 'Abidjan', countryCode: 'CI', location: Vector2(-4, 5.3)),
    CityData(name: 'Dakar', countryCode: 'SN', location: Vector2(-17.4, 14.7), isCapital: true),
    CityData(name: 'Saint-Louis', countryCode: 'SN', location: Vector2(-16.5, 16)),
    CityData(name: 'Yaounde', countryCode: 'CM', location: Vector2(11.5, 3.9), isCapital: true),
    CityData(name: 'Douala', countryCode: 'CM', location: Vector2(9.7, 4)),
    CityData(name: 'Kampala', countryCode: 'UG', location: Vector2(32.6, 0.3), isCapital: true),
    CityData(name: 'Gulu', countryCode: 'UG', location: Vector2(32.3, 2.8)),
    CityData(name: 'Harare', countryCode: 'ZW', location: Vector2(31, -17.8), isCapital: true),
    CityData(name: 'Bulawayo', countryCode: 'ZW', location: Vector2(28.6, -20.1)),
    CityData(name: 'Windhoek', countryCode: 'NA', location: Vector2(17.1, -22.6), isCapital: true),
    CityData(name: 'Walvis Bay', countryCode: 'NA', location: Vector2(14.5, -22.9)),

    // =========================================================
    // ASIA
    // =========================================================
    CityData(name: 'Beijing', countryCode: 'CN', location: Vector2(116.4, 39.9), isCapital: true),
    CityData(name: 'Shanghai', countryCode: 'CN', location: Vector2(121.5, 31.2)),
    CityData(name: 'Tokyo', countryCode: 'JP', location: Vector2(139.7, 35.7), isCapital: true),
    CityData(name: 'Osaka', countryCode: 'JP', location: Vector2(135.5, 34.7)),
    CityData(name: 'New Delhi', countryCode: 'IN', location: Vector2(77.2, 28.6), isCapital: true),
    CityData(name: 'Mumbai', countryCode: 'IN', location: Vector2(72.9, 19.1)),
    CityData(name: 'Seoul', countryCode: 'KR', location: Vector2(127, 37.6), isCapital: true),
    CityData(name: 'Busan', countryCode: 'KR', location: Vector2(129, 35.2)),
    CityData(name: 'Bangkok', countryCode: 'TH', location: Vector2(100.5, 13.8), isCapital: true),
    CityData(name: 'Chiang Mai', countryCode: 'TH', location: Vector2(99, 18.8)),
    CityData(name: 'Hanoi', countryCode: 'VN', location: Vector2(105.8, 21), isCapital: true),
    CityData(name: 'Ho Chi Minh City', countryCode: 'VN', location: Vector2(106.7, 10.8)),
    CityData(name: 'Jakarta', countryCode: 'ID', location: Vector2(106.8, -6.2), isCapital: true),
    CityData(name: 'Surabaya', countryCode: 'ID', location: Vector2(112.8, -7.3)),
    CityData(name: 'Manila', countryCode: 'PH', location: Vector2(121, 14.6), isCapital: true),
    CityData(name: 'Cebu', countryCode: 'PH', location: Vector2(123.9, 10.3)),
    CityData(name: 'Kuala Lumpur', countryCode: 'MY', location: Vector2(101.7, 3.1), isCapital: true),
    CityData(name: 'George Town', countryCode: 'MY', location: Vector2(100.3, 5.4)),
    CityData(name: 'Islamabad', countryCode: 'PK', location: Vector2(73.1, 33.7), isCapital: true),
    CityData(name: 'Karachi', countryCode: 'PK', location: Vector2(67, 24.9)),
    CityData(name: 'Dhaka', countryCode: 'BD', location: Vector2(90.4, 23.8), isCapital: true),
    CityData(name: 'Chittagong', countryCode: 'BD', location: Vector2(91.8, 22.3)),
    CityData(name: 'Riyadh', countryCode: 'SA', location: Vector2(46.7, 24.7), isCapital: true),
    CityData(name: 'Jeddah', countryCode: 'SA', location: Vector2(39.2, 21.5)),
    CityData(name: 'Abu Dhabi', countryCode: 'AE', location: Vector2(54.4, 24.5), isCapital: true),
    CityData(name: 'Dubai', countryCode: 'AE', location: Vector2(55.3, 25.3)),
    CityData(name: 'Tehran', countryCode: 'IR', location: Vector2(51.4, 35.7), isCapital: true),
    CityData(name: 'Isfahan', countryCode: 'IR', location: Vector2(51.7, 32.7)),
    CityData(name: 'Baghdad', countryCode: 'IQ', location: Vector2(44.4, 33.3), isCapital: true),
    CityData(name: 'Basra', countryCode: 'IQ', location: Vector2(47.8, 30.5)),
    CityData(name: 'Jerusalem', countryCode: 'IL', location: Vector2(35.2, 31.8), isCapital: true),
    CityData(name: 'Tel Aviv', countryCode: 'IL', location: Vector2(34.8, 32.1)),
    CityData(name: 'Singapore', countryCode: 'SG', location: Vector2(103.8, 1.4), isCapital: true),
    CityData(name: 'Astana', countryCode: 'KZ', location: Vector2(71.4, 51.2), isCapital: true),
    CityData(name: 'Almaty', countryCode: 'KZ', location: Vector2(76.9, 43.2)),

    // =========================================================
    // OCEANIA
    // =========================================================
    CityData(name: 'Sydney', countryCode: 'AU', location: Vector2(151.2, -33.9)),
    CityData(name: 'Melbourne', countryCode: 'AU', location: Vector2(145, -37.8)),
    CityData(name: 'Canberra', countryCode: 'AU', location: Vector2(149.1, -35.3), isCapital: true),
    CityData(name: 'Wellington', countryCode: 'NZ', location: Vector2(174.8, -41.3), isCapital: true),
    CityData(name: 'Auckland', countryCode: 'NZ', location: Vector2(174.8, -36.9)),
    CityData(name: 'Port Moresby', countryCode: 'PG', location: Vector2(147.2, -9.5), isCapital: true),
    CityData(name: 'Lae', countryCode: 'PG', location: Vector2(147, -6.7)),
    CityData(name: 'Suva', countryCode: 'FJ', location: Vector2(178.4, -18.1), isCapital: true),
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
