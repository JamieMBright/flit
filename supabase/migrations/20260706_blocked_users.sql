-- Migration: Blocked Users
-- Date: 2026-07-06
-- Purpose: Let a user block another user (Apple Guideline 1.2 for UGC/social:
--          block + report are both required). A block hides the blocked user
--          from the blocker across friends, leaderboards and matchmaking.
-- Idempotent: safe to re-run (IF NOT EXISTS / CREATE OR REPLACE throughout).
--
-- NOTE: not yet applied to production — the app feature-detects this table and
-- degrades gracefully if it is absent.

BEGIN;

-- ===================================================================
-- BLOCKED USERS TABLE
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.blocked_users (
  blocker_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id),
  -- A user cannot block themselves.
  CONSTRAINT blocked_users_no_self CHECK (blocker_id <> blocked_id)
);

-- Fast lookup of "who has this user blocked" (blocker → list) and the reverse
-- direction used by server-side filtering follow-up ("who blocked me").
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker
  ON public.blocked_users (blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked
  ON public.blocked_users (blocked_id);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Users can read their OWN blocks (the rows where they are the blocker).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'blocked_users' AND policyname = 'Users read own blocks'
  ) THEN
    CREATE POLICY "Users read own blocks"
      ON public.blocked_users FOR SELECT
      USING (auth.uid() = blocker_id);
  END IF;
END $$;

-- Users can create blocks only as themselves (never as another user).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'blocked_users' AND policyname = 'Users create own blocks'
  ) THEN
    CREATE POLICY "Users create own blocks"
      ON public.blocked_users FOR INSERT
      WITH CHECK (auth.uid() = blocker_id);
  END IF;
END $$;

-- Users can delete (unblock) only their own blocks.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'blocked_users' AND policyname = 'Users delete own blocks'
  ) THEN
    CREATE POLICY "Users delete own blocks"
      ON public.blocked_users FOR DELETE
      USING (auth.uid() = blocker_id);
  END IF;
END $$;

-- ===================================================================
-- BLOCK / UNBLOCK RPCs
-- ===================================================================
-- The blocker is ALWAYS auth.uid() — never a client-supplied id — so a caller
-- can only ever create/remove blocks on their own behalf.

CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_blocked_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot block yourself';
  END IF;

  INSERT INTO public.blocked_users (blocker_id, blocked_id)
  VALUES (auth.uid(), p_blocked_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.blocked_users
  WHERE blocker_id = auth.uid() AND blocked_id = p_blocked_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.block_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_user(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.unblock_user(UUID) TO service_role;

COMMIT;
