import 'package:flame/components.dart';

/// Geographic feature data for globe overlay rendering.
/// Sourced from OpenStreetMap and public domain datasets.
/// All coordinates are in decimal degrees (longitude, latitude).
abstract class OsmFeatures {
  // Major World Rivers (simplified polylines with 5-12 key waypoints)
  static final List<River> rivers = [
    River('Nile', [
      Vector2(32.5, -1.5), // Lake Victoria source
      Vector2(31.6, 2.3), // Uganda
      Vector2(31.2, 9.5), // South Sudan
      Vector2(32.5, 15.6), // Sudan
      Vector2(32.9, 21.5), // Egypt
      Vector2(31.2, 30.0), // Cairo
      Vector2(31.5, 31.2), // Delta
    ]),
    River('Amazon', [
      Vector2(-77.5, -5.2), // Peru source
      Vector2(-75.0, -4.5),
      Vector2(-73.0, -3.5),
      Vector2(-70.0, -3.2), // Brazil border
      Vector2(-65.0, -3.1),
      Vector2(-60.0, -3.0),
      Vector2(-55.0, -2.5),
      Vector2(-50.0, -1.5),
      Vector2(-48.5, -0.5), // Mouth
    ]),
    River('Mississippi', [
      Vector2(-93.5, 47.2), // Lake Itasca source
      Vector2(-93.1, 44.9), // Minneapolis
      Vector2(-91.2, 43.6),
      Vector2(-90.2, 38.6), // St Louis
      Vector2(-91.1, 33.0),
      Vector2(-91.4, 30.5), // Baton Rouge
      Vector2(-89.9, 29.2), // Delta
    ]),
    River('Yangtze', [
      Vector2(91.2, 33.4), // Tibet source
      Vector2(97.5, 30.8),
      Vector2(102.0, 29.5),
      Vector2(106.5, 29.6), // Chongqing
      Vector2(111.3, 30.4), // Wuhan
      Vector2(117.2, 31.4),
      Vector2(121.5, 31.2), // Shanghai
    ]),
    River('Danube', [
      Vector2(8.2, 47.8), // Black Forest source
      Vector2(10.2, 48.4), // Germany
      Vector2(13.0, 48.2), // Austria
      Vector2(16.4, 48.2), // Vienna
      Vector2(19.1, 47.5), // Budapest
      Vector2(21.2, 45.8), // Serbia
      Vector2(25.0, 44.5),
      Vector2(28.8, 44.4),
      Vector2(29.7, 45.2), // Delta
    ]),
    River('Rhine', [
      Vector2(8.6, 46.6), // Swiss Alps source
      Vector2(7.8, 47.6), // Basel
      Vector2(7.7, 48.6), // Strasbourg
      Vector2(8.2, 50.0), // Germany
      Vector2(6.8, 51.8), // Netherlands
      Vector2(4.5, 51.9), // Delta
    ]),
    River('Ganges', [
      Vector2(78.9, 30.9), // Gangotri glacier
      Vector2(78.2, 29.9),
      Vector2(77.4, 28.7),
      Vector2(81.8, 25.4), // Allahabad
      Vector2(83.0, 25.3), // Varanasi
      Vector2(88.4, 22.6), // Kolkata
      Vector2(89.6, 22.0), // Delta
    ]),
    River('Mekong', [
      Vector2(94.7, 33.8), // Tibet source
      Vector2(99.2, 28.0),
      Vector2(100.5, 20.3), // Myanmar/Laos
      Vector2(101.7, 17.4), // Laos
      Vector2(102.1, 14.8), // Thailand
      Vector2(105.0, 11.5), // Cambodia
      Vector2(106.7, 10.5), // Vietnam delta
    ]),
    River('Congo', [
      Vector2(26.4, -4.3), // Lualaba source
      Vector2(25.2, -3.5),
      Vector2(22.4, -2.5),
      Vector2(20.0, -1.5),
      Vector2(18.3, -0.5), // Brazzaville
      Vector2(16.5, -2.8),
      Vector2(14.2, -5.0),
      Vector2(12.4, -6.0), // Mouth
    ]),
    River('Niger', [
      Vector2(-9.2, 10.1), // Guinea source
      Vector2(-7.5, 12.5),
      Vector2(-4.2, 14.5), // Mali
      Vector2(-1.0, 16.3), // Timbuktu
      Vector2(3.5, 13.5), // Niger
      Vector2(6.5, 10.5), // Nigeria
      Vector2(6.4, 5.5), // Delta
    ]),
    River('Volga', [
      Vector2(32.5, 57.0), // Valdai Hills source
      Vector2(36.0, 56.9),
      Vector2(38.5, 56.3),
      Vector2(44.0, 56.3), // Kazan
      Vector2(46.1, 53.2), // Samara
      Vector2(48.0, 48.7), // Volgograd
      Vector2(47.5, 46.0), // Delta
    ]),
    River('Ob', [
      Vector2(85.0, 52.3), // Altai source
      Vector2(82.9, 55.0),
      Vector2(82.0, 58.0),
      Vector2(77.0, 61.0),
      Vector2(73.5, 64.5),
      Vector2(72.0, 66.5), // Mouth
    ]),
    River('Yenisei', [
      Vector2(97.5, 52.3), // Mongolia source
      Vector2(92.0, 52.3),
      Vector2(89.5, 56.0), // Krasnoyarsk
      Vector2(86.5, 61.0),
      Vector2(82.7, 66.5),
      Vector2(82.0, 71.5), // Mouth
    ]),
    River('Lena', [
      Vector2(108.0, 53.9), // Baikal source
      Vector2(112.0, 56.5),
      Vector2(120.0, 61.5), // Yakutsk
      Vector2(125.0, 66.0),
      Vector2(126.0, 70.0),
      Vector2(126.5, 73.0), // Delta
    ]),
    River('Amur', [
      Vector2(116.5, 53.3), // Mongolia/China source
      Vector2(121.5, 53.0),
      Vector2(127.5, 50.2), // China/Russia border
      Vector2(132.0, 48.5),
      Vector2(135.0, 48.0),
      Vector2(141.0, 52.9), // Mouth
    ]),
    River('Murray', [
      Vector2(148.2, -36.8), // Australian Alps
      Vector2(146.5, -36.0),
      Vector2(143.8, -34.2), // Mildura
      Vector2(140.5, -34.5),
      Vector2(139.0, -35.2), // Mouth
    ]),
    River('Colorado', [
      Vector2(-105.8, 40.5), // Rocky Mountains
      Vector2(-107.5, 39.1),
      Vector2(-109.5, 37.0), // Utah
      Vector2(-111.5, 36.9), // Grand Canyon
      Vector2(-113.5, 35.5),
      Vector2(-114.6, 32.7), // Mexico
      Vector2(-114.8, 31.8), // Delta
    ]),
    River('Columbia', [
      Vector2(-116.0, 50.3), // Canadian Rockies
      Vector2(-117.5, 48.5),
      Vector2(-119.0, 47.5), // Washington
      Vector2(-120.5, 46.2),
      Vector2(-123.0, 46.2), // Mouth
    ]),
    River('Rio Grande', [
      Vector2(-107.0, 37.8), // Colorado source
      Vector2(-106.5, 35.1), // Albuquerque
      Vector2(-106.0, 31.8), // El Paso
      Vector2(-102.0, 29.5),
      Vector2(-99.5, 27.5),
      Vector2(-97.2, 26.0), // Mouth
    ]),
    River('Euphrates', [
      Vector2(38.5, 39.5), // Turkey source
      Vector2(38.0, 37.5),
      Vector2(38.5, 36.0), // Syria
      Vector2(40.5, 34.5),
      Vector2(43.0, 33.3), // Iraq
      Vector2(47.5, 30.5), // Basra
    ]),
    River('Tigris', [
      Vector2(41.5, 38.5), // Turkey source
      Vector2(41.5, 37.0),
      Vector2(43.0, 36.3), // Mosul
      Vector2(44.4, 33.3), // Baghdad
      Vector2(46.0, 31.8),
      Vector2(47.7, 30.4), // Joins Euphrates
    ]),
    River('Indus', [
      Vector2(81.0, 31.5), // Tibet source
      Vector2(78.5, 32.5),
      Vector2(74.8, 34.0), // Pakistan
      Vector2(72.8, 32.5),
      Vector2(70.5, 28.5),
      Vector2(68.5, 25.0),
      Vector2(68.0, 24.0), // Delta
    ]),
    River('Brahmaputra', [
      Vector2(82.0, 30.5), // Tibet source
      Vector2(88.5, 29.0),
      Vector2(92.5, 27.5), // India
      Vector2(95.0, 26.0), // Assam
      Vector2(90.5, 24.5), // Bangladesh
      Vector2(90.0, 23.0), // Delta
    ]),
    River('Zambezi', [
      Vector2(24.0, -11.5), // Zambia source
      Vector2(26.0, -13.0),
      Vector2(27.5, -15.0),
      Vector2(28.5, -17.0), // Victoria Falls
      Vector2(32.0, -18.5),
      Vector2(35.5, -18.0),
      Vector2(36.5, -18.5), // Mouth
    ]),
    River('Orange', [
      Vector2(28.2, -28.8), // Lesotho source
      Vector2(25.0, -28.5),
      Vector2(22.0, -28.8),
      Vector2(19.0, -28.6),
      Vector2(17.0, -28.6), // Mouth
    ]),
    River('Mackenzie', [
      Vector2(-123.5, 60.0), // Great Slave Lake
      Vector2(-123.0, 62.5),
      Vector2(-125.0, 65.0),
      Vector2(-128.0, 67.5),
      Vector2(-133.5, 68.5),
      Vector2(-135.0, 69.3), // Delta
    ]),
    River('Paraná', [
      Vector2(-50.5, -20.5), // Brazil source
      Vector2(-51.5, -23.5),
      Vector2(-54.5, -25.5), // Argentina
      Vector2(-57.5, -27.5),
      Vector2(-58.5, -31.5), // Rosario
      Vector2(-58.5, -34.0), // Delta
    ]),
    River('Orinoco', [
      Vector2(-63.8, 2.3), // Venezuela source
      Vector2(-65.5, 4.5),
      Vector2(-67.5, 6.2),
      Vector2(-66.8, 8.1), // Ciudad Bolívar
      Vector2(-62.5, 8.5),
      Vector2(-60.5, 8.5), // Delta
    ]),
    River('Don', [
      Vector2(38.0, 53.5), // Russia source
      Vector2(39.5, 51.5),
      Vector2(40.0, 48.5),
      Vector2(39.3, 47.5), // Rostov
      Vector2(39.2, 47.1), // Mouth
    ]),
    River('Dnieper', [
      Vector2(33.5, 55.5), // Russia source
      Vector2(31.0, 52.0), // Belarus
      Vector2(30.5, 50.5), // Kiev
      Vector2(33.5, 48.5), // Ukraine
      Vector2(34.0, 47.0),
      Vector2(34.5, 46.5), // Mouth
    ]),
  ];

