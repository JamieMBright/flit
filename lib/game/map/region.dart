import 'package:flame/components.dart';

import 'country_data.dart';

/// Available game regions.
enum GameRegion {
  world,
  usStates,
  ukCounties,
  caribbean,
  ireland,
}

extension GameRegionExtension on GameRegion {
  String get displayName {
    switch (this) {
      case GameRegion.world:
        return 'World';
      case GameRegion.usStates:
        return 'US States';
      case GameRegion.ukCounties:
        return 'UK Counties';
      case GameRegion.caribbean:
        return 'Caribbean';
      case GameRegion.ireland:
        return 'Ireland';
    }
  }

  String get description {
    switch (this) {
      case GameRegion.world:
        return 'Navigate the entire globe';
      case GameRegion.usStates:
        return 'Explore all 50 US states';
      case GameRegion.ukCounties:
        return 'Discover counties of the UK';
      case GameRegion.caribbean:
        return 'Island hop through the Caribbean';
      case GameRegion.ireland:
        return 'Tour the counties of Ireland';
    }
  }

  /// Map bounds for the region [minLng, minLat, maxLng, maxLat]
  List<double> get bounds {
    switch (this) {
      case GameRegion.world:
        return [-180, -85, 180, 85];
      case GameRegion.usStates:
        return [-125, 24, -66, 50];
      case GameRegion.ukCounties:
        return [-11, 49, 3, 61];
      case GameRegion.caribbean:
        return [-85, 10, -59, 28];
      case GameRegion.ireland:
        return [-11, 51, -5, 56];
    }
  }

  /// Center point for the region
  Vector2 get center {
    final b = bounds;
    return Vector2((b[0] + b[2]) / 2, (b[1] + b[3]) / 2);
  }

  /// Required level to unlock this region
  int get requiredLevel {
    switch (this) {
      case GameRegion.world:
        return 1;
      case GameRegion.usStates:
        return 3;
      case GameRegion.ukCounties:
        return 5;
      case GameRegion.caribbean:
        return 7;
      case GameRegion.ireland:
        return 10;
    }
  }
}

/// Regional area shape (state, county, island, etc.)
class RegionalArea {
  const RegionalArea({
    required this.code,
    required this.name,
    required this.points,
    this.capital,
    this.population,
    this.funFact,
  });

  final String code;
  final String name;
  final List<Vector2> points;
  final String? capital;
  final int? population;
  final String? funFact;
}

/// Regional data provider.
abstract class RegionalData {
  /// Get areas for a region
  static List<RegionalArea> getAreas(GameRegion region) {
    switch (region) {
      case GameRegion.world:
        // Convert countries to regional areas
        return CountryData.countries.map((c) => RegionalArea(
          code: c.code,
          name: c.name,
          points: c.points,
          capital: c.capital,
        )).toList();
      case GameRegion.usStates:
        return _usStates;
      case GameRegion.ukCounties:
        return _ukCounties;
      case GameRegion.caribbean:
        return _caribbeanIslands;
      case GameRegion.ireland:
        return _irelandCounties;
    }
  }

  /// Get random area from a region
  static RegionalArea getRandomArea(GameRegion region) {
    final areas = getAreas(region);
    return areas[DateTime.now().millisecondsSinceEpoch % areas.length];
  }

