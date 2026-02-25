-- =============================================================================
-- Flit — Consolidated Supabase Schema Rebuild
-- =============================================================================
-- Run this in the Supabase SQL Editor (or via psql) to ensure ALL tables,
-- columns, RLS policies, views, functions, triggers, and indexes exist.
--
-- Safe to re-run: every statement is idempotent (IF NOT EXISTS / IF EXISTS
-- guards). Running on an existing DB will only add missing pieces.
--
-- To NUKE and rebuild from scratch, first run: supabase/teardown.sql
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 0. PROFILES TABLE (created by auth trigger, but ensured here)
-- ---------------------------------------------------------------------------
-- Supabase does NOT auto-create a profiles table — projects must create it
-- themselves. This is the foundation: one row per authenticated user.

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can read own profile'
  ) THEN
    CREATE POLICY "Users can read own profile"
      ON public.profiles FOR SELECT USING (auth.uid() = id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can insert own profile'
  ) THEN
    CREATE POLICY "Users can insert own profile"
      ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
      ON public.profiles FOR UPDATE USING (auth.uid() = id);
  END IF;
END $$;

-- Public read access for leaderboards (anyone can see any profile in views).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Profiles are publicly readable'
  ) THEN
    CREATE POLICY "Profiles are publicly readable"
      ON public.profiles FOR SELECT USING (true);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 0b. AUTH TRIGGER — auto-create profiles row on sign-up
-- ---------------------------------------------------------------------------
-- Without this trigger, new users get auth.users rows but no profiles row,
-- causing all subsequent data loads to fail silently.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Create profiles row (foundation — must exist for FK joins).
  -- Auto-promote known owner emails on signup.
  INSERT INTO public.profiles (id, admin_role)
  VALUES (
    NEW.id,
    CASE WHEN COALESCE(NEW.email, '') IN ('jamiebright1@gmail.com')
         THEN 'owner' ELSE NULL END
  )
  ON CONFLICT (id) DO NOTHING;  -- never overwrite an existing profile

  -- Create user_settings row with sensible defaults.
  INSERT INTO public.user_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Create account_state row with sensible defaults.
  INSERT INTO public.account_state (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Drop and recreate to ensure it's attached correctly.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ---------------------------------------------------------------------------
-- 1. PROFILES — identity and gameplay stat columns
-- ---------------------------------------------------------------------------

-- Identity columns (may already exist from earlier migration).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'username'
  ) THEN
    ALTER TABLE public.profiles
      ADD COLUMN username TEXT,
      ADD COLUMN display_name TEXT,
      ADD COLUMN avatar_url TEXT;
  END IF;
END $$;

-- Gameplay stat columns.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'level'
  ) THEN
    ALTER TABLE public.profiles
      ADD COLUMN level INT NOT NULL DEFAULT 1,
      ADD COLUMN xp INT NOT NULL DEFAULT 0,
      ADD COLUMN coins INT NOT NULL DEFAULT 100,
      ADD COLUMN games_played INT NOT NULL DEFAULT 0,
      ADD COLUMN best_score INT,
      ADD COLUMN best_time_ms BIGINT,
      ADD COLUMN total_flight_time_ms BIGINT NOT NULL DEFAULT 0,
      ADD COLUMN countries_found INT NOT NULL DEFAULT 0;
  END IF;
END $$;

-- Clue-type correctness counters and best streak (added 2026-02-22).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'flags_correct'
  ) THEN
    ALTER TABLE public.profiles
      ADD COLUMN flags_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN capitals_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN outlines_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN borders_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN stats_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN best_streak INT NOT NULL DEFAULT 0;
  END IF;
END $$;

-- Admin role (added 2026-02-22).
-- NULL = regular user, 'moderator' = limited admin, 'owner' = god mode.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS admin_role TEXT DEFAULT NULL
    CHECK (admin_role IS NULL OR admin_role IN ('moderator', 'owner'));


-- ---------------------------------------------------------------------------
-- 2. USER_SETTINGS — per-user game settings
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  turn_sensitivity   REAL NOT NULL DEFAULT 0.5,
  invert_controls    BOOLEAN NOT NULL DEFAULT FALSE,
  enable_night       BOOLEAN NOT NULL DEFAULT TRUE,
  map_style          TEXT NOT NULL DEFAULT 'topo',
  english_labels     BOOLEAN NOT NULL DEFAULT TRUE,
  difficulty         TEXT NOT NULL DEFAULT 'normal',
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audio and haptic columns (added 2026-02-21).
ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS sound_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS haptic_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Volume columns (added 2026-02-21).
ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS music_volume DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS effects_volume DOUBLE PRECISION NOT NULL DEFAULT 1.0;

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'user_settings' AND policyname = 'Users can read own settings'
  ) THEN
    CREATE POLICY "Users can read own settings"
      ON public.user_settings FOR SELECT USING (auth.uid() = user_id);
    CREATE POLICY "Users can insert own settings"
      ON public.user_settings FOR INSERT WITH CHECK (auth.uid() = user_id);
    CREATE POLICY "Users can update own settings"
      ON public.user_settings FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 3. ACCOUNT_STATE — avatar, license, cosmetics, daily state
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.account_state (
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

-- owned_cosmetics (added 2026-02-21).
ALTER TABLE public.account_state
  ADD COLUMN IF NOT EXISTS owned_cosmetics TEXT[] NOT NULL DEFAULT '{}';

-- Title, daily streak, last result (added 2026-02-22).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'account_state' AND column_name = 'equipped_title_id'
  ) THEN
    ALTER TABLE public.account_state
      ADD COLUMN equipped_title_id TEXT,
      ADD COLUMN daily_streak_data JSONB NOT NULL DEFAULT '{}',
      ADD COLUMN last_daily_result JSONB NOT NULL DEFAULT '{}';
  END IF;
