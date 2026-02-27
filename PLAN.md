# PLAN.md — Pre-Launch Admin & Moderation Feature Set

**Priority**: High — required before public launch
**Created**: 2026-02-27
**Status**: Pending approval

---

## Overview

12 features organised into 3 tiers of launch priority. Each feature includes the full Supabase schema (tables, RLS, RPCs), Dart model/service layer, admin UI, and moderator permission mapping. All features follow existing codebase conventions:

- `ConsumerStatefulWidget` + `ConsumerState` (Riverpod)
- `_AdminDialog` pattern for admin actions
- `FlitColors` theme tokens
- `MaterialPageRoute` push navigation
- RPC-based server-side mutations with `SECURITY DEFINER`
- Fire-and-forget writes with `_PendingWriteQueue` for offline resilience
- `AdminPermission` enum gates on the client side

---

## Tier 1 — Launch Blockers (Must Ship)

### 1. User Ban / Suspend System

**Why**: Cannot launch without the ability to remove abusive users. Currently there is zero mechanism to block a player from accessing the game.

**Database schema** — add to `supabase/rebuild.sql`:

```sql
-- On profiles table:
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS banned_at      TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ban_expires_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ban_reason     TEXT DEFAULT NULL;

-- Index for quick "is this user banned?" check on login:
CREATE INDEX IF NOT EXISTS idx_profiles_banned
  ON public.profiles (banned_at) WHERE banned_at IS NOT NULL;

-- RPC: admin_ban_user
-- Moderators can temp-ban (max 30d). Owners can permaban.
CREATE OR REPLACE FUNCTION public.admin_ban_user(
  target_user_id UUID,
  p_reason TEXT,
  p_duration_days INT DEFAULT NULL  -- NULL = permanent
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Permission denied: not an admin';
  END IF;

  -- Moderators can only temp-ban, max 30 days
  IF v_role = 'moderator' THEN
    IF p_duration_days IS NULL THEN
      RAISE EXCEPTION 'Moderators cannot issue permanent bans';
    END IF;
    IF p_duration_days > 30 THEN
      RAISE EXCEPTION 'Moderator ban limit: max 30 days';
    END IF;
  END IF;

  -- Cannot ban other admins (only owners can ban moderators)
  DECLARE v_target_role TEXT;
  BEGIN
    SELECT admin_role INTO v_target_role FROM public.profiles WHERE id = target_user_id;
    IF v_target_role IS NOT NULL AND v_role != 'owner' THEN
      RAISE EXCEPTION 'Only owners can ban other admins';
    END IF;
  END;

  UPDATE public.profiles SET
    banned_at = NOW(),
    ban_expires_at = CASE
      WHEN p_duration_days IS NOT NULL
      THEN NOW() + (p_duration_days || ' days')::INTERVAL
      ELSE NULL  -- permanent
    END,
    ban_reason = p_reason
  WHERE id = target_user_id;
END;
$$;

-- RPC: admin_unban_user (owner only)
CREATE OR REPLACE FUNCTION public.admin_unban_user(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN
    RAISE EXCEPTION 'Only owners can lift bans';
  END IF;
  UPDATE public.profiles SET banned_at = NULL, ban_expires_at = NULL, ban_reason = NULL
  WHERE id = target_user_id;
END;
$$;
```

**Dart changes**:

1. **`lib/data/models/player.dart`** — Add `bannedAt`, `banExpiresAt`, `banReason` fields. Add `bool get isBanned` (checks `bannedAt != null && (banExpiresAt == null || banExpiresAt.isAfter(DateTime.now()))`).

2. **`lib/data/services/auth_service.dart`** — In `_fetchOrCreateProfile()`, after hydrating the Player, check `player.isBanned`. If banned, sign out and return a new `AuthState(isBanned: true, banReason: ..., banExpiresAt: ...)`.

3. **`lib/features/auth/banned_screen.dart`** (new) — Full-screen "Account Suspended" display showing reason, expiry date (or "permanently"), and a "Contact Support" button (mailto link).

4. **`lib/main.dart`** / **`login_screen.dart`** — After auth, if `authState.isBanned`, navigate to `BannedScreen` instead of `HomeScreen`.

