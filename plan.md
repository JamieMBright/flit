# Flit — Project Plan

Last updated: 2026-02-21

---

## How It All Works

### Architecture Summary

Flit is a geography flight game built with **Flutter + Flame** on the frontend, **Supabase** for auth and data persistence, and **Vercel** for error telemetry. Players fly a hand-drawn plane over a GPU-rendered globe, receive clues about a target country/region, and try to land on it as fast as possible.

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (iOS / Android / Web)                      │
│                                                         │
│  LoginScreen ──► HomeScreen ──► RegionSelectScreen      │
│                                    │                    │
│                              PlayScreen                 │
│                    ┌───────────┼───────────┐            │
│                    │           │           │             │
│               FlitGame    GameHud    AccountNotifier     │
│              (FlameGame)  (overlay)   (Riverpod)        │
│                    │                      │             │
│          ┌────────┼────────┐         UserPrefs          │
│          │        │        │         Service            │
│    GlobeRenderer  Plane  Landing        │               │
│    (GLSL shader)  Comp   Detector       │               │
│          │                              │               │
│    ShaderManager                        │               │
│    (4 textures)                         │               │
└──────────┼──────────────────────────────┼───────────────┘
           │                              │
    ┌──────▼──────┐               ┌───────▼───────┐
    │  GPU / GLSL │               │   Supabase    │
    │  globe.frag │               │  (PostgreSQL) │
    │  4 samplers │               │  profiles     │
    └─────────────┘               │  user_settings│
                                  │  account_state│
    ┌─────────────┐               │  scores       │
    │   Vercel    │               │  friendships  │
    │  /api/errors│               │  challenges   │
    │  /api/health│               │  matchmaking  │
    └─────────────┘               └───────────────┘
