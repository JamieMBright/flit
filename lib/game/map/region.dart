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
        return 'Tour all 32 counties of Ireland';
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
        return CountryData.countries
            .map((c) => RegionalArea(
                  code: c.code,
                  name: c.name,
                  points: c.points,
                  capital: c.capital,
                ))
            .toList();
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

  // All 50 US States
  static final List<RegionalArea> _usStates = [
    // By population (largest first)
    RegionalArea(code: 'CA', name: 'California', capital: 'Sacramento', population: 39538223, funFact: 'Home to the tallest tree on Earth, Hyperion', points: [Vector2(-124.4, 42), Vector2(-120, 42), Vector2(-120, 39), Vector2(-117, 33), Vector2(-117.1, 32.5), Vector2(-120, 34), Vector2(-122, 37), Vector2(-124, 40), Vector2(-124.4, 42)]),
    RegionalArea(code: 'TX', name: 'Texas', capital: 'Austin', population: 29145505, funFact: 'The only US state that was once its own republic', points: [Vector2(-106.6, 32), Vector2(-103, 32), Vector2(-103, 36.5), Vector2(-100, 36.5), Vector2(-94, 34), Vector2(-94, 30), Vector2(-97, 26), Vector2(-100, 28), Vector2(-104, 29), Vector2(-106.5, 31.8), Vector2(-106.6, 32)]),
    RegionalArea(code: 'FL', name: 'Florida', capital: 'Tallahassee', population: 21538187, funFact: 'Has more golf courses than any other US state', points: [Vector2(-87.6, 31), Vector2(-85, 31), Vector2(-82, 30.5), Vector2(-81, 29), Vector2(-80, 26), Vector2(-80.3, 25.5), Vector2(-82, 25), Vector2(-83, 29), Vector2(-85, 30), Vector2(-87.6, 31)]),
    RegionalArea(code: 'NY', name: 'New York', capital: 'Albany', population: 20201249, funFact: 'Home to the first pizzeria in America, opened 1905', points: [Vector2(-79.8, 43), Vector2(-75, 45), Vector2(-73.3, 45), Vector2(-73.3, 41), Vector2(-74, 40.5), Vector2(-74.3, 40.5), Vector2(-79.8, 42.3), Vector2(-79.8, 43)]),
    RegionalArea(code: 'PA', name: 'Pennsylvania', capital: 'Harrisburg', population: 13002700, funFact: 'Home to the first computer, ENIAC, built in 1946', points: [Vector2(-80.5, 42), Vector2(-75, 42), Vector2(-75, 40), Vector2(-75.5, 39.7), Vector2(-80.5, 40), Vector2(-80.5, 42)]),
    RegionalArea(code: 'IL', name: 'Illinois', capital: 'Springfield', population: 12812508, funFact: 'Home to the first skyscraper, built in Chicago in 1885', points: [Vector2(-91.5, 42.5), Vector2(-87.5, 42.5), Vector2(-87.5, 39), Vector2(-89, 37), Vector2(-91.5, 37), Vector2(-91.5, 42.5)]),
    RegionalArea(code: 'OH', name: 'Ohio', capital: 'Columbus', population: 11799448, funFact: 'Birthplace of seven US presidents', points: [Vector2(-84.8, 42), Vector2(-80.5, 42), Vector2(-80.5, 39), Vector2(-84, 38.5), Vector2(-84.8, 39.5), Vector2(-84.8, 42)]),
    RegionalArea(code: 'GA', name: 'Georgia', capital: 'Atlanta', population: 10711908, funFact: 'Produces more peanuts than any other US state', points: [Vector2(-85.6, 35), Vector2(-83.1, 35), Vector2(-81, 32), Vector2(-81, 30.5), Vector2(-85.6, 30.5), Vector2(-85.6, 35)]),
    RegionalArea(code: 'NC', name: 'North Carolina', capital: 'Raleigh', population: 10439388, funFact: 'Site of the first powered airplane flight in 1903', points: [Vector2(-84.3, 36.6), Vector2(-75.5, 36.6), Vector2(-75.5, 34), Vector2(-78, 33.8), Vector2(-83, 35), Vector2(-84.3, 35), Vector2(-84.3, 36.6)]),
    RegionalArea(code: 'MI', name: 'Michigan', capital: 'Lansing', population: 10077331, funFact: 'Bordered by four of the five Great Lakes', points: [Vector2(-90.4, 48), Vector2(-84.4, 46.5), Vector2(-82.5, 43), Vector2(-82.5, 41.7), Vector2(-87, 42), Vector2(-88.5, 45.5), Vector2(-90.4, 48)]),
    RegionalArea(code: 'NJ', name: 'New Jersey', capital: 'Trenton', population: 9288994, funFact: 'Home of the first drive-in movie theater', points: [Vector2(-75.6, 41.4), Vector2(-74, 41.4), Vector2(-74, 40), Vector2(-74, 38.9), Vector2(-75.6, 39.5), Vector2(-75.6, 41.4)]),
    RegionalArea(code: 'VA', name: 'Virginia', capital: 'Richmond', population: 8631393, funFact: 'Birthplace of more US presidents than any other state', points: [Vector2(-83.7, 39.5), Vector2(-77, 39.3), Vector2(-75.2, 38), Vector2(-76, 36.5), Vector2(-83.7, 36.5), Vector2(-83.7, 39.5)]),
    RegionalArea(code: 'WA', name: 'Washington', capital: 'Olympia', population: 7614893, funFact: 'Produces over 60% of all US apples', points: [Vector2(-124.8, 49), Vector2(-117, 49), Vector2(-117, 46), Vector2(-124, 46), Vector2(-124.8, 47.5), Vector2(-124.8, 49)]),
    RegionalArea(code: 'AZ', name: 'Arizona', capital: 'Phoenix', population: 7278717, funFact: 'Home to the Grand Canyon, over 6 million years old', points: [Vector2(-114.8, 37), Vector2(-109, 37), Vector2(-109, 31.3), Vector2(-111.1, 31.3), Vector2(-114.7, 32.7), Vector2(-114.8, 37)]),
    RegionalArea(code: 'MA', name: 'Massachusetts', capital: 'Boston', population: 7029917, funFact: 'Home to the first public park in America, Boston Common', points: [Vector2(-73.5, 42.8), Vector2(-70, 42.8), Vector2(-70, 41.2), Vector2(-71.4, 41), Vector2(-73.5, 42), Vector2(-73.5, 42.8)]),
    RegionalArea(code: 'TN', name: 'Tennessee', capital: 'Nashville', population: 6910840, funFact: 'Nashville is the country music capital of the world', points: [Vector2(-90.3, 36.5), Vector2(-81.7, 36.6), Vector2(-81.7, 35), Vector2(-90.3, 35), Vector2(-90.3, 36.5)]),
    RegionalArea(code: 'IN', name: 'Indiana', capital: 'Indianapolis', population: 6785528, funFact: 'Hosts the Indy 500, the largest single-day sporting event', points: [Vector2(-88.1, 41.8), Vector2(-84.8, 41.8), Vector2(-84.8, 38), Vector2(-88.1, 38), Vector2(-88.1, 41.8)]),
    RegionalArea(code: 'MO', name: 'Missouri', capital: 'Jefferson City', population: 6154913, funFact: 'Home to the tallest man-made monument in the US', points: [Vector2(-95.8, 40.6), Vector2(-89.1, 40.6), Vector2(-89.1, 36), Vector2(-95.8, 36), Vector2(-95.8, 40.6)]),
    RegionalArea(code: 'MD', name: 'Maryland', capital: 'Annapolis', population: 6177224, funFact: 'The official state sport is jousting', points: [Vector2(-79.5, 39.7), Vector2(-75.1, 39.7), Vector2(-75.1, 38), Vector2(-76.2, 37.9), Vector2(-79.5, 39.2), Vector2(-79.5, 39.7)]),
    RegionalArea(code: 'CO', name: 'Colorado', capital: 'Denver', population: 5773714, funFact: 'Has the highest average elevation of any US state', points: [Vector2(-109, 41), Vector2(-102, 41), Vector2(-102, 37), Vector2(-109, 37), Vector2(-109, 41)]),
    RegionalArea(code: 'WI', name: 'Wisconsin', capital: 'Madison', population: 5893718, funFact: 'Produces more cheese than any other US state', points: [Vector2(-92.9, 47), Vector2(-87, 47), Vector2(-87, 42.5), Vector2(-92.9, 42.5), Vector2(-92.9, 47)]),
    RegionalArea(code: 'MN', name: 'Minnesota', capital: 'Saint Paul', population: 5706494, funFact: 'Land of 10,000 Lakes actually has over 11,842 lakes', points: [Vector2(-97.2, 49), Vector2(-89.5, 49), Vector2(-89.5, 43.5), Vector2(-97.2, 43.5), Vector2(-97.2, 49)]),
    RegionalArea(code: 'SC', name: 'South Carolina', capital: 'Columbia', population: 5118425, funFact: 'Home to the first museum in America, founded 1773', points: [Vector2(-83.4, 35.2), Vector2(-79, 35.2), Vector2(-79, 32), Vector2(-83.4, 32), Vector2(-83.4, 35.2)]),
    RegionalArea(code: 'AL', name: 'Alabama', capital: 'Montgomery', population: 5024279, funFact: 'Home of the first 911 call in the US', points: [Vector2(-88.5, 35), Vector2(-85, 35), Vector2(-85, 30.2), Vector2(-88.5, 30.2), Vector2(-88.5, 35)]),
    RegionalArea(code: 'LA', name: 'Louisiana', capital: 'Baton Rouge', population: 4657757, funFact: 'Home to the longest bridge over water in the world', points: [Vector2(-94.1, 33), Vector2(-89, 33), Vector2(-89, 29), Vector2(-94.1, 29), Vector2(-94.1, 33)]),
    RegionalArea(code: 'KY', name: 'Kentucky', capital: 'Frankfort', population: 4505836, funFact: 'Produces 95% of the world bourbon whiskey', points: [Vector2(-89.6, 39.2), Vector2(-82, 39.2), Vector2(-82, 36.5), Vector2(-89.6, 36.5), Vector2(-89.6, 39.2)]),
    RegionalArea(code: 'OR', name: 'Oregon', capital: 'Salem', population: 4237256, funFact: 'Home to Crater Lake, the deepest lake in the US', points: [Vector2(-124.6, 46.3), Vector2(-116.5, 46.3), Vector2(-116.5, 42), Vector2(-124.6, 42), Vector2(-124.6, 46.3)]),
    RegionalArea(code: 'OK', name: 'Oklahoma', capital: 'Oklahoma City', population: 3959353, funFact: 'The state Capitol building sits on top of an oil field', points: [Vector2(-103, 37), Vector2(-94.4, 37), Vector2(-94.4, 33.6), Vector2(-103, 33.6), Vector2(-103, 37)]),
    RegionalArea(code: 'CT', name: 'Connecticut', capital: 'Hartford', population: 3605944, funFact: 'Home to the first hamburger, served in 1900', points: [Vector2(-73.7, 42.1), Vector2(-71.8, 42.1), Vector2(-71.8, 41), Vector2(-73.7, 41), Vector2(-73.7, 42.1)]),
    RegionalArea(code: 'UT', name: 'Utah', capital: 'Salt Lake City', population: 3271616, funFact: 'Home to five national parks known as the Mighty Five', points: [Vector2(-114.1, 42), Vector2(-109, 42), Vector2(-109, 37), Vector2(-114.1, 37), Vector2(-114.1, 42)]),
    RegionalArea(code: 'IA', name: 'Iowa', capital: 'Des Moines', population: 3190369, funFact: 'The only US state name that starts with two vowels', points: [Vector2(-96.6, 43.5), Vector2(-90.1, 43.5), Vector2(-90.1, 40.4), Vector2(-96.6, 40.4), Vector2(-96.6, 43.5)]),
    RegionalArea(code: 'NV', name: 'Nevada', capital: 'Carson City', population: 3104614, funFact: 'Has more mountain ranges than any other US state', points: [Vector2(-120, 42), Vector2(-114, 42), Vector2(-114, 35), Vector2(-120, 39), Vector2(-120, 42)]),
    RegionalArea(code: 'AR', name: 'Arkansas', capital: 'Little Rock', population: 3011524, funFact: 'Home to the only active diamond mine in the US', points: [Vector2(-94.6, 36.5), Vector2(-89.6, 36.5), Vector2(-89.6, 33), Vector2(-94.6, 33), Vector2(-94.6, 36.5)]),
    RegionalArea(code: 'MS', name: 'Mississippi', capital: 'Jackson', population: 2961279, funFact: 'Named after the largest river in North America', points: [Vector2(-91.7, 35), Vector2(-88, 35), Vector2(-88, 30), Vector2(-91.7, 30), Vector2(-91.7, 35)]),
    RegionalArea(code: 'KS', name: 'Kansas', capital: 'Topeka', population: 2937880, funFact: 'Scientists proved it is literally flatter than a pancake', points: [Vector2(-102, 40), Vector2(-94.6, 40), Vector2(-94.6, 37), Vector2(-102, 37), Vector2(-102, 40)]),
    RegionalArea(code: 'NM', name: 'New Mexico', capital: 'Santa Fe', population: 2117522, funFact: 'Home to Santa Fe, the oldest US state capital city', points: [Vector2(-109, 37), Vector2(-103, 37), Vector2(-103, 31.8), Vector2(-109, 31.8), Vector2(-109, 37)]),
    RegionalArea(code: 'NE', name: 'Nebraska', capital: 'Lincoln', population: 1961504, funFact: 'The only US state with a unicameral legislature', points: [Vector2(-104, 43), Vector2(-95.3, 43), Vector2(-95.3, 40), Vector2(-104, 40), Vector2(-104, 43)]),
    RegionalArea(code: 'ID', name: 'Idaho', capital: 'Boise', population: 1839106, funFact: 'Produces about one-third of all US potatoes', points: [Vector2(-117.2, 49), Vector2(-111, 49), Vector2(-111, 42), Vector2(-117.2, 42), Vector2(-117.2, 49)]),
    RegionalArea(code: 'WV', name: 'West Virginia', capital: 'Charleston', population: 1793716, funFact: 'Formed during the Civil War by splitting from Virginia', points: [Vector2(-82.6, 40.6), Vector2(-77.7, 40.6), Vector2(-77.7, 37.2), Vector2(-82.6, 37.2), Vector2(-82.6, 40.6)]),
    RegionalArea(code: 'HI', name: 'Hawaii', capital: 'Honolulu', population: 1455271, funFact: 'The only US state made entirely of islands', points: [Vector2(-160.2, 22.2), Vector2(-154.8, 22.2), Vector2(-154.8, 18.9), Vector2(-160.2, 18.9), Vector2(-160.2, 22.2)]),
    RegionalArea(code: 'NH', name: 'New Hampshire', capital: 'Concord', population: 1377529, funFact: 'First colony to declare independence from Britain', points: [Vector2(-72.6, 45.3), Vector2(-70.7, 45.3), Vector2(-70.7, 42.7), Vector2(-72.6, 42.7), Vector2(-72.6, 45.3)]),
    RegionalArea(code: 'ME', name: 'Maine', capital: 'Augusta', population: 1362359, funFact: 'Produces 99% of all wild blueberries in the US', points: [Vector2(-71.1, 47.5), Vector2(-67, 47.5), Vector2(-67, 43), Vector2(-71.1, 43), Vector2(-71.1, 47.5)]),
    RegionalArea(code: 'MT', name: 'Montana', capital: 'Helena', population: 1084225, funFact: 'Has more cattle than people', points: [Vector2(-116.1, 49), Vector2(-104, 49), Vector2(-104, 45), Vector2(-116.1, 45), Vector2(-116.1, 49)]),
    RegionalArea(code: 'RI', name: 'Rhode Island', capital: 'Providence', population: 1097379, funFact: 'The smallest US state by area at just 1,545 sq miles', points: [Vector2(-71.9, 42.1), Vector2(-71.1, 42.1), Vector2(-71.1, 41.1), Vector2(-71.9, 41.1), Vector2(-71.9, 42.1)]),
    RegionalArea(code: 'DE', name: 'Delaware', capital: 'Dover', population: 989948, funFact: 'The first state to ratify the US Constitution in 1787', points: [Vector2(-75.8, 39.8), Vector2(-75, 39.8), Vector2(-75, 38.4), Vector2(-75.8, 38.4), Vector2(-75.8, 39.8)]),
    RegionalArea(code: 'SD', name: 'South Dakota', capital: 'Pierre', population: 886667, funFact: 'Home to Mount Rushmore with its four 60-foot faces', points: [Vector2(-104.1, 46), Vector2(-96.4, 46), Vector2(-96.4, 42.5), Vector2(-104.1, 42.5), Vector2(-104.1, 46)]),
    RegionalArea(code: 'ND', name: 'North Dakota', capital: 'Bismarck', population: 779094, funFact: 'Produces more sunflowers than any other US state', points: [Vector2(-104.1, 49), Vector2(-96.6, 49), Vector2(-96.6, 45.9), Vector2(-104.1, 45.9), Vector2(-104.1, 49)]),
    RegionalArea(code: 'AK', name: 'Alaska', capital: 'Juneau', population: 733391, funFact: 'Larger than Texas, California, and Montana combined', points: [Vector2(-180, 71.5), Vector2(-130, 71.5), Vector2(-130, 54.5), Vector2(-180, 54.5), Vector2(-180, 71.5)]),
    RegionalArea(code: 'VT', name: 'Vermont', capital: 'Montpelier', population: 643077, funFact: 'Produces more maple syrup than any other US state', points: [Vector2(-73.4, 45.1), Vector2(-71.5, 45.1), Vector2(-71.5, 42.7), Vector2(-73.4, 42.7), Vector2(-73.4, 45.1)]),
    RegionalArea(code: 'WY', name: 'Wyoming', capital: 'Cheyenne', population: 576851, funFact: 'Home to Yellowstone, the first national park', points: [Vector2(-111.1, 45), Vector2(-104, 45), Vector2(-104, 41), Vector2(-111.1, 41), Vector2(-111.1, 45)]),
  ];

  // UK Counties - England (48), Scotland (33), Wales (13), N. Ireland (6) = 100
  static final List<RegionalArea> _ukCounties = [
    // England - Metropolitan Counties & Greater London
    RegionalArea(code: 'GLA', name: 'Greater London', capital: 'London', population: 8982000, funFact: 'Over 300 languages are spoken across the city', points: [Vector2(-0.5, 51.7), Vector2(0.3, 51.7), Vector2(0.3, 51.3), Vector2(-0.5, 51.3), Vector2(-0.5, 51.7)]),
    RegionalArea(code: 'WMD', name: 'West Midlands', capital: 'Birmingham', population: 2919600, funFact: 'Birmingham has more miles of canal than Venice', points: [Vector2(-2.2, 52.7), Vector2(-1.5, 52.7), Vector2(-1.5, 52.3), Vector2(-2.2, 52.3), Vector2(-2.2, 52.7)]),
    RegionalArea(code: 'GTM', name: 'Greater Manchester', capital: 'Manchester', population: 2835686, funFact: 'Where the first stored-program computer ran in 1948', points: [Vector2(-2.7, 53.7), Vector2(-2, 53.7), Vector2(-2, 53.3), Vector2(-2.7, 53.3), Vector2(-2.7, 53.7)]),
    RegionalArea(code: 'WYK', name: 'West Yorkshire', capital: 'Leeds', population: 2320214, funFact: 'Home to the Bronte sisters of literary fame', points: [Vector2(-2.2, 54), Vector2(-1.2, 54), Vector2(-1.2, 53.6), Vector2(-2.2, 53.6), Vector2(-2.2, 54)]),
    RegionalArea(code: 'MER', name: 'Merseyside', capital: 'Liverpool', population: 1436877, funFact: 'Birthplace of The Beatles in 1960', points: [Vector2(-3.2, 53.6), Vector2(-2.7, 53.6), Vector2(-2.7, 53.3), Vector2(-3.2, 53.3), Vector2(-3.2, 53.6)]),
    RegionalArea(code: 'SYK', name: 'South Yorkshire', capital: 'Sheffield', population: 1415946, funFact: 'Home to Sheffield FC, the oldest football club', points: [Vector2(-1.8, 53.6), Vector2(-1, 53.6), Vector2(-1, 53.3), Vector2(-1.8, 53.3), Vector2(-1.8, 53.6)]),
    RegionalArea(code: 'TWR', name: 'Tyne and Wear', capital: 'Newcastle', population: 1140545, funFact: 'Has seven bridges crossing the River Tyne', points: [Vector2(-1.8, 55.1), Vector2(-1.3, 55.1), Vector2(-1.3, 54.8), Vector2(-1.8, 54.8), Vector2(-1.8, 55.1)]),
    // England - Ceremonial Counties
    RegionalArea(code: 'KEN', name: 'Kent', capital: 'Maidstone', population: 1568623, funFact: 'Known as the Garden of England', points: [Vector2(0, 51.5), Vector2(1.4, 51.4), Vector2(1.4, 51), Vector2(0, 51), Vector2(0, 51.5)]),
    RegionalArea(code: 'ESS', name: 'Essex', capital: 'Chelmsford', population: 1477764, funFact: 'Home to Colchester, oldest recorded town in Britain', points: [Vector2(0, 52), Vector2(1.3, 52), Vector2(1.3, 51.5), Vector2(0, 51.5), Vector2(0, 52)]),
    RegionalArea(code: 'HAM', name: 'Hampshire', capital: 'Winchester', population: 1376316, funFact: 'Birthplace of the Royal Navy at Portsmouth', points: [Vector2(-1.8, 51.3), Vector2(-0.7, 51.3), Vector2(-0.7, 50.7), Vector2(-1.8, 50.7), Vector2(-1.8, 51.3)]),
    RegionalArea(code: 'LAN', name: 'Lancashire', capital: 'Preston', population: 1210053, funFact: 'Birthplace of fish and chips in the 1860s', points: [Vector2(-3, 54.2), Vector2(-2, 54.2), Vector2(-2, 53.6), Vector2(-3, 53.6), Vector2(-3, 54.2)]),
    RegionalArea(code: 'SRY', name: 'Surrey', capital: 'Guildford', population: 1185329, funFact: 'One of the most wooded counties in England', points: [Vector2(-0.8, 51.5), Vector2(0, 51.5), Vector2(0, 51.1), Vector2(-0.8, 51.1), Vector2(-0.8, 51.5)]),
    RegionalArea(code: 'HRT', name: 'Hertfordshire', capital: 'Hertford', population: 1184365, funFact: 'Home to the studios where Harry Potter was filmed', points: [Vector2(-0.6, 52.1), Vector2(0.2, 52.1), Vector2(0.2, 51.7), Vector2(-0.6, 51.7), Vector2(-0.6, 52.1)]),
    RegionalArea(code: 'NFO', name: 'Norfolk', capital: 'Norwich', population: 903680, funFact: 'Has more medieval churches than any English county', points: [Vector2(0.1, 53), Vector2(1.8, 53), Vector2(1.8, 52.3), Vector2(0.1, 52.3), Vector2(0.1, 53)]),
    RegionalArea(code: 'DEV', name: 'Devon', capital: 'Exeter', population: 795286, funFact: 'Home to both Dartmoor and Exmoor national parks', points: [Vector2(-4.7, 51.3), Vector2(-3, 51.3), Vector2(-3, 50.2), Vector2(-4.7, 50.2), Vector2(-4.7, 51.3)]),
    RegionalArea(code: 'SOM', name: 'Somerset', capital: 'Taunton', population: 560619, funFact: 'Home to Cheddar Gorge, origin of cheddar cheese', points: [Vector2(-3.8, 51.4), Vector2(-2.3, 51.4), Vector2(-2.3, 50.9), Vector2(-3.8, 50.9), Vector2(-3.8, 51.4)]),
    RegionalArea(code: 'SUF', name: 'Suffolk', capital: 'Ipswich', population: 761350, funFact: 'Birthplace of painter Thomas Gainsborough', points: [Vector2(0.3, 52.5), Vector2(1.8, 52.5), Vector2(1.8, 52), Vector2(0.3, 52), Vector2(0.3, 52.5)]),
    RegionalArea(code: 'NTH', name: 'Northamptonshire', capital: 'Northampton', population: 747622, funFact: 'Historic shoemaking capital of England', points: [Vector2(-1.3, 52.6), Vector2(-0.3, 52.6), Vector2(-0.3, 52), Vector2(-1.3, 52), Vector2(-1.3, 52.6)]),
    RegionalArea(code: 'OXF', name: 'Oxfordshire', capital: 'Oxford', population: 687524, funFact: 'Home to the oldest English-speaking university', points: [Vector2(-1.7, 52.1), Vector2(-1, 52.1), Vector2(-1, 51.5), Vector2(-1.7, 51.5), Vector2(-1.7, 52.1)]),
    RegionalArea(code: 'DER', name: 'Derbyshire', capital: 'Derby', population: 802694, funFact: 'Contains most of the Peak District National Park', points: [Vector2(-2, 53.5), Vector2(-1.2, 53.5), Vector2(-1.2, 52.8), Vector2(-2, 52.8), Vector2(-2, 53.5)]),
    RegionalArea(code: 'NOT', name: 'Nottinghamshire', capital: 'Nottingham', population: 826659, funFact: 'Legendary home of Robin Hood', points: [Vector2(-1.3, 53.4), Vector2(-0.7, 53.4), Vector2(-0.7, 52.8), Vector2(-1.3, 52.8), Vector2(-1.3, 53.4)]),
    RegionalArea(code: 'STS', name: 'Staffordshire', capital: 'Stafford', population: 879560, funFact: 'Birthplace of the modern pottery industry', points: [Vector2(-2.5, 53.2), Vector2(-1.6, 53.2), Vector2(-1.6, 52.5), Vector2(-2.5, 52.5), Vector2(-2.5, 53.2)]),
    RegionalArea(code: 'LEI', name: 'Leicestershire', capital: 'Leicester', population: 713022, funFact: 'Where Richard III was found under a car park in 2012', points: [Vector2(-1.6, 52.9), Vector2(-0.7, 52.9), Vector2(-0.7, 52.4), Vector2(-1.6, 52.4), Vector2(-1.6, 52.9)]),
    RegionalArea(code: 'LIN', name: 'Lincolnshire', capital: 'Lincoln', population: 765996, funFact: 'Lincoln Cathedral was once the tallest building on Earth', points: [Vector2(-0.8, 53.6), Vector2(0.4, 53.6), Vector2(0.4, 52.7), Vector2(-0.8, 52.7), Vector2(-0.8, 53.6)]),
    RegionalArea(code: 'CAM', name: 'Cambridgeshire', capital: 'Cambridge', population: 684538, funFact: 'Home to a university with over 100 Nobel laureates', points: [Vector2(-0.3, 52.7), Vector2(0.5, 52.7), Vector2(0.5, 52), Vector2(-0.3, 52), Vector2(-0.3, 52.7)]),
    RegionalArea(code: 'GLO', name: 'Gloucestershire', capital: 'Gloucester', population: 637070, funFact: 'Hosts an annual cheese-rolling race down a steep hill', points: [Vector2(-2.7, 52.1), Vector2(-1.6, 52.1), Vector2(-1.6, 51.5), Vector2(-2.7, 51.5), Vector2(-2.7, 52.1)]),
    RegionalArea(code: 'WOR', name: 'Worcestershire', capital: 'Worcester', population: 592057, funFact: 'Birthplace of the famous Worcestershire sauce', points: [Vector2(-2.5, 52.5), Vector2(-1.8, 52.5), Vector2(-1.8, 52), Vector2(-2.5, 52), Vector2(-2.5, 52.5)]),
    RegionalArea(code: 'DOR', name: 'Dorset', capital: 'Dorchester', population: 425266, funFact: 'Has the Jurassic Coast, a 185-million-year-old shoreline', points: [Vector2(-3, 51), Vector2(-1.9, 51), Vector2(-1.9, 50.5), Vector2(-3, 50.5), Vector2(-3, 51)]),
    RegionalArea(code: 'WIL', name: 'Wiltshire', capital: 'Trowbridge', population: 498064, funFact: 'Home to Stonehenge, built around 3000 BC', points: [Vector2(-2.4, 51.7), Vector2(-1.5, 51.7), Vector2(-1.5, 51), Vector2(-2.4, 51), Vector2(-2.4, 51.7)]),
    RegionalArea(code: 'BKM', name: 'Buckinghamshire', capital: 'Aylesbury', population: 546024, funFact: 'Home to Bletchley Park, the WWII code-breaking HQ', points: [Vector2(-1.2, 52.1), Vector2(-0.5, 52.1), Vector2(-0.5, 51.5), Vector2(-1.2, 51.5), Vector2(-1.2, 52.1)]),
    RegionalArea(code: 'BED', name: 'Bedfordshire', capital: 'Bedford', population: 682327, funFact: 'Home to Whipsnade Zoo, the largest zoo in the UK', points: [Vector2(-0.7, 52.3), Vector2(-0.1, 52.3), Vector2(-0.1, 51.9), Vector2(-0.7, 51.9), Vector2(-0.7, 52.3)]),
    RegionalArea(code: 'SHR', name: 'Shropshire', capital: 'Shrewsbury', population: 323136, funFact: 'Birthplace of the Industrial Revolution at Ironbridge', points: [Vector2(-3.2, 52.9), Vector2(-2.3, 52.9), Vector2(-2.3, 52.3), Vector2(-3.2, 52.3), Vector2(-3.2, 52.9)]),
    RegionalArea(code: 'NYK', name: 'North Yorkshire', capital: 'Northallerton', population: 618054, funFact: 'The largest county in England by area', points: [Vector2(-2.4, 54.5), Vector2(-0.8, 54.5), Vector2(-0.8, 53.9), Vector2(-2.4, 53.9), Vector2(-2.4, 54.5)]),
    RegionalArea(code: 'CMA', name: 'Cumbria', capital: 'Carlisle', population: 499858, funFact: 'Home to Scafell Pike, the highest peak in England', points: [Vector2(-3.6, 55.2), Vector2(-2.1, 55.2), Vector2(-2.1, 54.1), Vector2(-3.6, 54.1), Vector2(-3.6, 55.2)]),
    RegionalArea(code: 'COR', name: 'Cornwall', capital: 'Truro', population: 568210, funFact: 'Has its own Celtic language, Cornish', points: [Vector2(-5.7, 50.8), Vector2(-4.5, 50.8), Vector2(-4.5, 50), Vector2(-5.7, 50), Vector2(-5.7, 50.8)]),
    RegionalArea(code: 'NBL', name: 'Northumberland', capital: 'Morpeth', population: 322434, funFact: 'Has the darkest skies in England for stargazing', points: [Vector2(-2.7, 55.8), Vector2(-1.5, 55.8), Vector2(-1.5, 54.9), Vector2(-2.7, 54.9), Vector2(-2.7, 55.8)]),
    RegionalArea(code: 'DUR', name: 'County Durham', capital: 'Durham', population: 530094, funFact: 'Durham Cathedral inspired the Hogwarts Great Hall', points: [Vector2(-2.3, 55), Vector2(-1.3, 55), Vector2(-1.3, 54.4), Vector2(-2.3, 54.4), Vector2(-2.3, 55)]),
    RegionalArea(code: 'ERY', name: 'East Riding of Yorkshire', capital: 'Beverley', population: 341173, funFact: 'Home to the Humber Bridge, once the longest in the world', points: [Vector2(-1, 54.1), Vector2(0.1, 54.1), Vector2(0.1, 53.6), Vector2(-1, 53.6), Vector2(-1, 54.1)]),
    RegionalArea(code: 'SSX', name: 'East Sussex', capital: 'Lewes', population: 553985, funFact: 'Home to the famous white chalk cliffs of Beachy Head', points: [Vector2(-0.2, 51.1), Vector2(0.9, 51.1), Vector2(0.9, 50.7), Vector2(-0.2, 50.7), Vector2(-0.2, 51.1)]),
    RegionalArea(code: 'WSX', name: 'West Sussex', capital: 'Chichester', population: 858852, funFact: 'Home to Gatwick, the second-busiest UK airport', points: [Vector2(-0.9, 51.2), Vector2(-0.1, 51.2), Vector2(-0.1, 50.7), Vector2(-0.9, 50.7), Vector2(-0.9, 51.2)]),
    RegionalArea(code: 'BRK', name: 'Berkshire', capital: 'Reading', population: 911403, funFact: 'Home to Windsor Castle, the largest occupied castle', points: [Vector2(-1.5, 51.6), Vector2(-0.6, 51.6), Vector2(-0.6, 51.3), Vector2(-1.5, 51.3), Vector2(-1.5, 51.6)]),
    RegionalArea(code: 'CHE', name: 'Cheshire', capital: 'Chester', population: 753512, funFact: 'Chester has the most complete city walls in England', points: [Vector2(-3.1, 53.4), Vector2(-2.1, 53.4), Vector2(-2.1, 53), Vector2(-3.1, 53), Vector2(-3.1, 53.4)]),
    RegionalArea(code: 'WAR', name: 'Warwickshire', capital: 'Warwick', population: 580987, funFact: 'Birthplace of William Shakespeare in 1564', points: [Vector2(-1.9, 52.6), Vector2(-1.2, 52.6), Vector2(-1.2, 52.1), Vector2(-1.9, 52.1), Vector2(-1.9, 52.6)]),
    RegionalArea(code: 'HEF', name: 'Herefordshire', capital: 'Hereford', population: 192107, funFact: 'Home to the Mappa Mundi, a medieval map from 1300', points: [Vector2(-3.1, 52.4), Vector2(-2.3, 52.4), Vector2(-2.3, 51.9), Vector2(-3.1, 51.9), Vector2(-3.1, 52.4)]),
    RegionalArea(code: 'RUT', name: 'Rutland', capital: 'Oakham', population: 40476, funFact: 'The smallest historic county in England', points: [Vector2(-0.8, 52.8), Vector2(-0.5, 52.8), Vector2(-0.5, 52.5), Vector2(-0.8, 52.5), Vector2(-0.8, 52.8)]),
    RegionalArea(code: 'IOW', name: 'Isle of Wight', capital: 'Newport', population: 142256, funFact: 'The largest island in England', points: [Vector2(-1.6, 50.8), Vector2(-1.1, 50.8), Vector2(-1.1, 50.6), Vector2(-1.6, 50.6), Vector2(-1.6, 50.8)]),
    // Scotland - Council Areas (33)
    RegionalArea(code: 'GLG', name: 'Glasgow City', capital: 'Glasgow', population: 635640, funFact: 'Known as one of the friendliest cities in the world', points: [Vector2(-4.5, 56), Vector2(-4, 56), Vector2(-4, 55.8), Vector2(-4.5, 55.8), Vector2(-4.5, 56)]),
    RegionalArea(code: 'EDH', name: 'City of Edinburgh', capital: 'Edinburgh', population: 524930, funFact: 'Inspired J.K. Rowling while she wrote Harry Potter', points: [Vector2(-3.4, 56), Vector2(-3, 56), Vector2(-3, 55.9), Vector2(-3.4, 55.9), Vector2(-3.4, 56)]),
    RegionalArea(code: 'FIF', name: 'Fife', capital: 'Glenrothes', population: 373550, funFact: 'Home to St Andrews, the birthplace of golf', points: [Vector2(-3.5, 56.4), Vector2(-2.7, 56.4), Vector2(-2.7, 56), Vector2(-3.5, 56), Vector2(-3.5, 56.4)]),
    RegionalArea(code: 'NLK', name: 'North Lanarkshire', capital: 'Motherwell', population: 341370, funFact: 'Once the center of the Scottish steel industry', points: [Vector2(-4.2, 56), Vector2(-3.7, 56), Vector2(-3.7, 55.7), Vector2(-4.2, 55.7), Vector2(-4.2, 56)]),
    RegionalArea(code: 'SLK', name: 'South Lanarkshire', capital: 'Hamilton', population: 320530, funFact: 'Home to New Lanark, a UNESCO World Heritage village', points: [Vector2(-4.3, 55.8), Vector2(-3.5, 55.8), Vector2(-3.5, 55.4), Vector2(-4.3, 55.4), Vector2(-4.3, 55.8)]),
    RegionalArea(code: 'ABE', name: 'Aberdeen City', capital: 'Aberdeen', population: 228670, funFact: 'Known as the Granite City for its stone buildings', points: [Vector2(-2.3, 57.2), Vector2(-2, 57.2), Vector2(-2, 57.1), Vector2(-2.3, 57.1), Vector2(-2.3, 57.2)]),
    RegionalArea(code: 'HLD', name: 'Highland', capital: 'Inverness', population: 235540, funFact: 'Home to Loch Ness and its legendary monster', points: [Vector2(-7, 58.5), Vector2(-3.5, 58.5), Vector2(-3.5, 56.5), Vector2(-7, 56.5), Vector2(-7, 58.5)]),
    RegionalArea(code: 'RFW', name: 'Renfrewshire', capital: 'Paisley', population: 179100, funFact: 'Home to Paisley, origin of the famous Paisley pattern', points: [Vector2(-4.7, 55.95), Vector2(-4.3, 55.95), Vector2(-4.3, 55.75), Vector2(-4.7, 55.75), Vector2(-4.7, 55.95)]),
    RegionalArea(code: 'WDU', name: 'West Dunbartonshire', capital: 'Dumbarton', population: 89130, funFact: 'Home to Dumbarton Castle, fortified for 1,500 years', points: [Vector2(-4.7, 56.1), Vector2(-4.4, 56.1), Vector2(-4.4, 55.9), Vector2(-4.7, 55.9), Vector2(-4.7, 56.1)]),
    RegionalArea(code: 'EDU', name: 'East Dunbartonshire', capital: 'Kirkintilloch', population: 108750, funFact: 'Part of the Antonine Wall UNESCO World Heritage Site', points: [Vector2(-4.4, 56.1), Vector2(-4.1, 56.1), Vector2(-4.1, 55.9), Vector2(-4.4, 55.9), Vector2(-4.4, 56.1)]),
    RegionalArea(code: 'DGY', name: 'Dumfries and Galloway', capital: 'Dumfries', population: 148790, funFact: 'Where poet Robert Burns spent his final years', points: [Vector2(-5.1, 55.4), Vector2(-3, 55.4), Vector2(-3, 54.8), Vector2(-5.1, 54.8), Vector2(-5.1, 55.4)]),
    RegionalArea(code: 'SCB', name: 'Scottish Borders', capital: 'Newtown St Boswells', population: 115510, funFact: 'Home to more ruined abbeys than anywhere in Scotland', points: [Vector2(-3.5, 55.8), Vector2(-2.1, 55.8), Vector2(-2.1, 55.4), Vector2(-3.5, 55.4), Vector2(-3.5, 55.8)]),
    RegionalArea(code: 'PKN', name: 'Perth and Kinross', capital: 'Perth', population: 151910, funFact: 'Once the ancient capital of Scotland', points: [Vector2(-4.5, 56.9), Vector2(-3.2, 56.9), Vector2(-3.2, 56.2), Vector2(-4.5, 56.2), Vector2(-4.5, 56.9)]),
    RegionalArea(code: 'ANS', name: 'Angus', capital: 'Forfar', population: 116520, funFact: 'Birthplace of the famous Angus cattle breed', points: [Vector2(-3.2, 56.9), Vector2(-2.4, 56.9), Vector2(-2.4, 56.5), Vector2(-3.2, 56.5), Vector2(-3.2, 56.9)]),
    RegionalArea(code: 'DND', name: 'Dundee City', capital: 'Dundee', population: 148710, funFact: 'Known as the City of Discovery for polar exploration', points: [Vector2(-3.1, 56.5), Vector2(-2.8, 56.5), Vector2(-2.8, 56.4), Vector2(-3.1, 56.4), Vector2(-3.1, 56.5)]),
    RegionalArea(code: 'STG', name: 'Stirling', capital: 'Stirling', population: 94080, funFact: 'Site of the Battle of Stirling Bridge in 1297', points: [Vector2(-4.5, 56.4), Vector2(-3.8, 56.4), Vector2(-3.8, 56), Vector2(-4.5, 56), Vector2(-4.5, 56.4)]),
    RegionalArea(code: 'FAL', name: 'Falkirk', capital: 'Falkirk', population: 160130, funFact: 'Home to the Falkirk Wheel, the only rotating boat lift', points: [Vector2(-3.9, 56.1), Vector2(-3.5, 56.1), Vector2(-3.5, 55.9), Vector2(-3.9, 55.9), Vector2(-3.9, 56.1)]),
    RegionalArea(code: 'CLK', name: 'Clackmannanshire', capital: 'Alloa', population: 51540, funFact: 'The smallest council area in mainland Scotland', points: [Vector2(-3.85, 56.2), Vector2(-3.7, 56.2), Vector2(-3.7, 56.1), Vector2(-3.85, 56.1), Vector2(-3.85, 56.2)]),
    RegionalArea(code: 'WLN', name: 'West Lothian', capital: 'Livingston', population: 183100, funFact: 'Birthplace of Mary Queen of Scots at Linlithgow', points: [Vector2(-3.7, 56), Vector2(-3.3, 56), Vector2(-3.3, 55.85), Vector2(-3.7, 55.85), Vector2(-3.7, 56)]),
    RegionalArea(code: 'MLN', name: 'Midlothian', capital: 'Dalkeith', population: 92460, funFact: 'Home to Rosslyn Chapel, featured in The Da Vinci Code', points: [Vector2(-3.2, 55.95), Vector2(-2.9, 55.95), Vector2(-2.9, 55.75), Vector2(-3.2, 55.75), Vector2(-3.2, 55.95)]),
    RegionalArea(code: 'ELN', name: 'East Lothian', capital: 'Haddington', population: 107090, funFact: 'Has more golf courses per head than anywhere on Earth', points: [Vector2(-3, 56.05), Vector2(-2.5, 56.05), Vector2(-2.5, 55.85), Vector2(-3, 55.85), Vector2(-3, 56.05)]),
    RegionalArea(code: 'ABD', name: 'Aberdeenshire', capital: 'Aberdeen', population: 261800, funFact: 'Has more castles per acre than anywhere in the UK', points: [Vector2(-3.5, 57.7), Vector2(-1.8, 57.7), Vector2(-1.8, 56.9), Vector2(-3.5, 56.9), Vector2(-3.5, 57.7)]),
    RegionalArea(code: 'MRY', name: 'Moray', capital: 'Elgin', population: 95520, funFact: 'Home to more Scotch whisky distilleries than anywhere', points: [Vector2(-4, 57.7), Vector2(-2.8, 57.7), Vector2(-2.8, 57.3), Vector2(-4, 57.3), Vector2(-4, 57.7)]),
    RegionalArea(code: 'AYR', name: 'East Ayrshire', capital: 'Kilmarnock', population: 122010, funFact: 'Birthplace of Alexander Fleming, penicillin discoverer', points: [Vector2(-4.6, 55.7), Vector2(-4.1, 55.7), Vector2(-4.1, 55.3), Vector2(-4.6, 55.3), Vector2(-4.6, 55.7)]),
    RegionalArea(code: 'NAY', name: 'North Ayrshire', capital: 'Irvine', population: 134250, funFact: 'Home to the Isle of Arran, Scotland in miniature', points: [Vector2(-5, 55.8), Vector2(-4.5, 55.8), Vector2(-4.5, 55.5), Vector2(-5, 55.5), Vector2(-5, 55.8)]),
    RegionalArea(code: 'SAY', name: 'South Ayrshire', capital: 'Ayr', population: 112140, funFact: 'Birthplace of poet Robert Burns in 1759', points: [Vector2(-5, 55.5), Vector2(-4.3, 55.5), Vector2(-4.3, 55.1), Vector2(-5, 55.1), Vector2(-5, 55.5)]),
    RegionalArea(code: 'INV', name: 'Inverclyde', capital: 'Greenock', population: 77800, funFact: 'Birthplace of James Watt, pioneer of the steam engine', points: [Vector2(-4.95, 55.95), Vector2(-4.7, 55.95), Vector2(-4.7, 55.85), Vector2(-4.95, 55.85), Vector2(-4.95, 55.95)]),
    RegionalArea(code: 'ERW', name: 'East Renfrewshire', capital: 'Giffnock', population: 95530, funFact: 'Regularly ranked the best place to live in Scotland', points: [Vector2(-4.5, 55.8), Vector2(-4.25, 55.8), Vector2(-4.25, 55.7), Vector2(-4.5, 55.7), Vector2(-4.5, 55.8)]),
    RegionalArea(code: 'ORK', name: 'Orkney Islands', capital: 'Kirkwall', population: 22270, funFact: 'Home to Skara Brae, a 5,000-year-old Neolithic village', points: [Vector2(-3.4, 59.4), Vector2(-2.4, 59.4), Vector2(-2.4, 58.7), Vector2(-3.4, 58.7), Vector2(-3.4, 59.4)]),
    RegionalArea(code: 'ZET', name: 'Shetland Islands', capital: 'Lerwick', population: 22870, funFact: 'Closer to Norway than to Edinburgh', points: [Vector2(-1.7, 60.9), Vector2(-0.7, 60.9), Vector2(-0.7, 59.9), Vector2(-1.7, 59.9), Vector2(-1.7, 60.9)]),
    RegionalArea(code: 'EIL', name: 'Eilean Siar', capital: 'Stornoway', population: 26830, funFact: 'One of the last strongholds of Scottish Gaelic', points: [Vector2(-7.7, 58.5), Vector2(-6.1, 58.5), Vector2(-6.1, 57), Vector2(-7.7, 57), Vector2(-7.7, 58.5)]),
    RegionalArea(code: 'ARG', name: 'Argyll and Bute', capital: 'Lochgilphead', population: 86260, funFact: 'Has the longest coastline of any Scottish council area', points: [Vector2(-6.5, 56.5), Vector2(-4.7, 56.5), Vector2(-4.7, 55.5), Vector2(-6.5, 55.5), Vector2(-6.5, 56.5)]),
    // Wales - Principal Areas (13)
    RegionalArea(code: 'CRF', name: 'Cardiff', capital: 'Cardiff', population: 362756, funFact: 'The youngest capital city in Europe', points: [Vector2(-3.3, 51.55), Vector2(-3.1, 51.55), Vector2(-3.1, 51.45), Vector2(-3.3, 51.45), Vector2(-3.3, 51.55)]),
    RegionalArea(code: 'SWA', name: 'Swansea', capital: 'Swansea', population: 246563, funFact: 'Birthplace of poet Dylan Thomas', points: [Vector2(-4.2, 51.7), Vector2(-3.85, 51.7), Vector2(-3.85, 51.55), Vector2(-4.2, 51.55), Vector2(-4.2, 51.7)]),
    RegionalArea(code: 'NWP', name: 'Newport', capital: 'Newport', population: 151500, funFact: 'Home to a medieval ship found under a shopping center', points: [Vector2(-3.1, 51.65), Vector2(-2.9, 51.65), Vector2(-2.9, 51.55), Vector2(-3.1, 51.55), Vector2(-3.1, 51.65)]),
    RegionalArea(code: 'RCT', name: 'Rhondda Cynon Taf', capital: 'Clydach Vale', population: 241873, funFact: 'Once the coal-mining heart of South Wales', points: [Vector2(-3.6, 51.75), Vector2(-3.25, 51.75), Vector2(-3.25, 51.55), Vector2(-3.6, 51.55), Vector2(-3.6, 51.75)]),
    RegionalArea(code: 'CAY', name: 'Caerphilly', capital: 'Caerphilly', population: 181019, funFact: 'Home to the largest castle in Wales by area', points: [Vector2(-3.3, 51.75), Vector2(-3.05, 51.75), Vector2(-3.05, 51.55), Vector2(-3.3, 51.55), Vector2(-3.3, 51.75)]),
    RegionalArea(code: 'FLN', name: 'Flintshire', capital: 'Mold', population: 155593, funFact: 'Home to Ewloe Castle, hidden in woodland since 1257', points: [Vector2(-3.35, 53.3), Vector2(-3, 53.3), Vector2(-3, 53.05), Vector2(-3.35, 53.05), Vector2(-3.35, 53.3)]),
    RegionalArea(code: 'WRX', name: 'Wrexham', capital: 'Wrexham', population: 135957, funFact: 'Wrexham AFC is one of the oldest football clubs', points: [Vector2(-3.2, 53.15), Vector2(-2.85, 53.15), Vector2(-2.85, 52.9), Vector2(-3.2, 52.9), Vector2(-3.2, 53.15)]),
    RegionalArea(code: 'POW', name: 'Powys', capital: 'Llandrindod Wells', population: 133030, funFact: 'The most sparsely populated county in Wales', points: [Vector2(-3.9, 52.7), Vector2(-3, 52.7), Vector2(-3, 51.8), Vector2(-3.9, 51.8), Vector2(-3.9, 52.7)]),
    RegionalArea(code: 'GWN', name: 'Gwynedd', capital: 'Caernarfon', population: 124178, funFact: 'Home to Snowdon, the highest peak in Wales', points: [Vector2(-4.5, 53.2), Vector2(-3.6, 53.2), Vector2(-3.6, 52.6), Vector2(-4.5, 52.6), Vector2(-4.5, 53.2)]),
    RegionalArea(code: 'CRG', name: 'Ceredigion', capital: 'Aberaeron', population: 72895, funFact: 'Home to the National Library of Wales', points: [Vector2(-4.7, 52.5), Vector2(-3.7, 52.5), Vector2(-3.7, 52), Vector2(-4.7, 52), Vector2(-4.7, 52.5)]),
    RegionalArea(code: 'PEM', name: 'Pembrokeshire', capital: 'Haverfordwest', population: 125055, funFact: 'Has the only coastal national park in the UK', points: [Vector2(-5.3, 52.1), Vector2(-4.6, 52.1), Vector2(-4.6, 51.6), Vector2(-5.3, 51.6), Vector2(-5.3, 52.1)]),
    RegionalArea(code: 'CMN', name: 'Carmarthenshire', capital: 'Carmarthen', population: 188771, funFact: 'Legendary birthplace of the wizard Merlin', points: [Vector2(-4.6, 52.2), Vector2(-3.6, 52.2), Vector2(-3.6, 51.7), Vector2(-4.6, 51.7), Vector2(-4.6, 52.2)]),
    RegionalArea(code: 'AGY', name: 'Isle of Anglesey', capital: 'Llangefni', population: 69961, funFact: 'Has a village with the longest place name in Europe', points: [Vector2(-4.7, 53.45), Vector2(-4.05, 53.45), Vector2(-4.05, 53.15), Vector2(-4.7, 53.15), Vector2(-4.7, 53.45)]),
    // Northern Ireland - Counties (6)
    RegionalArea(code: 'ANT', name: 'County Antrim', capital: 'Belfast', population: 618100, funFact: 'Home to the famous Giant Causeway rock formation', points: [Vector2(-6.5, 55.2), Vector2(-5.7, 55.2), Vector2(-5.7, 54.5), Vector2(-6.5, 54.5), Vector2(-6.5, 55.2)]),
    RegionalArea(code: 'ARM', name: 'County Armagh', capital: 'Armagh', population: 174792, funFact: 'Known as the Orchard County for its apple trees', points: [Vector2(-6.9, 54.5), Vector2(-6.3, 54.5), Vector2(-6.3, 54.1), Vector2(-6.9, 54.1), Vector2(-6.9, 54.5)]),
    RegionalArea(code: 'DOW', name: 'County Down', capital: 'Downpatrick', population: 531665, funFact: 'Said to be the burial place of St. Patrick', points: [Vector2(-6.1, 54.6), Vector2(-5.4, 54.6), Vector2(-5.4, 54.1), Vector2(-6.1, 54.1), Vector2(-6.1, 54.6)]),
    RegionalArea(code: 'FER', name: 'County Fermanagh', capital: 'Enniskillen', population: 64740, funFact: 'One-third of the county is covered by water', points: [Vector2(-8.2, 54.6), Vector2(-7.2, 54.6), Vector2(-7.2, 54.1), Vector2(-8.2, 54.1), Vector2(-8.2, 54.6)]),
    RegionalArea(code: 'LDY', name: 'County Londonderry', capital: 'Derry', population: 247132, funFact: 'Has one of the best-preserved walled cities in Europe', points: [Vector2(-7.5, 55.2), Vector2(-6.5, 55.2), Vector2(-6.5, 54.7), Vector2(-7.5, 54.7), Vector2(-7.5, 55.2)]),
    RegionalArea(code: 'TYR', name: 'County Tyrone', capital: 'Omagh', population: 177986, funFact: 'Largest county in Northern Ireland by area', points: [Vector2(-7.9, 54.9), Vector2(-6.6, 54.9), Vector2(-6.6, 54.3), Vector2(-7.9, 54.3), Vector2(-7.9, 54.9)]),
  ];

  // Caribbean Islands
  static final List<RegionalArea> _caribbeanIslands = [
    RegionalArea(code: 'CU', name: 'Cuba', capital: 'Havana', population: 11326616, funFact: 'Has the highest literacy rate in the Caribbean', points: [Vector2(-85, 22), Vector2(-84, 23.2), Vector2(-80, 23), Vector2(-75, 20.5), Vector2(-74.1, 20), Vector2(-77, 19.8), Vector2(-84.5, 21.5), Vector2(-85, 22)]),
    RegionalArea(code: 'JM', name: 'Jamaica', capital: 'Kingston', population: 2961167, funFact: 'Birthplace of reggae music', points: [Vector2(-78.4, 18.5), Vector2(-76, 18.5), Vector2(-76, 17.7), Vector2(-78.4, 17.7), Vector2(-78.4, 18.5)]),
    RegionalArea(code: 'HT', name: 'Haiti', capital: 'Port-au-Prince', population: 11402528, funFact: 'First Black republic, independent since 1804', points: [Vector2(-74.5, 20), Vector2(-72, 20), Vector2(-71.6, 18), Vector2(-74.5, 18), Vector2(-74.5, 20)]),
    RegionalArea(code: 'DO', name: 'Dominican Republic', capital: 'Santo Domingo', population: 10847910, funFact: 'Home to the oldest cathedral in the Americas', points: [Vector2(-72, 20), Vector2(-68.3, 19.8), Vector2(-68.3, 17.6), Vector2(-72, 17.6), Vector2(-72, 20)]),
    RegionalArea(code: 'PR', name: 'Puerto Rico', capital: 'San Juan', population: 3285874, funFact: 'Home to the only tropical rainforest in the US system', points: [Vector2(-67.3, 18.5), Vector2(-65.2, 18.5), Vector2(-65.2, 17.9), Vector2(-67.3, 17.9), Vector2(-67.3, 18.5)]),
    RegionalArea(code: 'BS', name: 'Bahamas', capital: 'Nassau', population: 393244, funFact: 'Where Columbus first landed in the Americas in 1492', points: [Vector2(-79.5, 27), Vector2(-74, 27), Vector2(-73, 21), Vector2(-77.5, 21), Vector2(-79.5, 27)]),
    RegionalArea(code: 'TT', name: 'Trinidad and Tobago', capital: 'Port of Spain', population: 1399488, funFact: 'Birthplace of the steel drum instrument', points: [Vector2(-61.9, 11), Vector2(-60.5, 11), Vector2(-60.5, 10), Vector2(-61.9, 10), Vector2(-61.9, 11)]),
    RegionalArea(code: 'BB', name: 'Barbados', capital: 'Bridgetown', population: 287375, funFact: 'Birthplace of rum, first distilled here in the 1600s', points: [Vector2(-59.7, 13.4), Vector2(-59.4, 13.4), Vector2(-59.4, 13.05), Vector2(-59.7, 13.05), Vector2(-59.7, 13.4)]),
    RegionalArea(code: 'LC', name: 'Saint Lucia', capital: 'Castries', population: 183627, funFact: 'The only country named after a woman', points: [Vector2(-61.1, 14.1), Vector2(-60.85, 14.1), Vector2(-60.85, 13.7), Vector2(-61.1, 13.7), Vector2(-61.1, 14.1)]),
    RegionalArea(code: 'VC', name: 'Saint Vincent', capital: 'Kingstown', population: 110940, funFact: 'A filming location for Pirates of the Caribbean', points: [Vector2(-61.3, 13.4), Vector2(-61.1, 13.4), Vector2(-61.1, 13.1), Vector2(-61.3, 13.1), Vector2(-61.3, 13.4)]),
    RegionalArea(code: 'GD', name: 'Grenada', capital: "St. George's", population: 112523, funFact: 'Known as the Spice Isle for its nutmeg production', points: [Vector2(-61.8, 12.3), Vector2(-61.6, 12.3), Vector2(-61.6, 12), Vector2(-61.8, 12), Vector2(-61.8, 12.3)]),
    RegionalArea(code: 'AG', name: 'Antigua and Barbuda', capital: "St. John's", population: 97929, funFact: 'Said to have a beach for every day of the year', points: [Vector2(-62, 17.75), Vector2(-61.65, 17.75), Vector2(-61.65, 17), Vector2(-62, 17), Vector2(-62, 17.75)]),
    RegionalArea(code: 'DM', name: 'Dominica', capital: 'Roseau', population: 71986, funFact: 'Home to the second-largest hot spring in the world', points: [Vector2(-61.5, 15.7), Vector2(-61.2, 15.7), Vector2(-61.2, 15.2), Vector2(-61.5, 15.2), Vector2(-61.5, 15.7)]),
    RegionalArea(code: 'KN', name: 'Saint Kitts and Nevis', capital: 'Basseterre', population: 53192, funFact: 'The smallest sovereign state in the Americas', points: [Vector2(-62.9, 17.45), Vector2(-62.5, 17.45), Vector2(-62.5, 17.05), Vector2(-62.9, 17.05), Vector2(-62.9, 17.45)]),
    RegionalArea(code: 'CW', name: 'Curaçao', capital: 'Willemstad', population: 155014, funFact: 'Gave its name to the famous blue liqueur', points: [Vector2(-69.2, 12.4), Vector2(-68.7, 12.4), Vector2(-68.7, 12.05), Vector2(-69.2, 12.05), Vector2(-69.2, 12.4)]),
    RegionalArea(code: 'AW', name: 'Aruba', capital: 'Oranjestad', population: 106766, funFact: 'One of the driest islands in the Caribbean', points: [Vector2(-70.1, 12.65), Vector2(-69.85, 12.65), Vector2(-69.85, 12.4), Vector2(-70.1, 12.4), Vector2(-70.1, 12.65)]),
  ];

  // All 32 Ireland Counties (26 Republic + 6 Northern Ireland)
  static final List<RegionalArea> _irelandCounties = [
    // Leinster (12 counties)
    RegionalArea(code: 'D', name: 'Dublin', capital: 'Dublin', population: 1426220, funFact: 'Home to the Book of Kells, a 1,200-year-old manuscript', points: [Vector2(-6.5, 53.5), Vector2(-6.05, 53.5), Vector2(-6.05, 53.2), Vector2(-6.5, 53.2), Vector2(-6.5, 53.5)]),
    RegionalArea(code: 'WW', name: 'Wicklow', capital: 'Wicklow', population: 142425, funFact: 'Known as the Garden of Ireland', points: [Vector2(-6.7, 53.2), Vector2(-6, 53.2), Vector2(-6, 52.8), Vector2(-6.7, 52.8), Vector2(-6.7, 53.2)]),
    RegionalArea(code: 'WX', name: 'Wexford', capital: 'Wexford', population: 149722, funFact: 'Home to one of the oldest towns in Ireland', points: [Vector2(-7, 52.7), Vector2(-6.2, 52.7), Vector2(-6.2, 52.15), Vector2(-7, 52.15), Vector2(-7, 52.7)]),
    RegionalArea(code: 'KK', name: 'Kilkenny', capital: 'Kilkenny', population: 99232, funFact: 'Once the medieval capital of Ireland', points: [Vector2(-7.6, 52.85), Vector2(-6.9, 52.85), Vector2(-6.9, 52.3), Vector2(-7.6, 52.3), Vector2(-7.6, 52.85)]),
    RegionalArea(code: 'CW', name: 'Carlow', capital: 'Carlow', population: 56932, funFact: 'One of the smallest counties in Ireland by area', points: [Vector2(-7.1, 52.9), Vector2(-6.6, 52.9), Vector2(-6.6, 52.5), Vector2(-7.1, 52.5), Vector2(-7.1, 52.9)]),
    RegionalArea(code: 'KE', name: 'Kildare', capital: 'Naas', population: 222504, funFact: 'Home to the Curragh, one of the oldest racecourses', points: [Vector2(-7.1, 53.4), Vector2(-6.5, 53.4), Vector2(-6.5, 53), Vector2(-7.1, 53), Vector2(-7.1, 53.4)]),
    RegionalArea(code: 'MH', name: 'Meath', capital: 'Navan', population: 195044, funFact: 'Home to Newgrange, older than the Egyptian pyramids', points: [Vector2(-7.3, 53.8), Vector2(-6.2, 53.8), Vector2(-6.2, 53.4), Vector2(-7.3, 53.4), Vector2(-7.3, 53.8)]),
    RegionalArea(code: 'WH', name: 'Westmeath', capital: 'Mullingar', population: 88770, funFact: 'Home to the geographic center of Ireland', points: [Vector2(-7.9, 53.7), Vector2(-7, 53.7), Vector2(-7, 53.3), Vector2(-7.9, 53.3), Vector2(-7.9, 53.7)]),
    RegionalArea(code: 'LS', name: 'Laois', capital: 'Portlaoise', population: 84697, funFact: 'Home to one of the first planned towns in Ireland', points: [Vector2(-7.9, 53.2), Vector2(-7.2, 53.2), Vector2(-7.2, 52.8), Vector2(-7.9, 52.8), Vector2(-7.9, 53.2)]),
    RegionalArea(code: 'OY', name: 'Offaly', capital: 'Tullamore', population: 77961, funFact: 'Home to Clonmacnoise, a famous early monastic site', points: [Vector2(-8.1, 53.4), Vector2(-7.3, 53.4), Vector2(-7.3, 53), Vector2(-8.1, 53), Vector2(-8.1, 53.4)]),
    RegionalArea(code: 'LD', name: 'Longford', capital: 'Longford', population: 40873, funFact: 'Birthplace of author Oliver Goldsmith', points: [Vector2(-8.1, 53.85), Vector2(-7.5, 53.85), Vector2(-7.5, 53.55), Vector2(-8.1, 53.55), Vector2(-8.1, 53.85)]),
    RegionalArea(code: 'LH', name: 'Louth', capital: 'Dundalk', population: 128884, funFact: 'The smallest county in Ireland by area', points: [Vector2(-6.6, 54.1), Vector2(-6.1, 54.1), Vector2(-6.1, 53.75), Vector2(-6.6, 53.75), Vector2(-6.6, 54.1)]),
    // Munster (6 counties)
    RegionalArea(code: 'C', name: 'Cork', capital: 'Cork', population: 542868, funFact: 'Largest county in Ireland, known as the Rebel County', points: [Vector2(-10, 52.2), Vector2(-8, 52.2), Vector2(-8, 51.4), Vector2(-10, 51.4), Vector2(-10, 52.2)]),
    RegionalArea(code: 'KY', name: 'Kerry', capital: 'Tralee', population: 147707, funFact: 'Home to Carrauntoohil, the highest peak in Ireland', points: [Vector2(-10.5, 52.5), Vector2(-9.2, 52.5), Vector2(-9.2, 51.75), Vector2(-10.5, 51.75), Vector2(-10.5, 52.5)]),
    RegionalArea(code: 'L', name: 'Limerick', capital: 'Limerick', population: 194899, funFact: 'Gave its name to the famous five-line limerick poem', points: [Vector2(-9.5, 52.8), Vector2(-8.3, 52.8), Vector2(-8.3, 52.3), Vector2(-9.5, 52.3), Vector2(-9.5, 52.8)]),
    RegionalArea(code: 'CE', name: 'Clare', capital: 'Ennis', population: 118817, funFact: 'Home to the Cliffs of Moher, 214 meters high', points: [Vector2(-10, 53.15), Vector2(-8.5, 53.15), Vector2(-8.5, 52.6), Vector2(-10, 52.6), Vector2(-10, 53.15)]),
    RegionalArea(code: 'T', name: 'Tipperary', capital: 'Clonmel', population: 159553, funFact: 'Home to the Rock of Cashel, seat of ancient kings', points: [Vector2(-8.5, 53), Vector2(-7.4, 53), Vector2(-7.4, 52.25), Vector2(-8.5, 52.25), Vector2(-8.5, 53)]),
    RegionalArea(code: 'W', name: 'Waterford', capital: 'Waterford', population: 116176, funFact: 'Oldest city in Ireland, founded by Vikings in 914', points: [Vector2(-8.1, 52.4), Vector2(-6.9, 52.4), Vector2(-6.9, 51.9), Vector2(-8.1, 51.9), Vector2(-8.1, 52.4)]),
    // Connacht (5 counties)
    RegionalArea(code: 'G', name: 'Galway', capital: 'Galway', population: 258058, funFact: 'Known as the City of the Tribes', points: [Vector2(-10.2, 53.6), Vector2(-8.2, 53.6), Vector2(-8.2, 53), Vector2(-10.2, 53), Vector2(-10.2, 53.6)]),
    RegionalArea(code: 'MO', name: 'Mayo', capital: 'Castlebar', population: 130507, funFact: 'Home to Croagh Patrick, a sacred pilgrimage mountain', points: [Vector2(-10.2, 54.1), Vector2(-9, 54.1), Vector2(-9, 53.5), Vector2(-10.2, 53.5), Vector2(-10.2, 54.1)]),
    RegionalArea(code: 'SO', name: 'Sligo', capital: 'Sligo', population: 65535, funFact: 'Known as Yeats Country after poet W.B. Yeats', points: [Vector2(-9, 54.4), Vector2(-8.1, 54.4), Vector2(-8.1, 53.9), Vector2(-9, 53.9), Vector2(-9, 54.4)]),
    RegionalArea(code: 'RN', name: 'Roscommon', capital: 'Roscommon', population: 64544, funFact: 'Home to Rathcroghan, legendary seat of Queen Medb', points: [Vector2(-8.8, 54), Vector2(-7.9, 54), Vector2(-7.9, 53.4), Vector2(-8.8, 53.4), Vector2(-8.8, 54)]),
    RegionalArea(code: 'LM', name: 'Leitrim', capital: 'Carrick-on-Shannon', population: 32044, funFact: 'The least populated county in Ireland', points: [Vector2(-8.5, 54.35), Vector2(-7.8, 54.35), Vector2(-7.8, 53.9), Vector2(-8.5, 53.9), Vector2(-8.5, 54.35)]),
    // Ulster - Republic of Ireland (3 counties)
    RegionalArea(code: 'DL', name: 'Donegal', capital: 'Lifford', population: 159192, funFact: 'The most northerly county on the island of Ireland', points: [Vector2(-8.7, 55.4), Vector2(-7, 55.4), Vector2(-7, 54.6), Vector2(-8.7, 54.6), Vector2(-8.7, 55.4)]),
    RegionalArea(code: 'CN', name: 'Cavan', capital: 'Cavan', population: 76176, funFact: 'Known as the Lake County with over 365 lakes', points: [Vector2(-8, 54.2), Vector2(-6.8, 54.2), Vector2(-6.8, 53.8), Vector2(-8, 53.8), Vector2(-8, 54.2)]),
    RegionalArea(code: 'MN', name: 'Monaghan', capital: 'Monaghan', population: 61386, funFact: 'Famous for its rolling drumlin hills landscape', points: [Vector2(-7.4, 54.4), Vector2(-6.5, 54.4), Vector2(-6.5, 53.9), Vector2(-7.4, 53.9), Vector2(-7.4, 54.4)]),
    // Ulster - Northern Ireland (6 counties)
    RegionalArea(code: 'ANT', name: 'Antrim', capital: 'Belfast', population: 618100, funFact: 'Home to 40,000 basalt columns at the Giant Causeway', points: [Vector2(-6.5, 55.2), Vector2(-5.7, 55.2), Vector2(-5.7, 54.5), Vector2(-6.5, 54.5), Vector2(-6.5, 55.2)]),
    RegionalArea(code: 'ARM', name: 'Armagh', capital: 'Armagh', population: 174792, funFact: 'Ecclesiastical capital of Ireland since St. Patrick', points: [Vector2(-6.9, 54.5), Vector2(-6.3, 54.5), Vector2(-6.3, 54.1), Vector2(-6.9, 54.1), Vector2(-6.9, 54.5)]),
    RegionalArea(code: 'DWN', name: 'Down', capital: 'Downpatrick', population: 531665, funFact: 'Where St. Patrick is said to be buried', points: [Vector2(-6.1, 54.6), Vector2(-5.4, 54.6), Vector2(-5.4, 54.1), Vector2(-6.1, 54.1), Vector2(-6.1, 54.6)]),
    RegionalArea(code: 'FRM', name: 'Fermanagh', capital: 'Enniskillen', population: 64740, funFact: 'Home to beautiful island-dotted Lough Erne', points: [Vector2(-8.2, 54.6), Vector2(-7.2, 54.6), Vector2(-7.2, 54.1), Vector2(-8.2, 54.1), Vector2(-8.2, 54.6)]),
    RegionalArea(code: 'LDY', name: 'Derry', capital: 'Derry', population: 247132, funFact: 'Has the most complete set of city walls in Ireland', points: [Vector2(-7.5, 55.2), Vector2(-6.5, 55.2), Vector2(-6.5, 54.7), Vector2(-7.5, 54.7), Vector2(-7.5, 55.2)]),
    RegionalArea(code: 'TYR', name: 'Tyrone', capital: 'Omagh', population: 177986, funFact: 'Largest of the six Northern Ireland counties', points: [Vector2(-7.9, 54.9), Vector2(-6.6, 54.9), Vector2(-6.6, 54.3), Vector2(-7.9, 54.3), Vector2(-7.9, 54.9)]),
  ];
}
