-- Per-mode ELO ratings for H2H challenges.
--
-- player_ratings holds one row per (user, game_mode). Ratings are only ever
-- written by the SECURITY DEFINER apply_challenge_rating() RPC — clients have
-- read-only access. The RPC is idempotent per challenge via the new
-- challenges.rating_applied_at column, so either player (or both, racing)
-- can trigger it after completion and the rating moves exactly once.
--
-- Cold start: a player's first rating in a mode is seeded from their profile
-- (1000 + level * 50 + best_score / 20, clamped to [800, 2000]) — mirrors
-- MatchmakingService.estimateElo / Elo.coldStartRating on the client.
--
-- NOT APPLIED AUTOMATICALLY — apply manually to the production database.
-- Until applied, the client falls back to the estimated (provisional) rating
-- and the rating RPC call silently no-ops.

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

-- Public read (ratings are shown on matchmaking screens); no INSERT/UPDATE/
-- DELETE policies — writes happen only inside SECURITY DEFINER RPCs.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'player_ratings' AND policyname = 'Ratings are publicly readable'
  ) THEN
    CREATE POLICY "Ratings are publicly readable"
      ON public.player_ratings FOR SELECT USING (true);
  END IF;
END $$;

-- Idempotency marker: set once when a challenge's rating change is applied.
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS rating_applied_at TIMESTAMPTZ;

-- Fetch (or cold-start) a player's rating row for a mode and return the
-- current rating. Internal helper — not granted to clients directly.
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

  -- Cold start from profile stats, clamped to [800, 2000].
  SELECT COALESCE(level, 1), COALESCE(best_score, 0)
  INTO v_level, v_best
  FROM public.profiles
  WHERE id = p_user_id;

  v_rating := LEAST(2000, GREATEST(800,
    1000 + COALESCE(v_level, 1) * 50 + COALESCE(v_best, 0) / 20));

  INSERT INTO public.player_ratings (user_id, game_mode, rating, games_played)
  VALUES (p_user_id, p_game_mode, v_rating, 0)
  ON CONFLICT (user_id, game_mode) DO NOTHING;

  -- Re-read in case of a concurrent seed.
  SELECT rating INTO v_rating
  FROM public.player_ratings
  WHERE user_id = p_user_id AND game_mode = p_game_mode;

  RETURN v_rating;
END;
$$;

-- Apply the ELO rating change for a completed challenge. Standard Elo with
-- K = 32; draws count as 0.5. Idempotent: the row lock plus the
-- rating_applied_at guard ensure the update happens exactly once even when
-- both players call it concurrently. Callable by either participant.
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
  v_score_challenger NUMERIC;  -- 1 win, 0 loss, 0.5 draw
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
    RETURN FALSE;  -- Not found, not completed, not a participant, or already applied.
  END IF;

  v_r_challenger := public._get_or_seed_rating(v_challenger, v_mode);
  v_r_challenged := public._get_or_seed_rating(v_challenged, v_mode);

  v_score_challenger := CASE
    WHEN v_winner = v_challenger THEN 1
    WHEN v_winner = v_challenged THEN 0
    ELSE 0.5  -- NULL winner = draw.
  END;

  -- Expected score for the challenger; K = 32.
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
