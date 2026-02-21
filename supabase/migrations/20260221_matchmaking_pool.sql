-- Migration: Matchmaking Pool table
-- Date: 2026-02-21
-- Description: Creates the matchmaking_pool table for async challengerless
--   matchmaking. Players submit completed rounds into a pool; the system
--   pairs them by ELO band and gameplay version.

-- ---------------------------------------------------------------------------
-- 1. matchmaking_pool — async matchmaking entries
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

-- Index for efficient pool searching: unmatched entries by region, ELO, version.
CREATE INDEX IF NOT EXISTS idx_matchmaking_unmatched
  ON public.matchmaking_pool (region, elo_rating, gameplay_version)
  WHERE matched_at IS NULL;

-- Index for looking up a user's own entries quickly.
CREATE INDEX IF NOT EXISTS idx_matchmaking_user
  ON public.matchmaking_pool (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 2. Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.matchmaking_pool ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'matchmaking_pool' AND policyname = 'Users can insert own entries'
  ) THEN
    -- Users can submit their own entries to the matchmaking pool.
    CREATE POLICY "Users can insert own entries"
      ON public.matchmaking_pool FOR INSERT
      WITH CHECK (auth.uid() = user_id);

    -- Users can read their own entries and entries they were matched with.
    CREATE POLICY "Users can read own or matched entries"
      ON public.matchmaking_pool FOR SELECT
      USING (auth.uid() = user_id OR auth.uid() = matched_with);

    -- Users can update own unmatched entries (for marking as matched).
    -- Also allow updating entries where the user is the matched_with target
    -- (the matching player needs to mark both entries).
    CREATE POLICY "Users can update own entries on match"
      ON public.matchmaking_pool FOR UPDATE
      USING (auth.uid() = user_id OR matched_at IS NULL);
  END IF;
END $$;