  // Major Lakes (center point + approximate radius in degrees)
  static final List<Lake> lakes = [
    Lake('Caspian Sea', Vector2(51.0, 40.0), 3.5),
    Lake('Lake Superior', Vector2(-87.5, 47.5), 1.5),
    Lake('Lake Victoria', Vector2(33.0, -1.5), 1.2),
    Lake('Lake Huron', Vector2(-82.5, 44.8), 1.2),
    Lake('Lake Michigan', Vector2(-87.0, 43.5), 1.5),
    Lake('Lake Tanganyika', Vector2(29.5, -6.0), 0.8),
    Lake('Lake Baikal', Vector2(107.5, 53.5), 0.7),
    Lake('Great Bear Lake', Vector2(-121.0, 66.0), 1.0),
    Lake('Lake Malawi', Vector2(34.5, -11.5), 0.8),
    Lake('Great Slave Lake', Vector2(-114.0, 62.0), 1.2),
    Lake('Lake Erie', Vector2(-81.0, 42.2), 0.8),
    Lake('Lake Ontario', Vector2(-77.5, 43.7), 0.7),
    Lake('Lake Winnipeg', Vector2(-97.5, 52.0), 0.8),
    Lake('Lake Ladoga', Vector2(31.0, 61.0), 0.6),
    Lake('Lake Balkhash', Vector2(74.5, 46.5), 0.8),
    Lake('Lake Chad', Vector2(14.0, 13.0), 0.5),
    Lake('Aral Sea', Vector2(59.5, 45.0), 0.6),
    Lake('Lake Titicaca', Vector2(-69.5, -15.8), 0.4),
    Lake('Lake Nicaragua', Vector2(-85.5, 11.5), 0.4),
    Lake('Lake Maracaibo', Vector2(-71.5, 9.5), 0.6),
  ];

