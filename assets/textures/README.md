# Texture Assets for Flit

This directory should contain texture files for the GPU shader renderer. All textures are **optional** - the game will run with black fallback textures if any fail to load, but will show a solid background instead of the rendered globe.

## Required Textures

### 1. `blue_marble.png`
- **Source**: [NASA Blue Marble](https://visibleearth.nasa.gov/collection/1484/blue-marble)
- **License**: Public Domain
- **Format**: Equirectangular projection (2:1 aspect ratio)
- **Recommended Size**: 2048x1024 or 4096x2048
- **Description**: Satellite imagery of Earth for terrain rendering

### 2. `heightmap.png`
- **Source**: [ETOPO1 or ETOPO2022](https://www.ncei.noaa.gov/products/etopo-global-relief-model)
- **License**: Public Domain
- **Format**: Equirectangular grayscale heightmap
- **Recommended Size**: 2048x1024 or 4096x2048
- **Description**: Terrain elevation and ocean depth data

### 3. `shore_distance.png`
- **Source**: Generated from coastline data (e.g., via Jump Flood Algorithm)
- **License**: Derived from Natural Earth or OSM (Public Domain / ODbL)
- **Format**: Equirectangular distance field
- **Recommended Size**: 1024x512 or 2048x1024
- **Description**: Distance to nearest coastline for foam rendering

### 4. `city_lights.png`
- **Source**: [NASA Earth at Night](https://earthobservatory.nasa.gov/features/NightLights)
- **License**: Public Domain
- **Format**: Equirectangular emission map
- **Recommended Size**: 2048x1024 or 4096x2048
- **Description**: City light emissions for night-side rendering

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
