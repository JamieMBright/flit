#!/usr/bin/env python3
"""
Generate high-resolution country_data.dart from Natural Earth 10m shapefiles.

Usage:
    python3 scripts/generate_country_data.py <path_to_ne_10m_admin_0_countries.shp>

Outputs:
    lib/game/map/country_data.dart

Features:
    - Uses Natural Earth 10m (highest resolution) for pristine borders
    - Includes disputed/contested territories (Western Sahara, Kosovo, Somaliland)
    - Multi-polygon support for archipelagos and exclaves
    - Preserves existing CountryShape/CityData API
"""

import sys
import os
import geopandas as gpd
from shapely.geometry import Polygon, MultiPolygon

# Minimum number of points for a polygon to be included (filters tiny slivers)
MIN_POLYGON_POINTS = 4

# Territories to ensure are included, with manual ISO codes for disputed ones
DISPUTED_TERRITORIES = {
    'Somaliland': 'XS',   # No ISO code; use custom
    'Kosovo': 'XK',        # Partially recognized; XK is commonly used
}

# Map from Natural Earth NAME field to our preferred name + code overrides
NAME_OVERRIDES = {
    'Dem. Rep. Congo': ('Congo (DR)', 'CD'),
    'Congo': ('Congo (Republic)', 'CG'),
    'Dominican Rep.': ('Dominican Rep.', 'DO'),
    "Côte d'Ivoire": ("Cote d'Ivoire", 'CI'),
    'eSwatini': ('Eswatini', 'SZ'),
    'Cabo Verde': ('Cabo Verde', 'CV'),
    'W. Sahara': ('Western Sahara', 'EH'),
    'N. Cyprus': ('Northern Cyprus', 'XC'),
    'Bosnia and Herz.': ('Bosnia and Herzegovina', 'BA'),
    'Central African Rep.': ('Central African Republic', 'CF'),
    'Czech Rep.': ('Czech Republic', 'CZ'),
    'Eq. Guinea': ('Equatorial Guinea', 'GQ'),
    'Fr. S. Antarctic Lands': None,  # Skip - uninhabited
    'S. Sudan': ('South Sudan', 'SS'),
    'Solomon Is.': ('Solomon Islands', 'SB'),
    'Marshall Is.': ('Marshall Islands', 'MH'),
    'S. Geo. and the Is.': None,  # Skip - uninhabited
    'Br. Indian Ocean Ter.': None,  # Skip - uninhabited
    'Heard I. and McDonald Is.': None,  # Skip - uninhabited
    'Fr. Polynesia': None,  # Skip - overseas territory
    'Falkland Is.': ('Falkland Islands', 'FK'),
    'N. Mariana Is.': None,  # Skip - US territory
    'Cayman Is.': None,  # Skip - UK territory
    'U.S. Virgin Is.': None,  # Skip - US territory
    'Turks and Caicos Is.': None,  # Skip - UK territory
    'St-Martin': None,  # Skip - French overseas
    'Sint Maarten': None,  # Skip - Dutch overseas
    'St. Vin. and Gren.': ('Saint Vincent and the Grenadines', 'VC'),
    'St. Kitts and Nevis': ('Saint Kitts and Nevis', 'KN'),
    'St. Lucia': ('Saint Lucia', 'LC'),
    'St-Barthélemy': None,  # Skip - French overseas
    'São Tomé and Príncipe': ('Sao Tome and Principe', 'ST'),
    'Sao Tome and Principe': ('Sao Tome and Principe', 'ST'),
    'Timor-Leste': ('Timor-Leste', 'TL'),
    'N. Korea': ('North Korea', 'KP'),
    'S. Korea': ('South Korea', 'KR'),
    'Lao PDR': ('Laos', 'LA'),
    'Myanmar': ('Myanmar', 'MM'),
    'Brunei': ('Brunei', 'BN'),
    'United States of America': ('United States', 'US'),
    'United Kingdom': ('United Kingdom', 'GB'),
    'Czechia': ('Czech Republic', 'CZ'),
    'Macedonia': ('North Macedonia', 'MK'),
    'North Macedonia': ('North Macedonia', 'MK'),
}

