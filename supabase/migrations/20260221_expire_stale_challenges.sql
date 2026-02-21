-- ---------------------------------------------------------------------------
-- Expire stale challenges
-- ---------------------------------------------------------------------------
-- Challenges stuck in 'pending' or 'in_progress' for more than 7 days are
-- automatically marked 'expired'. This prevents ghost challenges from
-- accumulating forever when one player abandons.
--
-- This function can be called by:
--   1. A pg_cron job (if enabled on the Supabase plan)
--   2. The Vercel health endpoint cron (every 3 days)
--   3. Manual invocation via: SELECT expire_stale_challenges();
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.expire_stale_challenges()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_count INT;
BEGIN
  UPDATE public.challenges
  SET status = 'expired',
      completed_at = NOW()
  WHERE status IN ('pending', 'in_progress')
    AND created_at < NOW() - INTERVAL '7 days';

  GET DIAGNOSTICS expired_count = ROW_COUNT;

  IF expired_count > 0 THEN
    RAISE LOG 'expire_stale_challenges: expired % challenges', expired_count;
  END IF;

  RETURN expired_count;
END;
$$;

-- Grant execute to authenticated users (needed if called from client, though
-- typically called server-side). The function is SECURITY DEFINER so it
-- bypasses RLS.
GRANT EXECUTE ON FUNCTION public.expire_stale_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_challenges() TO service_role;
