# Texture Assets for Flit

This directory should contain texture files for the GPU shader renderer. All textures are **optional** - the game will run with black fallback textures if any fail to load, but will show a solid background instead of the rendered globe.

## Required Textures

`globe.frag` currently samples only two textures (`uSatellite`, `uCityLights`). The
previously-planned `heightmap.png` and `shore_distance.png` textures were never wired
into the shader (no `uHeightmap`/`uShoreDist` samplers, no `texture()` calls) and have
been removed from this directory — see "Removed Textures" below.

### 1. `blue_marble.png`
- **Source**: [NASA Blue Marble](https://visibleearth.nasa.gov/collection/1484/blue-marble)
- **License**: Public Domain
- **Format**: Equirectangular projection (2:1 aspect ratio)
- **Recommended Size**: 2048x1024 or 4096x2048
- **Description**: Satellite imagery of Earth for terrain rendering

### 2. `city_lights.png`
- **Source**: [NASA Earth at Night](https://earthobservatory.nasa.gov/features/NightLights)
- **License**: Public Domain
- **Format**: Equirectangular emission map
- **Recommended Size**: 2048x1024 or 4096x2048
- **Description**: City light emissions for night-side rendering

## Removed Textures

- **`heightmap.png`** (ETOPO1/ETOPO2022) and **`shore_distance.png`** (coastline
  distance field) were removed — `globe.frag` never declared `uHeightmap` or
  `uShoreDist` samplers or sampled them via `texture()`. Surface classification is
  derived from the satellite color instead (see the "no heightmap" comment in
  `globe.frag`). If terrain-relief shading or coastline foam is implemented in the
  future, regenerate these textures (see `scripts/generate_shore_distance.dart`) and
  re-add them here along with the corresponding shader samplers.

## Download Instructions

1. Visit the NASA sources linked above
2. Download the images in equirectangular projection (2:1 aspect ratio)
3. Resize if needed to target resolution (recommend 2048x1024 for web performance)
4. Save as PNG files with the exact names listed above
5. Place in this directory (`assets/textures/`)

## Fallback Behavior

The shader manager (`lib/game/rendering/shader_manager.dart`) handles missing textures gracefully:
- Each texture loads independently
- Missing textures are replaced with 1x1 black fallback
- Shader continues to render with available textures
- Globe appears as solid black if all textures fail to load
- Errors are logged to telemetry but don't crash the app

## Notes

- All textures must be in equirectangular projection (longitude = x-axis, latitude = y-axis)
- Only use **open-license** sources (NASA, ETOPO, Natural Earth, OSM)
- Never use proprietary data (Google Maps, Mapbox, Apple Maps, etc.)
- Texture quality impacts performance on mobile/web - 2048x1024 is recommended
- See `SETUP.md` in the root directory for detailed setup instructions
