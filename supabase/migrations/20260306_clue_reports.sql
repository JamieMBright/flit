-- Migration: Clue Reports
-- Date: 2026-03-06
-- Purpose: Allow players to report incorrect clues (flags, outlines, etc.)
-- Idempotent: safe to re-run (IF NOT EXISTS / CREATE OR REPLACE throughout)

BEGIN;

-- ===================================================================
-- CLUE REPORTS TABLE
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.clue_reports (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  country_code  TEXT NOT NULL,
  country_name  TEXT NOT NULL,
  issue         TEXT NOT NULL,
  notes         TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',
  reviewed_by   UUID REFERENCES auth.users(id),
  reviewed_at   TIMESTAMPTZ,
  action_taken  TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clue_reports_status ON public.clue_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clue_reports_country ON public.clue_reports (country_code);

ALTER TABLE public.clue_reports ENABLE ROW LEVEL SECURITY;

-- Users can submit clue reports
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Users can submit clue reports'
  ) THEN
    CREATE POLICY "Users can submit clue reports"
      ON public.clue_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;

-- Users can read their own clue reports
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Users can read own clue reports'
  ) THEN
    CREATE POLICY "Users can read own clue reports"
      ON public.clue_reports FOR SELECT USING (auth.uid() = reporter_id);
  END IF;
END $$;

-- Admins can read all clue reports
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Admins can read all clue reports'
  ) THEN
    CREATE POLICY "Admins can read all clue reports"
      ON public.clue_reports FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

-- Admins can update clue reports
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'clue_reports' AND policyname = 'Admins can update clue reports'
  ) THEN
    CREATE POLICY "Admins can update clue reports"
      ON public.clue_reports FOR UPDATE
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

-- ===================================================================
-- RESOLVE CLUE REPORT (admin RPC)
-- ===================================================================

CREATE OR REPLACE FUNCTION public.admin_resolve_clue_report(
  p_report_id BIGINT, p_status TEXT, p_action_taken TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  IF p_status NOT IN ('actioned', 'dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  UPDATE clue_reports SET
    status = p_status, reviewed_by = auth.uid(),
    reviewed_at = NOW(), action_taken = p_action_taken
  WHERE id = p_report_id;

  PERFORM _log_admin_action('resolve_clue_report', NULL,
    jsonb_build_object('report_id', p_report_id, 'status', p_status, 'action', p_action_taken));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_clue_report(BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_clue_report(BIGINT, TEXT, TEXT) TO service_role;

COMMIT;
