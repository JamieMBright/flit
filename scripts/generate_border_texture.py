#!/usr/bin/env python3
"""Generate country border distance field and pack into shore_distance.png.

Reads polygon data from country_data.dart, rasterizes country boundaries,
computes a Euclidean distance transform, then packs the result into the
green channel of shore_distance.png (red channel = existing shore distance).

Output: assets/textures/shore_distance.png (RGB PNG, was grayscale)

Usage:
    python scripts/generate_border_texture.py
"""

import re
import sys
import numpy as np
from pathlib import Path
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt

# Texture dimensions (must match existing textures)
WIDTH = 5400
HEIGHT = 2700

# Maximum distance in pixels for normalization.
# At 5400x2700 equirectangular: 1 pixel ≈ 0.067° ≈ 7.4 km at equator.
# 15 pixels ≈ 111 km — borders fade to invisible beyond this.
MAX_DIST = 15


def parse_polygons_from_dart(dart_file):
    """Extract all polygon vertex lists from country_data.dart.

    Returns a list of polygons, where each polygon is a list of (lng, lat)
    tuples. We don't need country identity — just boundary locations.
    """
    content = Path(dart_file).read_text()

    # Find the start of the countries list
    countries_start = content.find('static final countries')
    if countries_start == -1:
        print("  Warning: 'static final countries' not found, scanning full file")
        countries_start = 0

    content = content[countries_start:]

    all_polygons = []
    in_polygons = False
    poly_depth = 0
    current_poly = []
    i = 0
    length = len(content)

    while i < length:
        # Detect "polygons:" keyword
        if content[i:i + 9] == 'polygons:':
            in_polygons = True
            poly_depth = 0
            i += 9
            continue

        if in_polygons:
            ch = content[i]

            if ch == '[':
                poly_depth += 1
                if poly_depth == 2:  # Entering an inner polygon list
                    current_poly = []
            elif ch == ']':
                if poly_depth == 2:  # Exiting an inner polygon list
                    if len(current_poly) >= 3:
                        all_polygons.append(current_poly)
                    current_poly = []
                poly_depth -= 1
                if poly_depth <= 0:
                    in_polygons = False

            # Try to match Vector2(lng, lat) at current position
            if poly_depth >= 2 and content[i:i + 7] == 'Vector2':
                m = re.match(r'Vector2\(([-\d.]+),\s*([-\d.]+)\)', content[i:])
                if m:
                    lng = float(m.group(1))
                    lat = float(m.group(2))
                    current_poly.append((lng, lat))
                    i += len(m.group(0))
                    continue

        i += 1

    return all_polygons


def lng_lat_to_pixel(lng, lat):
    """Convert longitude/latitude to pixel coordinates (equirectangular)."""
    x = (lng + 180.0) / 360.0 * WIDTH
    y = (90.0 - lat) / 180.0 * HEIGHT
    return x, y


def rasterize_borders(polygons):
    """Rasterize polygon boundary lines onto a binary image."""
    img = Image.new('L', (WIDTH, HEIGHT), 0)
    draw = ImageDraw.Draw(img)

    for polygon in polygons:
        n = len(polygon)
        for i in range(n):
            lng1, lat1 = polygon[i]
            lng2, lat2 = polygon[(i + 1) % n]

            # Skip edges that cross the antimeridian (>180° longitude span)
            if abs(lng2 - lng1) > 180:
                continue

            x1, y1 = lng_lat_to_pixel(lng1, lat1)
            x2, y2 = lng_lat_to_pixel(lng2, lat2)

            draw.line([(x1, y1), (x2, y2)], fill=255, width=1)

    return np.array(img) > 0  # Boolean mask


def main():
    project_root = Path(__file__).parent.parent
    dart_file = project_root / 'lib' / 'game' / 'map' / 'country_data.dart'
    shore_file = project_root / 'assets' / 'textures' / 'shore_distance.png'

    if not dart_file.exists():
        print(f"Error: {dart_file} not found")
        sys.exit(1)

    if not shore_file.exists():
        print(f"Error: {shore_file} not found")
        sys.exit(1)

    # --- Step 1: Parse polygon data ---
    print(f"Parsing polygons from {dart_file.name}...")
    polygons = parse_polygons_from_dart(str(dart_file))
    total_vertices = sum(len(p) for p in polygons)
    print(f"  Found {len(polygons)} polygons, {total_vertices:,} vertices")

    # --- Step 2: Rasterize borders ---
    print("Rasterizing boundaries...")
    border_mask = rasterize_borders(polygons)
    border_pixels = np.sum(border_mask)
    print(f"  Border pixels: {border_pixels:,}")

    # --- Step 3: Distance transform ---
    print("Computing Euclidean distance transform...")
    dist = distance_transform_edt(~border_mask)
    print(f"  Distance range: {dist.min():.1f} – {dist.max():.1f} px")

    # Normalize to 0–255 (0 = on border, 255 = far from border)
    dist_norm = np.clip(dist / MAX_DIST, 0.0, 1.0)
    border_channel = (dist_norm * 255).astype(np.uint8)

    # --- Step 4: Load existing shore distance ---
    print(f"Loading existing {shore_file.name}...")
    shore_img = Image.open(str(shore_file))
    shore_array = np.array(shore_img)

    # Handle size mismatch
    if shore_array.shape[:2] != (HEIGHT, WIDTH):
        print(f"  Resizing from {shore_array.shape[:2]} to ({HEIGHT}, {WIDTH})")
        shore_img = shore_img.resize((WIDTH, HEIGHT), Image.LANCZOS)
        shore_array = np.array(shore_img)

    # Extract shore distance as single channel
    if len(shore_array.shape) == 3:
        shore_channel = shore_array[:, :, 0]  # Red channel
    else:
        shore_channel = shore_array  # Already grayscale

    # --- Step 5: Pack into RGB (R=shore, G=border, B=reserved) ---
    print("Packing into RGB texture (R=shore, G=border, B=0)...")
    packed = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    packed[:, :, 0] = shore_channel     # Red = shore distance (unchanged)
    packed[:, :, 1] = border_channel    # Green = border distance (NEW)
    packed[:, :, 2] = 0                 # Blue = reserved for future use

    # --- Step 6: Save ---
    output_img = Image.fromarray(packed, 'RGB')
    output_img.save(str(shore_file), 'PNG', optimize=True)

    file_size = shore_file.stat().st_size
    print(f"\nSaved: {shore_file}")
    print(f"  Size: {file_size / 1024:.0f} KB")
    print(f"  Dimensions: {WIDTH}x{HEIGHT}")
    print(f"  Channels: RGB (R=shore, G=border, B=reserved)")
    print(f"  Border encoding: 0 = on border, 255 = {MAX_DIST}+ px away")


if __name__ == '__main__':
    main()