5. **`lib/core/config/admin_config.dart`** — Add permissions:
   - `AdminPermission.tempBanUser` (moderator + owner)
   - `AdminPermission.permaBanUser` (owner only)
   - `AdminPermission.unbanUser` (owner only)

6. **`lib/features/admin/admin_screen.dart`** — Add "Ban Player" dialog (username + reason + duration dropdown: 24h / 7d / 30d / Permanent). Add "Unban Player" dialog (owner only). Both in the Moderation section.

**Files touched**: `rebuild.sql`, `player.dart`, `auth_service.dart`, `admin_config.dart`, `admin_screen.dart`, new `banned_screen.dart`, `login_screen.dart`

---

### 2. Player Report Queue

**Why**: Users need a way to report bad actors. Without it, moderation is purely reactive (admins have to discover abuse themselves).

**Database schema**:

```sql
CREATE TABLE IF NOT EXISTS public.player_reports (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL,     -- 'offensive_username', 'cheating', 'harassment', 'other'
  details       TEXT,              -- free-text description
  status        TEXT NOT NULL DEFAULT 'pending',  -- 'pending', 'reviewed', 'actioned', 'dismissed'
  reviewed_by   UUID REFERENCES auth.users(id),
  reviewed_at   TIMESTAMPTZ,
  action_taken  TEXT,             -- e.g. 'username_changed', 'temp_ban_7d', 'dismissed'
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT no_self_report CHECK (reporter_id != reported_id)
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.player_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported ON public.player_reports (reported_id);

ALTER TABLE public.player_reports ENABLE ROW LEVEL SECURITY;

-- Users can INSERT their own reports
CREATE POLICY "Users can submit reports"
  ON public.player_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- Users can read their own submitted reports
CREATE POLICY "Users can read own reports"
  ON public.player_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- Admins can read and update all reports
CREATE POLICY "Admins can read all reports"
  ON public.player_reports FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
  ));

CREATE POLICY "Admins can update reports"
  ON public.player_reports FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
  ));

-- RPC: admin_resolve_report
CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id BIGINT,
  p_status TEXT,         -- 'actioned' or 'dismissed'
  p_action_taken TEXT    -- description of action
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  IF p_status NOT IN ('actioned', 'dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;
  UPDATE player_reports SET
    status = p_status,
    reviewed_by = auth.uid(),
    reviewed_at = NOW(),
    action_taken = p_action_taken
  WHERE id = p_report_id;
END;
$$;
```

**Dart changes**:

1. **`lib/data/models/player_report.dart`** (new) — Model with `id`, `reporterId`, `reportedId`, `reason`, `details`, `status`, `reviewedBy`, `reviewedAt`, `actionTaken`, `createdAt`.

2. **`lib/data/services/report_service.dart`** (new) — Singleton. `submitReport(reportedUserId, reason, details)` — inserts into `player_reports`. `fetchPendingReports({limit})` — admin query for `status = 'pending'` ordered by `created_at ASC`. `resolveReport(reportId, status, actionTaken)` — calls RPC.

3. **User-facing report UI** — Add "Report Player" option to the leaderboard player detail / friends list / profile view. Shows a dialog with reason picker (Offensive Username, Cheating, Harassment, Other) + optional details text field. Rate-limit: max 5 reports per day per user (client-side check + server constraint).

4. **Admin report queue screen** (`lib/features/admin/report_queue_screen.dart`, new) — ListView of pending reports, each card shows: reported user, reporter, reason, timestamp. Tap to expand details. Action buttons: "Change Username", "Temp Ban", "Dismiss". On action, calls `admin_resolve_report` RPC.

5. **`admin_config.dart`** — Add `AdminPermission.viewReports`, `AdminPermission.resolveReports` (both moderator + owner).

6. **`admin_screen.dart`** — Add "Report Queue (N pending)" card in Moderation section with badge count.

**Files touched**: `rebuild.sql`, new `player_report.dart`, new `report_service.dart`, new `report_queue_screen.dart`, `admin_config.dart`, `admin_screen.dart`, leaderboard/friends screens for the "Report" button

---

### 3. Admin Audit Log

**Why**: With multiple moderators, every admin action must be traceable. Required for accountability, dispute resolution, and detecting moderator abuse.

