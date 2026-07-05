-- Daily champion rewards: the #1 finisher on each daily leaderboard
-- (Scramble, Recon, Briefing) always gets a consumable for that day.
--
-- Follows the claim_challenge_coins pattern (20260705_challenge_coin_claims):
-- an idempotent SECURITY DEFINER RPC the client calls on app open /
-- leaderboard view. The claims table's primary key guarantees each
-- (mode, day) board pays out exactly once, so re-opening the app or a
-- second device can never double-grant.
--
-- APPLIED TO PRODUCTION 2026-07-05.
-- Degrade path: the client (ChampionService.claimDailyChampion) wraps the
-- RPC in try/catch and treats ANY error — including "function does not
-- exist" before this migration ships — as "no reward", silently. Behaviour
-- without this migration is exactly the pre-feature behaviour.
--
-- Mode encoding matches the daily leaderboards, which all live in
-- public.scores keyed by region:
--   'daily'                -> Daily Scramble
--   'daily_triangulation'  -> Daily Recon
--   'briefing'             -> Daily Briefing (mirror rows of
--                             daily_briefing_scores; written on completion)
--
-- Reward is deterministic per (mode, day) — one of the three timed
-- consumables — so every client that asks agrees on what the champion won.

CREATE TABLE IF NOT EXISTS public.daily_champion_claims (
  game_mode      TEXT NOT NULL,
  challenge_date DATE NOT NULL,
  user_id        UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  reward         TEXT NOT NULL,
  claimed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- One payout per board per day, whoever wins the insert race.
  PRIMARY KEY (game_mode, challenge_date)
);

ALTER TABLE public.daily_champion_claims ENABLE ROW LEVEL SECURITY;

-- Players may read their own claims (e.g. a trophy history screen);
-- writes only happen through the SECURITY DEFINER RPC below.
DROP POLICY IF EXISTS "read own champion claims"
  ON public.daily_champion_claims;
CREATE POLICY "read own champion claims"
  ON public.daily_champion_claims FOR SELECT
  USING (auth.uid() = user_id);

-- Claim the champion reward for a closed daily board.
--
-- Returns the reward consumable id ('license_polish' | 'gold_surge' |
-- 'xp_surge') exactly once — when the caller topped that day's board and
-- the claim row was inserted by this call. Returns NULL in every other
-- case: already claimed, not the champion, board still open, bad mode.
CREATE OR REPLACE FUNCTION public.claim_daily_champion(
  p_game_mode TEXT,
  p_challenge_date DATE
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_champion UUID;
  v_reward TEXT;
  v_inserted BOOLEAN;
BEGIN
  IF v_caller IS NULL THEN
    RETURN NULL;
  END IF;

  -- Only the three daily boards pay champion rewards.
  IF p_game_mode NOT IN ('daily', 'daily_triangulation', 'briefing') THEN
    RETURN NULL;
  END IF;

  -- The board must be closed (a finished UTC day) — no claiming a lead
  -- while the day is still running.
  IF p_challenge_date >= (NOW() AT TIME ZONE 'utc')::date THEN
    RETURN NULL;
  END IF;

  -- The champion: best score that UTC day, ties broken by fastest time
  -- then earliest submission (same ordering the leaderboards display).
  SELECT s.user_id INTO v_champion
  FROM public.scores s
  WHERE s.region = p_game_mode
    AND s.created_at >= p_challenge_date::timestamptz
    AND s.created_at < (p_challenge_date + 1)::timestamptz
  ORDER BY s.score DESC, s.time_ms ASC, s.created_at ASC
  LIMIT 1;

  IF v_champion IS NULL OR v_champion <> v_caller THEN
    RETURN NULL;
  END IF;

  -- Deterministic reward per (mode, day): every client agrees on the item.
  v_reward := (ARRAY['license_polish', 'gold_surge', 'xp_surge'])[
    (ABS(HASHTEXT(p_game_mode || ':' || p_challenge_date::text)) % 3) + 1
  ];

  -- Atomic exactly-once: the PK on (game_mode, challenge_date) makes
  -- concurrent calls race on the insert; only one returns the reward.
  INSERT INTO public.daily_champion_claims
    (game_mode, challenge_date, user_id, reward)
  VALUES (p_game_mode, p_challenge_date, v_caller, v_reward)
  ON CONFLICT (game_mode, challenge_date) DO NOTHING
  RETURNING TRUE INTO v_inserted;

  IF v_inserted IS TRUE THEN
    RETURN v_reward;
  END IF;
  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_daily_champion(TEXT, DATE)
  TO authenticated;
