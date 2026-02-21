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
    │  /api/health│               └───────────────┘
    └─────────────┘
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

1. **Auth** — Supabase email+password or guest (local-only, no persistence)
2. **Home** — Animated globe background, menu grid
3. **Region Select** — World + 5 regional modes, unlockable with coins/levels
4. **Play** — Flame game: clue appears, player flies to target, lands within 8 degrees at low altitude
5. **Score** — `10000 - (seconds * 10)`, with pilot license and level multipliers
6. **Persist** — Scores, stats, settings synced to Supabase (debounced 2s writes)

### State Management

- **Riverpod** `accountProvider` (StateNotifier) — single source of truth for player state
- **UserPreferencesService** — debounced write-through to Supabase (profiles, user_settings, account_state, scores tables)
- **GameSettings** singleton — user preferences (sensitivity, controls, map style)
- Guest users (`id == 'guest'`) get no-op writes — everything stays local

### Error Telemetry

Three-tier capture (FlutterError, PlatformDispatcher, runZonedGuarded) → ErrorService queue → HTTP POST to Vercel `/api/errors` → persisted to `logs/runtime-errors.jsonl` via GitHub API. DevOverlay shows errors in debug builds only.

---

## What's Done

### Supabase Integration (was Phases 0-9 in old plan)

All core Supabase work is **implemented and live**:

- [x] Supabase project created and configured (`zrffgpkscdaybfhujioc.supabase.co`)
- [x] `supabase_flutter: ^2.3.0` in pubspec.yaml
- [x] `SupabaseConfig` with URL + anon key (compile-time overridable via `--dart-define`)
- [x] `Supabase.initialize()` in `main.dart`
- [x] `AuthService` with real Supabase auth (signUp, signIn, signOut, session restore)
- [x] Email confirmation flow in `LoginScreen`
- [x] Guest mode (local-only `Player.guest()`, all writes no-op)
- [x] DB trigger auto-creates profile on sign-up
- [x] `UserPreferencesService` — reads/writes profiles, user_settings, account_state tables
- [x] Debounced 2-second write-through sync strategy
- [x] Score submission to `scores` table on game completion
- [x] `AccountNotifier` wired to Supabase via `UserPreferencesService`
- [x] `FriendsService` — search, friend requests, accept/decline, H2H records, coin gifting
- [x] `ChallengeService` — deterministic seeded H2H challenges
- [x] Row-Level Security on all tables
- [x] SQL migrations in `supabase/migrations/`
- [x] Admin panel gated by email check (client + RLS)

### Scaffolded Features (models + UI written, not yet wired in)

All these files exist with complete implementations. They are ready to integrate but not yet connected to the app flow:

- [x] `lib/data/models/subscription.dart` — 4-tier freemium model (free/monthly/annual/lifetime)
- [x] `lib/data/models/ad_config.dart` — Ad placement strategy (banner/interstitial/rewarded)
- [x] `lib/data/models/live_group.dart` — Real-time multiplayer sessions (up to 8 players)
- [x] `lib/data/models/leaderboard.dart` — Multi-board leaderboard system (daily/all-time/regional/friends)
- [x] `lib/data/models/social_title.dart` — 40+ achievement titles across 8 categories
- [x] `lib/features/challenge/challenge_result_screen.dart` — End-of-challenge summary UI
- [x] `lib/game/ui/altitude_slider.dart` — Vertical altitude control slider
- [x] `lib/game/rendering/region_camera_presets.dart` — Per-region camera positions + bounds
- [x] `lib/core/core.dart` — Barrel export for core services

### Infrastructure

- [x] CI/CD pipeline (`ci.yml`) — lint, test, build web + Android, deploy to GitHub Pages, smoke test, auto-version
- [x] Error telemetry — Vercel serverless + GitHub JSONL persistence
- [x] DevOverlay — debug-only floating error panel
- [x] WebErrorBridge — JS interop for iOS Safari PWA error display
- [x] ShaderLOD — auto-adjusting quality tiers (high/medium/low) with hysteresis
- [x] GlobeHitTest — inverse projection for screen-to-globe coordinate mapping
- [x] Profanity filter for usernames
- [x] Audio system scaffolded (AudioManager with engine/music/SFX types)

---

## Future Work

### Priority 1 — Required Before Public Launch

#### Privacy Policy
**Status:** Not started
**Why:** The app collects email addresses (PII) via Supabase Auth. Both the iOS App Store and Google Play Store **require** a published privacy policy. GDPR (EU users) and CCPA (California users) also mandate one. The error telemetry sends browser User-Agent strings on web, which GDPR considers PII (fingerprinting potential).

**What to do:**
- Write a privacy policy covering: data collected (email, username, game stats, error logs), how it's stored (Supabase, Vercel), retention periods, user rights (deletion, export), no third-party sharing, no analytics/tracking
- Host it at `flit-olive.vercel.app/privacy` or as an in-app screen
- Link from the App Store / Play Store listings
- Link from the sign-up screen (pre-consent)
- Consider: strip User-Agent from web error payloads (replace with coarse platform label like native builds do)

#### Supabase Keep-Alive Cron
**Status:** Not started
**Why:** Supabase free tier pauses projects after 7 days of inactivity. Once paused, all auth and data sync stops until manually reactivated.

**What to do:**
- Add a `crons` key to `vercel.json` pinging `/api/health` twice a week
- OR add a GitHub Actions workflow that curls the Supabase REST endpoint on a schedule
- This is a 5-line config change but critical for production reliability

