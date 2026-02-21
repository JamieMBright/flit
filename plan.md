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
- [x] Guest mode (implemented — **scheduled for removal**, see Priority 1)
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
- [x] `lib/features/challenge/challenge_result_screen.dart` — End-of-challenge summary UI
- [x] `lib/game/rendering/region_camera_presets.dart` — Per-region camera positions + bounds
- [x] `lib/core/core.dart` — Barrel export for core services

### Abandoned / To Delete

- ~~`lib/game/ui/altitude_slider.dart`~~ — Vertical altitude control slider. **Abandoned.** The high/low toggle is simpler and more game-like. File to be deleted.

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
**Status:** Not started
**Why:** All players should have accounts for data persistence, leaderboards, and social features. Guest mode creates a second code path that complicates every feature (friends, challenges, scores).

**What to do:**
- Remove "Play as Guest" button from `LoginScreen`
- Remove `Player.guest()` factory and `isGuest` checks
- Remove guest-gating logic in `UserPreferencesService` (the `_isGuest` flag and all no-op write branches)
- Remove guest-gating in `AccountNotifier`
- Clean up any `id == 'guest'` checks throughout the codebase
- Ensure login screen only shows email sign-up and sign-in

#### Account Deletion
**Status:** Not started
**Why:** GDPR Article 17 (right to erasure), Apple App Store requirement (Account Deletion requirement since June 2022), Google Play policy. Any app that offers account creation must offer deletion.

**What to do:**
- Add "Delete Account" option in Profile screen
- **Safety: require the user to type their email address** to confirm deletion (prevents accidental taps)
- On confirmation:
  1. Call Supabase Auth admin API to delete the auth user (requires a Supabase Edge Function or server-side call — the client SDK cannot self-delete auth users)
  2. Cascade-delete all user data: `profiles`, `user_settings`, `account_state`, `scores`, `friendships`, `challenges`
  3. Sign out locally, navigate to login screen
- Add a Supabase Edge Function `delete-account` that: verifies the caller's JWT, deletes auth user via `supabase.auth.admin.deleteUser()`, cascades data deletion via SQL `ON DELETE CASCADE` or explicit queries
- Consider: 30-day grace period with soft-delete? Or immediate permanent deletion? (Immediate is simpler and compliant)
- RLS must allow users to delete their own rows

#### Export User Data
**Status:** Not started
**Why:** GDPR Article 20 (right to data portability). Good practice for trust and transparency.

**What to do:**
- Add "Export My Data" button in Profile screen
- On tap: fetch all user data from Supabase (profile, settings, scores, friendships, challenges)
- Package as a JSON file with clear structure
- Offer download/share via platform share sheet (`Share.shareXFiles` or equivalent)
- Include: account info, game history, friends list, challenge history, settings
- Exclude: internal IDs, RLS metadata, server-side timestamps that aren't meaningful to the user

#### Error Handling Overhaul
**Status:** Not started
**Why:** Current system sends all errors to Vercel telemetry silently. No user-facing feedback, no prioritisation, no alerting for critical issues. Admin (you) should only be bothered by critical bugs from real users.

**Tiered user-facing error handling:**

| Tier | Severity | User sees | Admin sees |
|---|---|---|---|
| Silent | `warning` | Nothing | Telemetry log only |
| Toast | `error` | Brief auto-dismiss toast: "Something went wrong" | Telemetry + severity tag |
| Dialog | `critical` | Dialog: "We hit a problem" + "Send Report" button | GitHub Issue created automatically |

**GitHub Action — Error-to-Issue Pipeline:**
- Modify `fetch-errors.yml` (or create new workflow `process-errors.yml`)
- Workflow steps:
  1. Fetch errors from Vercel endpoint (`?severity=critical&since=<last_processed>`)
  2. For each critical error, check existing open GitHub issues for duplicates (match on error message fingerprint — first 100 chars + platform + app version)
  3. If no duplicate: create a GitHub issue with label `bug`, `critical`, `auto-triage` — assign to Copilot for initial analysis
  4. If duplicate exists: add a comment with occurrence count and latest timestamp
  5. **Purge the JSONL log completely** after processing — `echo "" > logs/runtime-errors.jsonl` and commit. Logs are ephemeral; issues are the durable record
  6. The Vercel in-memory buffer resets on cold start naturally
- Issue template should include: error message, stack trace, platform, device info, app version, occurrence count, session ID
- Assign to GitHub Copilot for initial triage/analysis

**Future wireframe — Email on fatal (not yet, pipe to GitHub for now):**
- Eventually: configure a GitHub webhook or Vercel integration to send email on `critical` severity
- For now: GitHub Issues are the notification mechanism — you'll see them in your GitHub notifications
- When ready: add SendGrid/Resend integration to the Vercel function for immediate email on `critical`

**In-app "Report Bug" button:**
- Add to Profile/Settings screen
- Lets users describe an issue in free text
- Bundles: description + last 5 error logs from `ErrorService.displayErrors` + device info + app version
- Submits as a `critical` severity error with `context.source = 'user_report'`

