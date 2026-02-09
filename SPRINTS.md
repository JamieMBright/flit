# SPRINTS.md - Flit Visual Redesign & Runtime Telemetry

## Vision

Transform Flit from 2D Canvas vector art into a GPU-rendered globe with satellite textures,
physical ocean, atmospheric scattering, volumetric clouds, and coastline foam — matching the
visual quality of Sebastian Lague's Geographical Adventures while staying 100% in Flutter.

**Reference:** [Geographical Adventures](https://sebastian.itch.io/geographical-adventures)

### Architecture Shift

| Aspect | Before | After |
|--------|--------|-------|
| Rendering | Flame Canvas 2D paths | Fragment shader raymarched globe |
| Terrain | Flat colored polygons | Satellite texture (NASA Blue Marble) |
| Ocean | Radial gradient fill | Shader: waves, specular, fresnel, depth tint |
| Coastlines | MaskFilter blur glow | Shore distance field + animated foam rings |
| Atmosphere | Radial gradient halo | Analytical Rayleigh approximation + rim glow |
| Clouds | None | Procedural noise layer / SDF sphere clusters |
| Sky | Solid color fill | Gradient with analytical scattering |
| Plane | Canvas Bezier paths | Canvas overlay (kept — stylistic contrast) |
| Country data | Canvas polygon fill | Shader-side texture; polygons retained for hit-testing |
| Error handling | Console logs | Runtime telemetry to Vercel + on-screen dev mode |

### Key Constraints

- **Cross-platform**: iOS, Android, Web — one shader, all platforms
- **Fragment shaders only**: Flutter's `FragmentProgram` (no vertex/compute shaders)
- **Max 4 samplers per pass**: may need multi-pass for all textures
- **Open-license assets only**: NASA Blue Marble, ETOPO, Natural Earth
- **Performance budget**: 60fps sustained, < 50MB total asset bundle

---

## Testing Strategy

### Primary: Flutter Web → PWA on iOS
- Deploy web build to **GitHub Pages** (free)
- Install as PWA on iOS home screen
- Near-native experience, instant updates

### Secondary: Native iOS via TestFlight
- Apple Developer account ($99/year) when ready for beta
- Codemagic free tier for iOS builds

### CI/CD Pipeline
```
Push → Lint → Test → Build (Web/Android) → Deploy Web to GitHub Pages
                                          → Deploy Android to Firebase App Distribution
```

### Local Development
```bash
flutter run -d chrome        # Web
flutter run -d ios            # iOS Simulator (Mac only)
flutter run -d android        # Android Emulator
```

---

## Sprint Overview

| Sprint | Focus | Est. Duration | Key Deliverable |
|--------|-------|---------------|-----------------|
| V0 | Runtime Telemetry & Error Pipeline | 1 day | Error logging to Vercel + dev overlay + GH Action |
| V1 | Shader Foundation & Globe | 2 days | Raymarched sphere with satellite texture |
| V2 | Ocean Shader | 2 days | Waves, specular, depth tinting, fresnel |
| V3 | Coastline Foam | 1 day | Animated foam rings from shore distance field |
| V4 | Atmosphere & Sky | 2 days | Analytical scattering, rim glow, sky gradient |
| V5 | Clouds | 2 days | Procedural cloud layer with lighting |
| V6 | Day/Night Cycle | 1 day | Sun rotation, city lights, stars |
| V7 | Camera & Altitude | 1 day | Smooth zoom, altitude-based detail levels |
| V8 | Plane Overlay Integration | 1 day | Canvas plane composited over shader globe |
| V9 | Gameplay Reconnection | 2 days | Hit-testing, clues, HUD over new renderer |
| V10 | Regional Maps in Shader | 2 days | US, UK, Caribbean, Ireland shader regions |
| V11 | Performance & Polish | 2 days | Profiling, LOD, asset optimization |
| V12 | Ship It | 1 day | Final QA, all platforms, launch |

---

## Sprint V0: Runtime Telemetry & Error Pipeline

**Goal:** Every runtime error, crash, and unhandled exception is captured, sent to a Vercel
serverless endpoint, stored, and fetchable via GitHub Action into an error log in the repo.
A dev-mode overlay displays critical errors on-screen for easy copy-paste debugging.

### Background-Appropriate Tasks
> Tasks marked with `[BG]` can run as background agents.

### Architecture

```
Flutter App
  │
  ├─ ErrorService (singleton)
  │   ├─ Captures: Zone errors, FlutterError, Platform errors
  │   ├─ Formats: stack trace, device info, timestamp, session ID, app version
  │   ├─ Queues locally (in-memory + optional Isar persistence)
  │   └─ Sends POST to Vercel endpoint (batched, with retry + exponential backoff)
  │
  ├─ DevOverlay (debug/profile mode only)
  │   ├─ Floating draggable error panel
  │   ├─ Shows last N critical errors with stack traces
  │   ├─ Tap-to-copy full error text
  │   └─ Hidden in release builds (kReleaseMode gate)
  │
  └─ Vercel Serverless Function
      ├─ POST /api/errors → validates, stores in Vercel KV or JSON blob
      ├─ GET /api/errors?since=<ISO>&limit=<N> → returns recent errors
      └─ Auth: simple API key in header (not user-facing)

GitHub Action (scheduled or manual)
  ├─ Fetches GET /api/errors?since=<last_fetch>
  ├─ Appends to logs/runtime-errors.jsonl in repo
  └─ Commits + pushes if new errors exist
```

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V0.1 | Create Vercel project + serverless function `/api/errors` (POST + GET) | implement | Yes | [BG] |
| V0.2 | Create `ErrorService` singleton in `lib/core/services/error_service.dart` | implement | Yes | |
| V0.3 | Create `DevOverlay` widget in `lib/core/services/dev_overlay.dart` | implement | Yes | |
| V0.4 | Wire `ErrorService` into app entrypoint (`runZonedGuarded`, `FlutterError.onError`) | implement | No (after V0.2) | |
| V0.5 | Wire `DevOverlay` into app widget tree (debug/profile only) | implement | No (after V0.3) | |
| V0.6 | Create GitHub Action `.github/workflows/fetch-errors.yml` | implement | Yes | [BG] |
| V0.7 | Create `logs/` directory with `.gitkeep` and initial `runtime-errors.jsonl` | implement | Yes | [BG] |
| V0.8 | Add `VERCEL_ERRORS_API_KEY` to GitHub Secrets documentation | implement | Yes | [BG] |
| V0.9 | Integration test: trigger test error → verify round-trip to Vercel → fetch via GH Action | test-runner | No (after all) | |

### Error Payload Schema
```json
{
  "timestamp": "2026-02-07T12:00:00.000Z",
  "sessionId": "uuid-v4",
  "appVersion": "1.0.0+42",
  "platform": "web|ios|android",
  "deviceInfo": "iPhone 15 / iOS 18.2 / Safari",
  "severity": "critical|error|warning",
  "error": "RangeError: index out of bounds",
  "stackTrace": "...",
  "context": {
    "screen": "PlayScreen",
    "gameState": "in_flight",
    "lastAction": "altitude_toggle"
  }
}
```

### DevOverlay Behavior
- **Debug/Profile mode only** — `kReleaseMode` gate, zero overhead in release
- Floating semi-transparent panel, draggable to any screen edge
- Shows last 5 errors with severity badge (red=critical, orange=error, yellow=warning)
- Tap error → expands to full stack trace
- Long-press → copies full error JSON to clipboard
- Shake device or triple-tap to toggle visibility
- Persists across screen navigation (overlay above Navigator)

### Definition of Done
- [ ] Vercel function accepts POST, returns GET with filtering
- [ ] `ErrorService` captures all unhandled Flutter/Zone/platform errors
- [ ] Errors POST to Vercel with retry (3 attempts, exponential backoff)
- [ ] `DevOverlay` shows errors in debug mode with copy functionality
- [ ] GitHub Action fetches and commits error logs
- [ ] Release builds have zero telemetry overhead (tree-shaken)
- [ ] Works on iOS, Android, AND Web

---

## Sprint V1: Shader Foundation & Globe

**Goal:** Replace the Canvas-based `WorldMap` with a fragment shader that raymarches a textured
sphere. The globe should display satellite imagery and respond to camera position/rotation.

### Architecture

```
FlitGame (Flame)
  │
  ├─ GlobeRenderer (new component, replaces WorldMap)
  │   ├─ CustomPainter + FragmentProgram
  │   ├─ Uniforms: cameraPos, cameraTarget, sunDir, time, altitude
  │   ├─ Samplers: satelliteTexture (Blue Marble), heightmap
  │   └─ Output: raymarched sphere with equirectangular texture mapping
  │
  ├─ ShaderManager (new singleton)
  │   ├─ Loads + caches FragmentProgram instances
  │   ├─ Manages uniform buffers
  │   └─ Handles shader hot-reload in debug mode
  │
  └─ PlaneComponent (unchanged — Canvas overlay on top)
```

### Shader Pipeline (globe.frag)
```
Per pixel:
1. Compute ray from camera through pixel (perspective projection)
2. Ray-sphere intersection test (analytical, not iterative)
3. At hit point: compute equirectangular UV from spherical coords
4. Sample satellite texture at UV
5. Compute diffuse lighting: dot(normal, sunDirection)
6. Apply simple height-based shading from heightmap
7. Miss: output sky color (placeholder, replaced in V4)
```

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V1.1 | Download + process NASA Blue Marble imagery (2048x1024 web-safe) | geo-data-validator | Yes | [BG] |
| V1.2 | Download + process ETOPO heightmap (2048x1024) | geo-data-validator | Yes | [BG] |
| V1.3 | Write `shaders/globe.frag` — ray-sphere intersection + equirectangular UV + texture sampling | implement | Yes | |
| V1.4 | Write `lib/game/rendering/shader_manager.dart` — load/cache FragmentProgram | implement | Yes | |
| V1.5 | Write `lib/game/rendering/globe_renderer.dart` — CustomPainter with shader | implement | No (after V1.3, V1.4) | |
| V1.6 | Integrate `GlobeRenderer` into `FlitGame` replacing `WorldMap` render calls | implement | No (after V1.5) | |
| V1.7 | Add diffuse lighting uniform (sun direction) | implement | No (after V1.6) | |
| V1.8 | Add heightmap sampling for terrain relief shading | implement | No (after V1.7) | |
| V1.9 | Camera-to-uniform pipeline: map game camera state → shader uniforms | implement | No (after V1.6) | |
| V1.10 | Cross-platform shader compilation verification (SPIR-V for mobile, GLSL ES for web) | platform-validator | No (after V1.6) | |
| V1.11 | Performance baseline: measure FPS with shader globe on all platforms | performance-profiler | No (after V1.10) | |

### Asset Pipeline
```
Source: NASA Blue Marble (public domain)
  → Download highest available equirectangular projection
  → Resize to 2048x1024 (or 4096x2048 if budget allows)
  → Convert to PNG (lossless for shader sampling)
  → Place in assets/textures/blue_marble.png

Source: ETOPO1 (public domain)
  → Download global heightmap
  → Normalize to 0-255 grayscale (0=deepest ocean, 255=highest peak)
  → Resize to 2048x1024
  → Convert to PNG
  → Place in assets/textures/heightmap.png
```

### Shader Uniform Contract
```glsl
// globe.frag uniforms
uniform vec2 uResolution;     // viewport size in pixels
uniform vec3 uCameraPos;      // camera position in world space
uniform vec3 uCameraTarget;   // what camera looks at (globe center)
uniform vec3 uSunDir;         // normalized sun direction
uniform float uTime;          // elapsed time in seconds
uniform float uGlobeRadius;   // globe radius in world units
uniform sampler2D uSatellite; // Blue Marble texture
uniform sampler2D uHeightmap; // ETOPO heightmap
```

### Definition of Done
- [ ] Fragment shader compiles on iOS (Metal/SPIR-V), Android (Vulkan/GLES), Web (WebGL)
- [ ] Globe renders with satellite texture, visually recognizable continents
- [ ] Camera position maps correctly from game state to shader uniforms
- [ ] Diffuse lighting produces visible day/shadow
- [ ] Heightmap modulates shading (mountains slightly brighter on sun side)
- [ ] 60fps on mid-range devices (iPhone 12, Pixel 6, Chrome desktop)
- [ ] Old `WorldMap` Canvas code preserved in `lib/game/map/world_map_legacy.dart` (fallback)
- [ ] Assets total < 15MB compressed

---

## Sprint V2: Ocean Shader

**Goal:** Ocean areas render with depth-based color, animated wave normals, specular sun
reflection, and fresnel rim brightening. Visually distinct from land.

### Shader Enhancement (globe.frag additions)
```
After texture sampling:
1. Check heightmap: if height < sea_level threshold → ocean pixel
2. Ocean color: lerp(deepBlue, shallowTurquoise, depth)
3. Wave normals: perturb surface normal using sin() waves + time
4. Specular: compute sun reflection highlight (Blinn-Phong or Gaussian)
5. Fresnel: brighten at glancing angles (pow(1-dot(view, normal), 5))
6. Ripple: subtle brightening based on perturbed normal · view
```

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V2.1 | Process bathymetry texture from ETOPO (ocean depth map, separate channel or texture) | geo-data-validator | Yes | [BG] |
| V2.2 | Implement land/ocean masking in `globe.frag` using heightmap threshold | implement | Yes | |
| V2.3 | Implement depth-based ocean coloring (deep navy → shallow turquoise) | implement | No (after V2.2) | |
| V2.4 | Implement animated wave normal perturbation (multi-octave sin waves) | implement | No (after V2.3) | |
| V2.5 | Implement specular sun reflection (Gaussian model: `exp(-angle²/smoothness²)`) | implement | No (after V2.4) | |
| V2.6 | Implement fresnel rim effect on ocean | implement | No (after V2.5) | |
| V2.7 | Tune ocean parameters: wave speed, scale, specular intensity, color ramp | implement | No (after V2.6) | |
| V2.8 | Performance test: measure shader complexity impact on FPS | performance-profiler | No (after V2.7) | |

### Ocean Color Ramp
```glsl
// Depth-based ocean coloring
vec3 deepOcean   = vec3(0.02, 0.05, 0.15);   // near-black blue
vec3 midOcean    = vec3(0.05, 0.15, 0.35);   // dark blue
vec3 shallowSea  = vec3(0.10, 0.35, 0.50);   // teal
vec3 coastalWater = vec3(0.15, 0.50, 0.55);  // turquoise
```

### Definition of Done
- [ ] Ocean visually distinct from land (color, reflections, movement)
- [ ] Waves animate smoothly, no strobing or aliasing
- [ ] Sun specular highlight visible and moves with sun direction
- [ ] Fresnel brightening at globe edges (ocean appears lighter at rim)
- [ ] No hard seam between land and ocean
- [ ] 60fps maintained on all platforms

---

## Sprint V3: Coastline Foam

**Goal:** White animated foam rings emanate from every coastline, with organic noise breakup
and solid white shore edges — the signature Geographical Adventures look.

### Pre-computation
A **shore distance texture** must be generated offline (or at build time) from the heightmap.
For each ocean pixel, encode its distance to the nearest land pixel. This is the input for
the foam shader.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V3.1 | Generate shore distance texture from heightmap (Jump Flood or brute-force offline script) | implement | Yes | [BG] |
| V3.2 | Add `uShoreDist` sampler to `globe.frag` | implement | No (after V3.1) | |
| V3.3 | Implement solid white shore edge (smoothstep on distance < threshold) | implement | No (after V3.2) | |
| V3.4 | Implement animated concentric foam rings (sin wave on distance + time) | implement | No (after V3.3) | |
| V3.5 | Implement noise mask to break up foam regularity (procedural noise) | implement | No (after V3.4) | |
| V3.6 | Implement distance-based fade (foam disappears far from shore) | implement | No (after V3.5) | |
| V3.7 | Tune foam parameters: width, speed, frequency, noise scale | implement | No (after V3.6) | |

### Foam Algorithm (in shader)
```glsl
float foam(vec2 uv, float shoreDist, float time) {
    float d = shoreDist / maxFoamDist;

    // Solid white edge at immediate shore
    float shoreEdge = smoothstep(0.02, 0.0, d);

    // Animated concentric rings
    float rings = sin(d * frequency - time * speed + noise(uv) * d);
    rings = smoothstep(foamWidth + blend, foamWidth, rings + 1.0);

    // Noise mask for organic breakup
    float mask = smoothstep(0.4, 0.5, noise(uv * maskScale + time * 0.02));
    rings *= mask;

    // Fade with distance
    rings *= 1.0 - smoothstep(0.7, 1.0, d);

    return clamp(rings + shoreEdge, 0.0, 1.0);
}
```

### Definition of Done
- [ ] Shore distance texture generated and bundled (< 2MB)
- [ ] White foam visible along all coastlines
- [ ] Foam animates outward from shore with organic noise breakup
- [ ] Solid white edge at immediate shoreline
- [ ] Foam fades to zero in open ocean
- [ ] No performance regression (still 60fps)
- [ ] Visually matches Geographical Adventures coastline style

---

## Sprint V4: Atmosphere & Sky

**Goal:** Replace the solid background with a physically-inspired sky gradient and add
atmospheric rim glow around the globe edge. Distant terrain subtly fades into blue haze.

### Approach
Full Rayleigh/Mie scattering is too expensive for a single-pass fragment shader without
compute shader LUTs. Instead, use an **analytical approximation** that captures the key
visual characteristics:
- Blue sky that shifts to orange/red near horizon
- Bright rim glow around the globe silhouette
- Haze that desaturates distant terrain

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V4.1 | Implement sky gradient background in `globe.frag` (ray-miss path) | implement | Yes | |
| V4.2 | Implement atmospheric rim glow at globe edge (fresnel on sphere silhouette) | implement | Yes | |
| V4.3 | Implement analytical Rayleigh approximation for sky color | implement | No (after V4.1) | |
| V4.4 | Implement aerial perspective haze on terrain (desaturate + lighten with view distance) | implement | No (after V4.3) | |
| V4.5 | Implement sun disc in sky (bright spot + gaussian bloom) | implement | No (after V4.3) | |
| V4.6 | Tune atmosphere parameters: density, color, falloff, haze intensity | implement | No (after V4.5) | |
| V4.7 | Performance test atmosphere shader complexity | performance-profiler | No (after V4.6) | |

### Analytical Atmosphere Model
```glsl
// Simplified scattering approximation
vec3 atmosphere(vec3 rayDir, vec3 sunDir) {
    float sunDot = max(dot(rayDir, sunDir), 0.0);

    // Rayleigh: blue scattered light, stronger perpendicular to sun
    vec3 rayleigh = vec3(0.3, 0.5, 1.0) * (1.0 - 0.5 * sunDot * sunDot);

    // Mie: forward scattering halo around sun
    float mie = pow(sunDot, 32.0) * 0.5;

    // Horizon brightening
    float horizon = pow(1.0 - abs(rayDir.y), 4.0);
    vec3 horizonColor = mix(vec3(0.4, 0.6, 1.0), vec3(1.0, 0.6, 0.3), sunDot);

    return rayleigh + mie + horizon * horizonColor;
}
```

### Definition of Done
- [ ] Sky gradient replaces solid background
- [ ] Globe has visible atmospheric rim glow
- [ ] Distant terrain fades slightly into blue haze
- [ ] Sun disc visible in sky with bloom effect
- [ ] Sky color shifts towards warm tones near sun
- [ ] 60fps maintained

---

## Sprint V5: Clouds

**Goal:** Add a procedural cloud layer above the globe surface. Clouds should look puffy and
volumetric, casting subtle shadows on terrain below.

### Approach
Two options (decide during implementation based on performance):

**Option A: Noise-based cloud shell**
- Second sphere slightly larger than globe
- Sample 3D noise at surface point for cloud density
- Simple lighting: dot(normal, sunDir)
- Fast, simple, good for mobile

**Option B: SDF sphere clusters**
- Define cloud positions on globe as lat/lng clusters
- Each cloud = union of overlapping SDF spheres
- Raymarch through cloud volume
- Looks puffier but more expensive

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V5.1 | Implement cloud sphere intersection (second larger sphere) | implement | Yes | |
| V5.2 | Implement procedural 3D noise for cloud density | implement | Yes | |
| V5.3 | Implement cloud lighting (diffuse from sun direction) | implement | No (after V5.1, V5.2) | |
| V5.4 | Implement cloud shadows on terrain (shadow ray test) | implement | No (after V5.3) | |
| V5.5 | Implement cloud animation (slow UV drift with time) | implement | No (after V5.3) | |
| V5.6 | [STRETCH] Implement SDF sphere-cluster clouds if performance allows | implement | No (after V5.5) | |
| V5.7 | Tune cloud coverage, density, height, speed, shadow intensity | implement | No (after V5.5) | |
| V5.8 | Performance test cloud layer impact | performance-profiler | No (after V5.7) | |

### Cloud Rendering (in shader)
```glsl
// After globe hit, before final color output:
// Cast ray further to check cloud shell intersection
float cloudHit = intersectSphere(ray, cloudRadius);
if (cloudHit > 0.0) {
    vec3 cloudPoint = rayOrigin + ray * cloudHit;
    vec3 cloudNormal = normalize(cloudPoint);

    // Sample noise for density
    float density = fbm(cloudNormal * noiseScale + time * windSpeed);
    density = smoothstep(coverageThreshold, coverageThreshold + 0.2, density);

    // Light cloud
    float cloudLight = max(dot(cloudNormal, sunDir), 0.0) * 0.7 + 0.3;
    vec3 cloudColor = vec3(cloudLight);

    // Blend over terrain
    finalColor = mix(finalColor, cloudColor, density * cloudOpacity);
}
```

### Definition of Done
- [ ] Clouds visible above globe surface
- [ ] Clouds animate slowly (wind drift)
- [ ] Clouds lit by sun direction (bright tops, darker undersides)
- [ ] Clouds cast approximate shadows on terrain
- [ ] Cloud coverage tunable (sparse to overcast)
- [ ] 60fps on target devices (may need LOD for mobile)
- [ ] Clouds render on all three platforms

---

## Sprint V6: Day/Night Cycle

**Goal:** Sun rotates, creating a moving terminator line. Night side shows city lights and stars.
Sunset/sunrise produces warm tones at the terminator.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V6.1 | Download + process NASA Earth at Night (city lights texture) | geo-data-validator | Yes | [BG] |
| V6.2 | Implement sun direction rotation over time | implement | Yes | |
| V6.3 | Implement day/night terrain blending at terminator | implement | No (after V6.2) | |
| V6.4 | Implement city lights on night side (emissive texture) | implement | No (after V6.1, V6.3) | |
| V6.5 | Implement star field behind globe (procedural or texture) | implement | Yes | |
| V6.6 | Implement warm terminator glow (sunset colors at day/night boundary) | implement | No (after V6.3) | |
| V6.7 | Implement night fresnel glow (atmospheric rim on dark side) | implement | No (after V6.6) | |
| V6.8 | Tune cycle speed, terminator width, light intensity | implement | No (after V6.7) | |

### Day/Night Shader Logic
```glsl
// Terminator calculation
float dayFactor = smoothstep(-0.1, 0.2, dot(surfaceNormal, sunDir));

// Day terrain
vec3 dayColor = satelliteColor * diffuseLight;

// Night terrain
float cityLight = texture(uCityLights, uv).r;
vec3 nightColor = satelliteColor * 0.02 + cityLight * vec3(1.0, 0.8, 0.4);

// Blend
vec3 terrainColor = mix(nightColor, dayColor, dayFactor);

// Warm terminator glow
float terminatorGlow = exp(-abs(dot(surfaceNormal, sunDir)) * 10.0);
terrainColor += terminatorGlow * vec3(1.0, 0.4, 0.1) * 0.15;
```

### Sampler Budget Check
After this sprint, samplers in `globe.frag`:
1. `uSatellite` — Blue Marble
2. `uHeightmap` — ETOPO heightmap
3. `uShoreDist` — shore distance field
4. `uCityLights` — NASA Earth at Night

**That's exactly 4 samplers** — the Flutter FragmentProgram limit. If we need more, we must:
- Pack multiple maps into RGBA channels of fewer textures
- Split into a multi-pass pipeline
- Use procedural generation instead of textures

### Definition of Done
- [ ] Sun visibly rotates (or player can be in different time zones)
- [ ] Smooth terminator transition (no hard line)
- [ ] City lights glow on night side
- [ ] Stars visible behind globe on dark side
- [ ] Warm glow at sunset terminator
- [ ] 4-sampler budget respected
- [ ] 60fps maintained

---

## Sprint V7: Camera & Altitude System

**Goal:** Smooth camera transitions between altitudes. High altitude = zoomed-out overview,
low altitude = close-up with more terrain detail. FOV shifts with speed.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V7.1 | Implement camera distance interpolation (high ↔ low altitude) | implement | Yes | |
| V7.2 | Implement FOV shift with speed (narrow at slow, wide at fast) | implement | Yes | |
| V7.3 | Implement smooth camera transitions (ease-out interpolation) | implement | No (after V7.1) | |
| V7.4 | Map camera parameters to shader uniforms (cameraPos, target, FOV) | implement | No (after V7.3) | |
| V7.5 | Implement altitude-based detail: show city labels at low altitude only | implement | No (after V7.4) | |
| V7.6 | Implement mip-level hinting for textures at different altitudes | implement | No (after V7.4) | |

### Camera-to-Shader Mapping
```dart
// In GlobeRenderer, each frame:
final cameraDistance = lerpDouble(
  highAltitudeDistance,  // e.g., 4.0 globe radii
  lowAltitudeDistance,   // e.g., 1.5 globe radii
  altitudeT,
);
final fov = lerpDouble(fovSlow, fovFast, speedT);

shader.setFloat(0, cameraPos.x);  // computed from plane lat/lng + distance
shader.setFloat(1, cameraPos.y);
shader.setFloat(2, cameraPos.z);
// ... etc
```

### Definition of Done
- [ ] Altitude toggle smoothly zooms in/out
- [ ] FOV widens with speed (subtle but noticeable)
- [ ] Camera stays centered on plane's globe position
- [ ] City labels/details appear only at low altitude
- [ ] No judder or snap during transitions
- [ ] 60fps during transitions

---

## Sprint V8: Plane Overlay Integration

**Goal:** The existing Canvas-drawn `PlaneComponent` composites cleanly on top of the
shader-rendered globe. Contrails render correctly over the globe surface.

### Approach
The plane stays as a **Canvas overlay** — its lo-fi hand-drawn style provides intentional
stylistic contrast against the realistic globe (similar to how Wind Waker mixes toon
characters with detailed environments).

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V8.1 | Ensure `PlaneComponent` renders on a separate Canvas layer above shader | implement | Yes | |
| V8.2 | Adjust plane shadow to project onto globe surface (parallax offset by altitude) | implement | No (after V8.1) | |
| V8.3 | Update contrail particles to render over globe correctly | implement | No (after V8.1) | |
| V8.4 | Implement contrail fade that respects globe curvature (older trail hidden by horizon) | implement | No (after V8.3) | |
| V8.5 | Tune plane scale relative to new globe rendering | implement | No (after V8.1) | |
| V8.6 | Test all 9 plane cosmetics render correctly over shader | platform-validator | No (after V8.5) | |

### Definition of Done
- [ ] Plane renders on top of globe with no z-fighting
- [ ] Plane shadow offset correlates with altitude
- [ ] Contrails visible and fade naturally behind horizon
- [ ] All 9 plane skins work over new renderer
- [ ] No visual glitches at plane/globe boundary

---

## Sprint V9: Gameplay Reconnection

**Goal:** All gameplay systems (clues, hit-testing, HUD, scoring, sessions) work with the new
shader-based renderer. The game is fully playable again.

### Challenge
Country hit-testing previously relied on Canvas polygon paths. The shader doesn't know about
individual countries — it samples a satellite texture. We need to maintain the projection math
for hit-testing while rendering via shader.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V9.1 | Retain `country_data.dart` polygon data for hit-testing (not rendering) | implement | Yes | |
| V9.2 | Implement screen-point → globe-point unprojection (reverse of shader ray) | implement | Yes | |
| V9.3 | Implement point-in-country-polygon test using retained polygon data | implement | No (after V9.1, V9.2) | |
| V9.4 | Wire clue system to new renderer (display clue overlay) | implement | No (after V9.3) | |
| V9.5 | Wire landing detection to new hit-test system | implement | No (after V9.3) | |
| V9.6 | Wire HUD overlay (timer, altitude indicator, clue display) | implement | Yes | |
| V9.7 | Wire game session management (start, play, score, end) | implement | No (after V9.5) | |
| V9.8 | Full gameplay loop test: spawn → clue → fly → land → score | test-runner | No (after V9.7) | |
| V9.9 | Test all game modes: solo, challenge, daily | test-runner | No (after V9.8) | |

### Unprojection Math
```dart
// Screen point → ray → globe intersection → lat/lng
Offset screenToGlobe(Offset screenPoint, CameraState camera) {
  // 1. Screen → NDC
  // 2. NDC → ray direction (inverse projection)
  // 3. Ray-sphere intersection
  // 4. Hit point → lat/lng
  // Same math as shader but in Dart
}
```

### Definition of Done
- [ ] Tapping a country correctly identifies it
- [ ] All clue types display correctly
- [ ] Landing detection works at low altitude over target
- [ ] Timer, score, altitude indicator all functional
- [ ] Full solo game loop playable
- [ ] Challenge mode playable
- [ ] Daily challenge playable
- [ ] No gameplay regression from old renderer

---

## Sprint V10: Regional Maps in Shader

**Goal:** Regional maps (US States, UK Counties, Caribbean, Ireland) work with the shader
renderer. Camera zooms to region, shader parameters adjust for regional view.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V10.1 | Implement camera preset positions for each region (lat/lng/zoom) | implement | Yes | |
| V10.2 | Implement camera constraints to keep view within region bounds | implement | No (after V10.1) | |
| V10.3 | Implement region-specific overlay borders (shader or Canvas) | implement | No (after V10.1) | |
| V10.4 | Update hit-testing for regional subdivision polygons | implement | Yes | |
| V10.5 | Test regional gameplay: fly within region, land on target subdivision | test-runner | No (after V10.4) | |
| V10.6 | Test all 4 regions on all platforms | platform-validator | No (after V10.5) | |

### Definition of Done
- [ ] Camera smoothly transitions to regional view
- [ ] Player can't fly outside region bounds (or wraps)
- [ ] Regional borders visible
- [ ] Hit-testing identifies correct subdivision (state/county/island)
- [ ] All 4 regions playable on iOS, Android, Web

---

## Sprint V11: Performance & Polish

**Goal:** Optimize shader complexity, asset sizes, and rendering pipeline for production
performance. Visual polish pass on all effects.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V11.1 | Profile shader: identify hotspots per platform (GPU timing) | performance-profiler | Yes | |
| V11.2 | Implement shader LOD: reduce iterations/samples when far from globe | implement | No (after V11.1) | |
| V11.3 | Optimize texture sizes: test 1024 vs 2048 quality/performance tradeoff | performance-profiler | Yes | [BG] |
| V11.4 | Implement texture channel packing (heightmap + shore dist in one RGBA) | implement | No (after V11.3) | |
| V11.5 | Memory audit: ensure no texture leaks, proper disposal | performance-profiler | Yes | [BG] |
| V11.6 | Visual polish: tune all shader parameters for cohesive look | implement | No (after V11.4) | |
| V11.7 | Anti-aliasing: implement FXAA or smoothstep-based edge softening | implement | No (after V11.6) | |
| V11.8 | Color banding: add dithering to prevent gradient stepping | implement | No (after V11.7) | |
| V11.9 | Bundle size audit: verify total assets < 50MB | build-validator | No (after V11.8) | |
| V11.10 | Final FPS verification on target devices | performance-profiler | No (after V11.9) | |

### Definition of Done
- [ ] 60fps sustained on: iPhone 12+, Pixel 6+, Chrome desktop, Safari
- [ ] Total app bundle < 50MB
- [ ] No memory leaks during extended play
- [ ] All visual effects cohesive and polished
- [ ] No color banding in gradients
- [ ] No aliasing artifacts on sphere edges

---

## Sprint V12: Ship It

**Goal:** Final QA, all platforms verified, production deployed.

### Tasks

| Task ID | Task | Agent | Parallel? | BG? |
|---------|------|-------|-----------|-----|
| V12.1 | Full gameplay regression test (all modes, all regions) | test-runner | Yes | |
| V12.2 | Cross-platform visual comparison (screenshot diff) | platform-validator | Yes | |
| V12.3 | Security audit of error telemetry endpoint | security-auditor | Yes | [BG] |
| V12.4 | Production Vercel deployment for error endpoint | implement | Yes | [BG] |
| V12.5 | Production web deployment (GitHub Pages) | build-validator | No (after V12.1) | |
| V12.6 | App Store / Play Store submission prep | implement | No (after V12.1) | |
| V12.7 | Smoke test all platforms in production | platform-validator | No (after V12.5) | |
| V12.8 | Monitor error telemetry for 24h post-launch | implement | No (after V12.7) | |

### Definition of Done
- [ ] All game modes playable on all platforms
- [ ] Visual quality matches target (Geographical Adventures aesthetic)
- [ ] Error telemetry flowing to Vercel + GitHub logs
- [ ] No P0/P1 bugs
- [ ] Performance budgets met
- [ ] Production deployed and accessible

---

## Parallel Execution Map

```
V0:  [V0.1]──┐   [V0.6]──┐
     [V0.2]──┼─[V0.4]──┐ │
     [V0.3]──┼─[V0.5]──┼─┼──[V0.9]
     [V0.7]──┘         │ │
     [V0.8]─────────────┘ │
                           │
V1:  [V1.1]──┐            │
     [V1.2]──┤            │
     [V1.3]──┼─[V1.5]──[V1.6]──[V1.7]──[V1.8]──[V1.9]──[V1.10]──[V1.11]
     [V1.4]──┘

V2:  [V2.1]──┐
     [V2.2]──┴─[V2.3]──[V2.4]──[V2.5]──[V2.6]──[V2.7]──[V2.8]

V3:  [V3.1]──[V3.2]──[V3.3]──[V3.4]──[V3.5]──[V3.6]──[V3.7]

V4:  [V4.1]──┐
     [V4.2]──┴─[V4.3]──[V4.4]──[V4.5]──[V4.6]──[V4.7]

V5:  [V5.1]──┐
     [V5.2]──┴─[V5.3]──[V5.4]──[V5.5]──[V5.6]──[V5.7]──[V5.8]

V6:  [V6.1]──┐
     [V6.2]──┼─[V6.3]──[V6.4]──[V6.6]──[V6.7]──[V6.8]
     [V6.5]──┘

V7:  [V7.1]──┐
     [V7.2]──┴─[V7.3]──[V7.4]──[V7.5]──[V7.6]

V8:  [V8.1]──[V8.2]──[V8.3]──[V8.4]──[V8.5]──[V8.6]

V9:  [V9.1]──┐
     [V9.2]──┼─[V9.3]──[V9.4]──[V9.5]──[V9.7]──[V9.8]──[V9.9]
     [V9.6]──┘

V10: [V10.1]──[V10.2]──[V10.3]──[V10.5]──[V10.6]
     [V10.4]──────────────────────┘

V11: [V11.1]──[V11.2]──┐
     [V11.3]────────────┼─[V11.4]──[V11.6]──[V11.7]──[V11.8]──[V11.9]──[V11.10]
     [V11.5]────────────┘

V12: [V12.1]──┐
     [V12.2]──┼──[V12.5]──[V12.7]──[V12.8]
     [V12.3]──┤
     [V12.4]──┘──[V12.6]
```

---

## Asset Budget

| Asset | Resolution | Format | Est. Size |
|-------|-----------|--------|-----------|
| NASA Blue Marble | 4096x2048 | PNG | ~12MB |
| ETOPO Heightmap | 2048x1024 | PNG | ~4MB |
| Shore Distance | 2048x1024 | PNG (single channel) | ~1MB |
| NASA Earth at Night | 2048x1024 | PNG | ~5MB |
| **Total** | | | **~22MB** |

Channel-packed version (after V11.4):

| Texture | R | G | B | A | Size |
|---------|---|---|---|---|------|
| `globe_pack_1.png` | Satellite R | Satellite G | Satellite B | Heightmap | ~14MB |
| `globe_pack_2.png` | City Lights | Shore Dist | (unused) | (unused) | ~3MB |
| **Total packed** | | | | | **~17MB** |

---

## Quick Commands

```bash
# Start sprint
git checkout -b sprint-VX-description

# Shader development (hot reload)
flutter run -d chrome --enable-experiment=native-assets

# Run all pre-commit checks
./scripts/test.sh && ./scripts/lint.sh

# Build all platforms
./scripts/build.sh

# Deploy web
git push origin main  # triggers GitHub Action

# Check error telemetry
curl -H "X-API-Key: $VERCEL_KEY" https://flit-olive.vercel.app/api/errors?limit=10

# Fetch errors into repo
gh workflow run fetch-errors.yml
```
