-- 003_fix_matchmaking_rls.sql
-- Fix matchmaking_pool RLS policies for proper cross-user matching and entry cancellation
--
-- Fixes:
-- 1. UPDATE policy: Add explicit WITH CHECK (true) so the matcher can set
--    matched_at on an opponent's entry without the new row failing the
--    implicit USING re-check.
-- 2. DELETE policy: Allow users to delete their own unmatched entries
--    (cancel matchmaking).
--
-- NOTE: Idempotent — safe to re-run.

-- Fix the UPDATE policy: drop the old one and recreate with WITH CHECK.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'matchmaking_pool'
    AND policyname = 'Users can update own entries on match'
  ) THEN
    DROP POLICY "Users can update own entries on match" ON public.matchmaking_pool;
  END IF;

  CREATE POLICY "Users can update own entries on match"
    ON public.matchmaking_pool FOR UPDATE
    USING (auth.uid() = user_id OR matched_at IS NULL)
    WITH CHECK (true);
END $$;

-- Add DELETE policy for cancellation.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'matchmaking_pool'
    AND policyname = 'Users can delete own unmatched entries'
  ) THEN
    CREATE POLICY "Users can delete own unmatched entries"
      ON public.matchmaking_pool FOR DELETE
      USING (auth.uid() = user_id AND matched_at IS NULL);
  END IF;
END $$;