  // US States (simplified outlines for key states)
  static const List<RegionalArea> _usStates = [
    RegionalArea(
      code: 'CA',
      name: 'California',
      capital: 'Sacramento',
      population: 39538223,
      points: [
        Vector2(-124.4, 42), Vector2(-120, 42), Vector2(-120, 39),
        Vector2(-117, 33), Vector2(-117.1, 32.5), Vector2(-120, 34),
        Vector2(-122, 37), Vector2(-124, 40), Vector2(-124.4, 42),
      ],
    ),
    RegionalArea(
      code: 'TX',
      name: 'Texas',
      capital: 'Austin',
      population: 29145505,
      points: [
        Vector2(-106.6, 32), Vector2(-103, 32), Vector2(-103, 36.5),
        Vector2(-100, 36.5), Vector2(-94, 34), Vector2(-94, 30),
        Vector2(-97, 26), Vector2(-100, 28), Vector2(-104, 29),
        Vector2(-106.5, 31.8), Vector2(-106.6, 32),
      ],
    ),
    RegionalArea(
      code: 'FL',
      name: 'Florida',
      capital: 'Tallahassee',
      population: 21538187,
      points: [
        Vector2(-87.6, 31), Vector2(-85, 31), Vector2(-82, 30.5),
        Vector2(-81, 29), Vector2(-80, 26), Vector2(-80.3, 25.5),
        Vector2(-82, 25), Vector2(-83, 29), Vector2(-85, 30),
        Vector2(-87.6, 31),
      ],
    ),
    RegionalArea(
      code: 'NY',
      name: 'New York',
      capital: 'Albany',
      population: 20201249,
      points: [
        Vector2(-79.8, 43), Vector2(-75, 45), Vector2(-73.3, 45),
        Vector2(-73.3, 41), Vector2(-74, 40.5), Vector2(-74.3, 40.5),
        Vector2(-79.8, 42.3), Vector2(-79.8, 43),
      ],
    ),
    RegionalArea(
      code: 'PA',
      name: 'Pennsylvania',
      capital: 'Harrisburg',
      population: 13002700,
      points: [
        Vector2(-80.5, 42), Vector2(-75, 42), Vector2(-75, 40),
        Vector2(-75.5, 39.7), Vector2(-80.5, 40), Vector2(-80.5, 42),
      ],
    ),
    RegionalArea(
      code: 'IL',
      name: 'Illinois',
      capital: 'Springfield',
      population: 12812508,
      points: [
        Vector2(-91.5, 42.5), Vector2(-87.5, 42.5), Vector2(-87.5, 39),
        Vector2(-89, 37), Vector2(-91.5, 37), Vector2(-91.5, 42.5),
      ],
    ),
    RegionalArea(
      code: 'OH',
      name: 'Ohio',
      capital: 'Columbus',
      population: 11799448,
      points: [
        Vector2(-84.8, 42), Vector2(-80.5, 42), Vector2(-80.5, 39),
        Vector2(-84, 38.5), Vector2(-84.8, 39.5), Vector2(-84.8, 42),
      ],
    ),
    RegionalArea(
      code: 'GA',
      name: 'Georgia',
      capital: 'Atlanta',
      population: 10711908,
      points: [
        Vector2(-85.6, 35), Vector2(-83.1, 35), Vector2(-81, 32),
        Vector2(-81, 30.5), Vector2(-85.6, 30.5), Vector2(-85.6, 35),
      ],
    ),
    RegionalArea(
      code: 'NC',
      name: 'North Carolina',
      capital: 'Raleigh',
      population: 10439388,
      points: [
        Vector2(-84.3, 36.6), Vector2(-75.5, 36.6), Vector2(-75.5, 34),
        Vector2(-78, 33.8), Vector2(-83, 35), Vector2(-84.3, 35),
        Vector2(-84.3, 36.6),
      ],
    ),
    RegionalArea(
      code: 'MI',
      name: 'Michigan',
      capital: 'Lansing',
      population: 10077331,
      points: [
        Vector2(-90.4, 48), Vector2(-84.4, 46.5), Vector2(-82.5, 43),
        Vector2(-82.5, 41.7), Vector2(-87, 42), Vector2(-88.5, 45.5),
        Vector2(-90.4, 48),
      ],
    ),
    RegionalArea(
      code: 'NJ',
      name: 'New Jersey',
      capital: 'Trenton',
      population: 9288994,
      points: [
        Vector2(-75.6, 41.4), Vector2(-74, 41.4), Vector2(-74, 40),
        Vector2(-74, 38.9), Vector2(-75.6, 39.5), Vector2(-75.6, 41.4),
      ],
    ),
    RegionalArea(
      code: 'VA',
      name: 'Virginia',
      capital: 'Richmond',
      population: 8631393,
      points: [
        Vector2(-83.7, 39.5), Vector2(-77, 39.3), Vector2(-75.2, 38),
        Vector2(-76, 36.5), Vector2(-83.7, 36.5), Vector2(-83.7, 39.5),
      ],
    ),
    RegionalArea(
      code: 'WA',
      name: 'Washington',
      capital: 'Olympia',
      population: 7614893,
      points: [
        Vector2(-124.8, 49), Vector2(-117, 49), Vector2(-117, 46),
        Vector2(-124, 46), Vector2(-124.8, 47.5), Vector2(-124.8, 49),
      ],
    ),
    RegionalArea(
      code: 'AZ',
      name: 'Arizona',
      capital: 'Phoenix',
      population: 7278717,
      points: [
        Vector2(-114.8, 37), Vector2(-109, 37), Vector2(-109, 31.3),
        Vector2(-111.1, 31.3), Vector2(-114.7, 32.7), Vector2(-114.8, 37),
      ],
    ),
    RegionalArea(
      code: 'MA',
      name: 'Massachusetts',
      capital: 'Boston',
      population: 7029917,
      points: [
        Vector2(-73.5, 42.8), Vector2(-70, 42.8), Vector2(-70, 41.2),
        Vector2(-71.4, 41), Vector2(-73.5, 42), Vector2(-73.5, 42.8),
      ],
    ),
    RegionalArea(
      code: 'TN',
      name: 'Tennessee',
      capital: 'Nashville',
      population: 6910840,
      points: [
        Vector2(-90.3, 36.5), Vector2(-81.7, 36.6), Vector2(-81.7, 35),
        Vector2(-90.3, 35), Vector2(-90.3, 36.5),
      ],
    ),
    RegionalArea(
      code: 'IN',
      name: 'Indiana',
      capital: 'Indianapolis',
      population: 6785528,
      points: [
        Vector2(-88.1, 41.8), Vector2(-84.8, 41.8), Vector2(-84.8, 38),
        Vector2(-88.1, 38), Vector2(-88.1, 41.8),
      ],
    ),
    RegionalArea(
      code: 'MO',
      name: 'Missouri',
      capital: 'Jefferson City',
      population: 6154913,
      points: [
        Vector2(-95.8, 40.6), Vector2(-89.1, 40.6), Vector2(-89.1, 36),
        Vector2(-95.8, 36), Vector2(-95.8, 40.6),
      ],
    ),
    RegionalArea(
      code: 'MD',
      name: 'Maryland',
      capital: 'Annapolis',
      population: 6177224,
      points: [
        Vector2(-79.5, 39.7), Vector2(-75.1, 39.7), Vector2(-75.1, 38),
        Vector2(-76.2, 37.9), Vector2(-79.5, 39.2), Vector2(-79.5, 39.7),
      ],
    ),
    RegionalArea(
      code: 'CO',
      name: 'Colorado',
      capital: 'Denver',
      population: 5773714,
      points: [
        Vector2(-109, 41), Vector2(-102, 41), Vector2(-102, 37),
        Vector2(-109, 37), Vector2(-109, 41),
      ],
    ),
  ];

