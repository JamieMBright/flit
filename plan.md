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

### Supabase Integration

All core Supabase work is **implemented and live**:

- [x] Supabase project configured (`zrffgpkscdaybfhujioc.supabase.co`)
- [x] `AuthService` with real Supabase auth (signUp, signIn, signOut, session restore)
- [x] Email confirmation flow in `LoginScreen`
- [x] ~~Guest mode~~ — **Removed** (all players require accounts now)
- [x] DB trigger auto-creates profile on sign-up
- [x] `UserPreferencesService` — reads/writes profiles, user_settings, account_state tables
- [x] Score submission to `scores` table on game completion
- [x] `AccountNotifier` wired to Supabase via `UserPreferencesService`
- [x] `FriendsService` — search, friend requests, accept/decline, H2H records, coin gifting
- [x] `ChallengeService` — deterministic seeded H2H challenges
- [x] Row-Level Security on all tables
- [x] Admin panel gated by email check (client + RLS)

### Scaffolded Features (models + UI written, not yet wired in)

- [x] `lib/data/models/subscription.dart` — 4-tier freemium model
- [x] `lib/data/models/ad_config.dart` — Ad placement strategy
- [x] `lib/data/models/live_group.dart` — Real-time multiplayer sessions
- [x] `lib/data/models/leaderboard.dart` — Multi-board leaderboard system
- [x] `lib/data/models/social_title.dart` — 40+ achievement titles
- [x] `lib/features/challenge/challenge_result_screen.dart` — End-of-challenge summary UI **(now fully wired with pilot cards, flags, round breakdown, rematch)**
- [x] `lib/game/rendering/region_camera_presets.dart` — Per-region camera positions + bounds **(now wired to globe camera)**
- [x] `lib/core/core.dart` — Barrel export for core services

### Abandoned / Deleted

- ~~`lib/game/ui/altitude_slider.dart`~~ — Vertical altitude control slider. **Deleted.** The high/low toggle is simpler and more game-like.

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

#### Remove Guest Mode
**Status:** DONE
Removed "Play as Guest" button, `Player.guest()` factory, `_isGuest` write guards in `UserPreferencesService`, and all `id == 'guest'` checks. Login screen shows only email auth.

#### Account Deletion
**Status:** DONE
Email confirmation dialog in Profile screen. `AccountManagementService` cascades deletion in FK dependency order. TODO: Supabase Edge Function for `auth.admin.deleteUser()` (client-side data deletion works, auth user requires server-side call).

#### Export User Data
**Status:** DONE
"Export My Data" button in Profile screen. Parallel Supabase fetch, packaged as JSON. Web: Blob download via dart:html. Mobile: clipboard fallback. Cross-platform conditional imports.

#### Error Handling Overhaul
**Status:** DONE
- Tiered user-facing errors: `UserFacingError` stream in `ErrorService`, `ErrorOverlayManager` in `main.dart`
- `ErrorToast` (auto-dismiss) for `error` severity, `ErrorDialog` (with Send Report) for `critical`
- `ReportBugButton` with free-text + last 5 errors + device info
- `fetch-errors.yml` rewritten: MD5 fingerprint deduplication, creates GitHub issues with `bug/critical/auto-triage` labels, comments on existing issues for recurring errors, purges logs after processing
- User-Agent stripped from error payloads (web/index.html, api/errors/index.js)
- **Future:** email on fatal (deferred — GitHub Issues are the notification mechanism for now)

#### Privacy Policy
**Status:** DONE
Full GDPR/CCPA-compliant privacy policy at `public/privacy.html`. Dark-themed, covers data collected, storage, retention, user rights, no third-party sharing, COPPA compliance. Linked from login screen via `_PrivacyLink` widget.

#### Supabase Keep-Alive Cron
**Status:** DONE
Vercel cron pings `/api/health` every 3 days. Health endpoint includes Supabase HEAD ping with latency measurement.

#### Leaderboard Service (Read Path)
**Status:** DONE
SQL views created (`leaderboard_global`, `leaderboard_daily`, `leaderboard_regional`). `LeaderboardService` with fetchGlobal/Daily/Regional/Friends methods. `LeaderboardScreen` wired to real Supabase data with tab system and player rank banner.

#### Regional Game Modes
**Status:** GATED — all 5 regional modes gated behind "Coming Soon" overlay.
- Non-World regions show a "Coming Soon" overlay with lock icon for regular users
- Admin accounts bypass the gate and can access all regions for testing/development
- Underlying regional mode issues still need fixing before ungating
- Challengerless matchmaking is World-mode only until regional modes work (rule 9 in matchmaking spec)

