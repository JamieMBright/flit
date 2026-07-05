-- H2H (best-of-3 Flight School) coin rewards: atomic per-player claiming.
--
-- h2h_challenges has no coin columns — the reward constants live in the
-- client (H2HChallenge.winnerCoins etc.), so this RPC only gates the claim:
-- it returns TRUE exactly once per player per completed challenge, and the
-- client computes + credits the coin amount when it gets TRUE.
--
-- NOT APPLIED AUTOMATICALLY — apply manually to the production database.
-- Until applied, the client claim call fails silently and H2H rewards stay
-- display-only (previous behaviour).

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
  -- Claim as challenger. The claimed_at IS NULL guard makes this atomic:
  -- concurrent calls race on the row lock and only one UPDATE matches.
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

  -- Claim as challenged player.
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