#### Leaderboard Service (Read Path)
**Status:** Scores are written to Supabase, but there is no service to *fetch* and display leaderboard rankings.
**What to do:**
- Create a leaderboard fetch service (or add methods to an existing service)
- Wire `LeaderboardScreen` to fetch from Supabase leaderboard views instead of `Leaderboard.placeholder()`
- The SQL views (`leaderboard_global`, `leaderboard_daily`, `leaderboard_regional`) may or may not exist in Supabase yet — check and create if needed

#### City Lights Texture
**Status:** `assets/textures/city_lights.png` is a `.gitkeep` placeholder — the actual NASA Earth at Night texture hasn't been added.
**Why:** The shader supports city lights for the night side of the globe, but renders black without the texture.
**What to do:** Download NASA Earth at Night (Public Domain), resize to match other textures, add to assets.

### Priority 2 — Post-Launch Features

#### Wire Leaderboard Model to UI
- Connect `LeaderboardScreen` to real Supabase data (depends on leaderboard service above)
- Support daily, all-time, regional, and friends board tabs
- Add player rank display (your position)
- Optional: Supabase Realtime for live leaderboard updates (WebSocket)

#### Wire Social Titles
- Connect `SocialTitle` catalog to gameplay milestones
- Track progress per category (flags, capitals, outlines, borders, stats, speed, streak)
- Display earned titles on profile screen
- Title selection UI (choose which title to display)

#### Wire Challenge Result Screen
- Connect `ChallengeResultScreen` to the challenge completion flow
- Show per-round time comparisons, coins earned, rematch option
- Currently challenges complete but may not show the full result UI

#### Wire Altitude Slider
- Connect `AltitudeSlider` widget to the game HUD
- Replace current altitude toggle (high/low) with smooth slider control
- Map slider position to continuous altitude values

#### Wire Region Camera Presets
- Connect `RegionCameraPresets` to the globe camera system
- Use per-region camera positions for region select screen previews
- Apply bounds-clamping during regional gameplay

#### Audio Assets
- All audio directories (`engines/`, `music/`, `sfx/`) contain only `.gitkeep` placeholders
- Source or create audio: engine loop sounds (6 types), background music, SFX (6 types)
- `AudioManager` code is ready — just needs actual audio files

### Priority 3 — Monetisation & Social

#### Subscription System
- Wire `Subscription` model to a payment provider (RevenueCat, Stripe, or platform in-app purchases)
- Gate premium features: ad removal, Live Group hosting, exclusive cosmetics
- Implement receipt validation server-side

#### Ad Integration
- Wire `AdConfig` model to an ad SDK (AdMob, Unity Ads)
- Implement banner, interstitial, and rewarded ad placements
- Gate by subscription tier (premium = no ads)
- Respect frequency limits defined in `AdConfig`

#### Live Groups (Multiplayer)
- Wire `LiveGroup` model to Supabase Realtime
- Implement lobby creation, player join, round synchronization
- Host-only feature (premium subscribers)
- Streaming leaderboard during play
- Requires: Supabase Realtime connections (200 concurrent on free tier)

#### Social Features Expansion
- Friend activity feed
- Challenge notifications (push notifications)
- Social sharing (share scores to social media)

### Priority 4 — Technical Debt & Polish

#### Input Validation Constraints
- Add PostgreSQL CHECK constraints on `profiles.username`, `scores.score`, `scores.time_ms` as documented in the old plan Phase 8.4
- Currently only validated client-side

#### Error Telemetry Privacy
- Strip or coarsen `navigator.userAgent` in web error payloads
- Scrub any URL query parameters from `context.url` before sending
- Consider: is `logs/runtime-errors.jsonl` in a public repo? If so, move to private storage

#### Offline Resilience
- Queue failed Supabase writes for retry on reconnection
- Currently: if a write fails, the data is lost (local state is already updated)
- Add a persistent local queue (SharedPreferences or SQLite)

#### Performance Profiling
- Profile shader performance on target devices (iPhone 12, Pixel 6)
- Measure actual LOD switching behavior
- Validate 60fps sustained across all platforms
- Asset bundle size audit (currently textures are ~5MB uncompressed)

#### Test Coverage
- Add unit tests for Supabase service layer (mock Supabase client)
- Add tests for sync debounce logic
- Add tests for offline fallback behavior
- Current test suite: 15 test files covering core game logic

---

## Platform & Store Requirements Checklist

For App Store / Play Store submission:

- [ ] Privacy policy published and linked
- [ ] Terms of service (recommended)
- [ ] Age rating assessment (geography game — likely rated for all ages, but verify no COPPA issues)
- [ ] App screenshots for all required device sizes
- [ ] App icon in all required resolutions
- [ ] Supabase keep-alive cron active (prevent backend going to sleep)
- [ ] City lights texture added (visual completeness)
- [ ] Audio assets added (or graceful silence — current state)
- [ ] All leaderboard features functional (not placeholder data)
- [ ] Error telemetry verified not leaking PII in release builds
- [ ] DevOverlay confirmed stripped from release builds (`kReleaseMode` gate)

---

## Cost Summary (Supabase Free Tier)

| Resource | Free Tier Limit | Expected Usage |
|---|---|---|
| Database storage | 500 MB | < 10 MB at launch |
| API requests | Unlimited | Hundreds/day |
| Auth MAU | 50,000 | < 100 at launch |
| File storage | 1 GB | 0 (avatars generated client-side) |
| Realtime connections | 200 concurrent | < 10 at launch |
| Edge functions | 500K/month | 0 (not used) |

First paid tier ($25/month) only needed at ~50K MAU — years away for an indie game.
