# Flit - GitHub Copilot Instructions

## Project Overview

Flit is an immersive geography flight game built with Flutter, featuring a GPU-rendered globe with realistic satellite textures, physical ocean rendering, and atmospheric effects. The game uses GLSL fragment shaders for rendering and targets iOS, Android, and Web platforms.

**Technology Stack:**
- Flutter 3.16+ (Dart 3.2+)
- GLSL fragment shaders (FragmentProgram API)
- Flame game engine
- Riverpod for state management
- NASA public domain textures (Blue Marble, Earth at Night, ETOPO heightmaps)

**Reference Aesthetic:** [Geographical Adventures](https://sebastian.itch.io/geographical-adventures) by Sebastian Lague

## Critical Requirements

### Cross-Platform First
- **ALWAYS target minimum 2 platforms** (iOS, Android, Web) for any code change
- Use **relative positioning only** in UI - never absolute values
- All fragment shaders must compile on:
  - iOS: Metal via SPIR-V
  - Android: Vulkan/GLES via SPIR-V  
  - Web: WebGL (GLSL ES 1.0)
- Avoid platform-specific APIs (SystemChrome, etc.) without cross-platform fallbacks
- Maximum 4 texture samplers per shader pass (WebGL limitation)

### Performance Targets
- **60fps sustained** on mid-range devices (iPhone 12, Pixel 6, Chrome desktop)
- Total asset bundle < 50MB compressed
- Shader compile time < 500ms per platform
- No frame drops, jank, or memory leaks

### Zero Warnings Policy
- All linting warnings are treated as errors
- Run `./scripts/lint.sh` before every commit
- Format code with `dart format lib/ test/ --fix`
- Static analysis with `flutter analyze --fatal-warnings`

## Build & Test Commands

### Development
```bash
flutter run -d chrome        # Web
flutter run -d ios           # iOS simulator
flutter run -d android       # Android emulator
```

### Testing (run ALL before commit)
```bash
./scripts/test.sh            # Full test suite
./scripts/test.sh unit       # Unit tests + format + analyze
./scripts/test.sh integration # Platform builds
./scripts/test.sh security   # Security audit
```

### Linting
```bash
./scripts/lint.sh            # Format check + analyze
dart format lib/ test/ --fix # Auto-fix formatting
flutter analyze              # Static analysis
```

### Production Builds
```bash
./scripts/build.sh           # All platforms
./scripts/build.sh web       # Web only
./scripts/build.sh android   # Android only
./scripts/build.sh ios       # iOS only (macOS required)
```

## Pre-Commit Checklist

Before committing, verify:
- [ ] All unit tests pass (`flutter test --coverage`)
- [ ] Shaders compile on iOS, Android, AND Web
- [ ] Security audit clean (`flutter pub outdated`)
- [ ] Linting passes with zero warnings (`./scripts/lint.sh`)
- [ ] Integration tests pass on 2+ platforms
- [ ] No platform-specific code without cross-platform equivalent
- [ ] Error telemetry doesn't leak into release builds (check `kReleaseMode` gates)
- [ ] Performance targets met (60fps, <50MB bundle)

## Code Structure

### Key Directories
- `lib/` - Main application code (Dart)
- `shaders/` - GLSL fragment shaders
- `assets/textures/` - NASA satellite imagery, heightmaps, city lights
- `assets/geo/` - Geographic data (country polygons, Natural Earth data)
- `test/` - Unit and widget tests
- `scripts/` - Build, test, and lint automation

### Important Files
- `CLAUDE.md` - Comprehensive project guidelines for AI assistants
- `AGENTS.md` - Task delegation framework for spawning specialized agents
- `ARCHITECTURE.md` - App navigation flow and screen architecture
- `GAME_DESIGN.md` - Game mechanics and design principles
- `pubspec.yaml` - Dependencies (minimal, cross-platform only)

## Shader Development

### GLSL Guidelines
- Uniforms prefixed with `u` (e.g., `uSunDir`, `uTime`, `uSatellite`)
- Maximum 4 samplers per pass (WebGL restriction)
- No `texture2D()` on Web - use `texture()` instead
- No `highp` precision assumptions (not supported on all WebGL devices)
- No dynamic loops (WebGL driver incompatibility)
- Comment visual purpose, not math - group by rendering layer:
  - Terrain → Ocean → Foam → Atmosphere → Clouds → Sky

### Shader Asset Pipeline
1. Edit `shaders/globe.frag`
2. Verify GLSL syntax (matching braces, valid types, no undefined variables)
3. Test compilation on all 3 platforms
4. Profile GPU timing per platform
5. Update `pubspec.yaml` if adding new shader assets

### Texture Sampler Slots
1. `uSatellite` - NASA Blue Marble (equirectangular satellite imagery)
2. `uHeightmap` - ETOPO heightmap (terrain elevation + ocean depth)
3. `uShoreDist` - Shore distance field (for coastline foam)
4. `uCityLights` - NASA Earth at Night (city light emissions)

If more textures needed → pack into RGBA channels or use multi-pass rendering.

## Geographic Data Sources

**Only use open-license sources:**
- ✅ NASA Blue Marble (Public Domain)
- ✅ NASA Earth at Night (Public Domain)
- ✅ ETOPO1/ETOPO2022 heightmaps (Public Domain)
- ✅ Natural Earth country boundaries (Public Domain)
- ✅ OpenStreetMap (ODbL license)
- ✅ GeoNames place data (CC-BY)

**Never use:**
- ❌ Google Maps, Mapbox, Apple Maps, HERE data
- ❌ Proprietary satellite imagery
- ❌ Scraped data without license verification

## Error Handling & Telemetry

### Runtime Error Pipeline
- `ErrorService` singleton captures unhandled exceptions
- Errors POST to Vercel serverless endpoint
- `DevOverlay` shows errors in debug/profile mode ONLY
- GitHub Action fetches logs to `logs/runtime-errors.jsonl`
- **CRITICAL:** DevOverlay must be tree-shaken from release builds (check `kReleaseMode` gates)

### Debugging
```bash
# Fetch recent errors from Vercel
curl -H "X-API-Key: $KEY" https://flit-errors.vercel.app/api/errors?limit=10

# Trigger error log fetch
gh workflow run fetch-errors.yml
```

## Style & Best Practices

### Dart Code Style
- Prefer composition over inheritance
- Small, focused functions (single responsibility)
- Descriptive naming over comments
- Explicit types everywhere (Dart strict mode)
- Use `const` constructors when possible

### Testing Strategy
- Unit tests for business logic
- Widget tests for UI components
- Integration tests via platform builds (not Flutter integration_test - too slow)
- Visual regression via screenshot comparison (manual for now)

### Dependencies
- Minimal dependencies only
- Must work on iOS, Android, AND Web
- Check security with `flutter pub outdated --dependency-overrides`
- Never add proprietary or closed-source packages

## Agent & Task Delegation

For complex tasks, reference `AGENTS.md` for specialized agents:
- **explore** - Codebase exploration, finding implementations
- **test-runner** - Running test suites, validating changes
- **platform-validator** - Cross-platform shader compilation
- **security-auditor** - Dependency scanning, SAST
- **performance-profiler** - GPU profiling, bundle size checks
- **shader-validator** - GLSL syntax, sampler count audits

Use parallel agents for independent tasks to minimize context overhead.

## Common Pitfalls to Avoid

1. **Platform-specific code** - Always consider 2+ platforms
2. **Absolute positioning** - Use relative layout only
3. **Shader sampler overflow** - Maximum 4 samplers per pass
4. **Linting warnings** - Zero tolerance, fix all before commit
5. **Incomplete work** - If fixing N items, fix ALL N, not a subset
6. **Reading loops** - Don't sequentially read 10+ files, spawn an explore agent
7. **Proprietary data** - Only use public domain/open-license geographic data
8. **Release build leaks** - Gate debug features with `kReleaseMode` checks
9. **Skipping tests** - Never commit without running full test suite
10. **Force pushing** - No `git reset` or `git rebase` (force push disabled)

## Additional Documentation

For deeper context, see:
- `CLAUDE.md` - Full project guidelines (architecture, testing, deployment)
- `AGENTS.md` - Task delegation patterns and agent protocols
- `ARCHITECTURE.md` - Screen flow and authentication architecture
- `GAME_DESIGN.md` - Game mechanics and design principles
- `SETUP.md` - Local development setup instructions

## Quick Reference

| Task | Command |
|------|---------|
| Run tests | `./scripts/test.sh` |
| Lint code | `./scripts/lint.sh` |
| Format code | `dart format lib/ test/ --fix` |
| Build web | `./scripts/build.sh web` |
| Build Android | `./scripts/build.sh android` |
| Build iOS | `./scripts/build.sh ios` |
| Security audit | `./scripts/test.sh security` |
| Run on Chrome | `flutter run -d chrome` |

**Remember:** This is a cross-platform game with strict performance requirements. Always test on multiple platforms, maintain 60fps, and use only open-license geographic data.