**Database schema**:

```sql
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id     UUID NOT NULL REFERENCES auth.users(id),
  actor_role   TEXT NOT NULL,               -- 'moderator' or 'owner' at time of action
  action       TEXT NOT NULL,               -- e.g. 'ban_user', 'change_username', 'gift_gold'
  target_id    UUID REFERENCES auth.users(id),  -- affected user (nullable for system actions)
  details      JSONB NOT NULL DEFAULT '{}', -- action-specific metadata
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON public.admin_audit_log (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON public.admin_audit_log (target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON public.admin_audit_log (action, created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can read (owner sees all, moderator sees own actions only)
CREATE POLICY "Owners can read all audit log"
  ON public.admin_audit_log FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role = 'owner'
  ));

CREATE POLICY "Moderators can read own audit log"
  ON public.admin_audit_log FOR SELECT
  USING (actor_id = auth.uid() AND EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
  ));

-- No direct INSERT/UPDATE/DELETE policies — all writes go through RPCs
```

**Implementation strategy**: Modify every existing admin RPC (`admin_increment_stat`, `admin_set_stat`, `admin_set_role`, `admin_ban_user`, `admin_set_license`, `admin_set_avatar`, `admin_unlock_all`) to INSERT into `admin_audit_log` at the end of the function body. Also add audit logging to `admin_resolve_report` and `admin_unban_user`. The `details` JSONB stores action-specific context (e.g. `{old_username: "badword", new_username: "player123"}` for username changes).

**Dart changes**:

1. **Client-side logging** — For actions that go through direct Supabase writes (not RPCs), like `_showChangeUsernameDialog`, add a fire-and-forget `.from('admin_audit_log').insert(...)` call after the action succeeds. Alternatively, convert the username change to an RPC so the audit log is written atomically server-side.

2. **`lib/features/admin/audit_log_screen.dart`** (new) — Paginated list of audit entries. Filters by: action type, actor, target, date range. Each row: timestamp, actor @username, action label, target @username, expand for details JSON.

3. **`admin_config.dart`** — Add `AdminPermission.viewAuditLog` (owner only) and `AdminPermission.viewOwnAuditLog` (moderator).

4. **`admin_screen.dart`** — Add "Audit Log" card in the Analytics section (owner sees all entries, moderator sees own actions).

**Files touched**: `rebuild.sql` (new table + modify 8+ existing RPCs), new `audit_log_screen.dart`, `admin_config.dart`, `admin_screen.dart`

---

### 4. Force App Update / Minimum Version Gate

**Why**: Once the app is in the App Store, you will ship breaking API changes (new DB schema, new RPCs). Without a force-update gate, users on old versions will crash.

**Database schema**:

```sql
CREATE TABLE IF NOT EXISTS public.app_config (
  id               INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- singleton row
  min_app_version  TEXT NOT NULL DEFAULT 'v1.0',     -- below this: force update
  recommended_version TEXT NOT NULL DEFAULT 'v1.0',  -- below this: soft nag
  maintenance_mode BOOLEAN NOT NULL DEFAULT FALSE,
  maintenance_message TEXT DEFAULT NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Public read (all users check on startup), admin-only write
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read app config"
  ON public.app_config FOR SELECT USING (true);

CREATE OR REPLACE FUNCTION public.admin_update_app_config(
  p_min_version TEXT DEFAULT NULL,
  p_recommended_version TEXT DEFAULT NULL,
  p_maintenance_mode BOOLEAN DEFAULT NULL,
  p_maintenance_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;
  UPDATE app_config SET
    min_app_version = COALESCE(p_min_version, min_app_version),
    recommended_version = COALESCE(p_recommended_version, recommended_version),
    maintenance_mode = COALESCE(p_maintenance_mode, maintenance_mode),
    maintenance_message = COALESCE(p_maintenance_message, maintenance_message),
    updated_at = NOW()
  WHERE id = 1;
END;
$$;

-- Seed the singleton row
INSERT INTO public.app_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
```

**Dart changes**:

1. **`lib/data/models/app_config.dart`** (new) — Model: `minAppVersion`, `recommendedVersion`, `maintenanceMode`, `maintenanceMessage`.