  // Major Mountain Peaks (location + elevation in meters)
  static final List<Peak> peaks = [
    Peak('Mount Everest', Vector2(86.925, 27.988), 8849),
    Peak('K2', Vector2(76.513, 35.881), 8611),
    Peak('Kangchenjunga', Vector2(88.147, 27.703), 8586),
    Peak('Denali', Vector2(-151.007, 63.069), 6190),
    Peak('Mount Kilimanjaro', Vector2(37.353, -3.076), 5895),
    Peak('Mount Elbrus', Vector2(42.439, 43.353), 5642),
    Peak('Aconcagua', Vector2(-70.011, -32.653), 6961),
    Peak('Mount Vinson', Vector2(-85.617, -78.525), 4892),
    Peak('Mont Blanc', Vector2(6.865, 45.833), 4808),
    Peak('Matterhorn', Vector2(7.658, 45.977), 4478),
    Peak('Mount Fuji', Vector2(138.727, 35.361), 3776),
    Peak('Mount Olympus', Vector2(22.358, 40.086), 2918),
    Peak('Mount Rainier', Vector2(-121.758, 46.853), 4392),
    Peak('Mount Cook', Vector2(170.142, -43.595), 3724),
    Peak('Mount Logan', Vector2(-140.406, 60.567), 5959),
    Peak('Chimborazo', Vector2(-78.817, -1.469), 6263),
    Peak('Cotopaxi', Vector2(-78.436, -0.677), 5897),
    Peak('Popocatépetl', Vector2(-98.628, 19.023), 5426),
    Peak('Mount Etna', Vector2(14.996, 37.748), 3357),
    Peak('Mount Vesuvius', Vector2(14.426, 40.821), 1281),
  ];