  // UK Counties (simplified)
  static const List<RegionalArea> _ukCounties = [
    RegionalArea(
      code: 'GLA',
      name: 'Greater London',
      capital: 'London',
      population: 8982000,
      points: [
        Vector2(-0.5, 51.7), Vector2(0.3, 51.7), Vector2(0.3, 51.3),
        Vector2(-0.5, 51.3), Vector2(-0.5, 51.7),
      ],
    ),
    RegionalArea(
      code: 'WMD',
      name: 'West Midlands',
      capital: 'Birmingham',
      population: 2919600,
      points: [
        Vector2(-2.2, 52.7), Vector2(-1.5, 52.7), Vector2(-1.5, 52.3),
        Vector2(-2.2, 52.3), Vector2(-2.2, 52.7),
      ],
    ),
    RegionalArea(
      code: 'GTM',
      name: 'Greater Manchester',
      capital: 'Manchester',
      population: 2835686,
      points: [
        Vector2(-2.7, 53.7), Vector2(-2, 53.7), Vector2(-2, 53.3),
        Vector2(-2.7, 53.3), Vector2(-2.7, 53.7),
      ],
    ),
    RegionalArea(
      code: 'WYK',
      name: 'West Yorkshire',
      capital: 'Leeds',
      population: 2320214,
      points: [
        Vector2(-2.2, 54), Vector2(-1.2, 54), Vector2(-1.2, 53.6),
        Vector2(-2.2, 53.6), Vector2(-2.2, 54),
      ],
    ),
    RegionalArea(
      code: 'KEN',
      name: 'Kent',
      capital: 'Maidstone',
      population: 1568623,
      points: [
        Vector2(0, 51.5), Vector2(1.4, 51.4), Vector2(1.4, 51),
        Vector2(0, 51), Vector2(0, 51.5),
      ],
    ),
    RegionalArea(
      code: 'ESS',
      name: 'Essex',
      capital: 'Chelmsford',
      population: 1477764,
      points: [
        Vector2(0, 52), Vector2(1.3, 52), Vector2(1.3, 51.5),
        Vector2(0, 51.5), Vector2(0, 52),
      ],
    ),
    RegionalArea(
      code: 'MER',
      name: 'Merseyside',
      capital: 'Liverpool',
      population: 1436877,
      points: [
        Vector2(-3.2, 53.6), Vector2(-2.7, 53.6), Vector2(-2.7, 53.3),
        Vector2(-3.2, 53.3), Vector2(-3.2, 53.6),
      ],
    ),
    RegionalArea(
      code: 'SYK',
      name: 'South Yorkshire',
      capital: 'Sheffield',
      population: 1415946,
      points: [
        Vector2(-1.8, 53.6), Vector2(-1, 53.6), Vector2(-1, 53.3),
        Vector2(-1.8, 53.3), Vector2(-1.8, 53.6),
      ],
    ),
    RegionalArea(
      code: 'HAM',
      name: 'Hampshire',
      capital: 'Winchester',
      population: 1376316,
      points: [
        Vector2(-1.8, 51.3), Vector2(-0.7, 51.3), Vector2(-0.7, 50.7),
        Vector2(-1.8, 50.7), Vector2(-1.8, 51.3),
      ],
    ),
    RegionalArea(
      code: 'LAN',
      name: 'Lancashire',
      capital: 'Preston',
      population: 1210053,
      points: [
        Vector2(-3, 54.2), Vector2(-2, 54.2), Vector2(-2, 53.6),
        Vector2(-3, 53.6), Vector2(-3, 54.2),
      ],
    ),
    RegionalArea(
      code: 'SRY',
      name: 'Surrey',
      capital: 'Guildford',
      population: 1185329,
      points: [
        Vector2(-0.8, 51.5), Vector2(0, 51.5), Vector2(0, 51.1),
        Vector2(-0.8, 51.1), Vector2(-0.8, 51.5),
      ],
    ),
    RegionalArea(
      code: 'DEV',
      name: 'Devon',
      capital: 'Exeter',
      population: 795286,
      points: [
        Vector2(-4.7, 51.3), Vector2(-3, 51.3), Vector2(-3, 50.2),
        Vector2(-4.7, 50.2), Vector2(-4.7, 51.3),
      ],
    ),
    RegionalArea(
      code: 'NFO',
      name: 'Norfolk',
      capital: 'Norwich',
      population: 903680,
      points: [
        Vector2(0.1, 53), Vector2(1.8, 53), Vector2(1.8, 52.3),
        Vector2(0.1, 52.3), Vector2(0.1, 53),
      ],
    ),
    RegionalArea(
      code: 'SOM',
      name: 'Somerset',
      capital: 'Taunton',
      population: 560619,
      points: [
        Vector2(-3.8, 51.4), Vector2(-2.3, 51.4), Vector2(-2.3, 50.9),
        Vector2(-3.8, 50.9), Vector2(-3.8, 51.4),
      ],
    ),
    RegionalArea(
      code: 'COR',
      name: 'Cornwall',
      capital: 'Truro',
      population: 568210,
      points: [
        Vector2(-5.7, 50.8), Vector2(-4.5, 50.8), Vector2(-4.5, 50),
        Vector2(-5.7, 50), Vector2(-5.7, 50.8),
      ],
    ),
    // Scotland
    RegionalArea(
      code: 'GLG',
      name: 'Glasgow City',
      capital: 'Glasgow',
      population: 635640,
      points: [
        Vector2(-4.5, 56), Vector2(-4, 56), Vector2(-4, 55.8),
        Vector2(-4.5, 55.8), Vector2(-4.5, 56),
      ],
    ),
    RegionalArea(
      code: 'EDH',
      name: 'City of Edinburgh',
      capital: 'Edinburgh',
      population: 524930,
      points: [
        Vector2(-3.4, 56), Vector2(-3, 56), Vector2(-3, 55.9),
        Vector2(-3.4, 55.9), Vector2(-3.4, 56),
      ],
    ),
    // Wales
    RegionalArea(
      code: 'CRF',
      name: 'Cardiff',
      capital: 'Cardiff',
      population: 362756,
      points: [
        Vector2(-3.3, 51.55), Vector2(-3.1, 51.55), Vector2(-3.1, 51.45),
        Vector2(-3.3, 51.45), Vector2(-3.3, 51.55),
      ],
    ),
    // Northern Ireland
    RegionalArea(
      code: 'BFS',
      name: 'Belfast',
      capital: 'Belfast',
      population: 343542,
      points: [
        Vector2(-6, 54.7), Vector2(-5.8, 54.7), Vector2(-5.8, 54.5),
        Vector2(-6, 54.5), Vector2(-6, 54.7),
      ],
    ),
  ];

