import 'package:flame/components.dart';

import '../../core/country_data_loader.dart';

/// Country shape data with multi-polygon support.
class CountryShape {
  const CountryShape({
    required this.code,
    required this.name,
    required this.polygons,
    this.capital,
  });

  final String code;
  final String name;
  final List<List<Vector2>> polygons;
  final String? capital;

  List<Vector2> get allPoints => polygons.expand((polygon) => polygon).toList();
}

/// City data for low-altitude view.
class CityData {
  const CityData({
    required this.name,
    required this.countryCode,
    required this.location,
    this.isCapital = false,
    this.difficulty = 'easy',
  });

  final String name;
  final String countryCode;
  final Vector2 location;
  final bool isCapital;
  final String difficulty;
}

/// Synchronous facade over the asynchronously loaded country asset.
abstract class CountryData {
  static List<CountryShape> get countries => CountryDataLoader().countries;

  static List<CityData> get majorCities => CountryDataLoader().majorCities;

  static CountryShape? getCountry(String code) {
    try {
      return countries.firstWhere((country) => country.code == code);
    } catch (_) {
      return null;
    }
  }

  static const Set<String> excludedTerritories = {
    'AI',
    'AS',
    'MS',
    'NF',
    'NU',
    'PM',
    'PN',
    'SH',
    'UM',
    'VG',
    'WF',
  };

  static List<CountryShape> get playableCountries => countries
      .where((country) => !excludedTerritories.contains(country.code))
      .toList(growable: false);

  static CountryShape getRandomCountry() => playableCountries[
      DateTime.now().millisecondsSinceEpoch % playableCountries.length];

  static List<CityData> getCitiesForCountry(String code) =>
      majorCities.where((city) => city.countryCode == code).toList();

  static CityData? getCapital(String code) {
    try {
      return majorCities.firstWhere(
        (city) => city.countryCode == code && city.isCapital,
      );
    } catch (_) {
      return null;
    }
  }
}