#### Privacy Policy
**Status:** Not started
**Why:** Required by iOS App Store, Google Play, GDPR, and CCPA. The app collects email addresses and game telemetry.

**What to do:**
- Write privacy policy covering: data collected, storage, retention, user rights (deletion + export), no third-party sharing
- Host at `flit-olive.vercel.app/privacy` or as an in-app screen
- Link from sign-up screen and App Store listings
- Strip User-Agent from web error payloads (replace with coarse platform label)

#### Supabase Keep-Alive Cron
**Status:** Not started
**Why:** Free tier pauses after 7 days of inactivity.

**What to do:**
- Add a `crons` key to `vercel.json` pinging `/api/health` twice a week
- OR add a GitHub Actions cron that curls the Supabase REST endpoint
- 5-line config change, critical for production reliability

#### Leaderboard Service (Read Path)
**Status:** Scores are written but there's no service to fetch/display rankings.

**What to do:**
- Create leaderboard fetch service
- Wire `LeaderboardScreen` to Supabase instead of `Leaderboard.placeholder()`
- Create SQL views if needed (`leaderboard_global`, `leaderboard_daily`, `leaderboard_regional`)

#### City Lights Texture
**Status:** Placeholder `.gitkeep` — actual NASA texture not added.
**What to do:** Download NASA Earth at Night (Public Domain), resize, add to assets.

### Priority 2 — Post-Launch Features

#### Challengerless Matchmaking ("Find a Challenger")
**Status:** Not started — design finalized
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
**Status:** Not started
**Why:** Adds identity and personality to H2H encounters. Seeing an opponent's nationality flag and license makes challengerless matchmaking feel more personal and global.

**What to do:**
- Add `nationality` field to `PilotLicense` model (ISO 3166-1 alpha-2 country code)
- Add nationality picker in Profile screen (use `flag` package for flag SVGs — already a dependency)
- Display nationality flag on the pilot license card
- Show both players' pilot licenses on the `ChallengeResultScreen` (rank, nationality, stats, equipped plane)
- Store nationality in Supabase `account_state` JSONB (inside the license object)
- Show nationality flag next to player names on leaderboards

#### Wire Leaderboard Model to UI
- Connect `LeaderboardScreen` to real Supabase data
- Support daily, all-time, regional, and friends board tabs
- Add player rank display

#### Wire Social Titles
- Connect `SocialTitle` catalog to gameplay milestones
- Track progress per category, display on profile
- Title selection UI

#### Wire Challenge Result Screen
- Connect `ChallengeResultScreen` to challenge completion flow
- Per-round time comparisons, coins earned, rematch option

#### Wire Region Camera Presets
- Connect `RegionCameraPresets` to the globe camera system
- Use per-region camera positions for region select screen previews
- Apply bounds-clamping during regional gameplay
- Presets already defined for all 6 regions (World, US, UK, Caribbean, Ireland, Canada)

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

#### Input Validation Constraints
- Add PostgreSQL CHECK constraints on `profiles.username`, `scores.score`, `scores.time_ms`
- Currently only validated client-side

#### Error Telemetry Privacy
- Strip or coarsen `navigator.userAgent` in web error payloads
- Scrub URL query parameters from `context.url` before sending
- Verify `logs/runtime-errors.jsonl` is not in a public repo (or move to private storage)

#### Offline Resilience
- Queue failed Supabase writes for retry on reconnection
- Add a persistent local queue (SharedPreferences or SQLite)

#### Performance Profiling
- Profile shader performance on target devices (iPhone 12, Pixel 6)
- Measure LOD switching behavior
- Validate 60fps sustained across all platforms
- Asset bundle size audit (textures ~5MB uncompressed)

#### Test Coverage
- Add unit tests for Supabase service layer (mock client)
- Tests for sync debounce logic
- Tests for offline fallback behavior
- Current: 15 test files covering core game logic

---

## Platform & Store Requirements Checklist

For App Store / Play Store submission:

- [ ] Guest mode removed (account required)
- [ ] Account deletion functional (App Store requirement)
- [ ] Data export functional (GDPR compliance)
- [ ] Privacy policy published and linked
- [ ] Terms of service (recommended)
- [ ] Age rating assessment (geography game — likely all ages, verify no COPPA issues)
- [ ] App screenshots for all required device sizes
- [ ] App icon in all required resolutions
- [ ] Supabase keep-alive cron active
- [ ] City lights texture added
- [ ] Audio assets added (or graceful silence)
- [ ] All leaderboard features functional (not placeholder data)
- [ ] Error handling tiered (users see toasts/dialogs, not raw errors)
- [ ] Critical errors auto-create GitHub issues
- [ ] Error telemetry verified not leaking PII in release builds
- [ ] DevOverlay confirmed stripped from release builds (`kReleaseMode` gate)
- [ ] Altitude slider file deleted (abandoned)

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
