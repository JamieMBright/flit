-- Migration: Friends and Challenges tables
-- Date: 2026-02-20
-- Description: Creates the friendships and challenges tables for the
--   friends system and dogfight (H2H) challenge mode.

-- ---------------------------------------------------------------------------
-- 1. friendships — friend connections between players
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
    -- Users can read friendships where they are either party.
    CREATE POLICY "Users can see own friendships"
      ON public.friendships FOR SELECT
      USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

    -- Users can send friend requests (they must be the requester).
    CREATE POLICY "Users can send friend requests"
      ON public.friendships FOR INSERT
      WITH CHECK (auth.uid() = requester_id);

    -- Users can update friendships where they are the addressee (accept/decline).
    CREATE POLICY "Addressee can respond to friend requests"
      ON public.friendships FOR UPDATE
      USING (auth.uid() = addressee_id);

    -- Either party can delete (unfriend).
    CREATE POLICY "Users can remove friendships"
      ON public.friendships FOR DELETE
      USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
  END IF;
END $$;

-- Auto-update updated_at.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_friendships_updated_at'
  ) THEN
    CREATE TRIGGER trg_friendships_updated_at
      BEFORE UPDATE ON public.friendships
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. challenges — H2H dogfight matches between two players
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
    -- Both players can read their challenges.
    CREATE POLICY "Players can see own challenges"
      ON public.challenges FOR SELECT
      USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);

    -- Challenger can create challenges.
    CREATE POLICY "Challenger can create challenges"
      ON public.challenges FOR INSERT
      WITH CHECK (auth.uid() = challenger_id);

    -- Both players can update their challenges (submit rounds, complete).
    CREATE POLICY "Players can update own challenges"
      ON public.challenges FOR UPDATE
      USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
  END IF;
END $$;