#### iOS App Icon
**Status:** CONFIGURED — `flutter_launcher_icons` package added to pubspec.yaml.
`flutter_launcher_icons` config added with `min_sdk_android: 21`, iOS/Android/Web targets. The icon source image (`assets/icon/app_icon.png`) should be a 1024x1024 PNG that fills the entire canvas without padding. When `flutter pub run flutter_launcher_icons` is run, icons will be auto-generated at all required resolutions.
**Remaining:** Ensure the source icon image fills the canvas edge-to-edge (no internal padding that would cause white strips).

#### License Stats Persistence
**Status:** FIXED — Race condition resolved.
**Root cause:** `AccountNotifier` constructor created default state with `PilotLicense.random()`. If `loadFromSupabase()` failed or returned null (network error, RLS issue), the random license remained in state. Any subsequent user action triggering `_syncAccountState()` would overwrite the saved license in Supabase with the random one.
**Fix:** Added `_supabaseLoaded` guard flag to `AccountNotifier`. The `_syncAccountState()` and `_syncProfile()` methods now refuse to write until `loadFromSupabase()` has successfully completed at least once for the current session. This prevents constructor defaults from ever being persisted to Supabase.

#### Wayline Origin Offset
**Status:** FIXED — Wayline now spawns from the rear half (50-80%) of all plane bodies.
**What was wrong:** Fixed `noseLength=13.0` forward offset didn't account for different plane sprites (e.g. Platinum Eagle). Now uses a consistent tail offset that works for all planes.

#### City Lights Texture
**Status:** Placeholder `.gitkeep` — actual NASA texture not added.
**What to do:** Download NASA Earth at Night (Public Domain), resize, add to assets.

### Priority 2 — Post-Launch Features

#### Challengerless Matchmaking ("Find a Challenger")
**Status:** DONE — fully implemented
**Why:** Players without friends in the game need a way to find opponents. This creates organic social connections without requiring real-time matchmaking (which is impossible with a small player base).

**How it works:**

```
Player A                              Supabase                           Player B
   │                                     │                                  │
   ├─ Plays round (seed generated) ──►   │                                  │
   ├─ Submits score ──────────────────►  │                                  │
   ├─ "Find a Challenger" ────────────►  │                                  │
   │   (enters matchmaking pool)         │  ◄── "Find a Challenger" ────────┤
   │                                     │      (searches pool for match)   │
   │                                     │                                  │
   │   ◄── Match found! ────────────────►│──── Match found! ───────────────►│
   │   (auto-friended)                   │     (plays same seed as A)       │
   │                                     │                                  │
   │   ◄── Results compared ────────────►│──── Results compared ───────────►│
   │   (dogfight begins)                 │     (multi-round H2H)           │
```

**Core rules:**
1. **Same seed**: All rounds within a dogfight between opponents use identical seeds (countries, clues). Different seeds only for new challenges after all rounds conclude
2. **Async play-then-wait**: Player plays their round, submits score, enters the matchmaking pool. Pairing happens in the background — no real-time waiting
3. **ELO-like banding**: Players are bracketed by an ELO-derived rating. Band width scales dynamically based on player base size and queue depth:
   - Large queue → tight bands (fair matches)
   - Small queue → wider bands (faster matches)
   - Never match wildly disparate skill levels (e.g., level 1 vs level 20)
4. **Auto-friend on match**: Both players are automatically added to each other's friend lists
5. **Multi-round dogfight**: Same format as all H2H challenges (standard round count)
6. **Play again option**: After dogfight concludes, offer "Play Again" to restart the H2H with the same opponent
7. **Multiple active submissions**: A player can have multiple challengerless submissions in the pool simultaneously
8. **No expiry**: Submissions persist until matched. Only invalidated by gameplay version changes (if a game update changes mechanics, old submissions using outdated seeds/rules are retired)
9. **World-mode only (for now)**: Challengerless matchmaking only supports World mode since regional game modes don't work yet. Expand to regional once those modes are functional
10. **Gameplay versioning**: Submissions are tagged with a gameplay version. Version bumps on mechanical changes (scoring formula, flight speed, clue changes) invalidate unmatched old submissions
11. **Show pilot license in H2H**: Both players' pilot licenses are displayed in the challenge result screen so opponents can see each other's rank, nationality, and stats
12. **Nationality flag on license**: Players can set a nationality flag on their pilot license (displayed in H2H and on leaderboards)

**Supabase schema (`matchmaking_pool`):**
```sql
CREATE TABLE matchmaking_pool (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  region TEXT NOT NULL DEFAULT 'world',  -- World-mode only for now
  seed TEXT NOT NULL,
  rounds JSONB NOT NULL,           -- array of round seeds + scores
  elo_rating INT NOT NULL,
  gameplay_version TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  matched_at TIMESTAMPTZ,
  matched_with UUID REFERENCES profiles(id),
  challenge_id UUID REFERENCES challenges(id)
);

-- Index for efficient pool searching
CREATE INDEX idx_matchmaking_unmatched
  ON matchmaking_pool (region, elo_rating, gameplay_version)
  WHERE matched_at IS NULL;
```

