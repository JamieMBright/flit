# Flit - Inspiration: Geographical Adventures

Reference: [Geographical Adventures](https://sebastian.itch.io/geographical-adventures)
by Sebastian Lague ([source code](https://github.com/SebLague/Geographical-Adventures), MIT)

---

## Why This Game Works

Geographical Adventures proves that flying a tiny plane around a miniature globe
is inherently compelling. Players don't learn geography through quizzes -- they
learn it by physically navigating a sphere, discovering that polar shortcuts
exist, that Mercator-distorted countries look different in 3D, and that the
globe feels nothing like a flat map.

Tagged "Relaxing" and "Exploration" on itch.io, it feels like a world, not a
tool. A teacher commented: *"If you are a geography teacher, install this game
for your students!"*

---

## Best Bits to Draw From

### 1. The Tiny World Feel
The globe is small enough to circumnavigate in ~15-20 seconds. This keeps pace
fast and comical. Mountains are exaggerated. The plane is oversized relative to
Earth. The result is a toy-like miniature that's endlessly satisfying to orbit.

### 2. Layered Rendering Pipeline
Every visual layer is built from scratch, composited in order:
- **Terrain**: NASA Blue Marble satellite texture on a sphere mesh
- **Ocean**: Animated waves with specular highlights and depth-based coloring
- **Coastline foam**: Shore distance field drives foam rendering
- **Atmosphere**: Rayleigh scattering (rim glow from space, sky gradient when low)
- **Clouds**: Procedural volumetric (Worley noise + raymarching) -- removed from
  release for performance, but visually stunning in dev builds
- **Day/Night**: Solar system simulation drives the terminator line
- **City Lights**: Compute-shader-spawned point lights on the dark side
- **Stars & Moon**: Background celestial rendering

This is exactly the pipeline Flit's `globe.frag` replicates in a single
fragment shader pass.

### 3. Navigation Through Knowledge
There is no waypoint or compass pointing to the destination. The game tells you
a city and country name, then you must find it on the globe using your own
geographic knowledge. A 2D map overlay (press M) exists as a crutch, but
experienced players consider using it "cheat mode." This creates natural
difficulty scaling without settings menus.

### 4. Distance-Based Scoring
Deliveries are scored by proximity to the target city:
- **Perfect**: within 75 km
- **Good**: within 300 km
- **OK**: within 1000 km
- **Miss**: beyond 1000 km

Feedback is contextual: *"Perfect delivery! The package will land just 12km from
the city centre"* or *"Oh no! The package will land in the water, 2847km away."*
The scoring formula heavily rewards proximity:
`score = pow(1 - min(1, distKM / 3000), 5) * 100`

### 5. Boost Reward Loop
Accurate deliveries earn boost time (perfect = 15 seconds of 2x speed). This
creates a satisfying feedback loop: accuracy -> speed -> more deliveries ->
higher score. Landing in the correct country adds +2s bonus even on imperfect
drops.

### 6. Day/Night as Gameplay
The solar system simulation isn't just cosmetic. Flying into nighttime reveals
city lights on the ground, which serve as **navigation aids** -- the brightest
cluster in a country often marks the target city. Players learn to use the
terminator line strategically.

### 7. Physical Package Drops
Packages are physical objects that fall with parachutes and land on terrain.
This gives tangible weight to the delivery action. The parachute descent creates
a moment of tension as you watch whether it lands close enough.

### 8. Hot Air Balloons as Pickup Markers
Colorful hot air balloons hovering over cities mark package pickup locations.
They display country flags. This is visually charming and functionally clear --
you always know where to go next.

### 9. Plane Personality
The plane has animated ailerons that bank during turns, a spinning propeller,
navigation lights that automatically turn on at night (dot product of up vector
with sun direction), and contrail/exhaust trails. These small details make the
plane feel alive.

### 10. Timed + Endless Modes
The default mode runs a 15-minute timer -- when it ends, you see your score.
An "Endless Mode" button on the game-over screen lets you continue without
pressure. This dual-mode approach serves both competitive and relaxed players.

---

## Technical Approach (Unity/C#)

| Aspect | Their Approach | Our Approach (Flit) |
|--------|---------------|---------------------|
| Engine | Unity (C#, HLSL) | Flutter/Flame (Dart, GLSL) |
| Globe mesh | Cube-sphere (6 projected planes) | Ray-sphere intersection in fragment shader |
| Terrain | Mesh displacement + satellite texture | Satellite texture via equirectangular UV |
| Ocean | Separate mesh + `Ocean.shader` | Same-pass ocean in `globe.frag` |
| Atmosphere | Post-process raycasting shader | In-shader Rayleigh/Mie scattering |
| Clouds | Volumetric raymarching (removed for perf) | Procedural FBM noise in shader |
| City lights | Compute shader spawning | Texture sampling (NASA Earth at Night) |
| Day/night | Full solar system simulation | `uSunDir` uniform + terminator math |
| Hit testing | Country index texture lookup | `isPointInPolygon()` on CPU |
| Platform | Windows, macOS, Linux | iOS, Android, Web |
| Samplers | Unlimited (desktop GPU) | 4 max per pass (Flutter constraint) |

---

## Data Sources They Use (All Open License)

| Source | License | What It Provides |
|--------|---------|-----------------|
| NASA Blue Marble | Public Domain | Satellite surface imagery |
| NASA Earth at Night | Public Domain | City light emissions |
| GEBCO Gridded Bathymetry | Public | Ocean floor topography |
| Natural Earth | Public Domain | Country boundaries, coastlines |
| Heightmap/ETOPO | Public Domain | Terrain elevation |

All of these are approved sources for Flit (see CLAUDE.md).

---

## What Flit Adds Beyond the Inspiration

| Feature | Geographical Adventures | Flit |
|---------|------------------------|------|
| Multiplayer | None | Dogfight (best-of-5 challenges vs friends) |
| Leaderboards | Local personal best only | Global daily/weekly/monthly/yearly/all-time |
| Game modes | Timed + Endless | Free Flight, Training, Daily Scramble, Dogfight |
| Regional maps | World only | World + US States + UK Counties + Caribbean + Ireland |
| Clue variety | City + country name only | Flags, outlines, borders, capitals, stat bundles |
| Progression | None | Levels, XP, coins, unlockable regions |
| Cosmetics | None | 9 plane skins, 5 contrail styles, mystery boxes |
| Platform | Desktop only | Mobile + Web (cross-platform) |
| Accounts | None | User accounts, friend system |
| Fuel mechanic | None | Unlimited mode with fuel management |
| Daily challenge | None | Date-seeded same-puzzle-for-everyone |

---

## Key Takeaway

Geographical Adventures succeeds because it's **simple, beautiful, and
educational without trying to be educational**. The core loop -- receive
destination, navigate globe, deliver package -- is immediately understandable
and infinitely replayable.

Flit extends this foundation with competitive multiplayer, progression systems,
and mobile accessibility while preserving the same sense of wonder that comes
from flying over a tiny, beautiful Earth.