  // Caribbean Islands (simplified)
  static const List<RegionalArea> _caribbeanIslands = [
    RegionalArea(
      code: 'CU',
      name: 'Cuba',
      capital: 'Havana',
      population: 11326616,
      points: [
        Vector2(-85, 22), Vector2(-84, 23.2), Vector2(-80, 23),
        Vector2(-75, 20.5), Vector2(-74.1, 20), Vector2(-77, 19.8),
        Vector2(-84.5, 21.5), Vector2(-85, 22),
      ],
    ),
    RegionalArea(
      code: 'JM',
      name: 'Jamaica',
      capital: 'Kingston',
      population: 2961167,
      points: [
        Vector2(-78.4, 18.5), Vector2(-76, 18.5), Vector2(-76, 17.7),
        Vector2(-78.4, 17.7), Vector2(-78.4, 18.5),
      ],
    ),
    RegionalArea(
      code: 'HT',
      name: 'Haiti',
      capital: 'Port-au-Prince',
      population: 11402528,
      points: [
        Vector2(-74.5, 20), Vector2(-72, 20), Vector2(-71.6, 18),
        Vector2(-74.5, 18), Vector2(-74.5, 20),
      ],
    ),
    RegionalArea(
      code: 'DO',
      name: 'Dominican Republic',
      capital: 'Santo Domingo',
      population: 10847910,
      points: [
        Vector2(-72, 20), Vector2(-68.3, 19.8), Vector2(-68.3, 17.6),
        Vector2(-72, 17.6), Vector2(-72, 20),
      ],
    ),
    RegionalArea(
      code: 'PR',
      name: 'Puerto Rico',
      capital: 'San Juan',
      population: 3285874,
      points: [
        Vector2(-67.3, 18.5), Vector2(-65.2, 18.5), Vector2(-65.2, 17.9),
        Vector2(-67.3, 17.9), Vector2(-67.3, 18.5),
      ],
    ),
    RegionalArea(
      code: 'BS',
      name: 'Bahamas',
      capital: 'Nassau',
      population: 393244,
      points: [
        Vector2(-79.5, 27), Vector2(-74, 27), Vector2(-73, 21),
        Vector2(-77.5, 21), Vector2(-79.5, 27),
      ],
    ),
    RegionalArea(
      code: 'TT',
      name: 'Trinidad and Tobago',
      capital: 'Port of Spain',
      population: 1399488,
      points: [
        Vector2(-61.9, 11), Vector2(-60.5, 11), Vector2(-60.5, 10),
        Vector2(-61.9, 10), Vector2(-61.9, 11),
      ],
    ),
    RegionalArea(
      code: 'BB',
      name: 'Barbados',
      capital: 'Bridgetown',
      population: 287375,
      points: [
        Vector2(-59.7, 13.4), Vector2(-59.4, 13.4), Vector2(-59.4, 13.05),
        Vector2(-59.7, 13.05), Vector2(-59.7, 13.4),
      ],
    ),
    RegionalArea(
      code: 'LC',
      name: 'Saint Lucia',
      capital: 'Castries',
      population: 183627,
      points: [
        Vector2(-61.1, 14.1), Vector2(-60.85, 14.1), Vector2(-60.85, 13.7),
        Vector2(-61.1, 13.7), Vector2(-61.1, 14.1),
      ],
    ),
    RegionalArea(
      code: 'VC',
      name: 'Saint Vincent',
      capital: 'Kingstown',
      population: 110940,
      points: [
        Vector2(-61.3, 13.4), Vector2(-61.1, 13.4), Vector2(-61.1, 13.1),
        Vector2(-61.3, 13.1), Vector2(-61.3, 13.4),
      ],
    ),
    RegionalArea(
      code: 'GD',
      name: 'Grenada',
      capital: "St. George's",
      population: 112523,
      points: [
        Vector2(-61.8, 12.3), Vector2(-61.6, 12.3), Vector2(-61.6, 12),
        Vector2(-61.8, 12), Vector2(-61.8, 12.3),
      ],
    ),
    RegionalArea(
      code: 'AG',
      name: 'Antigua and Barbuda',
      capital: "St. John's",
      population: 97929,
      points: [
        Vector2(-62, 17.75), Vector2(-61.65, 17.75), Vector2(-61.65, 17),
        Vector2(-62, 17), Vector2(-62, 17.75),
      ],
    ),
    RegionalArea(
      code: 'DM',
      name: 'Dominica',
      capital: 'Roseau',
      population: 71986,
      points: [
        Vector2(-61.5, 15.7), Vector2(-61.2, 15.7), Vector2(-61.2, 15.2),
        Vector2(-61.5, 15.2), Vector2(-61.5, 15.7),
      ],
    ),
    RegionalArea(
      code: 'KN',
      name: 'Saint Kitts and Nevis',
      capital: 'Basseterre',
      population: 53192,
      points: [
        Vector2(-62.9, 17.45), Vector2(-62.5, 17.45), Vector2(-62.5, 17.05),
        Vector2(-62.9, 17.05), Vector2(-62.9, 17.45),
      ],
    ),
    RegionalArea(
      code: 'CW',
      name: 'Curaçao',
      capital: 'Willemstad',
      population: 155014,
      points: [
        Vector2(-69.2, 12.4), Vector2(-68.7, 12.4), Vector2(-68.7, 12.05),
        Vector2(-69.2, 12.05), Vector2(-69.2, 12.4),
      ],
    ),
    RegionalArea(
      code: 'AW',
      name: 'Aruba',
      capital: 'Oranjestad',
      population: 106766,
      points: [
        Vector2(-70.1, 12.65), Vector2(-69.85, 12.65), Vector2(-69.85, 12.4),
        Vector2(-70.1, 12.4), Vector2(-70.1, 12.65),
      ],
    ),
  ];