  // Major Airports (IATA code, name, location)
  static final List<Airport> airports = [
    Airport('ATL', 'Hartsfield-Jackson Atlanta', Vector2(-84.428, 33.640)),
    Airport('DXB', 'Dubai International', Vector2(55.364, 25.253)),
    Airport('DFW', 'Dallas/Fort Worth', Vector2(-97.038, 32.897)),
    Airport('LHR', 'London Heathrow', Vector2(-0.454, 51.470)),
    Airport('HND', 'Tokyo Haneda', Vector2(139.781, 35.553)),
    Airport('PVG', 'Shanghai Pudong', Vector2(121.805, 31.143)),
    Airport('CDG', 'Paris Charles de Gaulle', Vector2(2.548, 49.010)),
    Airport('AMS', 'Amsterdam Schiphol', Vector2(4.764, 52.309)),
    Airport('DEL', 'Delhi Indira Gandhi', Vector2(77.103, 28.566)),
    Airport('FRA', 'Frankfurt', Vector2(8.571, 50.050)),
    Airport('IST', 'Istanbul', Vector2(28.815, 40.977)),
    Airport('JFK', 'New York JFK', Vector2(-73.779, 40.640)),
    Airport('SIN', 'Singapore Changi', Vector2(103.989, 1.350)),
    Airport('ICN', 'Seoul Incheon', Vector2(126.451, 37.460)),
    Airport('LAX', 'Los Angeles', Vector2(-118.408, 33.942)),
    Airport('PEK', 'Beijing Capital', Vector2(116.585, 40.072)),
    Airport('SYD', 'Sydney Kingsford Smith', Vector2(151.177, -33.946)),
    Airport('FCO', 'Rome Fiumicino', Vector2(12.251, 41.800)),
    Airport('MUC', 'Munich', Vector2(11.786, 48.354)),
    Airport('MAD', 'Madrid Barajas', Vector2(-3.567, 40.472)),
    Airport('HKG', 'Hong Kong', Vector2(113.915, 22.309)),
    Airport('BKK', 'Bangkok Suvarnabhumi', Vector2(100.747, 13.681)),
    Airport('KUL', 'Kuala Lumpur', Vector2(101.710, 2.746)),
    Airport('NRT', 'Tokyo Narita', Vector2(140.386, 35.765)),
    Airport('ORD', "Chicago O'Hare", Vector2(-87.905, 41.979)),
    Airport('MIA', 'Miami', Vector2(-80.291, 25.796)),
    Airport('GRU', 'São Paulo Guarulhos', Vector2(-46.473, -23.432)),
    Airport('JNB', 'Johannesburg', Vector2(28.246, -26.134)),
    Airport('CAI', 'Cairo', Vector2(31.406, 30.122)),
    Airport('DOH', 'Doha Hamad', Vector2(51.608, 25.273)),
  ];