END $$;

ALTER TABLE public.account_state ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'account_state' AND policyname = 'Users can read own account state'
  ) THEN
    CREATE POLICY "Users can read own account state"
      ON public.account_state FOR SELECT USING (auth.uid() = user_id);
    CREATE POLICY "Users can insert own account state"
      ON public.account_state FOR INSERT WITH CHECK (auth.uid() = user_id);
    CREATE POLICY "Users can update own account state"
      ON public.account_state FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;

-- Public read access for leaderboards (daily_streak_leaderboard needs to read
-- other players' streak data). Same pattern as profiles public read policy.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'account_state' AND policyname = 'Account state is publicly readable'
  ) THEN
    CREATE POLICY "Account state is publicly readable"
      ON public.account_state FOR SELECT USING (true);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 4. SCORES — individual game results (leaderboard source)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.scores (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score         INT NOT NULL,
  time_ms       BIGINT NOT NULL,
  region        TEXT NOT NULL DEFAULT 'world',
  rounds_completed INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.scores ADD COLUMN IF NOT EXISTS round_emojis TEXT;
ALTER TABLE public.scores ADD COLUMN IF NOT EXISTS round_details JSONB;

CREATE INDEX IF NOT EXISTS idx_scores_leaderboard
  ON public.scores (region, score DESC, created_at);
CREATE INDEX IF NOT EXISTS idx_scores_user
  ON public.scores (user_id, created_at DESC);

ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'scores' AND policyname = 'Scores are viewable by everyone'
  ) THEN
    CREATE POLICY "Scores are viewable by everyone"
      ON public.scores FOR SELECT USING (true);
    CREATE POLICY "Users can insert own scores"
      ON public.scores FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 5. COIN_ACTIVITY — coin movement audit log
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.coin_activity (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username      TEXT NOT NULL,
  coin_amount   INT NOT NULL,
  source        TEXT NOT NULL,
  balance_after INT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coin_activity_user_time
  ON public.coin_activity (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_coin_activity_source_time
  ON public.coin_activity (source, created_at DESC);

ALTER TABLE public.coin_activity ENABLE ROW LEVEL SECURITY;

-- Drop the old restrictive read policy if it exists, replace with public read.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'coin_activity' AND policyname = 'Users can read own coin activity'
  ) THEN
    DROP POLICY "Users can read own coin activity" ON public.coin_activity;
  END IF;
END $$;

-- Public coin ledger: all authenticated users can read all coin activity.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'coin_activity' AND policyname = 'Coin activity is publicly readable'
  ) THEN
    CREATE POLICY "Coin activity is publicly readable"
      ON public.coin_activity FOR SELECT USING (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'coin_activity' AND policyname = 'Users can insert own coin activity'
  ) THEN
    CREATE POLICY "Users can insert own coin activity"
      ON public.coin_activity FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 6. FRIENDSHIPS — friend connections between players
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.friendships (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  requester_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status         TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (requester_id, addressee_id),
  CHECK (requester_id <> addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_requester
  ON public.friendships (requester_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee
  ON public.friendships (addressee_id, status);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'friendships' AND policyname = 'Users can see own friendships'
  ) THEN
    CREATE POLICY "Users can see own friendships"
      ON public.friendships FOR SELECT
      USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
    CREATE POLICY "Users can send friend requests"
      ON public.friendships FOR INSERT
      WITH CHECK (auth.uid() = requester_id);
    CREATE POLICY "Addressee can respond to friend requests"
      ON public.friendships FOR UPDATE
      USING (auth.uid() = addressee_id);
    CREATE POLICY "Users can remove friendships"
      ON public.friendships FOR DELETE
      USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 7. CHALLENGES — H2H dogfight matches
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.challenges (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  challenger_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenger_name  TEXT NOT NULL,
  challenged_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenged_name  TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'in_progress', 'completed', 'expired', 'declined')),
  rounds           JSONB NOT NULL DEFAULT '[]',
  winner_id        UUID REFERENCES auth.users(id),
  challenger_coins INT NOT NULL DEFAULT 0,
  challenged_coins INT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_challenges_challenger
  ON public.challenges (challenger_id, status);
CREATE INDEX IF NOT EXISTS idx_challenges_challenged
  ON public.challenges (challenged_id, status);
CREATE INDEX IF NOT EXISTS idx_challenges_created
  ON public.challenges (created_at DESC);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'challenges' AND policyname = 'Players can see own challenges'
  ) THEN
    CREATE POLICY "Players can see own challenges"
      ON public.challenges FOR SELECT
      USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
    CREATE POLICY "Challenger can create challenges"
      ON public.challenges FOR INSERT
      WITH CHECK (auth.uid() = challenger_id);
    CREATE POLICY "Players can update own challenges"
      ON public.challenges FOR UPDATE
      USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 8. MATCHMAKING_POOL — async challengerless matchmaking
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.matchmaking_pool (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  region            TEXT NOT NULL DEFAULT 'world',
  seed              TEXT NOT NULL,
  rounds            JSONB NOT NULL DEFAULT '[]',
  elo_rating        INT NOT NULL,
  gameplay_version  TEXT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  matched_at        TIMESTAMPTZ,
  matched_with      UUID REFERENCES auth.users(id),
  challenge_id      UUID REFERENCES public.challenges(id)
);