# Capital cities - comprehensive list
CAPITALS = {
    'AD': 'Andorra la Vella', 'AE': 'Abu Dhabi', 'AF': 'Kabul', 'AG': "St. John's",
    'AL': 'Tirana', 'AM': 'Yerevan', 'AO': 'Luanda', 'AR': 'Buenos Aires',
    'AT': 'Vienna', 'AU': 'Canberra', 'AZ': 'Baku', 'BA': 'Sarajevo',
    'BB': 'Bridgetown', 'BD': 'Dhaka', 'BE': 'Brussels', 'BF': 'Ouagadougou',
    'BG': 'Sofia', 'BH': 'Manama', 'BI': 'Gitega', 'BJ': 'Porto-Novo',
    'BN': 'Bandar Seri Begawan', 'BO': 'Sucre', 'BR': 'Brasilia', 'BS': 'Nassau',
    'BT': 'Thimphu', 'BW': 'Gaborone', 'BY': 'Minsk', 'BZ': 'Belmopan',
    'CA': 'Ottawa', 'CD': 'Kinshasa', 'CF': 'Bangui', 'CG': 'Brazzaville',
    'CH': 'Bern', 'CI': 'Yamoussoukro', 'CL': 'Santiago', 'CM': 'Yaounde',
    'CN': 'Beijing', 'CO': 'Bogota', 'CR': 'San Jose', 'CU': 'Havana',
    'CV': 'Praia', 'CY': 'Nicosia', 'CZ': 'Prague', 'DE': 'Berlin',
    'DJ': 'Djibouti', 'DK': 'Copenhagen', 'DM': 'Roseau', 'DO': 'Santo Domingo',
    'DZ': 'Algiers', 'EC': 'Quito', 'EE': 'Tallinn', 'EG': 'Cairo',
    'EH': 'Laayoune', 'ER': 'Asmara', 'ES': 'Madrid', 'ET': 'Addis Ababa',
    'FI': 'Helsinki', 'FJ': 'Suva', 'FK': 'Stanley', 'FM': 'Palikir',
    'FR': 'Paris', 'GA': 'Libreville', 'GB': 'London', 'GD': "St. George's",
    'GE': 'Tbilisi', 'GH': 'Accra', 'GL': 'Nuuk', 'GM': 'Banjul',
    'GN': 'Conakry', 'GQ': 'Malabo', 'GR': 'Athens', 'GT': 'Guatemala City',
    'GW': 'Bissau', 'GY': 'Georgetown', 'HN': 'Tegucigalpa', 'HR': 'Zagreb',
    'HT': 'Port-au-Prince', 'HU': 'Budapest', 'ID': 'Jakarta', 'IE': 'Dublin',
    'IL': 'Jerusalem', 'IN': 'New Delhi', 'IQ': 'Baghdad', 'IR': 'Tehran',
    'IS': 'Reykjavik', 'IT': 'Rome', 'JM': 'Kingston', 'JO': 'Amman',
    'JP': 'Tokyo', 'KE': 'Nairobi', 'KG': 'Bishkek', 'KH': 'Phnom Penh',
    'KI': 'Tarawa', 'KM': 'Moroni', 'KN': 'Basseterre', 'KP': 'Pyongyang',
    'KR': 'Seoul', 'KW': 'Kuwait City', 'KZ': 'Astana', 'LA': 'Vientiane',
    'LB': 'Beirut', 'LC': 'Castries', 'LI': 'Vaduz', 'LK': 'Sri Jayawardenepura Kotte',
    'LR': 'Monrovia', 'LS': 'Maseru', 'LT': 'Vilnius', 'LU': 'Luxembourg',
    'LV': 'Riga', 'LY': 'Tripoli', 'MA': 'Rabat', 'MC': 'Monaco',
    'MD': 'Chisinau', 'ME': 'Podgorica', 'MG': 'Antananarivo', 'MH': 'Majuro',
    'MK': 'Skopje', 'ML': 'Bamako', 'MM': 'Naypyidaw', 'MN': 'Ulaanbaatar',
    'MR': 'Nouakchott', 'MT': 'Valletta', 'MU': 'Port Louis', 'MV': 'Male',
    'MW': 'Lilongwe', 'MX': 'Mexico City', 'MY': 'Kuala Lumpur', 'MZ': 'Maputo',
    'NA': 'Windhoek', 'NE': 'Niamey', 'NG': 'Abuja', 'NI': 'Managua',
    'NL': 'Amsterdam', 'NO': 'Oslo', 'NP': 'Kathmandu', 'NR': 'Yaren',
    'NZ': 'Wellington', 'OM': 'Muscat', 'PA': 'Panama City', 'PE': 'Lima',
    'PG': 'Port Moresby', 'PH': 'Manila', 'PK': 'Islamabad', 'PL': 'Warsaw',
    'PR': 'San Juan', 'PS': 'Ramallah', 'PT': 'Lisbon', 'PW': 'Ngerulmud',
    'PY': 'Asuncion', 'QA': 'Doha', 'RO': 'Bucharest', 'RS': 'Belgrade',
    'RU': 'Moscow', 'RW': 'Kigali', 'SA': 'Riyadh', 'SB': 'Honiara',
    'SC': 'Victoria', 'SD': 'Khartoum', 'SE': 'Stockholm', 'SG': 'Singapore',
    'SI': 'Ljubljana', 'SK': 'Bratislava', 'SL': 'Freetown', 'SM': 'San Marino',
    'SN': 'Dakar', 'SO': 'Mogadishu', 'SR': 'Paramaribo', 'SS': 'Juba',
    'ST': 'Sao Tome', 'SV': 'San Salvador', 'SY': 'Damascus', 'SZ': 'Mbabane',
    'TD': 'N\'Djamena', 'TG': 'Lome', 'TH': 'Bangkok', 'TJ': 'Dushanbe',
    'TL': 'Dili', 'TM': 'Ashgabat', 'TN': 'Tunis', 'TO': "Nuku'alofa",
    'TR': 'Ankara', 'TT': 'Port of Spain', 'TV': 'Funafuti', 'TW': 'Taipei',
    'TZ': 'Dodoma', 'UA': 'Kyiv', 'UG': 'Kampala', 'US': 'Washington, D.C.',
    'UY': 'Montevideo', 'UZ': 'Tashkent', 'VA': 'Vatican City',
    'VC': 'Kingstown', 'VE': 'Caracas', 'VN': 'Hanoi', 'VU': 'Port Vila',
    'WS': 'Apia', 'XK': 'Pristina', 'XS': 'Hargeisa',
    'YE': "Sana'a", 'ZA': 'Pretoria', 'ZM': 'Lusaka', 'ZW': 'Harare',
}

