-- Mode-agnostic challenges + atomic round submission / pool matching.
--
-- 1. Widen the game_mode CHECK constraints on challenges and matchmaking_pool
--    so future modes ('recon', 'scramble', ...) can create challenges without
--    another schema change. Completion is already length-driven client-side.
-- 2. Add challenges.rounds_config JSONB — an optional per-round configuration
--    blob (level/category/difficulty/whatever a mode needs), round-tripped
--    opaquely by the client.
-- 3. submit_challenge_round(): atomic jsonb round merge under a row lock,
--    replacing the client's read-modify-write (which could drop the other
--    player's concurrent submission).
-- 4. match_pool_entry(): atomically claim a matchmaking pool row so two
--    searchers can never both match the same entry.
--
-- APPLIED TO PRODUCTION 2026-07-05.
-- The client feature-detects both RPCs and falls back to the previous
-- read-modify-write behaviour when they are missing.

-- --- 1. game_mode column + CHECK constraints ---------------------------------

-- game_mode did not previously exist on either table in production; add it
-- with the historical default so existing rows are labelled as flight games.
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS game_mode TEXT NOT NULL DEFAULT 'flight';

ALTER TABLE public.matchmaking_pool
  ADD COLUMN IF NOT EXISTS game_mode TEXT NOT NULL DEFAULT 'flight';

DO $$
DECLARE
  v_name TEXT;
BEGIN
  -- Drop whatever CHECK constraint currently guards challenges.game_mode
  -- (inline CHECKs get auto-generated names).
  FOR v_name IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'public'
      AND rel.relname = 'challenges'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%game_mode%'
  LOOP
    EXECUTE format('ALTER TABLE public.challenges DROP CONSTRAINT %I', v_name);
  END LOOP;

  FOR v_name IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'public'
      AND rel.relname = 'matchmaking_pool'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%game_mode%'
  LOOP
    EXECUTE format('ALTER TABLE public.matchmaking_pool DROP CONSTRAINT %I', v_name);
  END LOOP;
END $$;

ALTER TABLE public.challenges
  ADD CONSTRAINT challenges_game_mode_check
    CHECK (game_mode IN ('flight', 'quiz', 'recon', 'scramble'));

ALTER TABLE public.matchmaking_pool
  ADD CONSTRAINT matchmaking_pool_game_mode_check
    CHECK (game_mode IN ('flight', 'quiz', 'recon', 'scramble'));

-- --- 2. Per-round mode configuration ----------------------------------------

ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS rounds_config JSONB;

-- --- 3. Atomic round submission ----------------------------------------------

-- Merge p_result into rounds[p_round_number - 1] under a row lock. The caller
-- passes already-prefixed keys (challenger_*/challenged_*); shared metadata
-- (clue_type, country_name) is written first-submitter-wins. Also bumps
-- 'pending' to 'in_progress'. Returns FALSE when the challenge/round doesn't
-- exist or the caller isn't the claimed participant.
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

-- --- 4. Atomic pool claim ------------------------------------------------------

-- Claim an unmatched matchmaking pool entry for the calling user. The
-- matched_at IS NULL guard makes the claim atomic: two concurrent searchers
-- race on the row lock and only one UPDATE matches. A second call by the SAME
-- claimer with a non-null p_challenge_id attaches the challenge id to the
-- already-claimed row (the claim happens before the challenge row exists).
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