  // Ireland Counties
  static const List<RegionalArea> _irelandCounties = [
    // Leinster
    RegionalArea(
      code: 'D',
      name: 'Dublin',
      capital: 'Dublin',
      population: 1426220,
      points: [
        Vector2(-6.5, 53.5), Vector2(-6.05, 53.5), Vector2(-6.05, 53.2),
        Vector2(-6.5, 53.2), Vector2(-6.5, 53.5),
      ],
    ),
    RegionalArea(
      code: 'WW',
      name: 'Wicklow',
      capital: 'Wicklow',
      population: 142425,
      points: [
        Vector2(-6.7, 53.2), Vector2(-6, 53.2), Vector2(-6, 52.8),
        Vector2(-6.7, 52.8), Vector2(-6.7, 53.2),
      ],
    ),
    RegionalArea(
      code: 'WX',
      name: 'Wexford',
      capital: 'Wexford',
      population: 149722,
      points: [
        Vector2(-7, 52.7), Vector2(-6.2, 52.7), Vector2(-6.2, 52.15),
        Vector2(-7, 52.15), Vector2(-7, 52.7),
      ],
    ),
    RegionalArea(
      code: 'KK',
      name: 'Kilkenny',
      capital: 'Kilkenny',
      population: 99232,
      points: [
        Vector2(-7.6, 52.85), Vector2(-6.9, 52.85), Vector2(-6.9, 52.3),
        Vector2(-7.6, 52.3), Vector2(-7.6, 52.85),
      ],
    ),
    // Munster
    RegionalArea(
      code: 'C',
      name: 'Cork',
      capital: 'Cork',
      population: 542868,
      points: [
        Vector2(-10, 52.2), Vector2(-8, 52.2), Vector2(-8, 51.4),
        Vector2(-10, 51.4), Vector2(-10, 52.2),
      ],
    ),
    RegionalArea(
      code: 'KY',
      name: 'Kerry',
      capital: 'Tralee',
      population: 147707,
      points: [
        Vector2(-10.5, 52.5), Vector2(-9.2, 52.5), Vector2(-9.2, 51.75),
        Vector2(-10.5, 51.75), Vector2(-10.5, 52.5),
      ],
    ),
    RegionalArea(
      code: 'L',
      name: 'Limerick',
      capital: 'Limerick',
      population: 194899,
      points: [
        Vector2(-9.5, 52.8), Vector2(-8.3, 52.8), Vector2(-8.3, 52.3),
        Vector2(-9.5, 52.3), Vector2(-9.5, 52.8),
      ],
    ),
    RegionalArea(
      code: 'CE',
      name: 'Clare',
      capital: 'Ennis',
      population: 118817,
      points: [
        Vector2(-10, 53.15), Vector2(-8.5, 53.15), Vector2(-8.5, 52.6),
        Vector2(-10, 52.6), Vector2(-10, 53.15),
      ],
    ),
    RegionalArea(
      code: 'TS',
      name: 'Tipperary',
      capital: 'Clonmel',
      population: 159553,
      points: [
        Vector2(-8.5, 53), Vector2(-7.4, 53), Vector2(-7.4, 52.25),
        Vector2(-8.5, 52.25), Vector2(-8.5, 53),
      ],
    ),
    RegionalArea(
      code: 'W',
      name: 'Waterford',
      capital: 'Waterford',
      population: 116176,
      points: [
        Vector2(-8.1, 52.4), Vector2(-6.9, 52.4), Vector2(-6.9, 51.9),
        Vector2(-8.1, 51.9), Vector2(-8.1, 52.4),
      ],
    ),
    // Connacht
    RegionalArea(
      code: 'G',
      name: 'Galway',
      capital: 'Galway',
      population: 258058,
      points: [
        Vector2(-10.2, 53.6), Vector2(-8.2, 53.6), Vector2(-8.2, 53),
        Vector2(-10.2, 53), Vector2(-10.2, 53.6),
      ],
    ),
    RegionalArea(
      code: 'MO',
      name: 'Mayo',
      capital: 'Castlebar',
      population: 130507,
      points: [
        Vector2(-10.2, 54.1), Vector2(-9, 54.1), Vector2(-9, 53.5),
        Vector2(-10.2, 53.5), Vector2(-10.2, 54.1),
      ],
    ),
    RegionalArea(
      code: 'SO',
      name: 'Sligo',
      capital: 'Sligo',
      population: 65535,
      points: [
        Vector2(-9, 54.4), Vector2(-8.1, 54.4), Vector2(-8.1, 53.9),
        Vector2(-9, 53.9), Vector2(-9, 54.4),
      ],
    ),
    RegionalArea(
      code: 'RN',
      name: 'Roscommon',
      capital: 'Roscommon',
      population: 64544,
      points: [
        Vector2(-8.8, 54), Vector2(-7.9, 54), Vector2(-7.9, 53.4),
        Vector2(-8.8, 53.4), Vector2(-8.8, 54),
      ],
    ),
    RegionalArea(
      code: 'LM',
      name: 'Leitrim',
      capital: 'Carrick-on-Shannon',
      population: 32044,
      points: [
        Vector2(-8.5, 54.35), Vector2(-7.8, 54.35), Vector2(-7.8, 53.9),
        Vector2(-8.5, 53.9), Vector2(-8.5, 54.35),
      ],
    ),
    // Ulster (Republic)
    RegionalArea(
      code: 'DL',
      name: 'Donegal',
      capital: 'Lifford',
      population: 159192,
      points: [
        Vector2(-8.7, 55.4), Vector2(-7, 55.4), Vector2(-7, 54.6),
        Vector2(-8.7, 54.6), Vector2(-8.7, 55.4),
      ],
    ),
    RegionalArea(
      code: 'CN',
      name: 'Cavan',
      capital: 'Cavan',
      population: 76176,
      points: [
        Vector2(-8, 54.2), Vector2(-6.8, 54.2), Vector2(-6.8, 53.8),
        Vector2(-8, 53.8), Vector2(-8, 54.2),
      ],
    ),
    RegionalArea(
      code: 'MN',
      name: 'Monaghan',
      capital: 'Monaghan',
      population: 61386,
      points: [
        Vector2(-7.4, 54.4), Vector2(-6.5, 54.4), Vector2(-6.5, 53.9),
        Vector2(-7.4, 53.9), Vector2(-7.4, 54.4),
      ],
    ),
  ];
}
