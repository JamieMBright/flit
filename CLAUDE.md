# CLAUDE.md - Flit Project Guidelines

## Core Principles

### Run to Completion
- Never leave tasks incomplete. Finish what you start.
- If blocked, document the blocker and propose solutions before stopping.
- All changes must pass all test suites before considering work done.
- **Apply fixes to ALL items, not a subset** — When a fix applies to multiple countries, clues, data entries, etc., apply it to every relevant instance. Don't cherry-pick 20 out of 85. If the scope is large, use parallel background agents to divide the work.

### Apply Fixes Generically Across All Game Modes
- **Never apply a fix to only one game mode** — When a rendering improvement, data fix, or gameplay enhancement applies to multiple game modes, apply it to ALL relevant modes. Game modes share common infrastructure (e.g., Uncharted and Flight School share the same map renderer basis). A border smoothing fix, a missing-country fix, or a visual improvement must propagate everywhere it's relevant.
- Before committing a mode-specific change, ask: "Does this apply to other modes too?" If yes, apply it universally.
- Shared rendering code (map renderers, polygon drawing, border styling) should be fixed at the shared layer, not patched per-mode.
- If a fix genuinely only applies to one mode, document why in a code comment.

### Re-read User Prompts Before Committing
- **Always re-read the user's original prompt** before considering work done — users often include multiple bugs, requests, or issues in a single message.
- Check off each item explicitly. Do not commit or push until every item in the prompt has been addressed.
- If an item is unclear, ask for clarification rather than skipping it.

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

### Error Log Review (Pre-Commit / Pre-Push)
- **`logs/runtime-errors.jsonl`** is the local error log fed by the Vercel endpoint and GitHub Action
- **Pre-commit and pre-push hooks** automatically report a summary of outstanding errors
- **Standard workflow**: Before each session or PR, review errors → fix root causes → clear the log
- Use `./scripts/check-error-logs.sh` to view outstanding errors
- Use `./scripts/check-error-logs.sh --clear` to purge the log after errors are resolved
- **Never clear the log without reviewing and addressing the errors first**
- Errors are informational (non-blocking) in hooks — but critical errors should be treated as bugs to fix

```bash
# Review outstanding runtime errors
./scripts/check-error-logs.sh

# One-line summary (used by hooks)
./scripts/check-error-logs.sh --summary

# Clear log after fixing all outstanding issues
./scripts/check-error-logs.sh --clear
```

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
- [ ] `dart format lib/ test/` run (advisory — won't block CI, but fix when convenient)
- [ ] All unit tests pass
- [ ] Shader compiles on iOS, Android, AND Web
- [ ] Security scan clean
- [ ] Integration tests pass on 2+ platforms
- [ ] Deployment simulation successful
- [ ] Linting reviewed (advisory — won't block CI, but address warnings when convenient)
- [ ] No platform-specific code without cross-platform equivalent
- [ ] Error telemetry doesn't leak into release builds
- [ ] Runtime error log reviewed (`./scripts/check-error-logs.sh`) — fix bugs, then clear

---

## Code Quality

### Linting
- Lint before commit when possible, but formatting and lint issues are **advisory, not blocking**
- CI reports formatting and lint warnings but does not fail the build on them
- Use project flutter_lints config
- **Zero-warning policy** — Do not leave existing warnings unresolved. When you see warnings in hook output or CI logs, fix them. A clean log is a healthy codebase.

```bash
./scripts/lint.sh            # Check linting
dart format lib/ test/ --fix # Auto-fix formatting
flutter analyze              # Static analysis (authoritative for prefer_const_constructors etc.)
```

### Warning & Log File Management
- **Always check hook/CI output for warnings** — treat them as bugs to fix, not noise to ignore
- After resolving warnings, verify they no longer appear in the output
- The `lint-noflutter.sh` script provides lightweight heuristic checks; `flutter analyze` is the authoritative source
- **Pre-push hooks only scan changed files** — they compare against the merge base with `origin/main`, so only your changes are validated
- Do not commit code that introduces new warnings — fix them before pushing

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
curl -H "X-API-Key: $KEY" https://flit-olive.vercel.app/api/errors?limit=10
gh workflow run fetch-errors.yml
./scripts/check-error-logs.sh         # Review outstanding errors
./scripts/check-error-logs.sh --clear # Clear after fixing
```

---

## Commit Protocol

1. **Run `dart format` when possible** — recommended but no longer a CI blocker:
   ```bash
   dart format lib/ test/             # If dart is on PATH
   /tmp/dart-sdk/bin/dart format lib/ test/  # Fallback if installed locally
   ```
   CI will report formatting issues as warnings but will not fail the build.
   Run formatting when convenient, but don't let it block progress.
2. Run full test suite: `./scripts/test.sh`
3. Run linting: `./scripts/lint.sh` (advisory — reports but doesn't block)
4. Verify shader compiles on 2+ platforms
5. Verify cross-platform: integration tests for 2+ platforms
6. **Review runtime error log**: `./scripts/check-error-logs.sh` — fix outstanding bugs, then `./scripts/check-error-logs.sh --clear` to purge resolved entries
7. **Update architecture docs if necessary** — If your changes affect the persistence layer, rendering pipeline, data flow, or any architecture described in this file or other docs, update those sections to reflect the new design before committing
8. Commit with descriptive message
9. Push after tests pass (formatting/lint warnings are acceptable)

### Flutter SDK (Claude Code web sessions)
The SessionStart hook automatically installs Flutter SDK (including Dart) at `/tmp/flutter`.
Both `flutter` and `dart` commands are available on PATH after session start.

If manual install is needed:
```bash
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.3-stable.tar.xz -o /tmp/flutter.tar.xz
tar -xf /tmp/flutter.tar.xz -C /tmp/ && rm -f /tmp/flutter.tar.xz
export PATH="/tmp/flutter/bin:/tmp/flutter/bin/cache/dart-sdk/bin:$PATH"
```

### Pre-Commit Hook
The project includes a pre-commit hook that auto-checks `dart format`. Install it:
```bash
bash scripts/setup-hooks.sh
```

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

## Pre-Push Validation

With Flutter available, run the full test suite before pushing:

```bash
flutter test                 # Unit tests
flutter analyze              # Static analysis
dart format lib/ test/       # Format check
```

Additionally verify:
1. **Shader syntax** - Verify GLSL syntax (matching braces, valid types, no undefined vars)
2. **Known patterns** - Avoid APIs that don't work on web (SystemChrome, etc.)
3. **Dependencies** - Only add packages known to work on web
4. **Sampler count** - Never exceed 4 samplers per shader pass
5. **Asset paths** - Verify all texture/shader asset paths in pubspec.yaml

CI is the final gate, but minimize round-trips by being careful.

---

## Red Lines (Never Do)

- Never skip tests to "save time"
- Never use absolute positioning in UI
- Never add platform-specific code without cross-platform support
- Never ignore test failures (formatting/lint warnings are acceptable, test failures are not)
- Never use non-open-license geographic data or satellite imagery
- Never sacrifice performance for convenience
- Never leave an agent task incomplete
- Never push incomplete work — if a task covers N items, finish all N before committing. Do not push partial results and call it done
- Never exceed 4 texture samplers per shader pass without multi-pass strategy
- Never ship DevOverlay or telemetry debug code in release builds
- Never hardcode API keys in source (use environment variables)
