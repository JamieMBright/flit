-- Migration: Allow admin/anon reads on matchmaking_pool for stats
-- Date: 2026-02-22
-- Description: Adds an RLS policy that allows anyone to SELECT from
--   matchmaking_pool for aggregate counting (pool size in admin stats).
--   The existing policies restrict SELECT to own/matched entries only,
--   which blocks the admin stats endpoint and Flutter admin panel.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'matchmaking_pool'
    AND policyname = 'Allow pool size counting for stats'
  ) THEN
    CREATE POLICY "Allow pool size counting for stats"
      ON public.matchmaking_pool FOR SELECT
      USING (true);
  END IF;
END $$;
