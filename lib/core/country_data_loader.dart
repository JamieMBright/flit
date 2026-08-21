import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/map/country_data.dart';

class CountryDataLoader {
  CountryDataLoader._();

  static final CountryDataLoader _instance = CountryDataLoader._();

  factory CountryDataLoader() => _instance;

  List<CountryShape> _countries = const [];
  List<CityData> _majorCities = const [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final source = await rootBundle.loadString('assets/geo/countries.json');
    final data = jsonDecode(source) as Map<String, dynamic>;
    _countries = (data['countries'] as List<dynamic>).map((raw) {
      final country = raw as Map<String, dynamic>;
      return CountryShape(
        code: country['code'] as String,
        name: country['name'] as String,
        capital: country['capital'] as String?,
        polygons: (country['polygons'] as List<dynamic>).map((polygon) =>
            _decodePolygon(polygon as List<dynamic>)).toList(growable: false),
      );
    }).toList(growable: false);
    _majorCities = (data['cities'] as List<dynamic>).map((raw) {
      final city = raw as Map<String, dynamic>;
      final location = city['location'] as List<dynamic>;
      return CityData(
        name: city['name'] as String,
        countryCode: city['countryCode'] as String,
        location: Vector2(
          (location[0] as num).toDouble(),
          (location[1] as num).toDouble(),
        ),
        isCapital: city['isCapital'] as bool? ?? false,
        difficulty: city['difficulty'] as String? ?? 'easy',
      );
    }).toList(growable: false);
    _loaded = true;
  }

  List<Vector2> _decodePolygon(List<dynamic> coordinates) {
    if (coordinates.length.isOdd) {
      throw const FormatException('Polygon coordinate count must be even.');
    }
    return [
      for (var i = 0; i < coordinates.length; i += 2)
        Vector2(
          (coordinates[i] as num).toDouble(),
          (coordinates[i + 1] as num).toDouble(),
        ),
    ];
  }

  List<CountryShape> get countries {
    _checkLoaded();
    return _countries;
  }

  List<CityData> get majorCities {
    _checkLoaded();
    return _majorCities;
  }

  void _checkLoaded() {
    if (!_loaded) {
      throw StateError('CountryDataLoader.load() must complete before access.');
    }
  }
}

final countryDataLoaderProvider = Provider<CountryDataLoader>(
  (ref) => CountryDataLoader(),
);
