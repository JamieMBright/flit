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
- Strip or coarsen `navigator.userAgent` in web error payloads
- Scrub URL query parameters from `context.url` before sending
- Verify `logs/runtime-errors.jsonl` is not in a public repo (or move to private storage)

#### 4b. Input Validation Constraints
- Add PostgreSQL CHECK constraints on `profiles.username`, `scores.score`, `scores.time_ms`
- Currently only validated client-side — server-side constraints prevent bad data from any source

#### 4c. Offline Resilience
- Queue failed Supabase writes for retry on reconnection
- Add a persistent local queue (SharedPreferences or SQLite)

#### 4d. Test Coverage
- Add unit tests for Supabase service layer (mock client)
- Tests for sync debounce logic
- Tests for offline fallback behavior
- Current: 15 test files covering core game logic

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
- [ ] Terms of service (recommended)
- [ ] Age rating assessment (geography game — likely all ages, verify no COPPA issues)
- [ ] App screenshots for all required device sizes
- [ ] App icon in all required resolutions
- [x] Supabase keep-alive cron active
- [ ] City lights texture added
- [ ] Audio assets added (or graceful silence)
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