2. **`lib/data/services/app_config_service.dart`** (new) — Singleton with 5-minute TTL cache. `fetchConfig()` reads `app_config` table. `checkCompatibility()` compares `appVersion` (from `core/app_version.dart`) against `minAppVersion` using semantic version parsing. Returns `AppCompatibility.ok | .updateRecommended | .updateRequired | .maintenance`.

3. **`lib/features/auth/update_required_screen.dart`** (new) — Full-screen "Update Required" with App Store / Play Store deep link. No way to dismiss.

4. **`lib/features/auth/maintenance_screen.dart`** (new) — Full-screen "Under Maintenance" with message. Retry button refetches config.

5. **`lib/main.dart`** or **`login_screen.dart`** — After successful auth, call `AppConfigService.instance.checkCompatibility()`. Route to the appropriate screen if not `.ok`.

6. **`admin_screen.dart`** — Add "App Config" section (owner only) with fields for min version, recommended version, maintenance toggle + message.

7. **`admin_config.dart`** — Add `AdminPermission.editAppConfig` (owner only).

**Files touched**: `rebuild.sql`, new `app_config.dart`, new `app_config_service.dart`, new `update_required_screen.dart`, new `maintenance_screen.dart`, `admin_config.dart`, `admin_screen.dart`, `login_screen.dart` or `main.dart`

---

## Tier 2 — Ship Within First Week

### 5. In-App Announcements / MOTD

**Why**: Need to communicate maintenance windows, new features, events, and promotions to all players without app updates.

**Database schema**:

```sql
CREATE TABLE IF NOT EXISTS public.announcements (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,             -- supports markdown or plain text
  type          TEXT NOT NULL DEFAULT 'info',  -- 'info', 'warning', 'event', 'maintenance'
  priority      INT NOT NULL DEFAULT 0,    -- higher = shown first
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at     TIMESTAMPTZ DEFAULT NULL,  -- NULL = immediately
  expires_at    TIMESTAMPTZ DEFAULT NULL,  -- NULL = never expires
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Public read for active announcements
CREATE POLICY "Anyone can read active announcements"
  ON public.announcements FOR SELECT USING (
    is_active = TRUE
    AND (starts_at IS NULL OR starts_at <= NOW())
    AND (expires_at IS NULL OR expires_at > NOW())
  );

-- Admin write via RPC
CREATE OR REPLACE FUNCTION public.admin_upsert_announcement(
  p_id BIGINT DEFAULT NULL,  -- NULL = create new
  p_title TEXT DEFAULT NULL,
  p_body TEXT DEFAULT NULL,
  p_type TEXT DEFAULT 'info',
  p_priority INT DEFAULT 0,
  p_is_active BOOLEAN DEFAULT TRUE,
  p_starts_at TIMESTAMPTZ DEFAULT NULL,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_id BIGINT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  -- Moderators can only create info announcements; owners can create any type
  IF v_role = 'moderator' AND p_type NOT IN ('info') THEN
    RAISE EXCEPTION 'Moderators can only create info announcements';
  END IF;

  IF p_id IS NOT NULL THEN
    UPDATE announcements SET
      title = COALESCE(p_title, title),
      body = COALESCE(p_body, body),
      type = COALESCE(p_type, type),
      priority = COALESCE(p_priority, priority),
      is_active = COALESCE(p_is_active, is_active),
      starts_at = p_starts_at,
      expires_at = p_expires_at
    WHERE id = p_id
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO announcements (title, body, type, priority, is_active, starts_at, expires_at, created_by)
    VALUES (p_title, p_body, p_type, p_priority, p_is_active, p_starts_at, p_expires_at, auth.uid())
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
```

**Dart changes**:

1. **`lib/data/models/announcement.dart`** (new) — Model with `id`, `title`, `body`, `type`, `priority`, `isActive`, `startsAt`, `expiresAt`, `createdAt`.

2. **`lib/data/services/announcement_service.dart`** (new) — Singleton, 2-minute TTL cache. `fetchActive()` reads announcements table (RLS handles filtering). `dismissLocally(id)` stores dismissed IDs in SharedPreferences so user doesn't see the same one repeatedly.