# Territories/dependencies to SKIP (not sovereign states for the game)
SKIP_NAMES = {
    'Ashmore and Cartier Is.',
    'Indian Ocean Ter.',
    'Bajo Nuevo Bank',
    'Clipperton I.',
    'Coral Sea Is.',
    'Cyprus U.N. Buffer Zone',
    'Dhekelia',
    'Akrotiri',  # UK base in Cyprus
    'Scarborough Reef',
    'Serranilla Bank',
    'Spratly Is.',
    'USNB Guantanamo Bay',
    'Siachen Glacier',
}

# Special ISO code mappings for entries where Natural Earth gives wrong/missing codes
ISO_CODE_FIXES = {
    'Taiwan': 'TW',
    'Norway': 'NO',
    'France': 'FR',
    'Somaliland': 'XS',
    'Kosovo': 'XK',
    'N. Cyprus': 'XC',
}


def extract_polygons(geometry):
    """Extract list of coordinate rings from a geometry."""
    polygons = []
    if geometry is None:
        return polygons

    if isinstance(geometry, Polygon):
        coords = list(geometry.exterior.coords)
        if len(coords) >= MIN_POLYGON_POINTS:
            polygons.append(coords)
    elif isinstance(geometry, MultiPolygon):
        for poly in geometry.geoms:
            coords = list(poly.exterior.coords)
            if len(coords) >= MIN_POLYGON_POINTS:
                polygons.append(coords)
    return polygons


