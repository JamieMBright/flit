# Plane Sprite Style Guide

## Overview

All plane sprites are **AI-generated PNG images** in a **realistic/photographic** style,
viewed from a **3rd-person chase camera** (above and behind the aircraft).
Sprites replace the previous procedural Canvas-drawn watercolor planes.

---

## Visual Style

### Camera Angle
- **Above and behind** the aircraft (~30° elevation, ~10° behind center)
- The viewer looks down and slightly forward over the aircraft's back
- The ground/horizon is **not visible** — transparent background only
- The plane fills roughly 60-70% of the frame

### Lighting
- **Top-left key light** (simulating sun from ~10 o'clock position)
- Soft shadow underneath the fuselage
- Subtle specular highlights on wings and canopy
- Consistent across all planes for visual cohesion

### Rendering Quality
- Photorealistic but slightly stylized (not hyper-real)
- Clean edges suitable for compositing over a globe
- No motion blur, no atmospheric haze on the aircraft itself
- Crisp silhouette against transparent background

### Background
- **Transparent (alpha channel)** — pure RGBA PNG
- No ground, sky, clouds, or environment in the sprite
- Clean anti-aliased edges for smooth compositing

---

## Sprite Sheet Format

### Frame Layout
- **7 banking frames** per plane (single row strip)
- Angles: **-45°, -30°, -15°, 0° (level), +15°, +30°, +45°**
- Frame 0 = max bank left, Frame 3 = level, Frame 6 = max bank right
- All frames same dimensions, horizontally packed

### Resolution
- **256×256 pixels per frame** (1792×256 total strip)
- Retina-ready: renders at ~128px on-screen, sharp at 2x
- Powers of 2 for GPU-friendly texture sampling
- Total per plane: ~100-200KB PNG (with transparency)

### Naming Convention
```
assets/sprites/planes/{plane_id}.png
```

Examples:
```
assets/sprites/planes/plane_default.png    # Classic Bi-Plane
assets/sprites/planes/plane_jet.png        # Sleek Jet
assets/sprites/planes/plane_stealth.png    # Stealth Bomber
assets/sprites/planes/plane_shuttle.png    # Challenger Shuttle
```

### Memory Budget
- 20 planes × ~150KB = ~3MB on disk
- Loaded on-demand (only equipped plane in memory during gameplay)
- Shop preview: load thumbnails or center frame only
- Total asset budget impact: well within 50MB limit

---

## AI Prompt Template

### Base Prompt (adapt per AI tool)

```
Product photograph of a {PLANE_DESCRIPTION}, viewed from above and behind
at a 30-degree angle. The aircraft is banking {BANK_ANGLE} degrees to the
{BANK_DIRECTION}. Transparent background, no ground or sky visible.
Studio lighting from top-left, soft shadows underneath. Clean edges,
photorealistic rendering with slight stylization. The aircraft fills
70% of the frame. PNG with alpha transparency. White/neutral studio
backdrop for easy background removal.
```

### Per-Plane Descriptions

| Plane ID | PLANE_DESCRIPTION |
|----------|-------------------|
| `plane_default` | classic yellow biplane with double-stacked wings and a propeller |
| `plane_paper` | white origami paper airplane, simple triangular folds |
| `plane_prop` | single-engine propeller plane, Cessna-style, white with blue stripe |
| `plane_padraigaer` | large turboprop cargo plane, grey fuselage, high wing |
| `plane_seaplane` | amphibious float plane with pontoons, white and orange |
| `plane_jet` | sleek modern private jet, white with silver accents |
| `plane_red_baron` | red Fokker Dr.I triplane, WWI era, three stacked wings |
| `plane_rocket` | retro rocket ship with fins, chrome and red, 1950s sci-fi style |
| `plane_warbird` | WWII P-51 Mustang fighter, olive drab with invasion stripes |
| `plane_night_raider` | B-17 Flying Fortress bomber, dark grey, four engines |
| `plane_concorde_classic` | Concorde supersonic airliner, white with blue tail, delta wings |
| `plane_hot_air_balloon` | colorful striped hot air balloon with wicker basket |
| `plane_shuttle` | NASA Space Shuttle orbiter, white with black thermal tiles |
| `plane_stealth` | B-2 Spirit stealth bomber, dark grey flying wing |
| `plane_presidential` | Boeing 747 in Air Force One livery, blue and white |
| `plane_golden_jet` | luxury private jet, gold metallic finish, sleek design |
| `plane_diamond_concorde` | Concorde with diamond-sparkle iridescent finish, prismatic |
| `plane_platinum_eagle` | futuristic eagle-shaped aircraft, platinum silver, swept wings |

### Banking Angle Prompts

Generate 7 images per plane with these angle substitutions:

| Frame | BANK_ANGLE | BANK_DIRECTION | Notes |
|-------|------------|----------------|-------|
| 0 | 45 | left | Hard bank left |
| 1 | 30 | left | Medium bank left |
| 2 | 15 | left | Gentle bank left |
| 3 | 0 | (level flight, wings level) | Straight ahead |
| 4 | 15 | right | Gentle bank right |
| 5 | 30 | right | Medium bank right |
| 6 | 45 | right | Hard bank right |

### Post-Processing Pipeline

1. **Generate** each frame individually using the AI tool
2. **Remove background** (if not already transparent) — use `rembg` or similar
3. **Crop & resize** to exactly 256×256, aircraft centered
4. **Strip** to consistent horizontal strip: `convert frame_*.png +append plane_id.png`
5. **Optimize**: `pngquant --quality=80-95 plane_id.png` (lossy compression, keeps alpha)

### Quick Command (ImageMagick)
```bash
# Combine 7 frames into a sprite strip
convert frame_0.png frame_1.png frame_2.png frame_3.png \
        frame_4.png frame_5.png frame_6.png +append \
        assets/sprites/planes/plane_id.png

# Verify dimensions
identify assets/sprites/planes/plane_id.png
# Expected: 1792x256
```

---

## Code Integration

### Rendering Pipeline

```
PlaneComponent (positioning, input, contrails)
  │
  ├─ SpritePlaneRenderer (NEW — loads PNG strip, selects frame by bank angle)
  │   ├─ Interpolates between adjacent frames for smooth banking
  │   ├─ Applies scale based on altitude
  │   └─ Draws shadow underneath
  │
  ├─ PlaneRenderer (EXISTING — procedural fallback for missing sprites)
  │
  └─ Procedural overlays (contrails, shadow) — kept as-is
```

### Key Changes

1. **`lib/game/rendering/sprite_plane_renderer.dart`** (NEW)
   - Loads sprite strip from assets
   - Selects frame based on `bankAngle` → frame index (with lerp between adjacent)
   - Renders with `canvas.drawImageRect()` for the selected frame region
   - Falls back to procedural `PlaneRenderer` if sprite asset missing

2. **`lib/game/components/plane_component.dart`** (MODIFY)
   - Add `ui.Image?` field for loaded sprite strip
   - In `render()`, prefer sprite rendering over procedural
   - Keep existing contrail, shadow, and fade-in logic

3. **`lib/data/models/cosmetic.dart`** (MINOR)
   - `previewAsset` field already exists — populate with sprite path
   - No structural changes needed

4. **`pubspec.yaml`** (ADD)
   ```yaml
   assets:
     - assets/sprites/planes/
   ```

### Banking Frame Selection

```dart
// Map bankAngle (-pi/4 to +pi/4) to frame index (0-6)
double normalized = (bankAngle / (pi / 4)).clamp(-1.0, 1.0); // -1 to +1
double frameFloat = (normalized + 1.0) * 3.0; // 0.0 to 6.0
int frameA = frameFloat.floor().clamp(0, 5);
int frameB = (frameA + 1).clamp(0, 6);
double blend = frameFloat - frameA; // 0.0 to 1.0

// Draw frameA at (1-blend) opacity, frameB at blend opacity
// for smooth interpolation between banking angles
```

---

## Migration Strategy

1. **Phase 1**: Add `SpritePlaneRenderer` alongside existing `PlaneRenderer`
2. **Phase 2**: Generate sprites for 2-3 planes as proof of concept
3. **Phase 3**: If satisfied, generate remaining planes
4. **Phase 4**: Remove procedural renderer once all sprites exist
5. **Fallback**: Any plane without a sprite strip automatically uses procedural rendering

The procedural system stays intact until all 20 planes have sprites.

---

## Companion Creatures

Companions (pidgey, eagle, dragon, etc.) remain **procedurally rendered** for now.
They have complex animations (wing flapping, breathing, flame effects) that
don't translate well to static sprite strips. Consider sprite-based companions
as a future enhancement.

---

## Checklist for Adding a New Plane

1. Write the AI prompt using the template above
2. Generate 7 frames (one per banking angle)
3. Remove backgrounds, crop to 256×256
4. Combine into horizontal strip (1792×256)
5. Save as `assets/sprites/planes/{plane_id}.png`
6. Add the `Cosmetic` entry in `cosmetic.dart` with `previewAsset` path
7. Test in PlanePreviewScreen (debug build)
8. Done — no code changes needed per plane