```

### Rendering

The globe is a **fragment shader** (`shaders/globe.frag`) rendered via `FragmentProgram.fromAsset()`. It uses ray-sphere intersection to render a textured Earth with:
- Satellite texture (NASA Blue Marble)
- Ocean waves, specular highlights, Fresnel, coastline foam
- Atmospheric scattering (Rayleigh + Mie), rim glow, sky gradient
- Procedural volumetric clouds
- Day/night cycle with city lights and star field
- Country borders from SDF texture

4 texture samplers (max per pass): satellite, heightmap, shore distance SDF, city lights.

The plane is drawn on a **Canvas overlay** — hand-drawn aesthetic contrasting the realistic globe. At low altitude, the shader fades out and an OSM tile map (`flutter_map`) fades in for the landing approach.

### Game Flow

1. **Auth** — Supabase email+password (account required, no guest mode)
2. **Home** — Animated globe background, menu grid
3. **Region Select** — World + 5 regional modes, unlockable with coins/levels
4. **Play** — Flame game: clue appears, player flies to target, lands within 8 degrees at low altitude
5. **Score** — `10000 - (seconds * 10)`, with pilot license and level multipliers
6. **Persist** — Scores, stats, settings synced to Supabase (debounced 2s writes)

### State Management

- **Riverpod** `accountProvider` (StateNotifier) — single source of truth for player state
- **UserPreferencesService** — debounced write-through to Supabase (profiles, user_settings, account_state, scores tables)
- **GameSettings** singleton — user preferences (sensitivity, controls, map style)

### Error Telemetry

Three-tier capture (FlutterError, PlatformDispatcher, runZonedGuarded) → ErrorService queue → tiered user-facing handling → HTTP POST to Vercel `/api/errors` → GitHub Action processes logs into issues → logs purged after processing. DevOverlay shows errors in debug builds only.

---

## What's Done

- [x] Supabase auth, profiles, scores, settings, account_state, friendships, challenges, matchmaking
- [x] Row-Level Security on all tables
- [x] Admin panel gated by email check (client + RLS)
- [x] Guest mode removed (account required)
- [x] Account deletion (cascading FK order, needs Edge Function for auth user deletion)
- [x] Data export (JSON download on web, clipboard on mobile)
- [x] Error handling overhaul (tiered toasts/dialogs, auto GitHub issues, bug report button)
- [x] Error telemetry privacy (URL scrubbing, context scrubbing, no PII in logs)
- [x] Privacy policy (`public/privacy.html`) linked from login
- [x] Terms of service (`public/terms.html`) linked from login
- [x] Supabase keep-alive cron (Vercel `/api/health` every 3 days)
- [x] Leaderboard service (SQL views, global/daily/regional/friends, wired to UI)
- [x] Challengerless matchmaking (async pool, ELO banding, auto-friend, world-mode only)
- [x] Pilot license nationality flag + H2H display
- [x] Social titles (40+ titles, unlock criteria, equip/unequip, progress bars)
- [x] Challenge result screen (pilot cards, flags, round breakdown, rematch)
- [x] Region camera presets (per-region center/altitude/FOV, bounds clamping)
- [x] License stats persistence (race condition fixed with `_supabaseLoaded` guard)
- [x] Wayline origin offset (tail-relative spawn for all plane bodies)
- [x] Input validation (client-side clamping + Supabase SQL CHECK constraints)
- [x] Offline resilience (`_PendingWriteQueue`, SharedPreferences-backed, 200-cap, 5 retries)
- [x] CI/CD pipeline (lint, test, build, deploy, smoke test, auto-version)
- [x] DevOverlay (debug-only, `kReleaseMode` gated)
- [x] ShaderLOD (auto quality tiers with hysteresis)
- [x] Profanity filter for usernames
- [x] Audio system scaffolded (AudioManager ready, needs audio files)
- [x] Scaffolded models: subscription, ad_config, live_group, leaderboard, social_title

---

## Remaining Work

### Pre-Launch

#### Regional Game Modes
**Status:** GATED — 5 regional modes behind "Coming Soon" overlay. Admin bypass for testing.
- Underlying regional mode issues still need fixing before ungating
- Challengerless matchmaking is World-mode only until regional modes work

#### iOS App Icon
**Status:** CONFIGURED — `flutter_launcher_icons` in pubspec.yaml.
- Need 1024x1024 PNG source icon at `assets/icon/app_icon.png` (edge-to-edge, no padding)
- Run `flutter pub run flutter_launcher_icons` to generate all sizes

#### City Lights Texture
- Download NASA Earth at Night (Public Domain), resize, add to assets
- Currently placeholder `.gitkeep`

#### Country Borders Visibility
**Status:** IMPROVED — width increased, alpha floor added. May need further tuning on-device.

#### Audio Assets
- All audio directories contain only `.gitkeep` placeholders
- Need: engine loops (6 types), background music, SFX (6 types)
- `AudioManager` code is ready — just needs actual files

#### Companion Sprites Quality
- All 8 companions are procedural Canvas primitives (ovals, paths, circles)
- Replace with proper sprite assets or hand-drawn sprite sheets
- Update both in-game (`CompanionRenderer`) and shop preview (`_CompanionPreviewPainter`)

#### Plane Sprites Quality
- Basic Canvas drawing, needs hand-drawn aesthetic improvement
- All unlockable planes should look distinct and polished
- Update both in-game rendering and shop preview

#### Age Rating Assessment
- Geography game — likely all ages, verify no COPPA issues

#### App Screenshots
- Screenshots for all required device sizes (App Store + Play Store)

### Post-Launch

#### Subscription System
- Wire `Subscription` model to payment provider (RevenueCat, Stripe, or platform IAP)
- Gate premium features: ad removal, Live Group hosting, exclusive cosmetics
- Receipt validation server-side

#### Ad Integration
- Wire `AdConfig` model to ad SDK (AdMob, Unity Ads)
- Banner, interstitial, and rewarded ad placements
- Gate by subscription tier (premium = no ads)

#### Live Multiplayer
**Status:** Model scaffolded. **Deferred** — massive overhaul, needs Supabase Realtime, lobby state machine, round sync, latency compensation. Defer until player base justifies cost.

#### Social Features Expansion
- Friend activity feed
- Challenge notifications (push notifications)
- Social sharing (share scores to social media)

### Technical Debt

#### Test Coverage
**Status:** PARTIALLY DONE — 17 test files covering core game logic.
- Still needed: mock Supabase client integration tests, offline queue drain tests, debounce timing tests

#### Performance Profiling
- Profile shader on target devices (iPhone 12, Pixel 6)
- Measure LOD switching behavior
- Validate 60fps sustained across all platforms
- Asset bundle size audit (textures ~5MB uncompressed)

---

## Platform & Store Requirements Checklist

- [x] Guest mode removed
- [x] Account deletion functional
- [x] Data export functional
- [x] Privacy policy published and linked
- [x] Terms of service published and linked
- [x] App icon configured
- [x] Supabase keep-alive cron active
- [x] Regional game modes gated
- [x] Leaderboards functional
- [x] Error handling tiered
- [x] Error telemetry PII-safe
- [x] DevOverlay release-gated
- [ ] Age rating assessment
- [ ] App screenshots
- [ ] City lights texture added
- [ ] Audio assets added (or graceful silence)

---

## Cost Summary (Supabase Free Tier)

| Resource | Free Tier Limit | Expected Usage |
|---|---|---|
| Database storage | 500 MB | < 10 MB at launch (+ matchmaking pool) |
| API requests | Unlimited | Hundreds/day |
| Auth MAU | 50,000 | < 100 at launch |
| File storage | 1 GB | 0 (avatars generated client-side) |
| Realtime connections | 200 concurrent | < 10 at launch (no live multiplayer yet) |
| Edge functions | 500K/month | ~100/month (account deletion) |

First paid tier ($25/month) only needed at ~50K MAU or when live multiplayer ships.