def format_vector2(lng, lat):
    """Format a coordinate as Vector2(lng, lat)."""
    return f'Vector2({lng:.6f}, {lat:.6f})'


def _extract_cities_block(output_path, backup_path):
    """Extract the cities block from the existing country_data.dart file."""
    # Read the existing file (before we overwrite it)
    source = None
    for p in [output_path, backup_path]:
        if os.path.exists(p):
            with open(p, 'r') as f:
                source = f.read()
            break
    if source is None:
        return None

    # Find the cities block: from "// Major cities" to the closing "];"
    start_marker = '  // Major cities for low-altitude view'
    start_idx = source.find(start_marker)
    if start_idx == -1:
        return None

    # Find the end of the majorCities list - look for "];" after the start
    # We need to find the matching closing bracket for the list
    search_from = source.find('static final List<CityData> majorCities', start_idx)
    if search_from == -1:
        return None

    # Find the opening bracket of the list
    bracket_start = source.find('[', search_from)
    if bracket_start == -1:
        return None

    # Count brackets to find matching close
    depth = 0
    i = bracket_start
    while i < len(source):
        if source[i] == '[':
            depth += 1
        elif source[i] == ']':
            depth -= 1
            if depth == 0:
                # Found the matching close bracket
                end_idx = source.find(';', i)
                if end_idx == -1:
                    end_idx = i + 1
                else:
                    end_idx += 1  # Include the semicolon
                return source[start_idx:end_idx] + '\n\n'
        i += 1

    return None