  // Major Deserts (bounding boxes: [minLng, minLat, maxLng, maxLat])
  static final List<Desert> deserts = [
    Desert('Sahara', [-17.0, 15.0, 35.0, 30.0]),
    Desert('Arabian', [35.0, 16.0, 60.0, 32.0]),
    Desert('Gobi', [90.0, 38.0, 110.0, 46.0]),
    Desert('Kalahari', [20.0, -27.0, 26.0, -18.0]),
    Desert('Patagonian', [-73.0, -52.0, -66.0, -40.0]),
    Desert('Great Victoria', [123.0, -32.0, 135.0, -24.0]),
    Desert('Syrian', [36.0, 30.0, 44.0, 36.0]),
    Desert('Great Basin', [-120.0, 38.0, -110.0, 42.0]),
    Desert('Chihuahuan', [-110.0, 25.0, -102.0, 32.0]),
    Desert('Karakum', [55.0, 38.0, 66.0, 42.0]),
    Desert('Namib', [12.0, -26.0, 16.0, -15.0]),
    Desert('Thar', [69.0, 24.0, 75.0, 28.0]),
    Desert('Atacama', [-71.0, -27.0, -68.5, -18.0]),
    Desert('Sonoran', [-116.0, 27.0, -108.0, 34.0]),
    Desert('Simpson', [135.0, -27.0, 139.0, -24.0]),
  ];

  // Named Seas/Oceans (label center points)
  static final List<SeaLabel> seas = [
    SeaLabel('Pacific Ocean', Vector2(-160.0, 0.0)),
    SeaLabel('Atlantic Ocean', Vector2(-30.0, 15.0)),
    SeaLabel('Indian Ocean', Vector2(75.0, -15.0)),
    SeaLabel('Arctic Ocean', Vector2(0.0, 85.0)),
    SeaLabel('Southern Ocean', Vector2(0.0, -65.0)),
    SeaLabel('Mediterranean Sea', Vector2(18.0, 36.0)),
    SeaLabel('Caribbean Sea', Vector2(-75.0, 15.0)),
    SeaLabel('South China Sea', Vector2(115.0, 12.0)),
    SeaLabel('Bering Sea', Vector2(-175.0, 58.0)),
    SeaLabel('Gulf of Mexico', Vector2(-90.0, 25.0)),
    SeaLabel('Bay of Bengal', Vector2(88.0, 15.0)),
    SeaLabel('Arabian Sea', Vector2(65.0, 15.0)),
    SeaLabel('Red Sea', Vector2(38.0, 20.0)),
    SeaLabel('Black Sea', Vector2(35.0, 43.0)),
    SeaLabel('Coral Sea', Vector2(155.0, -15.0)),
    SeaLabel('Sea of Japan', Vector2(135.0, 40.0)),
    SeaLabel('North Sea', Vector2(3.0, 56.0)),
    SeaLabel('Baltic Sea', Vector2(20.0, 58.0)),
    SeaLabel('Persian Gulf', Vector2(51.0, 27.0)),
    SeaLabel('Caspian Sea', Vector2(51.0, 42.0)),
  ];

