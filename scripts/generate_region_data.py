#!/usr/bin/env python3
"""
Generate high-resolution regional boundary data from Natural Earth 10m admin-1 shapefiles.

Usage:
    python3 scripts/generate_region_data.py <path_to_ne_10m_admin_1_states_provinces.shp>

Outputs:
    lib/game/map/region_polygons.dart

This replaces the manually-created rectangular approximations in region.dart with
real polygon boundaries from Natural Earth 10m admin-1 subdivisions.

Features:
    - Uses Natural Earth 10m admin-1 (highest resolution) for pristine borders
    - Applies Douglas-Peucker simplification to keep file size reasonable
    - Generates data for US States, UK Counties, Ireland Counties, Canadian Provinces
    - Multi-polygon support for complex boundaries (e.g. Great Lakes coastline)
"""

import sys
import os
import geopandas as gpd
from shapely.geometry import Polygon, MultiPolygon

# Simplification tolerance in degrees (~0.02° ≈ 2.2 km).
# Tighter than country data (0.05°) because states/provinces are smaller.
SIMPLIFY_TOLERANCE = 0.02

# Minimum vertices for a polygon to be included (filters slivers).
MIN_POLYGON_POINTS = 4

# Region definitions: Natural Earth iso_a2 → our region key
REGIONS = {
    'US': {
        'name': 'usStates',
        'filter_field': 'iso_a2',
        'filter_value': 'US',
        'name_field': 'name',
        'code_field': 'iso_3166_2',
        # Exclude territories
        'exclude': {'US-AS', 'US-GU', 'US-MP', 'US-PR', 'US-VI', 'US-UM', 'US-DC'},
    },
    'GB': {
        'name': 'ukCounties',
        'filter_field': 'iso_a2',
        'filter_value': 'GB',
        'name_field': 'name',
        'code_field': 'iso_3166_2',
        'exclude': set(),
    },
    'IE': {
        'name': 'ireland',
        'filter_field': 'iso_a2',
        'filter_value': 'IE',
        'name_field': 'name',
        'code_field': 'iso_3166_2',
        'exclude': set(),
    },
    'CA': {
        'name': 'canadianProvinces',
        'filter_field': 'iso_a2',
        'filter_value': 'CA',
        'name_field': 'name',
        'code_field': 'iso_3166_2',
        'exclude': set(),
    },
}


def extract_coords(geometry, tolerance):
    """Extract simplified coordinate lists from a geometry."""
    simplified = geometry.simplify(tolerance, preserve_topology=True)

    polygons = []
    if isinstance(simplified, Polygon):
        geoms = [simplified]
    elif isinstance(simplified, MultiPolygon):
        geoms = list(simplified.geoms)
    else:
        return polygons

    for poly in geoms:
        coords = list(poly.exterior.coords)
        if len(coords) >= MIN_POLYGON_POINTS:
            # Convert to (lng, lat) Vector2 format
            points = [(round(x, 4), round(y, 4)) for x, y in coords]
            polygons.append(points)
    return polygons


def generate_dart_region(gdf, region_config):
    """Generate Dart code for one region."""
    name_field = region_config['name_field']
    code_field = region_config['code_field']
    exclude = region_config['exclude']

    lines = []
    total_vertices = 0

    for _, row in gdf.iterrows():
        code = row.get(code_field, '')
        if code in exclude:
            continue

        area_name = row[name_field]
        if not area_name or not isinstance(area_name, str):
            continue

        polygons = extract_coords(row.geometry, SIMPLIFY_TOLERANCE)
        if not polygons:
            continue

        # Use the first (largest) polygon as the boundary
        main_poly = max(polygons, key=len)
        vertex_count = len(main_poly)
        total_vertices += vertex_count

        # Escape single quotes in name
        safe_name = area_name.replace("'", "\\'")
        short_code = code.split('-')[-1] if '-' in code else code

        points_str = ', '.join(
            f'Vector2({lng}, {lat})' for lng, lat in main_poly
        )

        lines.append(f"    RegionalArea(")
        lines.append(f"      code: '{short_code}',")
        lines.append(f"      name: '{safe_name}',")
        lines.append(f"      points: [{points_str}],")
        lines.append(f"    ),")

    return lines, total_vertices


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_region_data.py <ne_10m_admin_1.shp>")
        print()
        print("Download from: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/")
        print("File: ne_10m_admin_1_states_provinces.shp")
        sys.exit(1)

    shapefile = sys.argv[1]
    if not os.path.exists(shapefile):
        print(f"ERROR: File not found: {shapefile}")
        sys.exit(1)

    print(f"Reading {shapefile}...")
    gdf = gpd.read_file(shapefile)
    print(f"Loaded {len(gdf)} admin-1 subdivisions")

    output_lines = [
        "// GENERATED FILE — do not edit by hand.",
        "// Run: python3 scripts/generate_region_data.py <ne_10m_admin_1.shp>",
        "//",
        "// Source: Natural Earth 10m admin-1 states/provinces (Public Domain).",
        f"// Simplification: {SIMPLIFY_TOLERANCE}° (~{SIMPLIFY_TOLERANCE * 111:.1f} km)",
        "",
        "import 'package:flame/components.dart';",
        "",
        "import 'region.dart';",
        "",
    ]

    grand_total = 0

    for iso_code, config in REGIONS.items():
        region_name = config['name']
        filter_field = config['filter_field']
        filter_value = config['filter_value']

        subset = gdf[gdf[filter_field] == filter_value]
        print(f"\n{region_name}: {len(subset)} subdivisions for {filter_value}")

        dart_lines, vertex_count = generate_dart_region(subset, config)
        grand_total += vertex_count

        output_lines.append(f"/// High-resolution boundaries for {region_name}.")
        output_lines.append(f"/// {len(dart_lines) // 4} areas, {vertex_count:,} total vertices.")
        output_lines.append(f"const List<RegionalArea> {region_name}HiRes = [")
        output_lines.extend(dart_lines)
        output_lines.append("];")
        output_lines.append("")

        print(f"  → {len(dart_lines) // 4} areas, {vertex_count:,} vertices")

    # Write output
    out_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'lib', 'game', 'map', 'region_polygons.dart',
    )
    with open(out_path, 'w') as f:
        f.write('\n'.join(output_lines) + '\n')

    print(f"\nWrote {out_path}")
    print(f"Grand total: {grand_total:,} vertices across all regions")


if __name__ == '__main__':
    main()
