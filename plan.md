# Flit - Future Feature Plan

Scaffolded models and UI components that are not yet wired into the app but represent planned features. Each has a data model or widget already written and ready for integration.

---

## Monetisation

### Subscription Tiers
**File:** `lib/data/models/subscription.dart`

Four-tier freemium model (free, monthly, annual, lifetime) with premium perks including ad removal and Live Group hosting access. Includes pricing, active status tracking, and optional gifting.

### Ad System
**File:** `lib/data/models/ad_config.dart`

Ad placement strategy covering banner, interstitial, and rewarded ad types. Defines frequency limits per session and placement rules. Ad eligibility is gated by subscription tier (premium users see no ads).

---

## Social & Multiplayer

### Live Groups
**File:** `lib/data/models/live_group.dart`

Real-time multiplayer sessions where a premium subscriber hosts up to 8 players in live challenges with seeded questions and a streaming leaderboard. Supports two scoring modes: standard and first-to-answer.

### Leaderboards
**File:** `lib/data/models/leaderboard.dart`

Comprehensive leaderboard system supporting licensed/unlicensed play across multiple board types: daily, all-time, seasonal, regional, and friends. Includes placeholder data generation for UI development and annual cosmetic rewards for top performers.

### Social Titles
**File:** `lib/data/models/social_title.dart`

Achievement title system with 8 categories (flags, capitals, outlines, borders, stats, general, speed, streak) unlocked through gameplay milestones. Titles have rarity tiers with corresponding visual presentation.

---

## Gameplay UI

### Challenge Result Screen
**File:** `lib/features/challenge/challenge_result_screen.dart`

End-of-challenge summary screen showing victory/defeat, best-of-5 score, per-round time comparisons, coins earned, and rematch/home navigation. Consumes the `Challenge` model from `lib/data/models/challenge.dart`.

### Altitude Slider
**File:** `lib/game/ui/altitude_slider.dart`

Vertical slider widget for controlling camera altitude with smooth transitions, drag-to-adjust, and color/icon feedback representing zoom levels from low to high.

### Region Camera Presets
**File:** `lib/game/rendering/region_camera_presets.dart`

Per-region camera positions, altitudes, FOV overrides, and bounds-checking for the globe camera. Covers world, US, UK, Caribbean, Ireland, and Canada regions. Has a full test suite in `test/unit/game/rendering/camera_state_test.dart`.

---

## Core Infrastructure

### Core Barrel Export
**File:** `lib/core/core.dart`

Barrel file exporting core module services (dev overlay, error sender, error service) and theming utilities (colours and theme) for convenient access.

---
---

# Supabase Integration Plan

Zero-cost user database for Flit using Supabase (free tier). Covers authentication, player profiles, game settings, score submission, and leaderboards. Error telemetry stays on the existing Vercel endpoint — this is for user data only.

---

## Phase 0: Prerequisites (Manual — Jamie)

### 0.1 Create Supabase Account & Project

