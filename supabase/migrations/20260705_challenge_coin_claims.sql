-- Challenge coin rewards: atomic per-player claiming.
--
-- Bug this fixes: challenges.challenger_coins / challenged_coins are written
-- when a challenge completes, and the result screen shows "+N coins earned",
-- but the coins were NEVER credited to either player's balance. The client
-- (ChallengeResultScreen) now calls claim_challenge_coins() when a player
-- views the result of a completed challenge, then credits the returned
-- amount locally via the account provider.
--
-- The claimed_at columns guarantee each player's share is returned exactly
-- once, so re-opening the result screen (or opening it on a second device)
-- can never double-credit.
--
-- APPLIED TO PRODUCTION 2026-07-05.
-- Where not applied, the client claim call fails silently and behaviour is
-- unchanged (rewards stay display-only).

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
  -- Claim as challenger. The claimed_at IS NULL guard makes this atomic:
  -- concurrent calls race on the row lock and only one UPDATE matches.
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

  -- Claim as challenged player.
  UPDATE public.challenges
  SET challenged_claimed_at = NOW()
  WHERE id = p_challenge_id
    AND status = 'completed'
    AND challenged_id = auth.uid()
    AND challenged_claimed_at IS NULL
  RETURNING challenged_coins INTO v_coins;

  -- 0 = nothing to claim (already claimed, not a participant, or not
  -- completed). The client treats <= 0 as "do not credit".
  RETURN COALESCE(v_coins, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_challenge_coins(UUID) TO authenticated;
