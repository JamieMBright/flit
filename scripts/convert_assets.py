#!/usr/bin/env python3
"""
Convert raw downloaded assets into the formats Flit expects.

Requirements:
    pip install Pillow rasterio numpy pydub scipy

Usage:
    python scripts/convert_assets.py

Expects raw files already staged/placed in the asset directories.
Converts in-place and creates derived textures.
"""

import os
import sys
import numpy as np
from pathlib import Path

# Project root = parent of scripts/
ROOT = Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "assets" / "textures"
MUSIC = ROOT / "assets" / "audio" / "music"
ENGINES = ROOT / "assets" / "audio" / "engines"
SFX = ROOT / "assets" / "audio" / "sfx"

TARGET_SIZE = (2048, 1024)  # width x height, equirectangular


def convert_music():
    """Convert MP3 music tracks to OGG Vorbis, normalized to -14 LUFS."""
    from pydub import AudioSegment

    mp3_files = sorted(MUSIC.glob("*.mp3"))
    if not mp3_files:
        print("  No MP3 files found in assets/audio/music/")
        return

    for mp3 in mp3_files:
        ogg_path = mp3.with_suffix(".ogg")
        print(f"  {mp3.name} -> {ogg_path.name}")

        audio = AudioSegment.from_mp3(str(mp3))
        # Normalize: target -14 dBFS (approximation of -14 LUFS)
        change_in_dbfs = -14.0 - audio.dBFS
        audio = audio.apply_gain(change_in_dbfs)
        audio.export(str(ogg_path), format="ogg", codec="libvorbis",
                     parameters=["-q:a", "6"])

        # Remove original MP3
        mp3.unlink()
        print(f"    Removed {mp3.name}")

    print(f"  Converted {len(mp3_files)} music tracks to OGG")


def convert_audio_dir(directory, label):
    """Convert any WAV/MP3 files in a directory to OGG."""
    from pydub import AudioSegment

    count = 0
    for ext in ("*.mp3", "*.wav", "*.flac"):
        for f in sorted(directory.glob(ext)):
            ogg_path = f.with_suffix(".ogg")
            print(f"  {f.name} -> {ogg_path.name}")
            audio = AudioSegment.from_file(str(f))
            audio.export(str(ogg_path), format="ogg", codec="libvorbis",
                         parameters=["-q:a", "6"])
            f.unlink()
            count += 1

    if count == 0:
        print(f"  No files to convert in {label}")
    else:
        print(f"  Converted {count} {label} files to OGG")


def convert_city_lights():
    """Convert city_lights.jpg to city_lights.png, resized."""
    from PIL import Image

    jpg_path = TEXTURES / "city_lights.jpg"
    png_path = TEXTURES / "city_lights.png"

    if not jpg_path.exists():
        print("  city_lights.jpg not found, skipping")
        return

    print(f"  city_lights.jpg -> city_lights.png ({TARGET_SIZE[0]}x{TARGET_SIZE[1]})")
    img = Image.open(jpg_path).convert("RGB")
    img = img.resize(TARGET_SIZE, Image.LANCZOS)
    img.save(png_path, "PNG")
    jpg_path.unlink()
    print(f"    Removed city_lights.jpg")


def convert_heightmap():
    """Convert ETOPO GeoTIFF to grayscale PNG, normalized 0-255."""
    import rasterio

    tif_path = TEXTURES / "heightmap.tif"
    png_path = TEXTURES / "heightmap.png"

    if not tif_path.exists():
        print("  heightmap.tif not found, skipping")
        return

    print(f"  heightmap.tif -> heightmap.png ({TARGET_SIZE[0]}x{TARGET_SIZE[1]})")

    with rasterio.open(str(tif_path)) as src:
        # Read first band (elevation data)
        data = src.read(1).astype(np.float64)

    print(f"    Raw elevation range: {data.min():.0f}m to {data.max():.0f}m")

    # Normalize to 0-255
    # ETOPO ranges roughly -11000m (ocean trench) to +8849m (Everest)
    # Map full range to 0-255 so ocean < 128 < land
    data_min = data.min()
    data_max = data.max()
    normalized = ((data - data_min) / (data_max - data_min) * 255).astype(np.uint8)

    # Resize using PIL
    from PIL import Image
    img = Image.fromarray(normalized, mode="L")
    img = img.resize(TARGET_SIZE, Image.LANCZOS)
    img.save(png_path, "PNG")
    tif_path.unlink()
    print(f"    Removed heightmap.tif (was ~407MB)")

    return png_path


