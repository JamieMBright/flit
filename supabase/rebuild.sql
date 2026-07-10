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

-- Drop orphaned/redundant policies from earlier manual migrations.
-- "Users can view own profile" is redundant with "Profiles are publicly readable".
-- "Admin can read/update" used hardcoded email instead of admin_role column.
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admin can update any profile" ON public.profiles;

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
  -- TODO: Move hardcoded owner email to environment variable or config table.
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

-- Admin role (added 2026-02-22, collaborator added 2026-03-01).
-- NULL = regular user, 'moderator' = limited admin,
-- 'collaborator' = trusted game-design partner, 'owner' = god mode.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS admin_role TEXT DEFAULT NULL
    CHECK (admin_role IS NULL OR admin_role IN ('moderator', 'collaborator', 'owner'));


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

-- Direct FK from scores → profiles so PostgREST can resolve the embedded
-- resource join `profiles(username, avatar_url, level)` without needing to
-- traverse through auth.users.  Safe to add alongside the existing FK to
-- auth.users — both point to the same UUID.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_scores_profiles'
      AND table_schema = 'public'
      AND table_name = 'scores'
  ) THEN
    ALTER TABLE public.scores
      ADD CONSTRAINT fk_scores_profiles
      FOREIGN KEY (user_id) REFERENCES public.profiles(id);
  END IF;
END $$;

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

-- Direct FKs from friendships → profiles so PostgREST can resolve embedded
-- resource joins (e.g. profiles!fk_friendships_requester_profiles) without
-- needing to traverse through auth.users.  Same pattern as fk_scores_profiles.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_friendships_requester_profiles'
      AND table_schema = 'public'
      AND table_name = 'friendships'
  ) THEN
    ALTER TABLE public.friendships
      ADD CONSTRAINT fk_friendships_requester_profiles
      FOREIGN KEY (requester_id) REFERENCES public.profiles(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_friendships_addressee_profiles'
      AND table_schema = 'public'
      AND table_name = 'friendships'
  ) THEN
    ALTER TABLE public.friendships
      ADD CONSTRAINT fk_friendships_addressee_profiles
      FOREIGN KEY (addressee_id) REFERENCES public.profiles(id);
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
  game_mode        TEXT NOT NULL DEFAULT 'flight'
                     CHECK (game_mode IN ('flight', 'quiz', 'recon', 'scramble')),
  quiz_category    TEXT,
  quiz_mode        TEXT,
  rounds           JSONB NOT NULL DEFAULT '[]',
  rounds_config    JSONB,
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