3. **`lib/core/widgets/announcement_banner.dart`** (new) — A small banner widget displayed at the top of `HomeScreen` when there are active undismissed announcements. Styled per `type`: info (oceanHighlight), warning (gold), event (accent), maintenance (error). Tap to expand full message. Dismiss button.

4. **`lib/features/home/home_screen.dart`** — Insert `AnnouncementBanner()` widget at the top of the body.

5. **`lib/features/admin/announcement_manager_screen.dart`** (new) — List of all announcements (active + expired). Create/edit dialog with title, body, type picker, date range, active toggle.

6. **`admin_config.dart`** — Add `AdminPermission.viewAnnouncements` (moderator + owner), `AdminPermission.createAnnouncements` (moderator: info only, owner: all types), `AdminPermission.editAnnouncements` (owner only).

7. **`admin_screen.dart`** — Add "Announcements" card.

**Files touched**: `rebuild.sql`, new `announcement.dart`, new `announcement_service.dart`, new `announcement_banner.dart`, new `announcement_manager_screen.dart`, `home_screen.dart`, `admin_config.dart`, `admin_screen.dart`

---

### 6. Feature Flags (Remote Toggles)

**Why**: Need to be able to kill-switch features (matchmaking, ads, gifting, new game modes) without redeployment. Also useful for A/B testing and gradual rollouts.

**Database schema**:

```sql
CREATE TABLE IF NOT EXISTS public.feature_flags (
  flag_key     TEXT PRIMARY KEY,
  enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  description  TEXT,
  updated_by   UUID REFERENCES auth.users(id),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

-- Public read
CREATE POLICY "Anyone can read feature flags"
  ON public.feature_flags FOR SELECT USING (true);

-- Admin write
CREATE OR REPLACE FUNCTION public.admin_set_feature_flag(
  p_flag_key TEXT,
  p_enabled BOOLEAN,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;
  INSERT INTO feature_flags (flag_key, enabled, description, updated_by, updated_at)
  VALUES (p_flag_key, p_enabled, p_description, auth.uid(), NOW())
  ON CONFLICT (flag_key) DO UPDATE SET
    enabled = EXCLUDED.enabled,
    description = COALESCE(EXCLUDED.description, feature_flags.description),
    updated_by = EXCLUDED.updated_by,
    updated_at = NOW();
END;
$$;

-- Seed initial flags
INSERT INTO feature_flags (flag_key, enabled, description) VALUES
  ('matchmaking_enabled', true, 'Async H2H matchmaking'),
  ('ads_enabled', true, 'Show ads to free-tier users'),
  ('gifting_enabled', true, 'Player-to-player coin/cosmetic gifting'),
  ('daily_scramble_enabled', true, 'Daily challenge mode'),
  ('shop_enabled', true, 'In-app shop'),
  ('leaderboard_enabled', true, 'Public leaderboards')
ON CONFLICT (flag_key) DO NOTHING;
```

**Dart changes**:

1. **`lib/data/services/feature_flag_service.dart`** (new) — Singleton, 2-minute TTL cache. `isEnabled(String flagKey)` returns bool. `fetchAll()` returns `Map<String, bool>`. Uses `SharedPreferences` for offline fallback (last-known values).

2. **Gate features** — Wrap matchmaking, shop, gifting, ads, daily scramble entry points with `if (FeatureFlagService.instance.isEnabled('xxx'))` checks. When disabled, show a simple "Feature temporarily unavailable" message.

3. **Admin UI** — Add "Feature Flags" screen (owner only) showing toggle switches for each flag. Simple table layout: flag name, description, on/off switch.

4. **`admin_config.dart`** — Add `AdminPermission.viewFeatureFlags` (moderator + owner), `AdminPermission.editFeatureFlags` (owner only).

**Files touched**: `rebuild.sql`, new `feature_flag_service.dart`, `admin_config.dart`, `admin_screen.dart`, gate insertions in `home_screen.dart`, `matchmaking_service.dart`, `shop_screen.dart`, `friends_service.dart`

---

### 7. Enhanced Player Search

**Why**: Currently admin lookup requires exact username match. Support cases will come via email/user ID. Partial search is essential for moderation.

**Database schema**:

```sql
-- Add a GIN index for trigram-based fuzzy search on usernames
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
  ON public.profiles USING gin (username gin_trgm_ops);

-- RPC: admin_search_users
CREATE OR REPLACE FUNCTION public.admin_search_users(
  p_query TEXT,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id UUID, username TEXT, display_name TEXT, level INT, coins INT,
  games_played INT, admin_role TEXT, banned_at TIMESTAMPTZ, created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT profiles.admin_role INTO v_role FROM profiles WHERE profiles.id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;

  RETURN QUERY
  SELECT p.id, p.username, p.display_name, p.level, p.coins,
         p.games_played, p.admin_role, p.banned_at, p.created_at
  FROM profiles p
  WHERE p.username ILIKE '%' || p_query || '%'
     OR p.display_name ILIKE '%' || p_query || '%'
     OR p.id::TEXT = p_query  -- exact UUID match
  ORDER BY
    CASE WHEN p.username ILIKE p_query THEN 0 ELSE 1 END,  -- exact match first
    similarity(p.username, p_query) DESC
  LIMIT p_limit;
END;
$$;
```

**Dart changes**:

1. Replace the current `_lookupUser(username)` exact-match query in `admin_screen.dart` with a call to the `admin_search_users` RPC.

2. **`_showUserLookupDialog`** — Change from single username input to a search field with debounced results list. As the admin types, show matching users in a scrollable list below the input. Tap a result to open `_UserDetailScreen`.

3. The `_UserDetailScreen` (already added in prior commit) gains: ban status display, link to coin ledger, link to game history, link to reports about this user.

**Files touched**: `rebuild.sql`, `admin_screen.dart` (modify user lookup dialog + `_UserDetailScreen`)

---

## Tier 2B — Ship Within First 2 Weeks

### 8. Account Recovery Tools

**Why**: Users will get locked out (forgotten password, lost email access). Moderators need basic tools to assist.

**Implementation**:

1. **Password reset trigger** — Moderators can trigger `_client.auth.admin.resetPasswordForEmail(email)` via a Supabase Edge Function (since the admin API requires the `service_role` key which should never be in the client). Create an Edge Function `reset-user-password` that accepts a user ID, checks the caller is an admin, and invokes the admin API.

2. **Admin UI** — Add a "Send Password Reset Email" action in the `_UserDetailScreen`. Moderator + owner permission.

3. **Email change** (owner only) — Edge Function `change-user-email` to update auth email for locked-out users. Owner-only, requires the new email + confirmation.

4. **`admin_config.dart`** — Add `AdminPermission.triggerPasswordReset` (moderator + owner), `AdminPermission.changeUserEmail` (owner only).

**Files touched**: new Edge Function in `supabase/functions/`, `admin_config.dart`, `admin_screen.dart` (UserDetailScreen modifications)

**Note**: The `supabase/account_recovery_research.sql` file already exists in the repo — review it for prior research on this topic.

---

### 9. Economy Health Dashboard

**Why**: You have a virtual economy with gold. Without monitoring, you won't notice inflation, exploit abuse, or broken rewards until players complain.

**Implementation** — add to `AdminStatsScreen`:

1. **Economy metrics** (new queries in `admin_stats_screen.dart`):
   - Total coins in circulation: `SELECT SUM(coins) FROM profiles`
   - Average coins per player: `SELECT AVG(coins) FROM profiles`
   - Median coins per player: `SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY coins) FROM profiles`
   - Top 10 richest players: `SELECT username, coins FROM profiles ORDER BY coins DESC LIMIT 10`
   - Coins minted today (from `coin_activity`): `SELECT SUM(coin_amount) FROM coin_activity WHERE coin_amount > 0 AND created_at > NOW() - INTERVAL '24h'`
   - Coins spent today: `SELECT SUM(ABS(coin_amount)) FROM coin_activity WHERE coin_amount < 0 AND created_at > NOW() - INTERVAL '24h'`
   - Net coin flow (minted - spent) for last 7 days, per day

2. **UI** — New "Economy Health" tab within `AdminStatsScreen` or a separate screen. Key numbers at top (total, average, median), bar chart for daily net flow, table of top spenders.

3. **Permissions** — `AdminPermission.viewEconomyHealth` (moderator: view only summary, owner: full detail).