**Matching algorithm (runs on Player B's "Find a Challenger" tap):**
1. Query `matchmaking_pool` for unmatched entries in same region + gameplay version
2. Filter to ELO band (dynamic width based on pool size)
3. Exclude own entries and existing friends (optional — friends can use direct challenge)
4. Pick the oldest qualifying entry (FIFO within band)
5. If match found: mark both entries as matched, create a `challenges` row, auto-friend both players, Player B plays the same seed
6. If no match: insert Player B's submission into the pool

#### Pilot License — Nationality Flag & H2H Display
**Status:** DONE
`nationality` field on `PilotLicense` (ISO 3166-1 alpha-2). Nationality picker in Profile screen with searchable country list. Flags displayed on challenge result screen pilot cards. Preserved across license rerolls. Stored in Supabase `account_state` JSONB.

#### Wire Leaderboard Model to UI
**Status:** DONE — see Leaderboard Service above.

#### Wire Social Titles
**Status:** DONE
`TitleService` checks player stats against `SocialTitle` unlock criteria. `SocialTitlesCard` widget in profile shows earned titles (tap to equip/unequip), equipped title banner, and progress bars for next unlockable titles. `equippedTitleId` stored in `AccountState`.

#### Wire Challenge Result Screen
**Status:** DONE
Full result screen with pilot cards (name, flag, rank, plane), score display, per-round time comparison, total time, coins earned, rematch flow, play again option. `PlayScreen` navigates to `ChallengeResultScreen` after H2H completion.

#### Wire Region Camera Presets
**Status:** DONE
`CameraState.setRegion()` applies `CameraPreset` (center lat/lng, altitude, FOV). Bounds clamping in `update()` loop. `FlitGame.onLoad()` calls `setRegion()`. All 6 regions supported.

#### Audio Assets
- All audio directories contain only `.gitkeep` placeholders
- Source or create audio: engine loops (6 types), background music, SFX (6 types)
- `AudioManager` code is ready — just needs actual audio files

#### Companion Sprites Quality
**Status:** Poor quality — all 8 companions (pidgey, sparrow, eagle, parrot, phoenix, dragon, charizard) are procedurally drawn with Canvas primitives (ovals, paths, circles).
**What to do:**
- Replace procedural Canvas drawing with proper sprite assets or significantly improve the Canvas rendering
- Current rendering uses simple geometric shapes that lack detail and polish
- Two rendering paths need updating: in-game (`CompanionRenderer`) and shop preview (`_CompanionPreviewPainter`)
- Consider: hand-drawn sprite sheets matching the lo-fi plane aesthetic, or SVG assets

#### Plane Sprites Quality
**Status:** Needs improvement — plane rendering uses basic Canvas drawing.
**What to do:**
- Improve the visual quality of plane sprites to match the intended hand-drawn aesthetic
- Ensure all unlockable plane cosmetics look distinct and polished
- Both in-game rendering and shop preview need updating

#### Country Borders Visibility
**Status:** IMPROVED — Border width increased and minimum visibility floor added.
**What was wrong:** Border width at high altitude was only 0.05 (barely visible). The shader fades out entirely below altitude 0.3.
**Fix:** Increased high-altitude border width from 0.05 to 0.10 and added a minimum alpha floor of 0.3 so borders never completely disappear even at extreme distances. Borders remain white and unaffected by day/night cycle. Below altitude 0.3 (OSM tile map zone), borders are handled by the `CountryBorderOverlay` canvas component.

### Priority 3 — Monetisation & Future

#### Subscription System
- Wire `Subscription` model to a payment provider (RevenueCat, Stripe, or platform IAP)
- Gate premium features: ad removal, Live Group hosting, exclusive cosmetics
- Receipt validation server-side

#### Ad Integration
- Wire `AdConfig` model to an ad SDK (AdMob, Unity Ads)
- Banner, interstitial, and rewarded ad placements
- Gate by subscription tier (premium = no ads)

#### Live Multiplayer (Future Feasibility Scope)
**Status:** Model scaffolded (`lib/data/models/live_group.dart`). **Not planned for near-term — massive architectural overhaul.**

**Why scope now:** Understanding the requirements early prevents painting ourselves into architectural corners with other features (e.g., matchmaking, leaderboards, challenge system).

**What it would require:**
- **Supabase Realtime**: WebSocket channels for lobby state, player join/leave, round synchronization. Free tier allows 200 concurrent connections — may hit limits fast
- **Lobby state machine**: States (waiting, countdown, playing, scoring, results). Host controls start. Late-join handling. Graceful disconnect/reconnect
- **Round synchronization**: All players must play the same seed simultaneously. Timer sync across clients with latency compensation. Score submission with server-side validation to prevent cheating
- **Latency compensation**: Clock drift detection, grace periods for slow connections
- **Infrastructure**: Likely requires Supabase Pro tier ($25/mo) for higher Realtime limits. May need dedicated Realtime channels per lobby. Consider: is Supabase Realtime sufficient, or does this need a dedicated WebSocket server (e.g., Ably, Pusher)?
- **UI**: Lobby screen, player list, real-time score ticker during play, post-round leaderboard
- **Estimated effort**: 4-6 weeks of focused work. Significant testing across platforms and network conditions

**Decision point:** Defer until player base justifies the infrastructure cost and development investment. The async challengerless matchmaking covers the "play with strangers" use case without real-time requirements.

#### Social Features Expansion
- Friend activity feed
- Challenge notifications (push notifications)
- Social sharing (share scores to social media)

### Priority 4 — Technical Debt & Polish

#### 4a. Error Telemetry Privacy
**Status:** DONE
All privacy controls are implemented in the Vercel endpoint (`api/errors/index.js`):
- `scrubContext()` removes `userAgent` entirely (line 63) — prevents browser fingerprinting
- `scrubUrl()` strips query parameters and hash from URLs (lines 42-50) — prevents token/analytics ID leakage
- `SENSITIVE_PREFIXES` filter removes fields starting with `token`, `key`, `secret`, `password`, `auth`
- `web/index.html` sends coarsened URL (`location.origin + location.pathname`, line 162) — double protection
- Verified: `logs/runtime-errors.jsonl` contains no PII, no user-agent strings, no URLs with query params
- All caller context across the Dart codebase is safe metadata only (source, category, screen names)

#### 4b. Input Validation Constraints
**Status:** PARTIALLY DONE
- Client-side validation implemented: `saveGameResult()` clamps `score` to [0, 100000] and `time_ms` to [1, 3599999]
- SQL migration script created at `sql/002_check_constraints.sql` with server-side CHECK constraints
- TODO: Apply migration to production Supabase instance

#### 4c. Offline Resilience
**Status:** DONE
Full offline write queue implemented in `UserPreferencesService`:
- `_PendingWriteQueue` class backed by `SharedPreferences` for persistence across app restarts
- Capped at 200 entries with FIFO eviction when full
- Max 5 retries per entry before dropping (prevents infinite retry loops)
- `retryPendingWrites()` drains queue oldest-first, stops on first failure (backpressure)
- `_flush()` calls `retryPendingWrites()` before each batch write — ensures offline entries are replayed
- Failed writes from `_flush()` are automatically enqueued for later retry
- Cross-user contamination prevention: `clear()` purges the queue on sign-out
- Auth guard: skips retry if no authenticated user (prevents wasted retries on expired tokens)

#### 4d. Test Coverage
**Status:** PARTIALLY DONE — 17 test files covering core game logic
- `user_preferences_service_test.dart` — snapshot mapping, pilot license, avatar, settings defaults
- `auth_service_test.dart` — authentication service tests
- `error_service_test.dart` — error capture and reporting
- `audio_manager_test.dart` — audio system tests
- Still needed: mock Supabase client integration tests, offline queue drain tests, debounce timing tests

#### 4e. Performance Profiling
- Profile shader performance on target devices (iPhone 12, Pixel 6)
- Measure LOD switching behavior
- Validate 60fps sustained across all platforms
- Asset bundle size audit (textures ~5MB uncompressed)

---

## Platform & Store Requirements Checklist

For App Store / Play Store submission:

- [x] Guest mode removed (account required)
- [x] Account deletion functional (App Store requirement)
- [x] Data export functional (GDPR compliance)
- [x] Privacy policy published and linked
- [x] Terms of service published at `public/terms.html` and linked from login screen
- [ ] Age rating assessment (geography game — likely all ages, verify no COPPA issues)
- [ ] App screenshots for all required device sizes
- [x] App icon configured via `flutter_launcher_icons` in pubspec.yaml (run `flutter pub run flutter_launcher_icons` to generate)
- [x] Supabase keep-alive cron active
- [ ] City lights texture added
- [ ] Audio assets added (or graceful silence)
- [x] Regional game modes gated with "Coming Soon" (admin bypass)
- [x] All leaderboard features functional (not placeholder data)
- [x] Error handling tiered (users see toasts/dialogs, not raw errors)
- [x] Critical errors auto-create GitHub issues
- [x] Error telemetry verified not leaking PII in release builds
- [x] DevOverlay confirmed stripped from release builds (`kReleaseMode` gate)
- [x] Altitude slider file deleted (abandoned)

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