  // Major Volcanoes (active/notable)
  static final List<Volcano> volcanoes = [
    Volcano('Mauna Loa', Vector2(-155.608, 19.475), true),
    Volcano('Krakatoa', Vector2(105.423, -6.102), true),
    Volcano('Mount Vesuvius', Vector2(14.426, 40.821), true),
    Volcano('Mount Etna', Vector2(14.996, 37.748), true),
    Volcano('Mount Fuji', Vector2(138.727, 35.361), false),
    Volcano('Mount Pinatubo', Vector2(120.350, 15.130), true),
    Volcano('Mount St. Helens', Vector2(-122.188, 46.191), true),
    Volcano('Eyjafjallajökull', Vector2(-19.613, 63.633), true),
    Volcano('Kilauea', Vector2(-155.292, 19.421), true),
    Volcano('Mount Erebus', Vector2(167.157, -77.530), true),
    Volcano('Popocatépetl', Vector2(-98.628, 19.023), true),
    Volcano('Cotopaxi', Vector2(-78.436, -0.677), true),
    Volcano('Stromboli', Vector2(15.213, 38.789), true),
    Volcano('Mount Merapi', Vector2(110.446, -7.541), true),
    Volcano('Mount Bromo', Vector2(112.953, -7.942), true),
    Volcano('Mount Tambora', Vector2(118.001, -8.247), true),
    Volcano('Sakurajima', Vector2(130.657, 31.580), true),
    Volcano('Mount Ruapehu', Vector2(175.570, -39.281), true),
    Volcano('Villarrica', Vector2(-71.931, -39.420), true),
    Volcano('Mount Nyiragongo', Vector2(29.250, -1.521), true),
  ];

  // Major Straits (line segments connecting two points)
  static final List<Strait> straits = [
    Strait('Strait of Gibraltar', Vector2(-5.606, 35.967), Vector2(-5.345, 36.143)),
    Strait('Strait of Malacca', Vector2(99.5, 6.0), Vector2(100.5, 1.5)),
    Strait('Bosphorus', Vector2(29.005, 41.120), Vector2(29.080, 41.015)),
    Strait('Strait of Hormuz', Vector2(56.0, 26.6), Vector2(56.4, 26.0)),
    Strait('Bab-el-Mandeb', Vector2(43.3, 12.6), Vector2(43.4, 12.8)),
    Strait('Strait of Dover', Vector2(1.3, 51.0), Vector2(1.8, 50.9)),
    Strait('Mozambique Channel', Vector2(40.5, -15.0), Vector2(40.5, -18.0)),
    Strait('Taiwan Strait', Vector2(119.5, 25.0), Vector2(119.0, 24.0)),
    Strait('Korea Strait', Vector2(129.0, 34.5), Vector2(129.5, 35.0)),
    Strait('Sunda Strait', Vector2(105.4, -6.0), Vector2(105.8, -5.8)),
    Strait('Lombok Strait', Vector2(115.7, -8.5), Vector2(115.9, -8.3)),
    Strait('Strait of Messina', Vector2(15.55, 38.25), Vector2(15.65, 38.20)),
    Strait('Dardanelles', Vector2(26.4, 40.2), Vector2(26.7, 40.1)),
    Strait('Torres Strait', Vector2(142.0, -10.0), Vector2(143.0, -10.5)),
  ];
}

/// Represents a major river as a simplified polyline.
class River {
  const River(this.name, this.points);

  final String name;
  final List<Vector2> points;
}

/// Represents a major lake with center point and approximate radius.
class Lake {
  const Lake(this.name, this.center, this.radiusDegrees);

  final String name;
  final Vector2 center;
  final double radiusDegrees;
}

/// Represents a mountain peak with elevation.
class Peak {
  const Peak(this.name, this.location, this.elevationMeters);

  final String name;
  final Vector2 location;
  final int elevationMeters;
}

/// Represents a major airport with IATA code.
class Airport {
  const Airport(this.iataCode, this.name, this.location);

  final String iataCode;
  final String name;
  final Vector2 location;
}

/// Represents a desert region as a bounding box.
class Desert {
  const Desert(this.name, this.bounds);

  final String name;
  final List<double> bounds; // [minLng, minLat, maxLng, maxLat]
}

/// Represents a labeled sea or ocean region.
class SeaLabel {
  const SeaLabel(this.name, this.center);

  final String name;
  final Vector2 center;
}

/// Represents a volcano with activity status.
class Volcano {
  const Volcano(this.name, this.location, this.isActive);

  final String name;
  final Vector2 location;
  final bool isActive;
}

/// Represents a strait as a line segment.
class Strait {
  const Strait(this.name, this.start, this.end);

  final String name;
  final Vector2 start;
  final Vector2 end;
}