**Files touched**: `admin_stats_screen.dart` (extend with economy section), `admin_config.dart`

---

### 10. IAP Receipt Validation Dashboard

**Why**: Before you accept real money, you need server-side receipt validation. The economy_config gold packages have prices defined but no payment processing exists.

**Implementation** (scaffolding — actual IAP integration is a separate project):

1. **`lib/data/models/iap_receipt.dart`** (new) — Model for purchase records: `userId`, `productId`, `platform` (ios/android), `receiptData`, `isValid`, `amount`, `createdAt`.

2. **Database schema** — `iap_receipts` table storing validated purchases. RLS: users can read own, admins can read all.

3. **Edge Function** — `validate-receipt` (calls Apple/Google APIs to verify). Writes to `iap_receipts` + grants gold/subscription.

4. **Admin UI** — "Purchases" screen showing recent transactions. Filters by product, platform, user. Flag suspicious activity (rapid repurchases, foreign receipt IDs).

5. **Permissions** — `AdminPermission.viewPurchases` (moderator + owner).

**Note**: This is scaffolding. The actual IAP SDK integration (`in_app_purchase` Flutter package + App Store Connect / Play Console setup) is a separate workstream. This just ensures the admin infrastructure is ready.

**Files touched**: `rebuild.sql`, new `iap_receipt.dart`, new Edge Function, new admin screen, `admin_config.dart`, `admin_screen.dart`

---

## Tier 3 — Ship Within First Month

### 11. Anomaly Detection / Anti-Cheat Monitoring

**Why**: Even with DB constraints, you need to monitor for suspicious patterns — players earning coins too fast, impossible scores, API abuse.

**Implementation**:

1. **Database view** — `suspicious_activity` view that surfaces:
   - Players who earned > 10x the daily cap in coin_activity today
   - Scores that hit the CHECK constraint max (100,000) from new accounts
   - Users with > 100 games in 24h (abnormal volume)
   - Duplicate scores (same score + time_ms submitted within seconds)

```sql
CREATE OR REPLACE VIEW suspicious_activity AS
SELECT
  p.id, p.username, p.level, p.coins, p.games_played,
  (SELECT COUNT(*) FROM scores s WHERE s.user_id = p.id AND s.created_at > NOW() - INTERVAL '24h') AS games_24h,
  (SELECT SUM(coin_amount) FROM coin_activity c WHERE c.user_id = p.id AND c.coin_amount > 0 AND c.created_at > NOW() - INTERVAL '24h') AS coins_earned_24h,
  p.banned_at
FROM profiles p
WHERE
  (SELECT COUNT(*) FROM scores s WHERE s.user_id = p.id AND s.created_at > NOW() - INTERVAL '24h') > 100
  OR (SELECT SUM(coin_amount) FROM coin_activity c WHERE c.user_id = p.id AND c.coin_amount > 0 AND c.created_at > NOW() - INTERVAL '24h') > 1500
  OR p.best_score >= 99000;
```

2. **Admin UI** — "Suspicious Activity" screen showing flagged players with one-tap ban.

3. **Permissions** — `AdminPermission.viewSuspiciousActivity` (moderator + owner).

**Files touched**: `rebuild.sql`, new admin screen, `admin_config.dart`, `admin_screen.dart`

---

### 12. GDPR Compliance Tools

**Why**: GDPR requires responding to data deletion requests within 30 days. The app has `exportUserData()` and `deleteAccountData()`, but there's no admin queue for tracking requests.

**Current state**: `account_management_service.dart` has:
- `exportUserData()` (line 28) — fetches profiles, settings, account_state, scores, friendships, challenges
- `deleteAccountData()` (line 225) — cascades deletes but leaves auth.users orphaned (TODO at line 220)

**Implementation**:

1. **Fix auth deletion** — Create Edge Function `delete-auth-user` that calls `auth.admin.deleteUser(userId)` with the service role key. Call it from `deleteAccountData()` as the final step.

2. **GDPR request table** (optional but recommended):

