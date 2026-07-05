-- Standard Sortie: rated, seeded 5-round solo flight runs + ghost-duel Elo.
--
-- sortie_runs holds one row per completed run. Clients INSERT their own runs
-- (score bounds enforced by CHECK) and then call the SECURITY DEFINER
-- apply_sortie_rating() RPC, which resolves a "ghost duel": the run is
-- matched against a recent run by another pilot at a similar rating on the
-- standard format, and the caller's per-mode Elo ('sortie' in
-- player_ratings) moves as if it were a head-to-head — but ONE-SIDED: the
-- ghost's rating never moves (it isn't their game).
--
-- Idempotency mirrors apply_challenge_rating (20260705_player_ratings.sql):
-- the row lock plus the rating_applied_at guard mean the rating moves
-- exactly once per run, no matter how many times the RPC is called.
--
-- Rated play is boost-normalized client-side (standard loadout — see
-- lib/game/economy/rated_loadout.dart): money never buys rating.
--
-- Depends on: 20260705_player_ratings.sql (player_ratings table +
-- _get_or_seed_rating helper), already APPLIED TO PRODUCTION 2026-07-05.
--
-- APPLIED TO PRODUCTION 2026-07-05. Where not applied, the client degrades
-- silently: runs are kept locally/in the scores table, ratings show as
-- provisional, and the insert/RPC calls no-op (see sortie_service.dart).

CREATE TABLE IF NOT EXISTS public.sortie_runs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Denormalized display name (same pattern as challenges.challenger_name).
  player_name       TEXT NOT NULL DEFAULT '',
  -- Per-round seeds ([int x5]) — the run is reproducible/comparable.
  seeds             JSONB NOT NULL,
  -- Per-round details (country, time, score, hints) for breakdowns.
  rounds            JSONB,
  score             INT NOT NULL CHECK (score >= 0 AND score <= 50000),
  time_ms           INT NOT NULL DEFAULT 0 CHECK (time_ms >= 0),
  -- Player's 'sortie' rating at submission (stamped by the RPC; used to
  -- pick rating-comparable ghosts for future duels).
  rating            INT,
  ghost_run_id      UUID REFERENCES public.sortie_runs(id),
  ghost_user_id     UUID,
  rating_delta      INT,
  -- Idempotency marker: set once when this run's rating change is applied.
  rating_applied_at TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sortie_runs_leaderboard
  ON public.sortie_runs (score DESC, time_ms ASC);

-- Ghost pick: recent runs at a similar rating.
CREATE INDEX IF NOT EXISTS idx_sortie_runs_ghost_pick
  ON public.sortie_runs (rating, created_at DESC)
  WHERE rating IS NOT NULL;

ALTER TABLE public.sortie_runs ENABLE ROW LEVEL SECURITY;

-- Public read (leaderboards + ghost display); INSERT own rows only.
-- No UPDATE/DELETE policies — rating fields are written only inside the
-- SECURITY DEFINER RPC.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sortie_runs' AND policyname = 'Sortie runs are publicly readable'
  ) THEN
    CREATE POLICY "Sortie runs are publicly readable"
      ON public.sortie_runs FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sortie_runs' AND policyname = 'Players insert own sortie runs'
  ) THEN
    CREATE POLICY "Players insert own sortie runs"
      ON public.sortie_runs FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Resolve the ghost duel for a run and apply the one-sided Elo change.
--
-- Ghost selection: the most recent run by ANOTHER pilot within +/-400
-- rating of the caller, from the last 14 days. When no such run exists
-- (cold-start after the production reset), the run duels the "house ghost"
-- — a fixed par score at rating 1000 — so the ladder moves from day one.
--
-- Elo: standard, K = 32, draws 0.5 — identical math to
-- apply_challenge_rating and the client Elo class (keep all three in sync).
-- ONE-SIDED: only the caller's rating moves; the ghost isn't playing.
--
-- Returns JSONB:
--   {applied: bool, delta: int, new_rating: int,
--    ghost_name: text|null, ghost_score: int, player_score: int}
-- applied=false when the run is missing, not the caller's, or already rated.
CREATE OR REPLACE FUNCTION public.apply_sortie_rating(p_run_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID;
  v_score INT;
  v_rating INT;
  v_ghost_id UUID;
  v_ghost_user UUID;
  v_ghost_name TEXT;
  v_ghost_score INT;
  v_ghost_rating INT;
  v_s NUMERIC;         -- 1 win, 0 loss, 0.5 draw
  v_expected NUMERIC;
  v_delta INT;
BEGIN
  SELECT user_id, score INTO v_user, v_score
  FROM public.sortie_runs
  WHERE id = p_run_id
    AND user_id = auth.uid()
    AND rating_applied_at IS NULL
  FOR UPDATE;

  IF v_user IS NULL THEN
    RETURN jsonb_build_object('applied', false);
  END IF;

  v_rating := public._get_or_seed_rating(v_user, 'sortie');

  -- Pick a ghost: most recent rating-comparable run by another pilot.
  SELECT r.id, r.user_id, r.player_name, r.score, r.rating
  INTO v_ghost_id, v_ghost_user, v_ghost_name, v_ghost_score, v_ghost_rating
  FROM public.sortie_runs r
  WHERE r.user_id <> v_user
    AND r.id <> p_run_id
    AND r.rating IS NOT NULL
    AND r.rating BETWEEN v_rating - 400 AND v_rating + 400
    AND r.created_at > NOW() - INTERVAL '14 days'
  ORDER BY r.created_at DESC
  LIMIT 1;

  IF v_ghost_id IS NULL THEN
    -- House ghost: fixed par at the base rating (cold-start ladder mover).
    v_ghost_name := NULL;
    v_ghost_score := 20000;  -- 40% of the 50k max: beatable but honest par.
    v_ghost_rating := 1000;
  END IF;

  v_s := CASE
    WHEN v_score > v_ghost_score THEN 1
    WHEN v_score < v_ghost_score THEN 0
    ELSE 0.5
  END;

  -- Expected score for the player; K = 32. One-sided update.
  v_expected := 1 / (1 + power(10, (v_ghost_rating - v_rating) / 400.0));
  v_delta := round(32 * (v_s - v_expected));

  UPDATE public.player_ratings
  SET rating = rating + v_delta,
      games_played = games_played + 1,
      updated_at = NOW()
  WHERE user_id = v_user AND game_mode = 'sortie';

  UPDATE public.sortie_runs
  SET rating = v_rating,
      ghost_run_id = v_ghost_id,
      ghost_user_id = v_ghost_user,
      rating_delta = v_delta,
      rating_applied_at = NOW()
  WHERE id = p_run_id;

  RETURN jsonb_build_object(
    'applied', true,
    'delta', v_delta,
    'new_rating', v_rating + v_delta,
    'ghost_name', v_ghost_name,
    'ghost_score', v_ghost_score,
    'player_score', v_score
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_sortie_rating(UUID) TO authenticated;