CREATE INDEX IF NOT EXISTS idx_matchmaking_unmatched
  ON public.matchmaking_pool (region, elo_rating, gameplay_version)
  WHERE matched_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_matchmaking_user
  ON public.matchmaking_pool (user_id, created_at DESC);

ALTER TABLE public.matchmaking_pool ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'matchmaking_pool' AND policyname = 'Users can insert own entries'
  ) THEN
    CREATE POLICY "Users can insert own entries"
      ON public.matchmaking_pool FOR INSERT
      WITH CHECK (auth.uid() = user_id);
    CREATE POLICY "Users can read own or matched entries"
      ON public.matchmaking_pool FOR SELECT
      USING (auth.uid() = user_id OR auth.uid() = matched_with);
    CREATE POLICY "Users can update own entries on match"
      ON public.matchmaking_pool FOR UPDATE
      USING (auth.uid() = user_id OR matched_at IS NULL);
  END IF;
END $$;

-- Admin stats: allow count queries.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'matchmaking_pool'
    AND policyname = 'Allow pool size counting for stats'
  ) THEN
    CREATE POLICY "Allow pool size counting for stats"
      ON public.matchmaking_pool FOR SELECT
      USING (true);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 8. TRIGGERS — auto-update updated_at
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_profiles_updated_at') THEN
    CREATE TRIGGER trg_profiles_updated_at
      BEFORE UPDATE ON public.profiles
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_user_settings_updated_at') THEN
    CREATE TRIGGER trg_user_settings_updated_at
      BEFORE UPDATE ON public.user_settings
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_account_state_updated_at') THEN
    CREATE TRIGGER trg_account_state_updated_at
      BEFORE UPDATE ON public.account_state
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_friendships_updated_at') THEN
    CREATE TRIGGER trg_friendships_updated_at
      BEFORE UPDATE ON public.friendships
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 8b. TRIGGER — protect monotonic profile stats from regression
-- ---------------------------------------------------------------------------
-- Safety net: even if a client writes stale data, the DB keeps the higher
-- values for accumulator stats. Admin functions can bypass by setting the
-- session variable 'app.skip_stat_protection' to 'true'.

CREATE OR REPLACE FUNCTION public.protect_profile_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Allow admin functions to bypass (they set this session var).
  IF current_setting('app.skip_stat_protection', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- Monotonic counters: never decrease.
  NEW.games_played       := GREATEST(COALESCE(OLD.games_played, 0),       COALESCE(NEW.games_played, 0));
  NEW.countries_found    := GREATEST(COALESCE(OLD.countries_found, 0),    COALESCE(NEW.countries_found, 0));
  NEW.total_flight_time_ms := GREATEST(COALESCE(OLD.total_flight_time_ms, 0), COALESCE(NEW.total_flight_time_ms, 0));
  NEW.flags_correct      := GREATEST(COALESCE(OLD.flags_correct, 0),      COALESCE(NEW.flags_correct, 0));
  NEW.capitals_correct   := GREATEST(COALESCE(OLD.capitals_correct, 0),   COALESCE(NEW.capitals_correct, 0));
  NEW.outlines_correct   := GREATEST(COALESCE(OLD.outlines_correct, 0),   COALESCE(NEW.outlines_correct, 0));
  NEW.borders_correct    := GREATEST(COALESCE(OLD.borders_correct, 0),    COALESCE(NEW.borders_correct, 0));
  NEW.stats_correct      := GREATEST(COALESCE(OLD.stats_correct, 0),      COALESCE(NEW.stats_correct, 0));
  NEW.best_streak        := GREATEST(COALESCE(OLD.best_streak, 0),        COALESCE(NEW.best_streak, 0));
  NEW.level              := GREATEST(COALESCE(OLD.level, 1),              COALESCE(NEW.level, 1));

  -- XP: take max within same level.
  IF NEW.level = OLD.level THEN
    NEW.xp := GREATEST(COALESCE(OLD.xp, 0), COALESCE(NEW.xp, 0));
  END IF;

  -- best_score: higher is better (nullable).
  IF OLD.best_score IS NOT NULL THEN
    IF NEW.best_score IS NULL OR NEW.best_score < OLD.best_score THEN
      NEW.best_score := OLD.best_score;
    END IF;
  END IF;

  -- best_time_ms: lower is better (nullable).
  IF OLD.best_time_ms IS NOT NULL THEN
    IF NEW.best_time_ms IS NULL OR NEW.best_time_ms > OLD.best_time_ms THEN
      NEW.best_time_ms := OLD.best_time_ms;
    END IF;
  END IF;

  -- Coins are server-authoritative (consumable) — no protection needed.

  RETURN NEW;
END;
$$;

-- Drop and recreate to ensure latest version.
DROP TRIGGER IF EXISTS trg_protect_profile_stats ON public.profiles;
CREATE TRIGGER trg_protect_profile_stats
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_stats();


-- ---------------------------------------------------------------------------
-- 9. CONSTRAINTS
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_score') THEN
    ALTER TABLE public.scores ADD CONSTRAINT chk_score
      CHECK (score >= 0 AND score <= 100000);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_time') THEN
    ALTER TABLE public.scores ADD CONSTRAINT chk_time
      CHECK (time_ms > 0 AND time_ms < 3600000);
  END IF;
END $$;

-- Profile constraints (idempotent via IF NOT EXISTS).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_username_length') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT check_username_length
      CHECK (username IS NULL OR (LENGTH(username) >= 3 AND LENGTH(username) <= 20));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_username_pattern') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT check_username_pattern
      CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9_]+$');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_level_positive') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT check_level_positive
      CHECK (level >= 1);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_xp_non_negative') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT check_xp_non_negative
      CHECK (xp >= 0);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_coins_non_negative') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT check_coins_non_negative
      CHECK (coins >= 0);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 10. PERFORMANCE INDEXES
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_scores_global_rank
  ON public.scores (score DESC, time_ms ASC);