```sql
CREATE TABLE IF NOT EXISTS public.gdpr_requests (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  type        TEXT NOT NULL,  -- 'export' or 'delete'
  status      TEXT NOT NULL DEFAULT 'pending',  -- 'pending', 'completed', 'failed'
  completed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

3. **Admin UI** — "GDPR Requests" screen showing pending export/deletion requests. Owners can process them manually or confirm auto-processed ones.

4. **Auto-process** — Self-service deletion already works. The admin screen is a safety net for tracking compliance deadlines.

**Files touched**: `rebuild.sql`, new Edge Function, `account_management_service.dart`, new admin screen, `admin_config.dart`, `admin_screen.dart`

---

## Updated AdminPermission Enum (Complete)

After all 12 features, the `AdminPermission` enum should be:

```dart
enum AdminPermission {
  // ── View / Read ── (moderator + owner)
  viewAnalytics,
  viewUserData,
  viewGameHistory,
  viewCoinLedger,
  viewGameLog,
  viewDesignPreviews,
  viewDifficulty,
  viewAdConfig,
  viewErrors,
  viewReports,           // Feature 2
  viewAnnouncements,     // Feature 5
  viewFeatureFlags,      // Feature 6
  viewEconomyHealth,     // Feature 9
  viewPurchases,         // Feature 10
  viewSuspiciousActivity, // Feature 11
  viewOwnAuditLog,       // Feature 3

  // ── Moderation ── (moderator + owner)
  changeUsername,
  resolveReports,        // Feature 2
  tempBanUser,           // Feature 1
  triggerPasswordReset,  // Feature 8
  createAnnouncements,   // Feature 5 (moderator: info only)

  // ── Owner only ──
  selfServiceActions,
  giftGold, giftLevels, giftFlights,
  setCoins, setLevel, setFlights,
  giftCosmetic,
  setLicense, setAvatar,
  unlockAll,
  manageRoles,
  editEarnings, editPromotions, editGoldPackages, editShopPrices,
  editDifficulty,
  permaBanUser,          // Feature 1
  unbanUser,             // Feature 1
  editAppConfig,         // Feature 4
  editAnnouncements,     // Feature 5
  editFeatureFlags,      // Feature 6
  changeUserEmail,       // Feature 8
  viewAuditLog,          // Feature 3 (all entries)
}
```

---

## Implementation Order (Recommended)

1. **Feature 3: Audit Log** — Do this first because all subsequent features should log to it.
2. **Feature 1: Ban System** — Highest-priority moderation tool.
3. **Feature 2: Report Queue** — Players need a way to surface abuse.
4. **Feature 4: Force Update Gate** — Critical infrastructure for Day 1.
5. **Feature 7: Enhanced Player Search** — Quality-of-life for moderators using the tools above.
6. **Feature 5: Announcements** — Communicate with players.
7. **Feature 6: Feature Flags** — Kill-switch capability.
8. **Feature 9: Economy Dashboard** — Start monitoring before IAP goes live.
9. **Feature 8: Account Recovery** — Support tool.
10. **Feature 10: IAP Dashboard** — When payment processing is ready.
11. **Feature 11: Anomaly Detection** — When player base grows.
12. **Feature 12: GDPR Tools** — Before EU launch.

---

## Estimated Scope

| Feature | New Files | Modified Files | New DB Objects | Complexity |
|---|---|---|---|---|
| 1. Ban System | 1 | 5 | 3 cols + 2 RPCs | Medium |
| 2. Report Queue | 3 | 4 | 1 table + 1 RPC | Medium |
| 3. Audit Log | 1 | 10+ | 1 table + modify 8 RPCs | Medium-High |
| 4. Force Update | 4 | 3 | 1 table + 1 RPC | Medium |
| 5. Announcements | 4 | 3 | 1 table + 1 RPC | Medium |
| 6. Feature Flags | 1 | 6 | 1 table + 1 RPC | Low |
| 7. Player Search | 0 | 2 | 1 RPC + 1 index | Low |
| 8. Account Recovery | 0 | 3 | 1 Edge Function | Low-Medium |
| 9. Economy Dashboard | 0 | 2 | 0 | Low |
| 10. IAP Dashboard | 3 | 3 | 1 table + 1 Edge Function | High |
| 11. Anomaly Detection | 1 | 3 | 1 view | Low |
| 12. GDPR Tools | 1 | 2 | 1 table + 1 Edge Function | Medium |