1. Go to [supabase.com](https://supabase.com) and sign up (GitHub OAuth is fastest)
2. Create a new project:
   - **Name:** `flit`
   - **Region:** Pick closest to your player base (e.g. `eu-west-2` for UK)
   - **Database password:** Generate a strong one and save it somewhere safe
3. Wait ~2 minutes for the project to provision

### 0.2 Collect Credentials

From the Supabase dashboard → Settings → API, grab:
- **Project URL** — e.g. `https://abcdef.supabase.co`
- **Anon (public) key** — safe to embed in client code (RLS protects everything)
- **Service role key** — NEVER embed in client code (only for server-side/admin use)

These will be stored as environment variables, never hardcoded in source.

### 0.3 Configure Auth Providers

From Dashboard → Authentication → Providers:
- **Email** — Enable (confirm email OFF for dev, ON for production)
- **Apple** — Enable (required for iOS App Store if you offer social login)
- **Google** — Enable (optional, good for Android)

For launch, email + password is sufficient. Social providers can be added later without code changes — Supabase Auth handles the OAuth flow.

### 0.4 Keep-Alive Cron (Prevent 7-Day Pause)

The free tier pauses projects after 7 days of inactivity. Fix:

**Option A — Vercel Cron (recommended, since we already have Vercel):**

Add to `vercel.json`:
```json
{
  "crons": [{
    "path": "/api/health",
    "schedule": "0 8 * * 1,4"
  }]
}
```
This pings `/api/health` every Monday and Thursday at 08:00 UTC. The health endpoint already exists. Free on Vercel Hobby plan (1 cron job free).

**Option B — GitHub Actions (fallback):**

Create `.github/workflows/supabase-keepalive.yml`:
```yaml
name: Supabase Keep-Alive
on:
  schedule:
    - cron: '0 8 * * 1,4'
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - run: curl -sf "${{ secrets.SUPABASE_URL }}/rest/v1/" -H "apikey: ${{ secrets.SUPABASE_ANON_KEY }}" > /dev/null
```

Either option ensures zero-downtime at zero cost.

---

## Phase 1: Database Schema (SQL — Run in Supabase SQL Editor)

All tables use Row Level Security (RLS). The `auth.uid()` function returns the currently authenticated user's ID, enforced at the database level.

### 1.1 Profiles Table

Extends Supabase Auth's `auth.users` with game-specific data. Auto-created on first sign-up via a database trigger.

```sql
-- Player profiles (extends auth.users)
CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url  TEXT,
  level       INT NOT NULL DEFAULT 1,
  xp          INT NOT NULL DEFAULT 0,
  coins       INT NOT NULL DEFAULT 100,
  games_played INT NOT NULL DEFAULT 0,
  best_time_ms BIGINT,
  total_flight_time_ms BIGINT NOT NULL DEFAULT 0,
  countries_found INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS: users can read all profiles, but only update their own
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);
```

### 1.2 Auto-Create Profile on Sign-Up (Trigger)

```sql
-- Trigger function: create a profile row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'pilot_' || LEFT(NEW.id::TEXT, 8)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'username')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fire after each new user in auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 1.3 Game Settings Table

Persists `GameSettings` per user. Small row, rarely updated.

```sql
CREATE TABLE public.user_settings (
  user_id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  turn_sensitivity   REAL NOT NULL DEFAULT 0.5,
  invert_controls    BOOLEAN NOT NULL DEFAULT FALSE,
  enable_night       BOOLEAN NOT NULL DEFAULT TRUE,
  map_style          TEXT NOT NULL DEFAULT 'topo',
  english_labels     BOOLEAN NOT NULL DEFAULT TRUE,
  difficulty         TEXT NOT NULL DEFAULT 'normal',
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own settings"
  ON public.user_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can upsert own settings"
  ON public.user_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
  ON public.user_settings FOR UPDATE
  USING (auth.uid() = user_id);
```

### 1.4 Account State Table

Persists the `AccountState` fields not covered by profiles (avatar, license, cosmetics, daily tracking).

```sql
CREATE TABLE public.account_state (
  user_id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  avatar_config         JSONB NOT NULL DEFAULT '{}',
  license_data          JSONB NOT NULL DEFAULT '{}',
  unlocked_regions      TEXT[] NOT NULL DEFAULT '{}',
  owned_avatar_parts    TEXT[] NOT NULL DEFAULT '{}',
  equipped_plane_id     TEXT NOT NULL DEFAULT 'plane_default',
  equipped_contrail_id  TEXT NOT NULL DEFAULT 'contrail_default',
  last_free_reroll_date TEXT,
  last_daily_challenge_date TEXT,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.account_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own account state"
  ON public.account_state FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can upsert own account state"
  ON public.account_state FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own account state"
  ON public.account_state FOR UPDATE
  USING (auth.uid() = user_id);
```

### 1.5 Scores Table (Leaderboard Source)

Every completed game session submits a score row. Leaderboard views aggregate from this table.

```sql
CREATE TABLE public.scores (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score         INT NOT NULL,
  time_ms       BIGINT NOT NULL,
  region        TEXT NOT NULL DEFAULT 'world',
  rounds_completed INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for leaderboard queries
CREATE INDEX idx_scores_leaderboard ON public.scores (region, score DESC, created_at);
CREATE INDEX idx_scores_user ON public.scores (user_id, created_at DESC);

ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;

-- Anyone can read scores (leaderboards are public)
CREATE POLICY "Scores are viewable by everyone"
  ON public.scores FOR SELECT
  USING (true);

-- Users can only insert their own scores
CREATE POLICY "Users can insert own scores"
  ON public.scores FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### 1.6 Leaderboard View (Computed, Not Stored)

PostgreSQL view that computes rankings on-the-fly. No extra storage cost.

```sql
-- Global leaderboard: best score per user
CREATE OR REPLACE VIEW public.leaderboard_global AS
SELECT
  p.id AS player_id,
  p.username,
  p.display_name,
  p.avatar_url,
  p.level,
  MAX(s.score) AS best_score,
  MIN(s.time_ms) AS best_time_ms,
  COUNT(s.id) AS games_played,
  RANK() OVER (ORDER BY MAX(s.score) DESC) AS rank
FROM public.profiles p
JOIN public.scores s ON s.user_id = p.id
GROUP BY p.id, p.username, p.display_name, p.avatar_url, p.level;

-- Daily leaderboard: best score today per user
CREATE OR REPLACE VIEW public.leaderboard_daily AS
SELECT
  p.id AS player_id,
  p.username,
  p.display_name,
  p.avatar_url,
  p.level,
  MAX(s.score) AS best_score,
  MIN(s.time_ms) AS best_time_ms,
  COUNT(s.id) AS games_played,
  RANK() OVER (ORDER BY MAX(s.score) DESC) AS rank
FROM public.profiles p
JOIN public.scores s ON s.user_id = p.id
WHERE s.created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
GROUP BY p.id, p.username, p.display_name, p.avatar_url, p.level;

-- Regional leaderboard: best score per user per region
CREATE OR REPLACE VIEW public.leaderboard_regional AS
SELECT
  p.id AS player_id,
  p.username,
  p.display_name,
  p.avatar_url,
  p.level,
  s.region,
  MAX(s.score) AS best_score,
  MIN(s.time_ms) AS best_time_ms,
  COUNT(s.id) AS games_played,
  RANK() OVER (PARTITION BY s.region ORDER BY MAX(s.score) DESC) AS rank
FROM public.profiles p
JOIN public.scores s ON s.user_id = p.id
GROUP BY p.id, p.username, p.display_name, p.avatar_url, p.level, s.region;
```

### 1.7 Updated-At Trigger (Auto-Timestamps)

```sql
-- Auto-update updated_at on any row change
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_user_settings_updated_at
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER set_account_state_updated_at
  BEFORE UPDATE ON public.account_state
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
```

---

## Phase 2: Flutter Package Integration

### 2.1 Add Dependency

In `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.3.0
```

This single package includes auth, database, realtime, and storage. No other packages needed.

### 2.2 Environment Configuration

Create `lib/core/config/supabase_config.dart`:

```dart
/// Supabase configuration.
///
/// Values are compile-time constants injected via --dart-define:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// For local development, use a .env file with a wrapper script.
/// NEVER hardcode these values in source code.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
```

### 2.3 Initialization

In `main.dart`, add before `runApp()`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (no-op if not configured, for local dev)
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // ... existing error telemetry setup, runApp(), etc.
}
```

---

## Phase 3: Auth Service Migration

Replace the simulated `AuthService` with real Supabase Auth. The public API stays the same so `LoginScreen` needs minimal changes.

### 3.1 New SupabaseAuthService

Create `lib/data/services/supabase_auth_service.dart`:

- `signUpWithEmail(email, password, username)` → `Supabase.instance.client.auth.signUp()` with `data: {'username': username}`
- `signInWithEmail(email, password)` → `Supabase.instance.client.auth.signInWithPassword()`
- `signOut()` → `Supabase.instance.client.auth.signOut()`
- `continueAsGuest()` → `Supabase.instance.client.auth.signInAnonymously()` (Supabase supports anonymous auth)
- `onAuthStateChange` → stream from `Supabase.instance.client.auth.onAuthStateChange`
- `currentUser` → `Supabase.instance.client.auth.currentUser`

Password handling: **Supabase handles all hashing, salting, and token management server-side.** The client only sends the plaintext password over HTTPS; it never stores it.

Session persistence: `supabase_flutter` automatically persists the session token in platform-appropriate storage (Keychain on iOS, EncryptedSharedPreferences on Android, localStorage on Web). Users stay logged in across app restarts.

### 3.2 Auth Provider (Riverpod)

Create `lib/data/providers/auth_provider.dart`:

```dart
/// Riverpod provider for auth state, replacing direct AuthService instantiation.
/// LoginScreen and other screens consume this instead of creating AuthService directly.
final authProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((data) {
    return data.session != null
      ? AuthState(isAuthenticated: true, ...)
      : const AuthState();
  });
});
```

### 3.3 LoginScreen Update

Replace `final authService = AuthService();` with Riverpod `ref.read(authProvider)`. The UI stays the same — just the data source changes.

### 3.4 Graceful Offline Fallback

If `SupabaseConfig.isConfigured` is false (no credentials provided), the app falls back to the existing in-memory `AuthService`. This means:
- Local development works without a Supabase account
- CI tests work without credentials
- The app degrades gracefully if the backend is unreachable

---

## Phase 4: Data Persistence Layer

### 4.1 SupabaseProfileService

Create `lib/data/services/supabase_profile_service.dart`:

- `fetchProfile(userId)` → `SELECT * FROM profiles WHERE id = userId`
- `updateProfile(userId, fields)` → `UPDATE profiles SET ... WHERE id = userId`
- Maps to/from existing `Player` model (already has `toJson()`/`fromJson()`)
- Called by `AccountNotifier` on state changes (debounced, not on every frame)

### 4.2 SupabaseSettingsService

Create `lib/data/services/supabase_settings_service.dart`:

- `fetchSettings(userId)` → `SELECT * FROM user_settings WHERE user_id = userId`
- `saveSettings(userId, settings)` → `UPSERT INTO user_settings ...`
- Maps to/from `GameSettings` fields
- Called on `GameSettings.notifyListeners()` with a 2-second debounce

### 4.3 SupabaseAccountStateService

Create `lib/data/services/supabase_account_state_service.dart`:

- `fetchAccountState(userId)` → `SELECT * FROM account_state WHERE user_id = userId`
- `saveAccountState(userId, state)` → `UPSERT INTO account_state ...`
- Avatar config and license data stored as JSONB (flexible schema)
- Called on `AccountNotifier` state changes with debounce

### 4.4 Sync Strategy

**Write-through with debounce:**
1. State changes happen locally first (instant UI response)
2. A 2-second debounce timer batches changes
3. On debounce expiry, one Supabase UPSERT syncs the latest state
4. On app startup, fetch remote state and merge (remote wins for conflicts)
5. On app pause/detach, flush any pending writes immediately

This ensures:
- Zero perceived latency (local-first)
- Minimal API calls (batched writes)
- Cross-device sync (remote state loaded on login)
- No data loss on app kill (flush on lifecycle events)

---

## Phase 5: Score Submission & Leaderboards

### 5.1 SupabaseScoreService

Create `lib/data/services/supabase_score_service.dart`:

- `submitScore(userId, score, timeMs, region, rounds)` → `INSERT INTO scores ...`
- Called from `AccountNotifier.recordGameCompletion()` after local state update
- Fire-and-forget (don't block the game completion UI on network)

### 5.2 SupabaseLeaderboardService

Create `lib/data/services/supabase_leaderboard_service.dart`:

- `fetchGlobalLeaderboard(limit, offset)` → `SELECT * FROM leaderboard_global LIMIT $1 OFFSET $2`
- `fetchDailyLeaderboard(limit)` → `SELECT * FROM leaderboard_daily LIMIT $1`
- `fetchRegionalLeaderboard(region, limit)` → `SELECT * FROM leaderboard_regional WHERE region = $1 LIMIT $2`
- `fetchPlayerRank(userId)` → `SELECT rank FROM leaderboard_global WHERE player_id = $1`
- Maps to existing `LeaderboardEntry` model (already has `fromJson()`)
- `LeaderboardScreen` switches from `Leaderboard.placeholder()` to real data

### 5.3 Realtime Leaderboard (Optional, Phase 5+)

Supabase Realtime can push leaderboard updates via WebSocket:

```dart
Supabase.instance.client
  .from('scores')
  .stream(primaryKey: ['id'])
  .listen((data) { /* refresh leaderboard UI */ });
```

This is optional for launch — polling every 30 seconds is simpler and sufficient for an indie game. Realtime can be enabled later without schema changes.

---

## Phase 6: Wiring It All Together

### 6.1 Service Locator / Provider Setup

Add Riverpod providers for each service:

```dart
final profileServiceProvider = Provider((ref) => SupabaseProfileService());
final settingsServiceProvider = Provider((ref) => SupabaseSettingsService());
final accountStateServiceProvider = Provider((ref) => SupabaseAccountStateService());
final scoreServiceProvider = Provider((ref) => SupabaseScoreService());
final leaderboardServiceProvider = Provider((ref) => SupabaseLeaderboardService());
```

### 6.2 AccountNotifier Integration

Modify `AccountNotifier` to:
1. Accept service providers via constructor injection
2. On initialization: fetch remote profile + account state + settings
3. On state change: debounced write-through to Supabase
4. On `recordGameCompletion()`: also submit score to `scores` table

### 6.3 GameSettings Integration

Modify `GameSettings` to:
1. Load settings from Supabase on login
2. Debounced save on every `notifyListeners()` call
3. Fall back to defaults if no remote settings exist

### 6.4 Updated App Flow

```
App Launch
  │
  ├─ Initialize Supabase
  ├─ Check existing session (auto-login)
  │   ├─ Session exists → fetch profile + settings + account state → HomeScreen
  │   └─ No session → LoginScreen
  │       ├─ Sign up (email+password) → create auth user → trigger creates profile → HomeScreen
  │       ├─ Sign in (email+password) → fetch profile → HomeScreen
  │       └─ Guest (anonymous auth) → limited features → HomeScreen
  │
  ├─ Game Completion
  │   ├─ Update local state (instant)
  │   ├─ Submit score to Supabase (async, fire-and-forget)
  │   └─ Debounced profile sync (2s)
  │
  ├─ Leaderboard Screen
  │   └─ Fetch from leaderboard views (with local cache)
  │
  └─ App Pause / Close
      └─ Flush pending writes
```

---

## Phase 7: Error Logs Decision

**Keep the existing Vercel error telemetry system unchanged.**

Rationale:
- It works, it's deployed, it writes to `logs/runtime-errors.jsonl` via GitHub API
- Error logs are operational data, not user data — different access patterns
- Supabase free tier storage (500 MB) should be reserved for user data
- The Vercel endpoint is unauthenticated by design (errors must be reportable even when auth is broken)
- Mixing error telemetry into the user database creates unnecessary coupling

The only change: add the Supabase keep-alive ping to the existing Vercel cron (Phase 0.4).

---

## Phase 8: Security Checklist

### 8.1 Row Level Security (RLS)

Every table has RLS enabled. Even if someone extracts the anon key from the client:
- They can only read public data (profiles, scores)
- They can only write their own data (`auth.uid() = id`)
- They cannot read other users' settings or account state
- They cannot insert scores for other users

### 8.2 API Key Handling

- **Anon key** — injected via `--dart-define`, never in source code
- **Service role key** — NEVER in client code, only for admin/server scripts
- CI/CD uses GitHub Secrets for both keys
- Local dev uses a `.env` file (gitignored) with a wrapper script

### 8.3 Rate Limiting

Supabase applies automatic rate limiting on the free tier. For additional protection:
- Score submission: client-side throttle (max 1 per 5 seconds)
- Profile updates: 2-second debounce (already in the sync strategy)
- Leaderboard fetches: cache for 30 seconds client-side

### 8.4 Input Validation

- Username: 3-20 chars, alphanumeric + underscore only (enforced in Dart + CHECK constraint in Postgres)
- Score: non-negative integer, max 10000 (enforced by game logic + CHECK constraint)
- Time: positive integer, reasonable upper bound (CHECK constraint)

```sql
-- Add after table creation
ALTER TABLE public.profiles ADD CONSTRAINT chk_username
  CHECK (username ~ '^[a-zA-Z0-9_]{3,20}$');

ALTER TABLE public.scores ADD CONSTRAINT chk_score
  CHECK (score >= 0 AND score <= 10000);

ALTER TABLE public.scores ADD CONSTRAINT chk_time
  CHECK (time_ms > 0 AND time_ms < 3600000);
```

---

## Phase 9: Testing Strategy

### 9.1 Unit Tests (No Network)

- Mock Supabase client using interface abstraction
- Test `AccountNotifier` with mocked services
- Test sync debounce logic
- Test offline fallback behavior
- Test `Player.fromJson()` / `toJson()` round-trip with Supabase column names

### 9.2 Integration Tests

- Test against a real Supabase project (using test credentials)
- Verify RLS policies (user A cannot read user B's settings)
- Verify trigger creates profile on sign-up
- Verify leaderboard views return correct rankings

### 9.3 What Existing Tests Should Still Pass

All existing tests use in-memory state. They must continue to pass with no changes by using the offline fallback path (no Supabase credentials configured).

---

## Implementation Order

| Step | Description | Files Created/Modified | Depends On |
|------|------------|----------------------|------------|
| 0 | Jamie: Create Supabase project, run SQL schema | (Supabase dashboard) | Nothing |
| 1 | Add `supabase_flutter` to pubspec.yaml | `pubspec.yaml` | Step 0 |
| 2 | Create `SupabaseConfig` + initialization | `lib/core/config/supabase_config.dart`, `lib/main.dart` | Step 1 |
| 3 | Create `SupabaseAuthService` | `lib/data/services/supabase_auth_service.dart` | Step 2 |
| 4 | Create auth Riverpod provider | `lib/data/providers/auth_provider.dart` | Step 3 |
| 5 | Update `LoginScreen` to use real auth | `lib/features/auth/login_screen.dart` | Step 4 |
| 6 | Create `SupabaseProfileService` | `lib/data/services/supabase_profile_service.dart` | Step 2 |
| 7 | Create `SupabaseSettingsService` | `lib/data/services/supabase_settings_service.dart` | Step 2 |
| 8 | Create `SupabaseAccountStateService` | `lib/data/services/supabase_account_state_service.dart` | Step 2 |
| 9 | Wire services into `AccountNotifier` + `GameSettings` | `lib/data/providers/account_provider.dart`, `lib/core/services/game_settings.dart` | Steps 6-8 |
| 10 | Create `SupabaseScoreService` | `lib/data/services/supabase_score_service.dart` | Step 2 |
| 11 | Create `SupabaseLeaderboardService` | `lib/data/services/supabase_leaderboard_service.dart` | Step 2 |
| 12 | Wire leaderboard into `LeaderboardScreen` | `lib/features/leaderboard/leaderboard_screen.dart` | Step 11 |
| 13 | Add keep-alive cron to `vercel.json` | `vercel.json` | Step 0 |
| 14 | Add unit tests for new services | `test/unit/data/services/` | Steps 3-11 |
| 15 | Add security constraints to schema | (Supabase SQL editor) | Step 0 |

---

## Cost Summary

| Resource | Free Tier Limit | Flit Expected Usage |
|----------|----------------|-------------------|
| Database storage | 500 MB | < 10 MB at launch |
| API requests | Unlimited | Hundreds/day |
| Auth MAU | 50,000 | < 100 at launch |
| File storage | 1 GB | 0 (avatars are generated client-side) |
| Realtime connections | 200 concurrent | < 10 at launch |
| Edge functions | 500K/month | 0 (not needed) |

The free tier is vastly more than Flit needs for its first year. The first paid tier ($25/month) would only be needed at ~50K monthly active users.
