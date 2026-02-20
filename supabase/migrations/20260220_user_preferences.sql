-- Migration: Add user preferences tables (user_settings, account_state, scores)
-- Date: 2026-02-20
-- Description: Creates the persistence layer for user preferences, account
--   state, and game scores. The profiles table already exists and is extended
--   with stat columns via ALTER.

-- ---------------------------------------------------------------------------
-- 1. Ensure profiles has identity columns (created by auth trigger, but
--    added idempotently here for safety on fresh deploys)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- 2. Extend profiles with gameplay stat columns (if not already present)
-- ---------------------------------------------------------------------------

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
      ADD COLUMN countries_found INT NOT NULL DEFAULT 0,
      ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. user_settings — per-user game settings
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
-- 3. account_state — avatar, license, cosmetics, daily state
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

-- ---------------------------------------------------------------------------
-- 4. scores — individual game results (leaderboard source)
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
-- 5. Auto-update updated_at triggers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_profiles_updated_at'
  ) THEN
    CREATE TRIGGER trg_profiles_updated_at
      BEFORE UPDATE ON public.profiles
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_user_settings_updated_at'
  ) THEN
    CREATE TRIGGER trg_user_settings_updated_at
      BEFORE UPDATE ON public.user_settings
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_account_state_updated_at'
  ) THEN
    CREATE TRIGGER trg_account_state_updated_at
      BEFORE UPDATE ON public.account_state
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 6. Constraints
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_score'
  ) THEN
    ALTER TABLE public.scores ADD CONSTRAINT chk_score
      CHECK (score >= 0 AND score <= 100000);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_time'
  ) THEN
    ALTER TABLE public.scores ADD CONSTRAINT chk_time
      CHECK (time_ms > 0 AND time_ms < 3600000);
  END IF;
END $$;