def generate_dart(shapefile_path, output_path):
    """Generate country_data.dart from Natural Earth shapefile."""
    print(f"Reading shapefile: {shapefile_path}")
    gdf = gpd.read_file(shapefile_path)

    print(f"Total features in shapefile: {len(gdf)}")
    print(f"Columns: {list(gdf.columns)}")

    # Inspect available columns to find name/code fields
    # Natural Earth 10m uses: NAME, ISO_A2, ISO_A3, ADMIN, SOVEREIGNT, etc.
    name_col = 'NAME' if 'NAME' in gdf.columns else 'name'
    admin_col = 'ADMIN' if 'ADMIN' in gdf.columns else name_col

    # Prefer ISO_A2_EH which handles disputed territories better
    # Fall back to ISO_A2, then WB_A2
    iso_cols = ['ISO_A2_EH', 'ISO_A2', 'WB_A2']
    iso_col = None
    for col in iso_cols:
        if col in gdf.columns:
            iso_col = col
            break
    if iso_col is None:
        print("WARNING: No ISO A2 column found, will use NAME-based codes")
        iso_col = name_col

    countries = []
    seen_codes = set()
    total_points = 0
    skipped = []

    for _, row in gdf.iterrows():
        name = row[name_col] if name_col in row.index else row[admin_col]
        if name is None:
            continue

        # Skip non-sovereign territories
        if name in SKIP_NAMES:
            skipped.append(f"  SKIP (non-sovereign): {name}")
            continue

        # Check if this is in our name overrides
        if name in NAME_OVERRIDES:
            override = NAME_OVERRIDES[name]
            if override is None:
                skipped.append(f"  SKIP (override=None): {name}")
                continue
            display_name, code = override
        else:
            display_name = name
            # Check manual ISO fixes first
            if name in ISO_CODE_FIXES:
                code = ISO_CODE_FIXES[name]
            else:
                raw_code = str(row[iso_col]) if iso_col in row.index else ''
                # Natural Earth uses -99 for disputed territories
                if raw_code in ('-99', '-1', 'nan', '', 'None', '-99.0'):
                    # Check disputed territories
                    if name in DISPUTED_TERRITORIES:
                        code = DISPUTED_TERRITORIES[name]
                    else:
                        skipped.append(f"  SKIP (no ISO code): {name}")
                        continue
                else:
                    code = raw_code.strip()

        if not code or code == '-99':
            skipped.append(f"  SKIP (bad code): {name} -> '{code}'")
            continue

        # Handle duplicate codes (keep the one with more detail)
        polygons = extract_polygons(row.geometry)
        if not polygons:
            skipped.append(f"  SKIP (no geometry): {name} ({code})")
            continue

        point_count = sum(len(p) for p in polygons)

        if code in seen_codes:
            # Merge polygons with existing entry
            for c in countries:
                if c['code'] == code:
                    c['polygons'].extend(polygons)
                    c['point_count'] += point_count
                    break
        else:
            seen_codes.add(code)
            capital = CAPITALS.get(code)
            countries.append({
                'code': code,
                'name': display_name,
                'capital': capital,
                'polygons': polygons,
                'point_count': point_count,
            })

        total_points += point_count

    # Sort alphabetically by code
    countries.sort(key=lambda c: c['code'])

    print(f"\nIncluded: {len(countries)} countries/territories")
    print(f"Total points: {total_points:,}")
    print(f"Skipped: {len(skipped)} entries")
    for s in skipped:
        print(s)

    # Check for key territories
    codes = {c['code'] for c in countries}
    key_checks = {
        'EH': 'Western Sahara',
        'XK': 'Kosovo',
        'XS': 'Somaliland',
        'SO': 'Somalia',
        'SS': 'South Sudan',
        'PS': 'Palestine',
        'TW': 'Taiwan',
    }
    print("\nKey territory check:")
    for kc, kn in key_checks.items():
        status = 'PRESENT' if kc in codes else 'MISSING'
        print(f"  {kc} ({kn}): {status}")

    # Extract cities block BEFORE overwriting the file
    backup_path = output_path + '.bak'
    cities_block = _extract_cities_block(output_path, backup_path)

    # Generate Dart file
    print(f"\nWriting Dart file: {output_path}")
    with open(output_path, 'w') as f:
        f.write("import 'package:flame/components.dart';\n\n")
        f.write("/// Country shape data with multi-polygon support.\n")
        f.write("/// Derived from Natural Earth 10m (Public Domain).\n")
        f.write("/// High-resolution borders for pristine rendering.\n")
        f.write("class CountryShape {\n")
        f.write("  const CountryShape({\n")
        f.write("    required this.code,\n")
        f.write("    required this.name,\n")
        f.write("    required this.polygons,\n")
        f.write("    this.capital,\n")
        f.write("  });\n\n")
        f.write("  final String code;\n")
        f.write("  final String name;\n")
        f.write("  final List<List<Vector2>> polygons; // Each polygon is a list of [lng, lat] pairs\n")
        f.write("  final String? capital;\n\n")
        f.write("  /// Flat list of all points across all polygons (for hit-testing, bounding box, etc.)\n")
        f.write("  List<Vector2> get allPoints => polygons.expand((p) => p).toList();\n")
        f.write("}\n\n")

        f.write("/// City data for low-altitude view.\n")
        f.write("class CityData {\n")
        f.write("  const CityData({\n")
        f.write("    required this.name,\n")
        f.write("    required this.countryCode,\n")
        f.write("    required this.location,\n")
        f.write("    this.isCapital = false,\n")
        f.write("    this.difficulty = 'easy',\n")
        f.write("  });\n\n")
        f.write("  final String name;\n")
        f.write("  final String countryCode;\n")
        f.write("  final Vector2 location; // [lng, lat]\n")
        f.write("  final bool isCapital;\n")
        f.write("  final String difficulty; // 'easy', 'medium', 'hard'\n")
        f.write("}\n\n")

        f.write("/// Static country and city data.\n")
        f.write("/// High-resolution shapes derived from Natural Earth 10m (Public Domain).\n")
        f.write("abstract class CountryData {\n")
        f.write("  static final List<CountryShape> countries = [\n")

        for country in countries:
            code = country['code']
            name = country['name'].replace("'", "\\'")
            capital = country['capital']

            f.write("    CountryShape(\n")
            f.write(f"      code: '{code}',\n")
            f.write(f"      name: '{name}',\n")
            if capital:
                capital_escaped = capital.replace("'", "\\'")
                f.write(f"      capital: '{capital_escaped}',\n")
            f.write("      polygons: [\n")

            for polygon in country['polygons']:
                f.write("        [\n")
                # Write coordinates in rows of 3 for readability
                line_items = []
                for lng, lat, *_ in polygon:
                    line_items.append(format_vector2(lng, lat))
                    if len(line_items) == 3:
                        f.write("          " + ", ".join(line_items) + ",\n")
                        line_items = []
                if line_items:
                    f.write("          " + ", ".join(line_items) + ",\n")
                f.write("        ],\n")

            f.write("      ],\n")
            f.write("    ),\n")

        f.write("  ];\n\n")

        # Preserve the cities section from existing file (extracted before overwriting)
        if cities_block:
            f.write(cities_block)
        else:
            f.write("  // Major cities for low-altitude view\n")
            f.write("  static final List<CityData> majorCities = [];\n\n")

        # Helper methods
        f.write("  /// Get country by code\n")
        f.write("  static CountryShape? getCountry(String code) {\n")
        f.write("    try {\n")
        f.write("      return countries.firstWhere((c) => c.code == code);\n")
        f.write("    } catch (_) {\n")
        f.write("      return null;\n")
        f.write("    }\n")
        f.write("  }\n\n")
        f.write("  /// Get random country\n")
        f.write("  static CountryShape getRandomCountry() {\n")
        f.write("    return countries[DateTime.now().millisecondsSinceEpoch % countries.length];\n")
        f.write("  }\n\n")
        f.write("  /// Get cities for a country\n")
        f.write("  static List<CityData> getCitiesForCountry(String code) {\n")
        f.write("    return majorCities.where((c) => c.countryCode == code).toList();\n")
        f.write("  }\n\n")
        f.write("  /// Get capital city for a country\n")
        f.write("  static CityData? getCapital(String code) {\n")
        f.write("    try {\n")
        f.write("      return majorCities.firstWhere((c) => c.countryCode == code && c.isCapital);\n")
        f.write("    } catch (_) {\n")
        f.write("      return null;\n")
        f.write("    }\n")
        f.write("  }\n")
        f.write("}\n")

    # File size check
    file_size = os.path.getsize(output_path)
    print(f"\nOutput file size: {file_size / 1024 / 1024:.1f} MB")
    print(f"Countries: {len(countries)}")
    print(f"Total polygon points: {total_points:,}")
    print("Done!")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        # Try to find shapefile automatically
        search_paths = [
            '/tmp/natearth/ne_10m/ne_10m_admin_0_countries.shp',
            '/tmp/natearth/ne_10m_admin_0_countries.shp',
            'ne_10m_admin_0_countries.shp',
        ]
        shapefile = None
        for p in search_paths:
            if os.path.exists(p):
                shapefile = p
                break
        if shapefile is None:
            print("Usage: python3 scripts/generate_country_data.py <path_to_shapefile>")
            print("  Download from: https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_0_countries.zip")
            sys.exit(1)
    else:
        shapefile = sys.argv[1]

    output = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          'lib', 'game', 'map', 'country_data.dart')
    generate_dart(shapefile, output)