def convert_blue_marble():
    """Convert blue_marble.jpg to blue_marble.png, resized."""
    from PIL import Image

    jpg_path = TEXTURES / "blue_marble.jpg"
    png_path = TEXTURES / "blue_marble.png"

    if not jpg_path.exists():
        print("  blue_marble.jpg not found, skipping")
        return

    print(f"  blue_marble.jpg -> blue_marble.png ({TARGET_SIZE[0]}x{TARGET_SIZE[1]})")
    img = Image.open(jpg_path).convert("RGB")
    img = img.resize(TARGET_SIZE, Image.LANCZOS)
    img.save(png_path, "PNG")
    jpg_path.unlink()
    print(f"    Removed blue_marble.jpg")


def generate_shore_distance(heightmap_png=None):
    """Generate shore_distance.png from heightmap using distance transform."""
    from PIL import Image
    from scipy.ndimage import distance_transform_edt

    if heightmap_png is None:
        heightmap_png = TEXTURES / "heightmap.png"

    shore_path = TEXTURES / "shore_distance.png"

    if not heightmap_png.exists():
        print("  heightmap.png not found, cannot generate shore distance")
        return

    print(f"  Generating shore_distance.png from heightmap...")

    img = Image.open(heightmap_png).convert("L")
    data = np.array(img, dtype=np.float64)

    # Sea level is roughly where the normalized value represents 0m elevation
    # In our normalization: 0 = deepest ocean, 255 = highest peak
    # Sea level = -data_min / (data_max - data_min) * 255
    # For ETOPO: roughly -11000 to 8849, so sea level ~ 11000/19849*255 ~ 141
    # But we can estimate: pixels below ~141 are ocean, above are land
    # A simpler approach: use the median or find the mode around coastlines
    # For robustness, treat the ~55% mark as sea level (oceans are ~71% of Earth)
    # Actually, let's use a percentile approach: 71% of Earth is ocean
    sea_level = np.percentile(data, 71)
    print(f"    Estimated sea level threshold: {sea_level:.0f}/255")

    # Create land mask (1 = land, 0 = ocean)
    land = (data >= sea_level).astype(np.float64)

    # Find coastline pixels (land pixels adjacent to ocean)
    # Distance from ocean to nearest land (for foam)
    ocean_mask = land == 0

    # Distance transform from coastline into ocean
    # Invert: distance of each ocean pixel to nearest land pixel
    dist_ocean = distance_transform_edt(ocean_mask)

    # Distance of each land pixel to nearest ocean pixel
    dist_land = distance_transform_edt(~ocean_mask)

    # Combine: negative in ocean, positive on land
    # Normalize both sides independently for better contrast near coast
    max_dist = 50.0  # pixels — only care about ~50px from shore

    # Shore distance: 0 = far ocean, 128 = coastline, 255 = far inland
    shore = np.zeros_like(data)
    # Ocean side: 0 (far) to 128 (coast)
    ocean_part = np.clip(dist_ocean / max_dist, 0, 1)
    shore[ocean_mask] = (1.0 - ocean_part[ocean_mask]) * 128

    # Land side: 128 (coast) to 255 (far inland)
    land_part = np.clip(dist_land / max_dist, 0, 1)
    shore[~ocean_mask] = 128 + land_part[~ocean_mask] * 127

    shore = shore.astype(np.uint8)

    result = Image.fromarray(shore, mode="L")
    result.save(shore_path, "PNG")
    print(f"    Saved shore_distance.png ({result.size[0]}x{result.size[1]})")