CREATE INDEX IF NOT EXISTS idx_scores_daily_rank
  ON public.scores (created_at, score DESC, time_ms ASC)
  WHERE region = 'daily';

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username
  ON public.profiles (username);


-- ---------------------------------------------------------------------------
-- 11. SERVER-SIDE FUNCTIONS
-- ---------------------------------------------------------------------------

-- Atomic cosmetic purchase.
CREATE OR REPLACE FUNCTION public.purchase_cosmetic(
  p_user_id UUID,
  p_cosmetic_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;

  SELECT coins INTO v_current_coins
  FROM public.profiles WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current_coins, 'cost', p_cost);
  END IF;

  SELECT owned_cosmetics INTO v_owned
  FROM public.account_state WHERE user_id = p_user_id;

  IF v_owned IS NOT NULL AND p_cosmetic_id = ANY(v_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already owned',
      'current_balance', v_current_coins);
  END IF;

  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = p_user_id;

  INSERT INTO public.account_state (user_id, owned_cosmetics)
  VALUES (p_user_id, ARRAY[p_cosmetic_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_cosmetics = array_append(
    COALESCE(account_state.owned_cosmetics, '{}'), p_cosmetic_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'cosmetic_id', p_cosmetic_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.purchase_cosmetic(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_cosmetic(UUID, TEXT, INT) TO service_role;


-- Expire stale challenges.
CREATE OR REPLACE FUNCTION public.expire_stale_challenges()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  expired_count INT;
BEGIN
  UPDATE public.challenges
  SET status = 'expired', completed_at = NOW()
  WHERE status IN ('pending', 'in_progress')
    AND created_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  IF expired_count > 0 THEN
    RAISE LOG 'expire_stale_challenges: expired % challenges', expired_count;
  END IF;
  RETURN expired_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expire_stale_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_challenges() TO service_role;


-- Atomic admin stat increment (used by admin panel to gift coins/levels/flights).
-- Uses an allowlist to prevent SQL injection via stat_column.
CREATE OR REPLACE FUNCTION public.admin_increment_stat(
  target_user_id UUID,
  stat_column TEXT,
  amount INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target_username TEXT;
  v_new_balance INT;
BEGIN
  -- Look up caller's admin role.
  SELECT admin_role INTO v_role
  FROM public.profiles WHERE id = auth.uid();

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Permission denied: caller is not an admin';
  END IF;

  -- Allowlist of safe column names to prevent SQL injection.
  IF stat_column NOT IN ('coins', 'level', 'xp', 'games_played') THEN
    RAISE EXCEPTION 'Invalid stat column: %', stat_column;
  END IF;

  -- Moderators have per-call limits. Owners have none.
  IF v_role = 'moderator' THEN
    IF (stat_column = 'coins' AND amount > 1000) THEN
      RAISE EXCEPTION 'Moderator limit: max 1000 coins per call';
    END IF;
    IF (stat_column = 'level' AND amount > 5) THEN
      RAISE EXCEPTION 'Moderator limit: max 5 levels per call';
    END IF;
    IF (stat_column = 'xp' AND amount > 5000) THEN
      RAISE EXCEPTION 'Moderator limit: max 5000 XP per call';
    END IF;
    IF (stat_column = 'games_played' AND amount > 10) THEN
      RAISE EXCEPTION 'Moderator limit: max 10 games_played per call';
    END IF;
  END IF;

  -- Bypass the stat-protection trigger so admin decrements work.
  PERFORM set_config('app.skip_stat_protection', 'true', true);

  -- Use dynamic SQL with the validated column name.
  EXECUTE format(
    'UPDATE public.profiles SET %I = %I + $1 WHERE id = $2',
    stat_column, stat_column
  ) USING amount, target_user_id;

  IF stat_column = 'coins' THEN
    SELECT username, coins INTO v_target_username, v_new_balance
    FROM public.profiles
    WHERE id = target_user_id;

    INSERT INTO public.coin_activity (
      user_id,
      username,
      coin_amount,
      source,
      balance_after
    ) VALUES (
      target_user_id,
      COALESCE(NULLIF(v_target_username, ''), target_user_id::TEXT),
      amount,
      'admin_gift',
      v_new_balance
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_increment_stat(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_increment_stat(UUID, TEXT, INT) TO service_role;


-- Atomic admin stat setter for absolute-value updates.
-- Uses the same admin checks and allowlist as admin_increment_stat.
CREATE OR REPLACE FUNCTION public.admin_set_stat(
  target_user_id UUID,
  stat_column TEXT,
  new_value INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target_username TEXT;
BEGIN
  SELECT admin_role INTO v_role
  FROM public.profiles WHERE id = auth.uid();

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Permission denied: caller is not an admin';
  END IF;

  IF stat_column NOT IN ('coins', 'level', 'xp', 'games_played') THEN
    RAISE EXCEPTION 'Invalid stat column: %', stat_column;
  END IF;

  IF new_value < 0 THEN
    RAISE EXCEPTION 'Invalid stat value: must be >= 0';
  END IF;

  -- Bypass the stat-protection trigger so admins can decrease stats.
  PERFORM set_config('app.skip_stat_protection', 'true', true);

  EXECUTE format(
    'UPDATE public.profiles SET %I = $1 WHERE id = $2',
    stat_column
  ) USING new_value, target_user_id;

  IF stat_column = 'coins' THEN
    SELECT username INTO v_target_username
    FROM public.profiles
    WHERE id = target_user_id;

    INSERT INTO public.coin_activity (
      user_id,
      username,
      coin_amount,
      source,
      balance_after
    ) VALUES (
      target_user_id,
      COALESCE(NULLIF(v_target_username, ''), target_user_id::TEXT),
      -- Absolute set operation: store delta as 0 and use balance_after
      -- for the authoritative post-set coin balance.
      0,
      'admin_set',
      new_value
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_stat(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_stat(UUID, TEXT, INT) TO service_role;


-- Admin: set another player's license data (bypasses RLS on account_state).
-- Only owners can set licenses; moderators are denied.
CREATE OR REPLACE FUNCTION public.admin_set_license(
  target_user_id UUID,
  p_license_data JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role
  FROM public.profiles WHERE id = auth.uid();

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Permission denied: caller is not an admin';
  END IF;

  IF v_role = 'moderator' THEN
    RAISE EXCEPTION 'Permission denied: only owners can set licenses';
  END IF;

  -- Upsert account_state with the license data.
  INSERT INTO public.account_state (user_id, license_data)
  VALUES (target_user_id, p_license_data)
  ON CONFLICT (user_id)
  DO UPDATE SET license_data = p_license_data, updated_at = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_license(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_license(UUID, JSONB) TO service_role;


-- Admin: manage player roles (promote/demote moderators). Owner-only.
CREATE OR REPLACE FUNCTION public.admin_set_role(
  target_user_id UUID,
  p_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role
  FROM public.profiles WHERE id = auth.uid();

  IF v_role != 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can manage roles';
  END IF;

  -- Validate role value.
  IF p_role IS NOT NULL AND p_role NOT IN ('moderator', 'owner') THEN
    RAISE EXCEPTION 'Invalid role: must be NULL, moderator, or owner';
  END IF;

  -- Prevent demoting self.
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;

  UPDATE public.profiles SET admin_role = p_role WHERE id = target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_role(UUID, TEXT) TO service_role;


-- Admin: unlock all shop cosmetics and avatar parts for a player. Owner-only.
CREATE OR REPLACE FUNCTION public.admin_unlock_all(
  target_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role
  FROM public.profiles WHERE id = auth.uid();

  IF v_role != 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can unlock all';
  END IF;

  -- Unlock all avatar parts: merge with existing.
  UPDATE public.account_state
  SET owned_avatar_parts = (
    SELECT ARRAY(
      SELECT DISTINCT unnest(owned_avatar_parts || ARRAY[
        -- All paid eye variants
        'eyes_variant14','eyes_variant15','eyes_variant16','eyes_variant17',
        'eyes_variant18','eyes_variant19','eyes_variant20','eyes_variant21',
        'eyes_variant22','eyes_variant23','eyes_variant24','eyes_variant25','eyes_variant26',
        -- All paid hair colors
        'hairColor_green','hairColor_teal','hairColor_pink','hairColor_purple',
        -- All paid glasses
        'glasses_variant01','glasses_variant02','glasses_variant03','glasses_variant04','glasses_variant05',
        -- All paid earrings
        'earrings_variant01','earrings_variant02','earrings_variant03',
        'earrings_variant04','earrings_variant05','earrings_variant06',
        -- All paid hair styles (short06-19, long06-26)
        'hair_short06','hair_short07','hair_short08','hair_short09','hair_short10',
        'hair_short11','hair_short12','hair_short13','hair_short14','hair_short15',
        'hair_short16','hair_short17','hair_short18','hair_short19',
        'hair_long06','hair_long07','hair_long08','hair_long09','hair_long10',
        'hair_long11','hair_long12','hair_long13','hair_long14','hair_long15',
        'hair_long16','hair_long17','hair_long18','hair_long19','hair_long20',
        'hair_long21','hair_long22','hair_long23','hair_long24','hair_long25','hair_long26',
        -- All paid eyebrow variants
        'eyebrows_variant09','eyebrows_variant10','eyebrows_variant11',
        'eyebrows_variant12','eyebrows_variant13','eyebrows_variant14','eyebrows_variant15',
        -- All paid mouth variants
        'mouth_variant16','mouth_variant17','mouth_variant18','mouth_variant19','mouth_variant20',
        'mouth_variant21','mouth_variant22','mouth_variant23','mouth_variant24','mouth_variant25',
        'mouth_variant26','mouth_variant27','mouth_variant28','mouth_variant29','mouth_variant30'
      ])
    )
  ),
  updated_at = NOW()
  WHERE user_id = target_user_id;

  -- Unlock all cosmetics (planes, contrails, companions).
  UPDATE public.account_state
  SET owned_cosmetics = (
    SELECT ARRAY(
      SELECT DISTINCT unnest(owned_cosmetics || ARRAY[
        'plane_paper','plane_prop','plane_padraigaer','plane_seaplane',
        'plane_jet','plane_red_baron','plane_rocket','plane_warbird',
        'plane_night_raider','plane_concorde_classic','plane_stealth',
        'plane_presidential','plane_golden_jet','plane_diamond_concorde',
        'plane_platinum_eagle',
        'contrail_fire','contrail_rainbow','contrail_sparkle','contrail_neon',
        'contrail_gold_dust','contrail_aurora','contrail_chemtrails',
        'companion_pidgey','companion_sparrow','companion_eagle',
        'companion_parrot','companion_phoenix','companion_dragon',
        'companion_charizard'
      ])
    )
  ),
  updated_at = NOW()
  WHERE user_id = target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_unlock_all(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unlock_all(UUID) TO service_role;


-- Atomic avatar-part purchase (mirrors purchase_cosmetic for avatar parts).
CREATE OR REPLACE FUNCTION public.purchase_avatar_part(
  p_user_id UUID,
  p_part_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_part_id IS NULL OR p_part_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid part ID');
  END IF;

  SELECT coins INTO v_current_coins
  FROM public.profiles WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current_coins, 'cost', p_cost);
  END IF;

  SELECT owned_avatar_parts INTO v_owned
  FROM public.account_state WHERE user_id = p_user_id;

  IF v_owned IS NOT NULL AND p_part_id = ANY(v_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already owned',
      'current_balance', v_current_coins);
  END IF;

  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = p_user_id;

  INSERT INTO public.account_state (user_id, owned_avatar_parts)
  VALUES (p_user_id, ARRAY[p_part_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_avatar_parts = array_append(
    COALESCE(account_state.owned_avatar_parts, '{}'), p_part_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'part_id', p_part_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.purchase_avatar_part(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_avatar_part(UUID, TEXT, INT) TO service_role;


-- Atomic coin transfer between two players.
-- Replaces the non-atomic dual-UPDATE pattern in friends_service.dart.
CREATE OR REPLACE FUNCTION public.send_coins(
  p_sender_id UUID,
  p_recipient_id UUID,
  p_amount INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_coins INT;
  v_recipient_coins INT;
  v_sender_balance INT;
  v_sender_username TEXT;
  v_recipient_username TEXT;
BEGIN
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;
  IF p_sender_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send coins to yourself');
  END IF;

  -- Lock sender first (consistent ordering prevents deadlocks).
  SELECT coins INTO v_sender_coins
  FROM public.profiles WHERE id = p_sender_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sender not found');
  END IF;
  IF v_sender_coins < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_sender_coins);
  END IF;

  -- Lock recipient.
  SELECT coins INTO v_recipient_coins
  FROM public.profiles WHERE id = p_recipient_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient not found');
  END IF;

  v_sender_balance := v_sender_coins - p_amount;
  UPDATE public.profiles SET coins = v_sender_balance WHERE id = p_sender_id;
  UPDATE public.profiles SET coins = v_recipient_coins + p_amount WHERE id = p_recipient_id;

  SELECT username INTO v_sender_username FROM public.profiles WHERE id = p_sender_id;
  SELECT username INTO v_recipient_username FROM public.profiles WHERE id = p_recipient_id;

  INSERT INTO public.coin_activity (
    user_id,
    username,
    coin_amount,
    source,
    balance_after
  ) VALUES (
    p_sender_id,
    COALESCE(NULLIF(v_sender_username, ''), p_sender_id::TEXT),
    -p_amount,
    'gift_sent',
    v_sender_balance
  );

  INSERT INTO public.coin_activity (
    user_id,
    username,
    coin_amount,
    source,
    balance_after
  ) VALUES (
    p_recipient_id,
    COALESCE(NULLIF(v_recipient_username, ''), p_recipient_id::TEXT),
    p_amount,
    'gift_received',
    v_recipient_coins + p_amount
  );

  RETURN jsonb_build_object('success', true,
    'sender_balance', v_sender_balance,
    'amount', p_amount);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_coins(UUID, UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_coins(UUID, UUID, INT) TO service_role;


-- Gift a shop cosmetic to another player (gifter pays the cost).
CREATE OR REPLACE FUNCTION public.gift_cosmetic(
  p_gifter_id UUID,
  p_recipient_id UUID,
  p_cosmetic_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gifter_coins INT;
  v_recipient_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;
  IF p_gifter_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot gift to yourself');
  END IF;

  -- Lock gifter.
  SELECT coins INTO v_gifter_coins
  FROM public.profiles WHERE id = p_gifter_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gifter not found');
  END IF;
  IF v_gifter_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_gifter_coins, 'cost', p_cost);
  END IF;

  -- Check recipient doesn't already own it.
  SELECT owned_cosmetics INTO v_recipient_owned
  FROM public.account_state WHERE user_id = p_recipient_id;
  IF v_recipient_owned IS NOT NULL AND p_cosmetic_id = ANY(v_recipient_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient already owns this');
  END IF;

  -- Deduct from gifter.
  v_new_balance := v_gifter_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = p_gifter_id;

  -- Add to recipient.
  INSERT INTO public.account_state (user_id, owned_cosmetics)
  VALUES (p_recipient_id, ARRAY[p_cosmetic_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_cosmetics = array_append(
    COALESCE(account_state.owned_cosmetics, '{}'), p_cosmetic_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'cosmetic_id', p_cosmetic_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_cosmetic(UUID, UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_cosmetic(UUID, UUID, TEXT, INT) TO service_role;


-- Gift an avatar part to another player (gifter pays the cost).
CREATE OR REPLACE FUNCTION public.gift_avatar_part(
  p_gifter_id UUID,
  p_recipient_id UUID,
  p_part_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gifter_coins INT;
  v_recipient_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_part_id IS NULL OR p_part_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid part ID');
  END IF;
  IF p_gifter_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot gift to yourself');
  END IF;

  -- Lock gifter.
  SELECT coins INTO v_gifter_coins
  FROM public.profiles WHERE id = p_gifter_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gifter not found');
  END IF;
  IF v_gifter_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_gifter_coins, 'cost', p_cost);
  END IF;

  -- Check recipient doesn't already own it.
  SELECT owned_avatar_parts INTO v_recipient_owned
  FROM public.account_state WHERE user_id = p_recipient_id;
  IF v_recipient_owned IS NOT NULL AND p_part_id = ANY(v_recipient_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient already owns this');
  END IF;

  -- Deduct from gifter.
  v_new_balance := v_gifter_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = p_gifter_id;

  -- Add to recipient.
  INSERT INTO public.account_state (user_id, owned_avatar_parts)
  VALUES (p_recipient_id, ARRAY[p_part_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_avatar_parts = array_append(
    COALESCE(account_state.owned_avatar_parts, '{}'), p_part_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'part_id', p_part_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_avatar_part(UUID, UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_avatar_part(UUID, UUID, TEXT, INT) TO service_role;


-- ---------------------------------------------------------------------------
-- 12. VIEWS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW leaderboard_global AS
SELECT s.user_id, p.username, p.level, p.avatar_url,
       s.score, s.time_ms, s.region, s.created_at,
       ROW_NUMBER() OVER (ORDER BY s.score DESC, s.time_ms ASC) as rank
FROM scores s
JOIN profiles p ON s.user_id = p.id
WHERE s.region = 'daily'
ORDER BY s.score DESC, s.time_ms ASC;

CREATE OR REPLACE VIEW leaderboard_daily AS
SELECT s.user_id, p.username, p.level, p.avatar_url,
       s.score, s.time_ms, s.region, s.created_at,
       ROW_NUMBER() OVER (ORDER BY s.score DESC, s.time_ms ASC) as rank
FROM scores s
JOIN profiles p ON s.user_id = p.id
WHERE s.created_at >= (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date
  AND s.region = 'daily'
ORDER BY s.score DESC, s.time_ms ASC;

CREATE OR REPLACE VIEW leaderboard_regional AS
SELECT s.user_id, p.username, p.level, p.avatar_url,
       s.score, s.time_ms, s.region, s.created_at,
       ROW_NUMBER() OVER (PARTITION BY s.region ORDER BY s.score DESC, s.time_ms ASC) as rank
FROM scores s
JOIN profiles p ON s.user_id = p.id
ORDER BY s.region, s.score DESC, s.time_ms ASC;

CREATE OR REPLACE VIEW daily_streak_leaderboard AS
SELECT
  a.user_id,
  p.username,
  COALESCE((a.daily_streak_data->>'current_streak')::int, 0) AS current_streak,
  COALESCE((a.daily_streak_data->>'longest_streak')::int, 0) AS longest_streak,
  COALESCE((a.daily_streak_data->>'total_completed')::int, 0) AS total_completed,
  a.daily_streak_data->>'last_completion_date' AS last_completion_date
FROM account_state a
JOIN profiles p ON p.id = a.user_id
WHERE (a.daily_streak_data->>'current_streak')::int > 0
ORDER BY current_streak DESC, longest_streak DESC
LIMIT 100;

-- Use SECURITY INVOKER so views respect the querying user's RLS policies
-- instead of bypassing them with the view creator's permissions.
-- Requires the underlying tables to have public SELECT policies (which they do).
ALTER VIEW leaderboard_global SET (security_invoker = on);
ALTER VIEW leaderboard_daily SET (security_invoker = on);
ALTER VIEW leaderboard_regional SET (security_invoker = on);
ALTER VIEW daily_streak_leaderboard SET (security_invoker = on);


-- ---------------------------------------------------------------------------
-- 13. DATA MIGRATIONS — rename legacy plane IDs
-- ---------------------------------------------------------------------------
-- Old trademarked plane names were renamed. This is a no-op on fresh DBs
-- (no rows exist yet), but ensures correctness if rebuild.sql is re-run
-- on a live DB without teardown.

UPDATE public.account_state
SET equipped_plane_id = 'plane_warbird'
WHERE equipped_plane_id = 'plane_spitfire';

UPDATE public.account_state
SET equipped_plane_id = 'plane_night_raider'
WHERE equipped_plane_id = 'plane_lancaster';

UPDATE public.account_state
SET equipped_plane_id = 'plane_presidential'
WHERE equipped_plane_id = 'plane_air_force_one';

UPDATE public.account_state
SET equipped_plane_id = 'plane_padraigaer'
WHERE equipped_plane_id = 'plane_bryanair';

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_spitfire', 'plane_warbird')
WHERE 'plane_spitfire' = ANY(owned_cosmetics);

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_lancaster', 'plane_night_raider')
WHERE 'plane_lancaster' = ANY(owned_cosmetics);

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_air_force_one', 'plane_presidential')
WHERE 'plane_air_force_one' = ANY(owned_cosmetics);

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_bryanair', 'plane_padraigaer')
WHERE 'plane_bryanair' = ANY(owned_cosmetics);


-- ---------------------------------------------------------------------------
-- 14. ECONOMY CONFIG — server-driven economy tuning
-- ---------------------------------------------------------------------------
-- Single-row table holding all economy parameters as JSONB.
-- The client reads this on startup (TTL-cached) to drive coin rewards,
-- shop pricing, and promotions. Admins update via RPC.

CREATE TABLE IF NOT EXISTS public.economy_config (
  id          INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  config      JSONB NOT NULL DEFAULT '{}',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.economy_config ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read the economy config.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'economy_config' AND policyname = 'Economy config is readable by all'
  ) THEN
    CREATE POLICY "Economy config is readable by all"
      ON public.economy_config FOR SELECT USING (true);
  END IF;
END $$;

-- Seed the default row if it doesn't exist.
INSERT INTO public.economy_config (id, config)
VALUES (1, '{}')
ON CONFLICT (id) DO NOTHING;

-- RPC: upsert economy config (owner-only, enforced by caller).
CREATE OR REPLACE FUNCTION public.upsert_economy_config(new_config JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.economy_config (id, config, updated_at)
  VALUES (1, new_config, NOW())
  ON CONFLICT (id) DO UPDATE SET config = new_config, updated_at = NOW();
END;
$$;

-- Free-flight daily cap tracking columns on account_state.
ALTER TABLE public.account_state
  ADD COLUMN IF NOT EXISTS free_flight_coins_today INT NOT NULL DEFAULT 0;
ALTER TABLE public.account_state
  ADD COLUMN IF NOT EXISTS free_flight_coin_date TEXT;


-- ---------------------------------------------------------------------------
-- 15. SEED ADMIN ROLES
-- ---------------------------------------------------------------------------
-- Promote existing accounts by email. The auth trigger handles new signups,
-- but this catches accounts created before admin_role existed.
--
-- To add a moderator, add their email to the second UPDATE below.
-- To add an owner, add their email to the first UPDATE.

UPDATE public.profiles
SET admin_role = 'owner'
WHERE id IN (
  SELECT id FROM auth.users WHERE email IN ('jamiebright1@gmail.com')
);

-- Moderators (add emails here as needed):
-- UPDATE public.profiles
-- SET admin_role = 'moderator'
-- WHERE id IN (
--   SELECT id FROM auth.users WHERE email IN ('someone@example.com')
-- );


-- ---------------------------------------------------------------------------
-- DONE
-- ---------------------------------------------------------------------------
-- Run supabase/verify.sql next to validate the schema is correct.