-- Coin-claim tracking (see migrations/20260705_challenge_coin_claims.sql).
-- Each player's coin share is claimed exactly once via claim_challenge_coins.
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS challenger_claimed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS challenged_claimed_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.claim_challenge_coins(p_challenge_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coins INT;
BEGIN
  UPDATE public.challenges
  SET challenger_claimed_at = NOW()
  WHERE id = p_challenge_id
    AND status = 'completed'
    AND challenger_id = auth.uid()
    AND challenger_claimed_at IS NULL
  RETURNING challenger_coins INTO v_coins;

  IF v_coins IS NOT NULL THEN
    RETURN v_coins;
  END IF;

  UPDATE public.challenges
  SET challenged_claimed_at = NOW()
  WHERE id = p_challenge_id
    AND status = 'completed'
    AND challenged_id = auth.uid()
    AND challenged_claimed_at IS NULL
  RETURNING challenged_coins INTO v_coins;

  RETURN COALESCE(v_coins, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_challenge_coins(UUID) TO authenticated;

-- Mode-agnostic columns (see migrations/20260705_challenge_modes.sql).
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS rounds_config JSONB;

-- Atomic round submission (see migrations/20260705_challenge_modes.sql).
-- Merges p_result into rounds[p_round_number - 1] under a row lock so two
-- players submitting concurrently can never drop each other's results.
CREATE OR REPLACE FUNCTION public.submit_challenge_round(
  p_challenge_id UUID,
  p_round_number INT,
  p_is_challenger BOOLEAN,
  p_result JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rounds JSONB;
  v_round JSONB;
  v_merged JSONB;
  v_idx INT;
BEGIN
  SELECT rounds INTO v_rounds
  FROM public.challenges
  WHERE id = p_challenge_id
    AND ((p_is_challenger AND challenger_id = auth.uid())
      OR (NOT p_is_challenger AND challenged_id = auth.uid()))
  FOR UPDATE;

  IF v_rounds IS NULL THEN
    RETURN FALSE;
  END IF;

  v_idx := p_round_number - 1;
  IF v_idx < 0 OR v_idx >= jsonb_array_length(v_rounds) THEN
    RETURN FALSE;
  END IF;

  v_round := v_rounds -> v_idx;
  v_merged := p_result;

  -- Shared round metadata: first submitter wins.
  IF v_round ? 'clue_type' THEN
    v_merged := v_merged - 'clue_type';
  END IF;
  IF v_round ? 'country_name' THEN
    v_merged := v_merged - 'country_name';
  END IF;

  v_rounds := jsonb_set(v_rounds, ARRAY[v_idx::text], v_round || v_merged);

  UPDATE public.challenges
  SET rounds = v_rounds,
      status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END
  WHERE id = p_challenge_id;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_challenge_round(UUID, INT, BOOLEAN, JSONB) TO authenticated;


-- ---------------------------------------------------------------------------
-- 7b. PLAYER_RATINGS — per-mode ELO ratings
-- (see migrations/20260705_player_ratings.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.player_ratings (
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_mode    TEXT NOT NULL,
  rating       INT NOT NULL DEFAULT 1000,
  games_played INT NOT NULL DEFAULT 0,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, game_mode)
);

CREATE INDEX IF NOT EXISTS idx_player_ratings_mode_rating
  ON public.player_ratings (game_mode, rating DESC);

ALTER TABLE public.player_ratings ENABLE ROW LEVEL SECURITY;

-- Public read; no write policies — writes happen only via SECURITY DEFINER RPC.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'player_ratings' AND policyname = 'Ratings are publicly readable'
  ) THEN
    CREATE POLICY "Ratings are publicly readable"
      ON public.player_ratings FOR SELECT USING (true);
  END IF;
END $$;

-- Idempotency marker for apply_challenge_rating.
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS rating_applied_at TIMESTAMPTZ;

-- Fetch (or cold-start) a player's rating row for a mode. Cold start mirrors
-- the client's Elo.coldStartRating: 1000 + level*50 + best_score/20, [800,2000].
CREATE OR REPLACE FUNCTION public._get_or_seed_rating(p_user_id UUID, p_game_mode TEXT)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rating INT;
  v_level INT;
  v_best INT;
BEGIN
  SELECT rating INTO v_rating
  FROM public.player_ratings
  WHERE user_id = p_user_id AND game_mode = p_game_mode;

  IF v_rating IS NOT NULL THEN
    RETURN v_rating;
  END IF;

  SELECT COALESCE(level, 1), COALESCE(best_score, 0)
  INTO v_level, v_best
  FROM public.profiles
  WHERE id = p_user_id;

  v_rating := LEAST(2000, GREATEST(800,
    1000 + COALESCE(v_level, 1) * 50 + COALESCE(v_best, 0) / 20));

  INSERT INTO public.player_ratings (user_id, game_mode, rating, games_played)
  VALUES (p_user_id, p_game_mode, v_rating, 0)
  ON CONFLICT (user_id, game_mode) DO NOTHING;

  SELECT rating INTO v_rating
  FROM public.player_ratings
  WHERE user_id = p_user_id AND game_mode = p_game_mode;

  RETURN v_rating;
END;
$$;

-- Apply the ELO rating change for a completed challenge (K = 32, draws 0.5).
-- Idempotent via rating_applied_at + row lock; callable by either participant.
CREATE OR REPLACE FUNCTION public.apply_challenge_rating(p_challenge_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenger UUID;
  v_challenged UUID;
  v_winner UUID;
  v_mode TEXT;
  v_r_challenger INT;
  v_r_challenged INT;
  v_score_challenger NUMERIC;
  v_expected NUMERIC;
  v_delta INT;
BEGIN
  SELECT challenger_id, challenged_id, winner_id, COALESCE(game_mode, 'flight')
  INTO v_challenger, v_challenged, v_winner, v_mode
  FROM public.challenges
  WHERE id = p_challenge_id
    AND status = 'completed'
    AND rating_applied_at IS NULL
    AND (challenger_id = auth.uid() OR challenged_id = auth.uid())
  FOR UPDATE;

  IF v_challenger IS NULL THEN
    RETURN FALSE;
  END IF;

  v_r_challenger := public._get_or_seed_rating(v_challenger, v_mode);
  v_r_challenged := public._get_or_seed_rating(v_challenged, v_mode);

  v_score_challenger := CASE
    WHEN v_winner = v_challenger THEN 1
    WHEN v_winner = v_challenged THEN 0
    ELSE 0.5
  END;

  v_expected := 1 / (1 + power(10, (v_r_challenged - v_r_challenger) / 400.0));
  v_delta := round(32 * (v_score_challenger - v_expected));

  UPDATE public.player_ratings
  SET rating = rating + v_delta,
      games_played = games_played + 1,
      updated_at = NOW()
  WHERE user_id = v_challenger AND game_mode = v_mode;

  UPDATE public.player_ratings
  SET rating = rating - v_delta,
      games_played = games_played + 1,
      updated_at = NOW()
  WHERE user_id = v_challenged AND game_mode = v_mode;

  UPDATE public.challenges
  SET rating_applied_at = NOW()
  WHERE id = p_challenge_id;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_challenge_rating(UUID) TO authenticated;


-- ---------------------------------------------------------------------------
-- 8. MATCHMAKING_POOL — async challengerless matchmaking
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.matchmaking_pool (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  region            TEXT NOT NULL DEFAULT 'world',
  game_mode         TEXT NOT NULL DEFAULT 'flight'
                      CHECK (game_mode IN ('flight', 'quiz', 'recon', 'scramble')),
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
    -- UPDATE: USING allows touching own rows or unmatched rows (so the matcher
    -- can mark an opponent's entry). WITH CHECK (true) permits the new row
    -- state after update (matched_at is now set, which would otherwise fail
    -- the implicit USING re-check on the new row).
    CREATE POLICY "Users can update own entries on match"
      ON public.matchmaking_pool FOR UPDATE
      USING (auth.uid() = user_id OR matched_at IS NULL)
      WITH CHECK (true);
    -- DELETE: owners can remove their own unmatched entries (cancel matchmaking).
    CREATE POLICY "Users can delete own unmatched entries"
      ON public.matchmaking_pool FOR DELETE
      USING (auth.uid() = user_id AND matched_at IS NULL);
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

-- Atomic pool claim (see migrations/20260705_challenge_modes.sql). The
-- matched_at IS NULL guard means two concurrent searchers race on the row
-- lock and only one claim succeeds. A second call by the same claimer with a
-- non-null p_challenge_id attaches the challenge id to the claimed row.
CREATE OR REPLACE FUNCTION public.match_pool_entry(
  p_entry_id UUID,
  p_challenge_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  UPDATE public.matchmaking_pool
  SET matched_at = COALESCE(matched_at, NOW()),
      matched_with = auth.uid(),
      challenge_id = COALESCE(p_challenge_id, challenge_id)
  WHERE id = p_entry_id
    AND user_id <> auth.uid()
    AND (matched_at IS NULL
      OR (matched_with = auth.uid() AND challenge_id IS NULL))
  RETURNING id INTO v_id;

  RETURN v_id IS NOT NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_pool_entry(UUID, UUID) TO authenticated;


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

-- Prevent stale writes from overwriting daily streak data
CREATE OR REPLACE FUNCTION protect_daily_streak_data()
RETURNS TRIGGER AS $$
DECLARE
  old_streak JSONB;
  new_streak JSONB;
  old_current INT;
  new_current INT;
  old_longest INT;
  new_longest INT;
  old_total INT;
  new_total INT;
  old_date TEXT;
  new_date TEXT;
BEGIN
  old_streak := COALESCE(OLD.daily_streak_data, '{}'::jsonb);
  new_streak := COALESCE(NEW.daily_streak_data, '{}'::jsonb);

  old_current := COALESCE((old_streak->>'current_streak')::int, 0);
  new_current := COALESCE((new_streak->>'current_streak')::int, 0);
  old_longest := COALESCE((old_streak->>'longest_streak')::int, 0);
  new_longest := COALESCE((new_streak->>'longest_streak')::int, 0);
  old_total   := COALESCE((old_streak->>'total_completed')::int, 0);
  new_total   := COALESCE((new_streak->>'total_completed')::int, 0);
  old_date    := old_streak->>'last_completion_date';
  new_date    := new_streak->>'last_completion_date';

  IF new_date IS NOT NULL AND old_date IS NOT NULL
     AND new_date <= old_date AND new_current < old_current THEN
    new_current := old_current;
  END IF;

  new_longest := GREATEST(old_longest, new_longest);
  new_total   := GREATEST(old_total, new_total);

  NEW.daily_streak_data := jsonb_build_object(
    'current_streak', new_current,
    'longest_streak', new_longest,
    'last_completion_date', COALESCE(new_date, old_date),
    'total_completed', new_total
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS protect_daily_streak ON account_state;
CREATE TRIGGER protect_daily_streak
  BEFORE UPDATE ON account_state
  FOR EACH ROW
  EXECUTE FUNCTION protect_daily_streak_data();


-- ---------------------------------------------------------------------------
-- 9. CONSTRAINTS
-- ---------------------------------------------------------------------------

-- Clean up legacy duplicate constraints from earlier migrations.
-- These were superseded by the canonical check_* / chk_* names below.
ALTER TABLE public.scores DROP CONSTRAINT IF EXISTS chk_score_range;
ALTER TABLE public.scores DROP CONSTRAINT IF EXISTS chk_time_range;
ALTER TABLE public.scores DROP CONSTRAINT IF EXISTS chk_rounds_range;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_coins_non_neg;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_level_positive;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_xp_non_negative;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_username_length;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_username_chars;

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


-- Admin: set another player's avatar config (bypasses RLS on account_state).
CREATE OR REPLACE FUNCTION public.admin_set_avatar(
  target_user_id UUID,
  p_avatar_config JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  -- Only owner or moderator can set avatar config.
  SELECT admin_role INTO v_caller_role
  FROM public.profiles WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('owner', 'moderator') THEN
    RAISE EXCEPTION 'Forbidden: must be owner or moderator';
  END IF;

  INSERT INTO public.account_state (user_id, avatar_config)
  VALUES (target_user_id, p_avatar_config)
  ON CONFLICT (user_id) DO UPDATE
  SET avatar_config = p_avatar_config,
      updated_at = NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_avatar(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_avatar(UUID, JSONB) TO service_role;


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
  IF p_role IS NOT NULL AND p_role NOT IN ('moderator', 'collaborator', 'owner') THEN
    RAISE EXCEPTION 'Invalid role: must be NULL, moderator, collaborator, or owner';
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

-- Per-player dedup: only each player's best score appears on the board.
-- Uses a subquery to pick the best score per user_id (highest score, fastest
-- time as tiebreaker), then ranks the deduplicated results.

CREATE OR REPLACE VIEW leaderboard_global AS
SELECT ranked.user_id, ranked.username, ranked.level, ranked.avatar_url,
       ranked.score, ranked.time_ms, ranked.region, ranked.created_at,
       ROW_NUMBER() OVER (ORDER BY ranked.score DESC, ranked.time_ms ASC) as rank
FROM (
  SELECT DISTINCT ON (s.user_id)
    s.user_id, p.username, p.level, p.avatar_url,
    s.score, s.time_ms, s.region, s.created_at
  FROM scores s
  JOIN profiles p ON s.user_id = p.id
  WHERE s.region = 'daily'
  ORDER BY s.user_id, s.score DESC, s.time_ms ASC
) ranked
ORDER BY ranked.score DESC, ranked.time_ms ASC;

CREATE OR REPLACE VIEW leaderboard_daily AS
SELECT ranked.user_id, ranked.username, ranked.level, ranked.avatar_url,
       ranked.score, ranked.time_ms, ranked.region, ranked.created_at,
       ROW_NUMBER() OVER (ORDER BY ranked.score DESC, ranked.time_ms ASC) as rank
FROM (
  SELECT DISTINCT ON (s.user_id)
    s.user_id, p.username, p.level, p.avatar_url,
    s.score, s.time_ms, s.region, s.created_at
  FROM scores s
  JOIN profiles p ON s.user_id = p.id
  WHERE s.created_at >= (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date
    AND s.region = 'daily'
  ORDER BY s.user_id, s.score DESC, s.time_ms ASC
) ranked
ORDER BY ranked.score DESC, ranked.time_ms ASC;

CREATE OR REPLACE VIEW leaderboard_regional AS
SELECT ranked.user_id, ranked.username, ranked.level, ranked.avatar_url,
       ranked.score, ranked.time_ms, ranked.region, ranked.created_at,
       ROW_NUMBER() OVER (PARTITION BY ranked.region ORDER BY ranked.score DESC, ranked.time_ms ASC) as rank
FROM (
  SELECT DISTINCT ON (s.user_id, s.region)
    s.user_id, p.username, p.level, p.avatar_url,
    s.score, s.time_ms, s.region, s.created_at
  FROM scores s
  JOIN profiles p ON s.user_id = p.id
  ORDER BY s.user_id, s.region, s.score DESC, s.time_ms ASC
) ranked
ORDER BY ranked.region, ranked.score DESC, ranked.time_ms ASC;

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
SET search_path = public
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

ALTER TABLE public.account_state
  ADD COLUMN IF NOT EXISTS flight_school_progress JSONB NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_account_flight_school_progress
  ON public.account_state USING gin (flight_school_progress);

-- H2H Flight School Challenges (best-of-3)
CREATE TABLE IF NOT EXISTS public.h2h_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenger_name text NOT NULL DEFAULT '',
  challenged_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenged_name text NOT NULL DEFAULT '',
  rounds jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed', 'declined', 'expired')),
  winner_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_h2h_challenges_challenger ON public.h2h_challenges (challenger_id);
CREATE INDEX IF NOT EXISTS idx_h2h_challenges_challenged ON public.h2h_challenges (challenged_id);
CREATE INDEX IF NOT EXISTS idx_h2h_challenges_status ON public.h2h_challenges (status);
CREATE INDEX IF NOT EXISTS idx_h2h_challenges_created ON public.h2h_challenges (created_at DESC);
ALTER TABLE public.h2h_challenges ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'h2h_challenges' AND policyname = 'h2h_challenges_select_own'
  ) THEN
    CREATE POLICY "h2h_challenges_select_own" ON public.h2h_challenges FOR SELECT
      USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'h2h_challenges' AND policyname = 'h2h_challenges_insert_own'
  ) THEN
    CREATE POLICY "h2h_challenges_insert_own" ON public.h2h_challenges FOR INSERT
      WITH CHECK (auth.uid() = challenger_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'h2h_challenges' AND policyname = 'h2h_challenges_update_own'
  ) THEN
    CREATE POLICY "h2h_challenges_update_own" ON public.h2h_challenges FOR UPDATE
      USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
  END IF;
END $$;

-- H2H coin-claim tracking (see migrations/20260705_h2h_coin_claims.sql).
-- Reward constants live client-side; the RPC returns TRUE exactly once per
-- player per completed challenge and the client credits the coins.
ALTER TABLE public.h2h_challenges
  ADD COLUMN IF NOT EXISTS challenger_claimed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS challenged_claimed_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.claim_h2h_coins(p_challenge_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_claimed BOOLEAN;
BEGIN
  UPDATE public.h2h_challenges
  SET challenger_claimed_at = NOW()
  WHERE id = p_challenge_id
    AND status = 'completed'
    AND challenger_id = auth.uid()
    AND challenger_claimed_at IS NULL
  RETURNING TRUE INTO v_claimed;

  IF v_claimed THEN
    RETURN TRUE;
  END IF;

  UPDATE public.h2h_challenges
  SET challenged_claimed_at = NOW()
  WHERE id = p_challenge_id
    AND status = 'completed'
    AND challenged_id = auth.uid()
    AND challenged_claimed_at IS NULL
  RETURNING TRUE INTO v_claimed;

  RETURN COALESCE(v_claimed, FALSE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_h2h_coins(UUID) TO authenticated;

-- Daily Flight Briefing scores
CREATE TABLE IF NOT EXISTS public.daily_briefing_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date_key text NOT NULL,
  score int NOT NULL DEFAULT 0,
  time_ms int NOT NULL DEFAULT 0,
  level_id text NOT NULL,
  category text NOT NULL,
  difficulty text NOT NULL,
  mode text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'daily_briefing_scores_user_date_unique'
      AND table_schema = 'public'
      AND table_name = 'daily_briefing_scores'
  ) THEN
    ALTER TABLE public.daily_briefing_scores
      ADD CONSTRAINT daily_briefing_scores_user_date_unique UNIQUE (user_id, date_key);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_daily_briefing_scores_date_score
  ON public.daily_briefing_scores (date_key, score DESC);
CREATE INDEX IF NOT EXISTS idx_daily_briefing_scores_user
  ON public.daily_briefing_scores (user_id, created_at DESC);
ALTER TABLE public.daily_briefing_scores ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'daily_briefing_scores' AND policyname = 'Anyone can read daily briefing scores'
  ) THEN
    CREATE POLICY "Anyone can read daily briefing scores" ON public.daily_briefing_scores
      FOR SELECT USING (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'daily_briefing_scores' AND policyname = 'Users can insert own daily briefing scores'
  ) THEN
    CREATE POLICY "Users can insert own daily briefing scores" ON public.daily_briefing_scores
      FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'daily_briefing_scores' AND policyname = 'Users can update own daily briefing scores'
  ) THEN
    CREATE POLICY "Users can update own daily briefing scores" ON public.daily_briefing_scores
      FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;


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
-- 16. ADMIN AUDIT LOG — tracks every admin/moderator action
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id     UUID NOT NULL REFERENCES auth.users(id),
  actor_role   TEXT NOT NULL,
  action       TEXT NOT NULL,
  target_id    UUID REFERENCES auth.users(id),
  details      JSONB NOT NULL DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON public.admin_audit_log (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON public.admin_audit_log (target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON public.admin_audit_log (action, created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'admin_audit_log' AND policyname = 'Owners can read all audit log'
  ) THEN
    CREATE POLICY "Owners can read all audit log"
      ON public.admin_audit_log FOR SELECT
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role = 'owner'
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'admin_audit_log' AND policyname = 'Moderators can read own audit entries'
  ) THEN
    CREATE POLICY "Moderators can read own audit entries"
      ON public.admin_audit_log FOR SELECT
      USING (actor_id = auth.uid() AND EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

-- Helper: log an admin action (called from other RPCs).
CREATE OR REPLACE FUNCTION public._log_admin_action(
  p_action TEXT,
  p_target_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RETURN; END IF;
  INSERT INTO admin_audit_log (actor_id, actor_role, action, target_id, details)
  VALUES (auth.uid(), v_role, p_action, p_target_id, p_details);
END;
$$;

GRANT EXECUTE ON FUNCTION public._log_admin_action(TEXT, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public._log_admin_action(TEXT, UUID, JSONB) TO service_role;


-- ---------------------------------------------------------------------------
-- 17. BAN SYSTEM — columns on profiles + RPCs
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS banned_at      TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ban_expires_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ban_reason     TEXT DEFAULT NULL;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS banned_by UUID DEFAULT NULL REFERENCES auth.users(id);
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS unban_reason TEXT DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_banned
  ON public.profiles (banned_at) WHERE banned_at IS NOT NULL;

-- Ban a user. Moderators: temp only (max 30d). Owners: any duration.
CREATE OR REPLACE FUNCTION public.admin_ban_user(
  target_user_id UUID,
  p_reason TEXT,
  p_duration_days INT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target_role TEXT;
  caller_id UUID;
BEGIN
  caller_id := auth.uid();
  SELECT admin_role INTO v_role FROM profiles WHERE id = caller_id;
  IF v_role IS NULL THEN RAISE EXCEPTION 'Permission denied: not an admin'; END IF;

  -- Moderators: temp-ban only, max 30 days
  IF v_role = 'moderator' THEN
    IF p_duration_days IS NULL THEN
      RAISE EXCEPTION 'Moderators cannot issue permanent bans';
    END IF;
    IF p_duration_days > 30 THEN
      RAISE EXCEPTION 'Moderator ban limit: max 30 days';
    END IF;
  END IF;

  -- Cannot ban other admins unless you are owner
  SELECT admin_role INTO v_target_role FROM profiles WHERE id = target_user_id;
  IF v_target_role IS NOT NULL AND v_role != 'owner' THEN
    RAISE EXCEPTION 'Only owners can ban other admins';
  END IF;

  UPDATE profiles SET
    banned_at = NOW(),
    ban_expires_at = CASE WHEN p_duration_days IS NOT NULL
                     THEN NOW() + (p_duration_days || ' days')::INTERVAL
                     ELSE NULL END,
    ban_reason = p_reason,
    banned_by = caller_id
  WHERE id = target_user_id;

  -- Audit log
  PERFORM _log_admin_action(
    'ban_user',
    target_user_id,
    jsonb_build_object('reason', p_reason, 'duration_days', p_duration_days)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_ban_user(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_ban_user(UUID, TEXT, INT) TO service_role;

-- Unban a user (owner only).
CREATE OR REPLACE FUNCTION public.admin_unban_user(
  target_user_id UUID,
  p_unban_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Only owners can lift bans'; END IF;

  UPDATE profiles SET
    banned_at = NULL,
    ban_expires_at = NULL,
    ban_reason = NULL,
    banned_by = NULL,
    unban_reason = p_unban_reason
  WHERE id = target_user_id;

  PERFORM _log_admin_action('unban_user', target_user_id, jsonb_build_object(
    'unban_reason', p_unban_reason
  ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_unban_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unban_user(UUID, TEXT) TO service_role;


-- ---------------------------------------------------------------------------
-- 18. PLAYER REPORTS — user-submitted reports for moderation
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.player_reports (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL,
  details       TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',
  reviewed_by   UUID REFERENCES auth.users(id),
  reviewed_at   TIMESTAMPTZ,
  action_taken  TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT no_self_report CHECK (reporter_id != reported_id)
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.player_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported ON public.player_reports (reported_id);

ALTER TABLE public.player_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Users can submit reports'
  ) THEN
    CREATE POLICY "Users can submit reports"
      ON public.player_reports FOR INSERT
      WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Users can read own reports'
  ) THEN
    CREATE POLICY "Users can read own reports"
      ON public.player_reports FOR SELECT
      USING (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Admins can read all reports'
  ) THEN
    CREATE POLICY "Admins can read all reports"
      ON public.player_reports FOR SELECT
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Admins can update reports'
  ) THEN
    CREATE POLICY "Admins can update reports"
      ON public.player_reports FOR UPDATE
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

-- Resolve a report (moderator + owner).
CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id BIGINT,
  p_status TEXT,
  p_action_taken TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target UUID;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  IF p_status NOT IN ('actioned', 'dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT reported_id INTO v_target FROM player_reports WHERE id = p_report_id;

  UPDATE player_reports SET
    status = p_status,
    reviewed_by = auth.uid(),
    reviewed_at = NOW(),
    action_taken = p_action_taken
  WHERE id = p_report_id;

  PERFORM _log_admin_action(
    'resolve_report',
    v_target,
    jsonb_build_object('report_id', p_report_id, 'status', p_status, 'action', p_action_taken)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_report(BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(BIGINT, TEXT, TEXT) TO service_role;


-- ---------------------------------------------------------------------------
-- 19. APP CONFIG — force update gate + maintenance mode
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.app_config (
  id                   INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  min_app_version      TEXT NOT NULL DEFAULT 'v1.0',
  recommended_version  TEXT NOT NULL DEFAULT 'v1.0',
  maintenance_mode     BOOLEAN NOT NULL DEFAULT FALSE,
  maintenance_message  TEXT DEFAULT NULL,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'app_config' AND policyname = 'Anyone can read app config'
  ) THEN
    CREATE POLICY "Anyone can read app config"
      ON public.app_config FOR SELECT USING (true);
  END IF;
END $$;

INSERT INTO public.app_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

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

  PERFORM _log_admin_action(
    'update_app_config',
    NULL,
    jsonb_build_object(
      'min_version', p_min_version,
      'recommended_version', p_recommended_version,
      'maintenance_mode', p_maintenance_mode
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_app_config(TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_config(TEXT, TEXT, BOOLEAN, TEXT) TO service_role;


-- ---------------------------------------------------------------------------
-- 20. ANNOUNCEMENTS — in-app messages to all players
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.announcements (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  type          TEXT NOT NULL DEFAULT 'info',
  priority      INT NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at     TIMESTAMPTZ DEFAULT NULL,
  expires_at    TIMESTAMPTZ DEFAULT NULL,
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'announcements' AND policyname = 'Anyone can read active announcements'
  ) THEN
    CREATE POLICY "Anyone can read active announcements"
      ON public.announcements FOR SELECT USING (
        is_active = TRUE
        AND (starts_at IS NULL OR starts_at <= NOW())
        AND (expires_at IS NULL OR expires_at > NOW())
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'announcements' AND policyname = 'Admins can read all announcements'
  ) THEN
    CREATE POLICY "Admins can read all announcements"
      ON public.announcements FOR SELECT
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_upsert_announcement(
  p_id BIGINT DEFAULT NULL,
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
    RETURNING announcements.id INTO v_id;
  ELSE
    INSERT INTO announcements (title, body, type, priority, is_active, starts_at, expires_at, created_by)
    VALUES (p_title, p_body, p_type, p_priority, p_is_active, p_starts_at, p_expires_at, auth.uid())
    RETURNING announcements.id INTO v_id;
  END IF;

  PERFORM _log_admin_action(
    CASE WHEN p_id IS NOT NULL THEN 'update_announcement' ELSE 'create_announcement' END,
    NULL,
    jsonb_build_object('announcement_id', v_id, 'title', p_title, 'type', p_type)
  );

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_announcement(BIGINT, TEXT, TEXT, TEXT, INT, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_announcement(BIGINT, TEXT, TEXT, TEXT, INT, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;


-- ---------------------------------------------------------------------------
-- 21. FEATURE FLAGS — remote kill switches
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.feature_flags (
  flag_key     TEXT PRIMARY KEY,
  enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  description  TEXT,
  updated_by   UUID REFERENCES auth.users(id),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'feature_flags' AND policyname = 'Anyone can read feature flags'
  ) THEN
    CREATE POLICY "Anyone can read feature flags"
      ON public.feature_flags FOR SELECT USING (true);
  END IF;
END $$;

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

  PERFORM _log_admin_action(
    'set_feature_flag',
    NULL,
    jsonb_build_object('flag_key', p_flag_key, 'enabled', p_enabled)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_feature_flag(TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_feature_flag(TEXT, BOOLEAN, TEXT) TO service_role;

-- Seed initial flags
INSERT INTO public.feature_flags (flag_key, enabled, description) VALUES
  ('matchmaking_enabled', true, 'Async H2H matchmaking'),
  ('ads_enabled', true, 'Show ads to free-tier users'),
  ('gifting_enabled', true, 'Player-to-player coin/cosmetic gifting'),
  ('daily_scramble_enabled', true, 'Daily challenge mode'),
  ('shop_enabled', true, 'In-app shop'),
  ('leaderboard_enabled', true, 'Public leaderboards')
ON CONFLICT (flag_key) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 22. ADMIN SEARCH — fuzzy user lookup for moderation
-- ---------------------------------------------------------------------------

-- pg_trgm may already be enabled; safe to re-run.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
  ON public.profiles USING gin (username gin_trgm_ops);

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
     OR p.id::TEXT = p_query
  ORDER BY
    CASE WHEN p.username ILIKE p_query THEN 0 ELSE 1 END,
    similarity(p.username, p_query) DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_search_users(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_users(TEXT, INT) TO service_role;


-- ---------------------------------------------------------------------------
-- 23. SUSPICIOUS ACTIVITY VIEW — anomaly detection
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW suspicious_activity AS
SELECT
  p.id,
  p.username,
  p.level,
  p.coins,
  p.games_played,
  p.banned_at,
  (SELECT COUNT(*) FROM scores s WHERE s.user_id = p.id
     AND s.created_at > NOW() - INTERVAL '24 hours') AS games_24h,
  (SELECT COALESCE(SUM(c.coin_amount), 0) FROM coin_activity c WHERE c.user_id = p.id
     AND c.coin_amount > 0 AND c.created_at > NOW() - INTERVAL '24 hours') AS coins_earned_24h,
  p.created_at
FROM profiles p
WHERE
  (SELECT COUNT(*) FROM scores s WHERE s.user_id = p.id
     AND s.created_at > NOW() - INTERVAL '24 hours') > 100
  OR (SELECT COALESCE(SUM(c.coin_amount), 0) FROM coin_activity c WHERE c.user_id = p.id
     AND c.coin_amount > 0 AND c.created_at > NOW() - INTERVAL '24 hours') > 1500
  OR p.best_score >= 99000;

ALTER VIEW suspicious_activity SET (security_invoker = on);


-- ────────────────────────────────────────────────────────────────
-- 24. GDPR Request Tracking
-- ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.gdpr_requests (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL,
  username TEXT,
  request_type TEXT NOT NULL CHECK (request_type IN ('export', 'delete')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES auth.users(id),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.gdpr_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'gdpr_requests' AND policyname = 'Admins can manage GDPR requests'
  ) THEN
    CREATE POLICY "Admins can manage GDPR requests"
      ON public.gdpr_requests FOR ALL
      USING ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;

-- RPC: admin_process_gdpr_request
CREATE OR REPLACE FUNCTION public.admin_process_gdpr_request(
  p_request_id BIGINT,
  p_status TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN
    RAISE EXCEPTION 'Only owners can process GDPR requests';
  END IF;

  UPDATE gdpr_requests SET
    status = p_status,
    completed_at = CASE WHEN p_status IN ('completed', 'failed') THEN NOW() ELSE NULL END,
    processed_by = auth.uid(),
    notes = COALESCE(p_notes, notes)
  WHERE id = p_request_id;

  PERFORM _log_admin_action('process_gdpr_request', (SELECT user_id FROM gdpr_requests WHERE id = p_request_id), jsonb_build_object('request_id', p_request_id, 'status', p_status));
END;
$$;


-- ────────────────────────────────────────────────────────────────
-- 25. Economy Health Dashboard RPC
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_economy_summary()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_result JSON;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Permission denied: not an admin';
  END IF;

  SELECT json_build_object(
    'total_coins', COALESCE(SUM(coins), 0),
    'avg_coins', COALESCE(ROUND(AVG(coins)::numeric, 1), 0),
    'median_coins', COALESCE((SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY coins) FROM profiles), 0),
    'max_coins', COALESCE(MAX(coins), 0),
    'total_players', COUNT(*),
    'players_with_coins', COUNT(*) FILTER (WHERE coins > 0)
  ) INTO v_result FROM profiles;

  RETURN v_result;
END;
$$;

-- ────────────────────────────────────────────────────────────────
-- 26. IAP Receipts (scaffolding)
-- ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.iap_receipts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- ON DELETE CASCADE so GDPR account deletion can remove auth.users
  -- without an FK violation once IAP starts writing receipts.
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  receipt_data TEXT,
  is_valid BOOLEAN DEFAULT FALSE,
  amount INT NOT NULL DEFAULT 0,
  currency TEXT DEFAULT 'gold',
  transaction_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.iap_receipts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'iap_receipts' AND policyname = 'Users read own receipts'
  ) THEN
    CREATE POLICY "Users read own receipts"
      ON public.iap_receipts FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;


DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'iap_receipts' AND policyname = 'Admins read all receipts'
  ) THEN
    CREATE POLICY "Admins read all receipts"
      ON public.iap_receipts FOR SELECT
      USING ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_iap_receipts_user ON public.iap_receipts (user_id);
CREATE INDEX IF NOT EXISTS idx_iap_receipts_created ON public.iap_receipts (created_at DESC);

-- ---------------------------------------------------------------------------
-- 18. CLUE_REPORTS — player-submitted clue corrections
-- ---------------------------------------------------------------------------
-- Allows players to report incorrect clues (flags, outlines, etc.).
-- Admins can review, resolve, or dismiss reports.

CREATE TABLE IF NOT EXISTS public.clue_reports (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  country_code  TEXT NOT NULL,
  country_name  TEXT NOT NULL,
  issue         TEXT NOT NULL,
  notes         TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',
  reviewed_by   UUID REFERENCES auth.users(id),
  reviewed_at   TIMESTAMPTZ,
  action_taken  TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clue_reports_status ON public.clue_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clue_reports_country ON public.clue_reports (country_code);

ALTER TABLE public.clue_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Users can submit clue reports'
  ) THEN
    CREATE POLICY "Users can submit clue reports"
      ON public.clue_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Users can read own clue reports'
  ) THEN
    CREATE POLICY "Users can read own clue reports"
      ON public.clue_reports FOR SELECT USING (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Admins can read all clue reports'
  ) THEN
    CREATE POLICY "Admins can read all clue reports"
      ON public.clue_reports FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Admins can update clue reports'
  ) THEN
    CREATE POLICY "Admins can update clue reports"
      ON public.clue_reports FOR UPDATE
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

-- Resolve a clue report (admin RPC).
CREATE OR REPLACE FUNCTION public.admin_resolve_clue_report(
  p_report_id BIGINT, p_status TEXT, p_action_taken TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  IF p_status NOT IN ('actioned', 'dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  UPDATE clue_reports SET
    status = p_status, reviewed_by = auth.uid(),
    reviewed_at = NOW(), action_taken = p_action_taken
  WHERE id = p_report_id;

  PERFORM _log_admin_action('resolve_clue_report', NULL,
    jsonb_build_object('report_id', p_report_id, 'status', p_status, 'action', p_action_taken));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_clue_report(BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_clue_report(BIGINT, TEXT, TEXT) TO service_role;


-- ---------------------------------------------------------------------------
-- 19. REMOTE_CONFIG — generic key/value store for admin-managed config
-- ---------------------------------------------------------------------------
-- Used by Flight School admin, Gold Management, and other admin screens
-- to persist JSONB configuration blobs keyed by a unique string.

CREATE TABLE IF NOT EXISTS public.remote_config (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.remote_config ENABLE ROW LEVEL SECURITY;

-- Anyone can read remote config (needed for client-side feature loading).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'remote_config' AND policyname = 'Anyone can read remote config'
  ) THEN
    CREATE POLICY "Anyone can read remote config"
      ON public.remote_config FOR SELECT USING (true);
  END IF;
END $$;

-- Only admins can write remote config.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'remote_config' AND policyname = 'Admins can write remote config'
  ) THEN
    CREATE POLICY "Admins can write remote config"
      ON public.remote_config FOR ALL
      USING ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 20. COIN_LEDGER — audit trail of admin gold operations
-- ---------------------------------------------------------------------------
-- Records every admin gift/remove/set gold operation for traceability.

CREATE TABLE IF NOT EXISTS public.coin_ledger (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount     INT NOT NULL,
  source     TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.coin_ledger ENABLE ROW LEVEL SECURITY;

-- Admins can read all ledger entries (needed for Gold Management audit log).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'coin_ledger' AND policyname = 'Admins can read coin ledger'
  ) THEN
    CREATE POLICY "Admins can read coin ledger"
      ON public.coin_ledger FOR SELECT
      USING ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;

-- Admins can insert ledger entries.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'coin_ledger' AND policyname = 'Admins can insert coin ledger'
  ) THEN
    CREATE POLICY "Admins can insert coin ledger"
      ON public.coin_ledger FOR INSERT
      WITH CHECK ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_coin_ledger_user ON public.coin_ledger (user_id);
CREATE INDEX IF NOT EXISTS idx_coin_ledger_created ON public.coin_ledger (created_at DESC);


-- ---------------------------------------------------------------------------
-- 21. DIFFICULTY CONFIG — upsert and recalibrate functions
-- ---------------------------------------------------------------------------
-- Stores per-country difficulty overrides and clue-type weights in
-- remote_config, then optionally recalibrates existing scores.

CREATE OR REPLACE FUNCTION public.upsert_difficulty_config(
  p_country_overrides JSONB,
  p_clue_weights JSONB
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  INSERT INTO remote_config (key, value, updated_at)
  VALUES (
    'difficulty_config',
    jsonb_build_object(
      'country_overrides', p_country_overrides,
      'clue_weights', p_clue_weights
    ),
    NOW()
  )
  ON CONFLICT (key) DO UPDATE SET
    value = jsonb_build_object(
      'country_overrides', p_country_overrides,
      'clue_weights', p_clue_weights
    ),
    updated_at = NOW();

  PERFORM _log_admin_action(
    'upsert_difficulty_config',
    NULL,
    jsonb_build_object(
      'country_count', jsonb_array_length(
        COALESCE((SELECT jsonb_agg(k) FROM jsonb_object_keys(p_country_overrides) AS k), '[]'::jsonb)
      ),
      'clue_weight_count', jsonb_array_length(
        COALESCE((SELECT jsonb_agg(k) FROM jsonb_object_keys(p_clue_weights) AS k), '[]'::jsonb)
      )
    )
  );
END;
$$;


-- Recalibrate existing scores using per-country difficulty multipliers.
-- Returns the number of scores processed.
--
-- NOTE: The scores table stores country info inside round_details JSONB,
-- not as a top-level column. This function logs the request and returns 0
-- as a placeholder — full recalibration logic should be implemented once
-- the round_details schema is finalized.
CREATE OR REPLACE FUNCTION public.recalibrate_scores(
  country_multipliers JSONB
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_count INT := 0;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  -- Placeholder: log the recalibration request.
  -- Full implementation will iterate round_details to apply multipliers.
  PERFORM _log_admin_action(
    'recalibrate_scores',
    NULL,
    jsonb_build_object(
      'country_count', (SELECT count(*) FROM jsonb_object_keys(country_multipliers)),
      'scores_updated', v_count
    )
  );

  RETURN v_count;
END;
$$;


-- ===========================================================================
-- SECURITY HARDENING (WAVE 3) — applied 2026-07-06
-- ---------------------------------------------------------------------------
-- The base schema above is the PRE-hardening definition. The block below is an
-- inline copy of supabase/migrations/20260706_security_hardening.sql (Sections
-- 1-7 ACTIVE; Section 8 left DEFERRED/commented, exactly as in the migration).
-- It is appended here so a FRESH rebuild produces the SAME hardened end-state
-- that production runs — without it, rebuild.sql would reintroduce the audited
-- vulnerabilities (client-supplied-id coin theft, self-privilege-escalation,
-- fail-open owner checks, unpinned RLS, and the EXECUTE-to-PUBLIC default).
-- Every statement is idempotent (CREATE OR REPLACE / IF (NOT) EXISTS / DROP
-- POLICY IF EXISTS / tolerant DO-block grants), so applying it after the base
-- schema is safe and order-independent within this file.
-- Keep this block in sync if the migration changes.
-- ===========================================================================

-- =============================================================================
-- Flit — Backend Security Hardening (WAVE 3)
-- =============================================================================
-- Source: launch-readiness security audit. Closes: privilege escalation /
-- infinite coins / self-unban, forgeable scores, coin-theft via caller-supplied
-- ids, unguarded economy config, ELO/inventory forgery, over-broad RLS, and the
-- Postgres "EXECUTE to PUBLIC" default that exposes every SECURITY DEFINER RPC
-- to anon/authenticated.
--
-- =============================================================================
--  !!! APPLY-HELD — DO NOT RUN THIS MIGRATION BEFORE THE CLIENT PR IS DEPLOYED
-- =============================================================================
-- This is a COORDINATED client + server change against a LIVE production DB.
-- Sections 1–7 are safe to apply ONLY AFTER the matching client PR has shipped
-- and rolled out, because the client must already:
--   * route score submission through submit_score() (with a direct-insert
--     fallback for the transition), and
--   * tolerate the auth.uid()-authoritative coin/economy RPCs.
-- The client PR is transition-safe on BOTH the un-hardened (today) and hardened
-- (post-apply) schema: every new RPC call feature-detects the function and
-- falls back to the current direct-write path when it is missing (42883 /
-- PGRST202). So the ORDER is mandatory:
--
--   (1) Ship the client PR (feature-detect + fallback everywhere).
--   (2) Confirm clients are updated (telemetry / store rollout complete).
--   (3) Apply THIS migration (sections 1–7).
--   (4) Review + optionally enable Section 8 (the final economy/inventory
--       LOCKDOWN) once you have confirmed every coin / xp / inventory write
--       path is routed through an RPC. Section 8 is intentionally left as a
--       commented, owner-reviewed block — running sections 1–7 does NOT apply
--       it.
--
-- Every statement is idempotent (CREATE OR REPLACE / IF (NOT) EXISTS guards),
-- so re-running is safe. Nothing here is destructive.
-- =============================================================================


-- =============================================================================
-- SECTION 1 (ACTIVE) — profiles: pin privileged columns on client UPDATE
-- -----------------------------------------------------------------------------
-- FINDING #1 (privilege escalation / self-unban): the profiles UPDATE policy is
-- USING(auth.uid()=id) with NO WITH CHECK, and protect_profile_stats() does not
-- guard admin_role or ban columns. A user can PATCH their own row to
-- admin_role='owner' or clear banned_at.
--
-- Fix: a BEFORE UPDATE trigger that force-pins the privileged identity/ban
-- columns to their OLD values on ANY write that does NOT come from a vetted
-- SECURITY DEFINER admin RPC. The three admin RPCs that legitimately mutate
-- these columns (admin_set_role / admin_ban_user / admin_unban_user) opt in by
-- setting a transaction-local session flag before their UPDATE; the trigger
-- honours that flag. A normal PostgREST client UPDATE never sets the flag, so
-- admin_role and every ban column become immutable from the client.
--
-- NOTE: coins / level / xp / best_score are NOT pinned here — they still flow
-- through the client's whole-row profile upsert today. Their server-authoritative
-- lockdown is Section 8 (deferred), enabled after the client routes all coin/xp
-- writes through RPCs. This section closes the SEVERE escalation + self-unban
-- holes immediately, with zero client impact (the client never writes these
-- columns).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Vetted admin RPCs set this transaction-local flag immediately before their
  -- UPDATE. Anything else (a raw client PATCH) leaves it unset and gets pinned.
  IF current_setting('app.allow_privileged_profile_write', true) = 'on' THEN
    RETURN NEW;
  END IF;

  -- Force privileged/security columns back to their stored values. A client can
  -- never escalate its role, ban/unban itself, or rewrite ban metadata.
  NEW.admin_role     := OLD.admin_role;
  NEW.banned_at      := OLD.banned_at;
  NEW.ban_expires_at := OLD.ban_expires_at;
  NEW.ban_reason     := OLD.ban_reason;
  NEW.banned_by      := OLD.banned_by;
  NEW.unban_reason   := OLD.unban_reason;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_privileged ON public.profiles;
CREATE TRIGGER trg_protect_profile_privileged
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privileged_columns();

-- Redefine the three admin RPCs that legitimately write the pinned columns so
-- they opt in to the bypass. Bodies are otherwise byte-for-byte identical to
-- rebuild.sql; only the `set_config(...)` line before the UPDATE is new.

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

  -- IS DISTINCT FROM correctly rejects NULL (non-admin) callers; a bare
  -- `v_role != 'owner'` evaluates to NULL for NULL v_role and FAILS OPEN.
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can manage roles';
  END IF;

  IF p_role IS NOT NULL AND p_role NOT IN ('moderator', 'collaborator', 'owner') THEN
    RAISE EXCEPTION 'Invalid role: must be NULL, moderator, collaborator, or owner';
  END IF;

  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;

  -- Opt in to the privileged-column bypass for this UPDATE only.
  PERFORM set_config('app.allow_privileged_profile_write', 'on', true);
  UPDATE public.profiles SET admin_role = p_role WHERE id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_ban_user(
  target_user_id UUID,
  p_reason TEXT,
  p_duration_days INT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target_role TEXT;
  caller_id UUID;
BEGIN
  caller_id := auth.uid();
  SELECT admin_role INTO v_role FROM profiles WHERE id = caller_id;
  IF v_role IS NULL THEN RAISE EXCEPTION 'Permission denied: not an admin'; END IF;

  IF v_role = 'moderator' THEN
    IF p_duration_days IS NULL THEN
      RAISE EXCEPTION 'Moderators cannot issue permanent bans';
    END IF;
    IF p_duration_days > 30 THEN
      RAISE EXCEPTION 'Moderator ban limit: max 30 days';
    END IF;
  END IF;

  SELECT admin_role INTO v_target_role FROM profiles WHERE id = target_user_id;
  IF v_target_role IS NOT NULL AND v_role != 'owner' THEN
    RAISE EXCEPTION 'Only owners can ban other admins';
  END IF;

  PERFORM set_config('app.allow_privileged_profile_write', 'on', true);
  UPDATE profiles SET
    banned_at = NOW(),
    ban_expires_at = CASE WHEN p_duration_days IS NOT NULL
                     THEN NOW() + (p_duration_days || ' days')::INTERVAL
                     ELSE NULL END,
    ban_reason = p_reason,
    banned_by = caller_id
  WHERE id = target_user_id;

  PERFORM _log_admin_action(
    'ban_user',
    target_user_id,
    jsonb_build_object('reason', p_reason, 'duration_days', p_duration_days)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_unban_user(
  target_user_id UUID,
  p_unban_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  -- IS DISTINCT FROM rejects NULL-role callers (bare != fails open on NULL).
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Only owners can lift bans'; END IF;

  PERFORM set_config('app.allow_privileged_profile_write', 'on', true);
  UPDATE profiles SET
    banned_at = NULL,
    ban_expires_at = NULL,
    ban_reason = NULL,
    banned_by = NULL,
    unban_reason = p_unban_reason
  WHERE id = target_user_id;

  PERFORM _log_admin_action('unban_user', target_user_id, jsonb_build_object(
    'unban_reason', p_unban_reason
  ));
END;
$$;


-- =============================================================================
-- SECTION 2 (ACTIVE) — coin RPCs: actor = auth.uid(), never a caller parameter
-- -----------------------------------------------------------------------------
-- FINDING #3 (coin theft): send_coins/purchase_*/gift_* trust the sender/user/
-- gifter id PARAMETER, so a JWT holder can spend from or credit any account.
--
-- Fix: force the acting account to auth.uid() and IGNORE the caller-supplied id.
-- Signatures are UNCHANGED (the id parameter is still accepted for wire
-- compatibility with today's clients — it is simply overridden), so existing
-- clients keep working before and after apply. Recipients (gifts/transfers) are
-- still taken from parameters, which is correct — you choose who to gift.
-- =============================================================================

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
  v_user_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_user_id ignored
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;

  SELECT coins INTO v_current_coins
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current_coins, 'cost', p_cost);
  END IF;

  SELECT owned_cosmetics INTO v_owned
  FROM public.account_state WHERE user_id = v_user_id;

  IF v_owned IS NOT NULL AND p_cosmetic_id = ANY(v_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already owned',
      'current_balance', v_current_coins);
  END IF;

  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_user_id;

  INSERT INTO public.account_state (user_id, owned_cosmetics)
  VALUES (v_user_id, ARRAY[p_cosmetic_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_cosmetics = array_append(
    COALESCE(account_state.owned_cosmetics, '{}'), p_cosmetic_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'cosmetic_id', p_cosmetic_id);
END;
$$;

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
  v_user_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_user_id ignored
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_part_id IS NULL OR p_part_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid part ID');
  END IF;

  SELECT coins INTO v_current_coins
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current_coins, 'cost', p_cost);
  END IF;

  SELECT owned_avatar_parts INTO v_owned
  FROM public.account_state WHERE user_id = v_user_id;

  IF v_owned IS NOT NULL AND p_part_id = ANY(v_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already owned',
      'current_balance', v_current_coins);
  END IF;

  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_user_id;

  INSERT INTO public.account_state (user_id, owned_avatar_parts)
  VALUES (v_user_id, ARRAY[p_part_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_avatar_parts = array_append(
    COALESCE(account_state.owned_avatar_parts, '{}'), p_part_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'part_id', p_part_id);
END;
$$;

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
  v_sender_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_sender_id ignored
  v_sender_coins INT;
  v_recipient_coins INT;
  v_sender_balance INT;
  v_sender_username TEXT;
  v_recipient_username TEXT;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;
  IF v_sender_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send coins to yourself');
  END IF;

  SELECT coins INTO v_sender_coins
  FROM public.profiles WHERE id = v_sender_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sender not found');
  END IF;
  IF v_sender_coins < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_sender_coins);
  END IF;

  SELECT coins INTO v_recipient_coins
  FROM public.profiles WHERE id = p_recipient_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient not found');
  END IF;

  v_sender_balance := v_sender_coins - p_amount;
  UPDATE public.profiles SET coins = v_sender_balance WHERE id = v_sender_id;
  UPDATE public.profiles SET coins = v_recipient_coins + p_amount WHERE id = p_recipient_id;

  SELECT username INTO v_sender_username FROM public.profiles WHERE id = v_sender_id;
  SELECT username INTO v_recipient_username FROM public.profiles WHERE id = p_recipient_id;

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (v_sender_id, COALESCE(NULLIF(v_sender_username, ''), v_sender_id::TEXT),
    -p_amount, 'gift_sent', v_sender_balance);

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (p_recipient_id, COALESCE(NULLIF(v_recipient_username, ''), p_recipient_id::TEXT),
    p_amount, 'gift_received', v_recipient_coins + p_amount);

  RETURN jsonb_build_object('success', true,
    'sender_balance', v_sender_balance, 'amount', p_amount);
END;
$$;

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
  v_gifter_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_gifter_id ignored
  v_gifter_coins INT;
  v_recipient_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_gifter_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;
  IF v_gifter_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot gift to yourself');
  END IF;

  SELECT coins INTO v_gifter_coins
  FROM public.profiles WHERE id = v_gifter_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gifter not found');
  END IF;
  IF v_gifter_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_gifter_coins, 'cost', p_cost);
  END IF;

  SELECT owned_cosmetics INTO v_recipient_owned
  FROM public.account_state WHERE user_id = p_recipient_id;
  IF v_recipient_owned IS NOT NULL AND p_cosmetic_id = ANY(v_recipient_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient already owns this');
  END IF;

  v_new_balance := v_gifter_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_gifter_id;

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
  v_gifter_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_gifter_id ignored
  v_gifter_coins INT;
  v_recipient_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_gifter_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_part_id IS NULL OR p_part_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid part ID');
  END IF;
  IF v_gifter_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot gift to yourself');
  END IF;

  SELECT coins INTO v_gifter_coins
  FROM public.profiles WHERE id = v_gifter_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gifter not found');
  END IF;
  IF v_gifter_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_gifter_coins, 'cost', p_cost);
  END IF;

  SELECT owned_avatar_parts INTO v_recipient_owned
  FROM public.account_state WHERE user_id = p_recipient_id;
  IF v_recipient_owned IS NOT NULL AND p_part_id = ANY(v_recipient_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient already owns this');
  END IF;

  v_new_balance := v_gifter_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_gifter_id;

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


-- =============================================================================
-- SECTION 3 (ACTIVE) — server-authoritative generic coin earn / spend RPCs
-- -----------------------------------------------------------------------------
-- FINDING #1/#3 (coin authority): today the client persists coins by writing
-- the whole profiles row (coins column) directly, so any balance is forgeable.
-- These RPCs give a legitimate, auth.uid()-scoped, audited path for generic
-- coin earn/spend so the client can stop writing coins directly and Section 8
-- can eventually pin the coins column.
--
--   * earn_coins:  credits the CALLER only, capped per call, logs coin_activity.
--     NOTE: the amount still originates client-side, so this is NOT a full
--     anti-inflation control — it bounds/audits/authenticates the credit. True
--     reward re-computation requires server-side game validation (out of scope;
--     tracked for a later wave).
--   * spend_coins: atomically checks the CALLER's balance server-side and
--     refuses to overspend / go negative — a real integrity gain over the
--     client-authoritative debit.
--
-- Both set the Section-1 privileged-write flag is NOT needed (coins is not a
-- pinned column yet); they set the Section-8 coin-write flag so they already
-- bypass the (future) coins pin the moment the owner enables it.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.earn_coins(
  p_amount INT,
  p_source TEXT DEFAULT 'coins_earned'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_username TEXT;
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;
  -- Sanity cap: no single legitimate reward approaches this. Blocks absurd grants.
  IF p_amount > 100000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount exceeds per-call cap');
  END IF;

  -- Forward-compat: bypass the (deferred) Section-8 coins pin when enabled.
  PERFORM set_config('app.allow_coin_write', 'on', true);

  UPDATE public.profiles
  SET coins = COALESCE(coins, 0) + p_amount
  WHERE id = v_user_id
  RETURNING coins, username INTO v_new_balance, v_username;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (v_user_id, COALESCE(NULLIF(v_username, ''), v_user_id::TEXT),
    p_amount, LEFT(COALESCE(NULLIF(TRIM(p_source), ''), 'coins_earned'), 64), v_new_balance);

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance);
END;
$$;

CREATE OR REPLACE FUNCTION public.spend_coins(
  p_amount INT,
  p_source TEXT DEFAULT 'coins_spent'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_username TEXT;
  v_current INT;
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  SELECT coins INTO v_current
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current);
  END IF;

  v_new_balance := v_current - p_amount;

  PERFORM set_config('app.allow_coin_write', 'on', true);
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_user_id
  RETURNING username INTO v_username;

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (v_user_id, COALESCE(NULLIF(v_username, ''), v_user_id::TEXT),
    -p_amount, LEFT(COALESCE(NULLIF(TRIM(p_source), ''), 'coins_spent'), 64), v_new_balance);

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance);
END;
$$;


-- =============================================================================
-- SECTION 4 (ACTIVE) — server-authoritative score submission
-- -----------------------------------------------------------------------------
-- FINDING #2 (forgeable scores): scores rows are inserted directly by the client
-- with only a CHECK(score 0..100000). Any JWT holder can insert a perfect score.
--
-- Fix: submit_score() forces user_id = auth.uid(), re-validates bounds
-- server-side, and inserts. The client prefers this RPC and falls back to the
-- (still-granted, for the transition) direct INSERT when the function is
-- missing. Dropping the client INSERT grant is Section 8 (deferred) — do it only
-- after every client is on the RPC path.
--
-- One-per-day-per-mode is intentionally NOT enforced here: `scores` is an
-- append-only leaderboard feed deduped to best-per-user by the leaderboard view,
-- and multiple plays per day are legitimate. (Left as a documented future rule.)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.submit_score(
  p_score INT,
  p_time_ms BIGINT,
  p_region TEXT,
  p_rounds_completed INT DEFAULT 0,
  p_round_emojis TEXT DEFAULT NULL,
  p_round_details JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_score INT;
  v_time_ms BIGINT;
  v_rounds INT;
  v_region TEXT;
  v_id BIGINT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Server-side bounds (mirror the table CHECK + client clamp; authoritative).
  v_score   := GREATEST(0, LEAST(COALESCE(p_score, 0), 100000));
  v_time_ms := GREATEST(1, LEAST(COALESCE(p_time_ms, 1), 3600000));
  v_rounds  := GREATEST(0, LEAST(COALESCE(p_rounds_completed, 0), 100000));
  v_region  := LEFT(COALESCE(NULLIF(TRIM(p_region), ''), 'world'), 64);

  INSERT INTO public.scores
    (user_id, score, time_ms, region, rounds_completed, round_emojis, round_details)
  VALUES
    (v_user_id, v_score, v_time_ms, v_region, v_rounds, p_round_emojis, p_round_details)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id,
    'score', v_score, 'region', v_region);
END;
$$;


-- =============================================================================
-- SECTION 5 (ACTIVE) — economy_config: owner-gate + lock down
-- -----------------------------------------------------------------------------
-- FINDING #4: upsert_economy_config is SECURITY DEFINER with NO admin check and
-- relies on the PUBLIC default EXECUTE grant, so ANY authenticated (or, pre-sweep,
-- anon) user can overwrite global coin rewards + shop pricing.
--
-- Fix: in-body owner check + explicit REVOKE from PUBLIC/anon and GRANT to
-- authenticated only (the owner is an authenticated JWT user; the body gates it).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.upsert_economy_config(new_config JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM public.profiles WHERE id = auth.uid();
  -- IS DISTINCT FROM rejects NULL-role callers; a bare `!= 'owner'` returns
  -- NULL for a normal (NULL admin_role) user and would FAIL OPEN.
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can edit the economy config';
  END IF;

  INSERT INTO public.economy_config (id, config, updated_at)
  VALUES (1, new_config, NOW())
  ON CONFLICT (id) DO UPDATE SET config = new_config, updated_at = NOW();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.upsert_economy_config(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.upsert_economy_config(JSONB) FROM anon;
GRANT  EXECUTE ON FUNCTION public.upsert_economy_config(JSONB) TO authenticated;


-- =============================================================================
-- SECTION 5b (ACTIVE) — close fail-open owner checks (privilege escalation)
-- -----------------------------------------------------------------------------
-- BONUS FINDING surfaced while verifying finding #1/#4: several owner-gated
-- SECURITY DEFINER functions guard with `IF v_role != 'owner' THEN RAISE`.
-- For a normal user, admin_role is NULL, so `NULL != 'owner'` evaluates to NULL
-- (NOT true) and the RAISE is SKIPPED — the function FAILS OPEN. Proven on a
-- scratch DB: a NULL-role user could grant roles to other users, unlock-all,
-- unban, toggle feature flags, and overwrite difficulty/economy config.
--
-- Fix: replace the guard with `IF v_role IS DISTINCT FROM 'owner'`, which is
-- TRUE for NULL. Bodies below are extracted VERBATIM from rebuild.sql; only the
-- guard line is changed (admin_set_role / admin_unban_user / upsert_economy_config
-- are fixed in Sections 1 & 5; admin_ban_user already NULL-guards separately).
-- =============================================================================

-- admin_unlock_all: fail-open guard -> IS DISTINCT FROM
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

  IF v_role IS DISTINCT FROM 'owner' THEN
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

-- admin_update_app_config: fail-open guard -> IS DISTINCT FROM
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
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  UPDATE app_config SET
    min_app_version = COALESCE(p_min_version, min_app_version),
    recommended_version = COALESCE(p_recommended_version, recommended_version),
    maintenance_mode = COALESCE(p_maintenance_mode, maintenance_mode),
    maintenance_message = COALESCE(p_maintenance_message, maintenance_message),
    updated_at = NOW()
  WHERE id = 1;

  PERFORM _log_admin_action(
    'update_app_config',
    NULL,
    jsonb_build_object(
      'min_version', p_min_version,
      'recommended_version', p_recommended_version,
      'maintenance_mode', p_maintenance_mode
    )
  );
END;
$$;

-- admin_set_feature_flag: fail-open guard -> IS DISTINCT FROM
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
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  INSERT INTO feature_flags (flag_key, enabled, description, updated_by, updated_at)
  VALUES (p_flag_key, p_enabled, p_description, auth.uid(), NOW())
  ON CONFLICT (flag_key) DO UPDATE SET
    enabled = EXCLUDED.enabled,
    description = COALESCE(EXCLUDED.description, feature_flags.description),
    updated_by = EXCLUDED.updated_by,
    updated_at = NOW();

  PERFORM _log_admin_action(
    'set_feature_flag',
    NULL,
    jsonb_build_object('flag_key', p_flag_key, 'enabled', p_enabled)
  );
END;
$$;

-- admin_process_gdpr_request: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.admin_process_gdpr_request(
  p_request_id BIGINT,
  p_status TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Only owners can process GDPR requests';
  END IF;

  UPDATE gdpr_requests SET
    status = p_status,
    completed_at = CASE WHEN p_status IN ('completed', 'failed') THEN NOW() ELSE NULL END,
    processed_by = auth.uid(),
    notes = COALESCE(p_notes, notes)
  WHERE id = p_request_id;

  PERFORM _log_admin_action('process_gdpr_request', (SELECT user_id FROM gdpr_requests WHERE id = p_request_id), jsonb_build_object('request_id', p_request_id, 'status', p_status));
END;
$$;

-- upsert_difficulty_config: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.upsert_difficulty_config(
  p_country_overrides JSONB,
  p_clue_weights JSONB
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  INSERT INTO remote_config (key, value, updated_at)
  VALUES (
    'difficulty_config',
    jsonb_build_object(
      'country_overrides', p_country_overrides,
      'clue_weights', p_clue_weights
    ),
    NOW()
  )
  ON CONFLICT (key) DO UPDATE SET
    value = jsonb_build_object(
      'country_overrides', p_country_overrides,
      'clue_weights', p_clue_weights
    ),
    updated_at = NOW();

  PERFORM _log_admin_action(
    'upsert_difficulty_config',
    NULL,
    jsonb_build_object(
      'country_count', jsonb_array_length(
        COALESCE((SELECT jsonb_agg(k) FROM jsonb_object_keys(p_country_overrides) AS k), '[]'::jsonb)
      ),
      'clue_weight_count', jsonb_array_length(
        COALESCE((SELECT jsonb_agg(k) FROM jsonb_object_keys(p_clue_weights) AS k), '[]'::jsonb)
      )
    )
  );
END;
$$;

-- recalibrate_scores: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.recalibrate_scores(
  country_multipliers JSONB
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_count INT := 0;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  -- Placeholder: log the recalibration request.
  -- Full implementation will iterate round_details to apply multipliers.
  PERFORM _log_admin_action(
    'recalibrate_scores',
    NULL,
    jsonb_build_object(
      'country_count', (SELECT count(*) FROM jsonb_object_keys(country_multipliers)),
      'scores_updated', v_count
    )
  );

  RETURN v_count;
END;
$$;



-- =============================================================================
-- SECTION 6 (ACTIVE) — RLS WITH CHECK tightening (identity/ownership pins)
-- -----------------------------------------------------------------------------
-- FINDING #5/#6: several UPDATE policies have USING but no WITH CHECK (or
-- WITH CHECK(true)), so the post-update row is unconstrained.
--
-- These ACTIVE pins add WITH CHECK clauses that keep a row OWNED BY / SCOPED TO
-- the caller after an update — they do NOT restrict which business columns
-- (winner_id, status, owned_cosmetics, …) can change, so they are safe for
-- today's clients. The stronger economy/result-column pins (winner_id + status
-- immutability, inventory anti-tamper) are Section 8 (deferred), gated on the
-- client routing all result/inventory writes through RPCs.
-- =============================================================================

-- challenges: post-update row must still belong to the caller as a participant.
DROP POLICY IF EXISTS "Players can update own challenges" ON public.challenges;
CREATE POLICY "Players can update own challenges"
  ON public.challenges FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challenged_id)
  WITH CHECK (auth.uid() = challenger_id OR auth.uid() = challenged_id);

-- h2h_challenges: same ownership pin.
DROP POLICY IF EXISTS "h2h_challenges_update_own" ON public.h2h_challenges;
CREATE POLICY "h2h_challenges_update_own"
  ON public.h2h_challenges FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challenged_id)
  WITH CHECK (auth.uid() = challenger_id OR auth.uid() = challenged_id);

-- account_state: post-update row must still be the caller's own row.
DROP POLICY IF EXISTS "Users can update own account state" ON public.account_state;
CREATE POLICY "Users can update own account state"
  ON public.account_state FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- matchmaking_pool: was WITH CHECK(true) — anyone could stamp any row into any
-- state. Constrain the post-update row to one the caller owns OR has claimed
-- as the matcher (matched_with = self). Preserves both legitimate client paths:
--   * updating your OWN entry to record the match (user_id = self), and
--   * claiming an opponent's unmatched entry (matched_with = self).
DROP POLICY IF EXISTS "Users can update own entries on match" ON public.matchmaking_pool;
CREATE POLICY "Users can update own entries on match"
  ON public.matchmaking_pool FOR UPDATE
  USING (auth.uid() = user_id OR matched_at IS NULL)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = matched_with);


-- =============================================================================
-- SECTION 7 (ACTIVE) — blanket EXECUTE lockdown + explicit re-grant allowlist
-- -----------------------------------------------------------------------------
-- FINDING #7: Postgres grants EXECUTE to PUBLIC by default, so EVERY function in
-- schema public (including all SECURITY DEFINER RPCs) is reachable by anon and
-- authenticated regardless of the explicit GRANTs in rebuild.sql/migrations.
--
-- Fix: revoke the PUBLIC + anon default, stop future functions inheriting it,
-- then GRANT EXECUTE back to `authenticated` for ONLY the functions clients
-- legitimately call. Internal helpers (_log_admin_action, _get_or_seed_rating)
-- and trigger functions are deliberately NOT re-granted — they run inside other
-- SECURITY DEFINER functions as the definer/owner and need no caller grant.
--
-- Every SECURITY DEFINER function on this list performs its own in-body auth
-- (auth.uid() ownership or admin_role check), so `authenticated` EXECUTE is safe;
-- the grant just makes the function reachable, the body decides who may act.
-- =============================================================================

-- 7a. Remove the default "everyone can execute" grant, now and for the future.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- (anon default is already empty; be explicit so future functions never leak.)

-- 7b. Re-grant EXECUTE to `authenticated` for the exact client/owner allowlist.
--     Tolerant by-name grant: for each allowlisted NAME, grant every existing
--     overload found in this database. This avoids aborting when a hardcoded
--     signature drifts from the deployed one (e.g. a param type differs) — a
--     name that doesn't exist is simply skipped. The function BODY still decides
--     who may act; this grant only makes the function reachable by authenticated.
DO $grant_allowlist$
DECLARE
  allow text[] := ARRAY[
    -- Coins / economy (self-scoped or owner-gated in body)
    'earn_coins','spend_coins','purchase_cosmetic','purchase_avatar_part',
    'send_coins','gift_cosmetic','gift_avatar_part','upsert_economy_config',
    'upsert_difficulty_config','recalibrate_scores','admin_economy_summary',
    -- Scores / gameplay results
    'submit_score',
    -- Challenges / H2H / matchmaking / ratings / claims
    'claim_challenge_coins','claim_h2h_coins','claim_daily_champion',
    'submit_challenge_round','apply_challenge_rating','apply_sortie_rating',
    'match_pool_entry','expire_stale_challenges',
    -- Social (block / unblock — self-scoped in body)
    'block_user','unblock_user',
    -- Admin panel (every one re-checks admin_role in body)
    'admin_increment_stat','admin_set_stat','admin_set_license','admin_set_avatar',
    'admin_set_role','admin_unlock_all','admin_ban_user','admin_unban_user',
    'admin_resolve_report','admin_resolve_clue_report','admin_update_app_config',
    'admin_upsert_announcement','admin_set_feature_flag','admin_search_users',
    'admin_upsert_country_alias','admin_delete_country_alias',
    'admin_upsert_border_display','admin_process_gdpr_request'
  ];
  r record;
  granted int := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(allow)
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
    granted := granted + 1;
  END LOOP;
  RAISE NOTICE 'Section 7: granted EXECUTE to authenticated on % function overloads', granted;
END $grant_allowlist$;

-- service_role: explicit GRANT ... TO service_role lines in rebuild.sql/migrations
-- are unaffected by the PUBLIC/anon revokes above (revoking PUBLIC does not touch
-- explicit role grants). No service_role re-grants are required here.


-- =============================================================================
-- SECTION 8 (DEFERRED — DO NOT UNCOMMENT UNTIL THE CLIENT ROUTES *EVERY* COIN /
--            XP / INVENTORY / RESULT WRITE THROUGH AN RPC)
-- -----------------------------------------------------------------------------
-- Running Sections 1–7 does NOT execute anything below. These are the FINAL
-- economy/inventory LOCKDOWNS. Each will BREAK the app if enabled before the
-- corresponding client write path is fully RPC-routed, because today the client
-- still writes these values directly (whole-row profile upsert, optimistic
-- account_state upsert, direct challenge result UPDATE, direct scores INSERT).
--
-- OWNER CHECKLIST before enabling each block:
--   [ ] 8a coins/xp pin  → confirm addCoins/spendCoins AND every direct coin-set
--                           site (refund reverts, resets, reconciles) route
--                           through earn_coins/spend_coins, and coins/level/xp/
--                           best_score are removed from the client profile upsert.
--   [ ] 8b inventory pin → confirm ALL owned_cosmetics / owned_avatar_parts /
--                           unlocked_regions / license_data writes route through
--                           purchase_*/gift_*/admin_* RPCs (no optimistic direct
--                           account_state array writes remain).
--   [ ] 8c result pin    → confirm winner_id + status are only ever written by
--                           submit_challenge_round / claim_* RPCs.
--   [ ] 8d scores insert → confirm 100% of clients use submit_score().
--
-- ---- 8a. Pin coins / level / xp / best_score to server-authoritative --------
-- Extends protect_profile_privileged_columns() (or add a companion trigger) to
-- also pin these unless app.allow_coin_write='on' (earn_coins/spend_coins set
-- it). Sketch:
--
--   CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns()
--   RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $fn$
--   BEGIN
--     IF current_setting('app.allow_privileged_profile_write', true) = 'on' THEN
--       RETURN NEW;
--     END IF;
--     NEW.admin_role := OLD.admin_role;
--     NEW.banned_at := OLD.banned_at; NEW.ban_expires_at := OLD.ban_expires_at;
--     NEW.ban_reason := OLD.ban_reason; NEW.banned_by := OLD.banned_by;
--     NEW.unban_reason := OLD.unban_reason;
--     -- Economy columns: only coin/xp RPCs may change them.
--     IF current_setting('app.allow_coin_write', true) <> 'on' THEN
--       NEW.coins := OLD.coins;
--     END IF;
--     RETURN NEW;
--   END; $fn$;
--   -- (level/xp/best_score already ratchet monotonically via protect_profile_stats;
--   --  add an equivalent RPC-gated pin here if you want them fully server-owned.)
--
-- ---- 8b. account_state inventory anti-tamper --------------------------------
-- A BEFORE UPDATE trigger on account_state pinning owned_cosmetics /
-- owned_avatar_parts / unlocked_regions / license_data to OLD unless a
-- purchase_*/gift_*/admin_* RPC set an app.allow_inventory_write flag. (Those
-- RPCs write via their own SECURITY DEFINER path today; add the flag when you
-- enable this.)
--
-- ---- 8c. challenges / h2h_challenges result pin -----------------------------
-- Add to the Section-6 WITH CHECK (or a trigger): winner_id and status may only
-- change to a valid transition, and only via submit_challenge_round / claim_*.
-- Simplest: revoke direct UPDATE of winner_id/status by pinning them in a
-- BEFORE UPDATE trigger unless an app.allow_result_write flag is set by the RPC.
--
-- ---- 8d. drop the direct client scores INSERT grant -------------------------
--   DROP POLICY IF EXISTS "Users can insert own scores" ON public.scores;
--   -- submit_score() (SECURITY DEFINER) becomes the ONLY insert path.
--
-- =============================================================================
-- END SECTION 8 (deferred)
-- =============================================================================


-- ---------------------------------------------------------------------------
-- DONE
-- ---------------------------------------------------------------------------
-- Run supabase/verify.sql next to validate the schema is correct.