def main():
    print("=" * 60)
    print("Flit Asset Converter")
    print("=" * 60)

    # Check dependencies
    missing = []
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        missing.append("Pillow")
    try:
        import rasterio  # noqa: F401
    except ImportError:
        missing.append("rasterio")
    try:
        from pydub import AudioSegment  # noqa: F401
    except ImportError:
        missing.append("pydub")
    try:
        from scipy.ndimage import distance_transform_edt  # noqa: F401
    except ImportError:
        missing.append("scipy")

    if missing:
        print(f"\nMissing packages: {', '.join(missing)}")
        print(f"Install with: pip install {' '.join(missing)}")
        # Continue with what we can do
        print("Continuing with available packages...\n")

    # 1. Textures
    print("\n[1/6] Converting Blue Marble...")
    try:
        convert_blue_marble()
    except Exception as e:
        print(f"  ERROR: {e}")

    print("\n[2/6] Converting heightmap (GeoTIFF -> PNG)...")
    heightmap_path = None
    try:
        heightmap_path = convert_heightmap()
    except Exception as e:
        print(f"  ERROR: {e}")

    print("\n[3/6] Converting city lights...")
    try:
        convert_city_lights()
    except Exception as e:
        print(f"  ERROR: {e}")

    print("\n[4/6] Generating shore distance texture...")
    try:
        generate_shore_distance(heightmap_path)
    except Exception as e:
        print(f"  ERROR: {e}")

    # 2. Audio
    print("\n[5/6] Converting music (MP3 -> OGG)...")
    try:
        convert_music()
    except Exception as e:
        print(f"  ERROR: {e}")

    print("\n[6/6] Converting engine/SFX audio...")
    try:
        convert_audio_dir(ENGINES, "engine")
    except Exception as e:
        print(f"  ERROR: {e}")
    try:
        convert_audio_dir(SFX, "SFX")
    except Exception as e:
        print(f"  ERROR: {e}")

    # Summary
    print("\n" + "=" * 60)
    print("Summary — files in assets/textures/:")
    for f in sorted(TEXTURES.glob("*")):
        if f.name == ".gitkeep":
            continue
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"  {f.name:30s} {size_mb:6.1f} MB")

    print("\nFiles in assets/audio/:")
    for subdir in [MUSIC, ENGINES, SFX]:
        for f in sorted(subdir.glob("*")):
            if f.name == ".gitkeep":
                continue
            size_mb = f.stat().st_size / (1024 * 1024)
            rel = f.relative_to(ROOT / "assets" / "audio")
            print(f"  {str(rel):30s} {size_mb:6.1f} MB")

    # Check what's still missing
    print("\nStill needed:")
    expected_textures = ["blue_marble.png", "heightmap.png", "city_lights.png", "shore_distance.png"]
    for t in expected_textures:
        path = TEXTURES / t
        if not path.exists() or path.stat().st_size == 0:
            print(f"  MISSING: assets/textures/{t}")

    expected_engines = ["biplane_engine.ogg", "prop_engine.ogg", "bomber_engine.ogg",
                        "jet_engine.ogg", "rocket_engine.ogg", "wind.ogg"]
    for e in expected_engines:
        path = ENGINES / e
        if not path.exists() or path.stat().st_size == 0:
            print(f"  MISSING: assets/audio/engines/{e}")

    expected_sfx = ["clue_pop.ogg", "landing_success.ogg", "coin_collect.ogg",
                    "ui_click.ogg", "altitude_change.ogg", "boost_start.ogg"]
    for s in expected_sfx:
        path = SFX / s
        if not path.exists() or path.stat().st_size == 0:
            print(f"  MISSING: assets/audio/sfx/{s}")

    print("\nDone!")


if __name__ == "__main__":
    main()
