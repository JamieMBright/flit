# CLAUDE.md - Flit Project Guidelines

## Core Principles

### Run to Completion
- Never leave tasks incomplete. Finish what you start.
- If blocked, document the blocker and propose solutions before stopping.
- All changes must pass all test suites before considering work done.
- **Apply fixes to ALL items, not a subset** — When a fix applies to multiple countries, clues, data entries, etc., apply it to every relevant instance. Don't cherry-pick 20 out of 85. If the scope is large, use parallel background agents to divide the work.

### Context Management
- Keep context lean. Spawn agents for discrete tasks.
- Always defer to AGENTS.md when handling multiple tasks.
- Tasks must be context-bound and executed in parallel where possible.
- Summarize learnings; don't carry raw data through conversation.
- **Avoid reading death loops** — Don't sequentially read file after file in the main context window. Instead, spawn background agents (using `haiku` or `sonnet` models for cost/speed) to read and summarize files. Only bring concise findings back to the main context.
- Reserve `opus` model for complex reasoning tasks (architecture decisions, tricky bugs, nuanced code changes). Use `haiku` for simple lookups, file reads, and grep tasks. Use `sonnet` for moderate exploration and code search.

---

## Project Identity

### Domain
- **Game Development** - We are building an immersive geography flight game
- **Geography-Based** - Leveraging open-source, open-license geographic data (OSM, Natural Earth, NASA, etc.)
- **Reference Aesthetic** - [Geographical Adventures](https://sebastian.itch.io/geographical-adventures) by Sebastian Lague

### Aesthetic
- **Satellite-Textured Globe** - Real NASA imagery rendered via fragment shader
- **Physical Ocean** - Animated waves, specular highlights, fresnel, coastline foam
- **Atmospheric Scattering** - Sky gradients, rim glow, aerial haze
- **Volumetric Clouds** - Procedural noise or SDF sphere clusters
- **Lo-Fi Plane Overlay** - Hand-drawn Canvas plane contrasts against realistic globe
- **Immersive Experience** - The app should feel like a world, not a tool

---

## Architecture Overview

### Rendering Pipeline
```
Fragment Shader (globe.frag)          Canvas Overlay
  │                                     │
  ├─ Ray-sphere intersection            ├─ PlaneComponent (Bezier paths)
  ├─ Satellite texture sampling         ├─ Contrail particles
  ├─ Ocean: waves, specular, foam       ├─ City labels (low altitude)
  ├─ Atmosphere: rim glow, haze         └─ HUD (timer, clues, score)
  ├─ Clouds: procedural noise
  ├─ Day/night: terminator, city lights
  └─ Sky: analytical scattering
```

### Key Rendering Components
- **`shaders/globe.frag`** - Main GLSL fragment shader (raymarched globe)
- **`lib/game/rendering/globe_renderer.dart`** - CustomPainter + FragmentProgram host
- **`lib/game/rendering/shader_manager.dart`** - Shader loading, caching, uniform management
- **`lib/game/components/plane_component.dart`** - Canvas-drawn plane overlay (unchanged)
- **`lib/game/map/country_data.dart`** - Polygon data retained for hit-testing only

### Texture Samplers (4 max per shader pass)
1. `uSatellite` — NASA Blue Marble (equirectangular satellite imagery)
2. `uHeightmap` — ETOPO heightmap (terrain elevation + ocean depth)
3. `uShoreDist` — Shore distance field (for coastline foam)
4. `uCityLights` — NASA Earth at Night (city light emissions)

If more textures needed → pack into RGBA channels or use multi-pass.

---

## Platform Requirements

### Cross-Platform First
- **NEVER edit code for just one platform** - Always consider minimum 2 platforms
- Target platforms: iOS, Android, Web
- All UI must use **relative positioning only** - no absolute values
- Test on all platforms before any merge

### Shader Compatibility
- **Fragment shaders** must compile on all three targets:
  - iOS: Metal via SPIR-V transpilation
  - Android: Vulkan/GLES via SPIR-V
  - Web: WebGL (GLSL ES 1.0 compatible)
- Use `FragmentProgram.fromAsset()` (stable since Flutter 3.7)
- No vertex shaders, compute shaders, or storage buffers
- Test shader compilation on all platforms before merge

### Performance
- **60fps sustained** on mid-range devices (iPhone 12, Pixel 6, Chrome desktop)
- Profile before and after shader changes
- No frame drops, no jank, no memory leaks
- Total asset bundle < 50MB compressed
- Shader complexity monitored per-platform (GPU timing)

---

## Runtime Error Telemetry

### Architecture
- **ErrorService** singleton captures all unhandled exceptions
- Errors POST to Vercel serverless endpoint with retry + backoff
- **DevOverlay** shows errors on-screen in debug/profile mode only
- GitHub Action fetches error logs into `logs/runtime-errors.jsonl`
- Zero overhead in release builds (tree-shaken)

### DevOverlay Rules
- Only in debug/profile builds (`kReleaseMode` gate)
- Tap-to-copy for easy bug reporting
- Never ship overlay to production

---

## Testing Requirements

All tests must pass before commit. Run in this order:

### 1. Unit Tests
```bash
# Run unit tests with coverage
flutter test --coverage
```

### 2. Shader Compilation Tests
```bash
# Verify shaders compile on all targets
./scripts/test.sh shaders
```

### 3. Security Tests
```bash
# Security audit and SAST
./scripts/test.sh security
```

### 4. Integration Tests
```bash
# Must cover ALL platforms
./scripts/test.sh integration
```

### 5. Deployment Tests
```bash
# Simulate deployment
./scripts/test.sh deploy
```

### Pre-Commit Checklist
- [ ] All unit tests pass
- [ ] Shader compiles on iOS, Android, AND Web
- [ ] Security scan clean
- [ ] Integration tests pass on 2+ platforms
- [ ] Deployment simulation successful
- [ ] Linting passes with zero warnings
- [ ] No platform-specific code without cross-platform equivalent
- [ ] Error telemetry doesn't leak into release builds

---

## Code Quality

### Linting
- Lint ALWAYS before commit
- Zero warnings policy - warnings are errors
- Use project flutter_lints config

```bash
./scripts/lint.sh            # Check linting
dart format lib/ test/ --fix # Auto-fix formatting
flutter analyze              # Static analysis
```

### Style
- Prefer composition over inheritance
- Small, focused functions
- Descriptive naming over comments
- Types everywhere (Dart strict mode)
- Shader code: comment complex math, name magic numbers

### Shader Code Style
- All uniforms prefixed with `u` (e.g., `uSunDir`, `uTime`)
- Helper functions at top of file, main rendering logic at bottom
- Comment the visual purpose of each section, not the math itself
- Group by rendering layer: terrain → ocean → foam → atmosphere → clouds → sky

---

## Agent Usage

### When to Use Agents
- Multiple independent tasks - spawn parallel agents
- Deep exploration of codebase
- Complex multi-step implementations
- Cross-platform testing coordination
- Shader debugging across platforms
- Asset pipeline processing

### Cost & Usage Efficiency
- **Always assign the cheapest appropriate model** to background agents to save money and usage limits:
  - `haiku` — Repetitive/bounded edits (find-and-replace, bulk data updates, simple reads/greps)
  - `sonnet` — Moderate exploration, multi-file code search, generating structured data
  - `opus` — Complex reasoning, architecture decisions, tricky bugs, nuanced changes
- Default to `haiku` unless the task genuinely needs more capability
- See AGENTS.md for full model selection guide

### Agent Delegation Rules
1. Check AGENTS.md for appropriate agent type
2. Provide clear, bounded context to each agent
3. Run independent agents in parallel
4. Aggregate results before proceeding
5. **Model selection**: Use `haiku` for simple file reads/searches and repetitive edits (find-and-replace, data entry), `sonnet` for moderate exploration, `opus` only for complex reasoning
6. **Prefer background agents for exploration** — Don't read 10+ files sequentially in the main context. Spawn a background agent to gather info and return a summary
7. **Repetitive context-bound edits** — For tasks like updating 85 country entries, replacing data across many blocks, or bulk find-and-replace, use `haiku` — it's fast, cheap, and the task is well-bounded

---

## Geographic Data Sources (Open License)

### Approved Sources
- **NASA Blue Marble (Public Domain)** - Satellite imagery texture
- **NASA Earth at Night (Public Domain)** - City lights texture
- **ETOPO1 / ETOPO2022 (Public Domain)** - Global heightmap + bathymetry
- **Natural Earth (Public Domain)** - Country/region boundaries (hit-testing polygons)
- **OpenStreetMap (ODbL)** - Supplementary map data
- **SRTM/ASTER (Public)** - High-res elevation data
- **GeoNames (CC-BY)** - Place names and city coordinates

### Never Use
- Google Maps data
- Proprietary satellite imagery
- Scraped data without license verification
- Mapbox, Apple Maps, or HERE data

---

## Build Commands (Flutter)

```bash
# Development
flutter run -d chrome        # Run on web
flutter run -d ios           # Run on iOS simulator
flutter run -d android       # Run on Android emulator

# Testing (run ALL before commit)
./scripts/test.sh            # All tests
./scripts/test.sh unit       # Unit only
./scripts/test.sh shaders    # Shader compilation
./scripts/test.sh security   # Security audit
./scripts/test.sh integration # All platform builds

# Production
./scripts/build.sh           # Build all platforms
./scripts/build.sh web       # Web only
./scripts/build.sh android   # Android only
./scripts/build.sh ios       # iOS only (macOS only)

# Quality
./scripts/lint.sh            # Check linting
dart format lib/ test/ --fix # Auto-fix formatting
flutter analyze              # Static analysis

# Error Telemetry
curl -H "X-API-Key: $KEY" https://flit-errors.vercel.app/api/errors?limit=10
gh workflow run fetch-errors.yml
```

---

## Commit Protocol

1. Run full test suite: `./scripts/test.sh`
2. Run linting: `./scripts/lint.sh`
3. Verify shader compiles on 2+ platforms
4. Verify cross-platform: integration tests for 2+ platforms
5. Commit with descriptive message
6. Push only after all checks pass

---

## PR Workflow

**ALWAYS provide the PR URL when pushing a branch.**

After pushing:
```
Pushed to: claude/feature-name-XXXXX

Create PR: https://github.com/JamieMBright/flit/pull/new/claude/feature-name-XXXXX
```

User is on iOS Claude Code app - they need the direct link to merge.

---

## Pre-Push Validation (No Flutter Locally)

Since Flutter isn't available in this environment, do these checks before committing:

1. **Syntax** - Verify all brackets, parentheses, semicolons balanced
2. **Imports** - Check all import paths exist and are spelled correctly
3. **File references** - Verify referenced files exist
4. **Shader syntax** - Verify GLSL syntax (matching braces, valid types, no undefined vars)
5. **Known patterns** - Avoid APIs that don't work on web (SystemChrome, etc.)
6. **Lint rules** - Only use lint rules known to exist in flutter_lints
7. **Dependencies** - Only add packages known to work on web
8. **Sampler count** - Never exceed 4 samplers per shader pass
9. **Asset paths** - Verify all texture/shader asset paths in pubspec.yaml

CI is the final gate, but minimize round-trips by being careful.

---

## Red Lines (Never Do)

- Never skip tests to "save time"
- Never use absolute positioning in UI
- Never add platform-specific code without cross-platform support
- Never commit with linting warnings
- Never use non-open-license geographic data or satellite imagery
- Never sacrifice performance for convenience
- Never leave an agent task incomplete
- Never exceed 4 texture samplers per shader pass without multi-pass strategy
- Never ship DevOverlay or telemetry debug code in release builds
- Never hardcode API keys in source (use environment variables)
