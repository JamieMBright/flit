-- Migration: Country Aliases
-- Date: 2026-03-19
-- Purpose: Persist admin-managed country alias overrides and baseline removals
--          so they survive cache clears and sync across devices.
-- Idempotent: safe to re-run (IF NOT EXISTS / CREATE OR REPLACE throughout)

BEGIN;

-- ===================================================================
-- COUNTRY ALIASES TABLE
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.country_aliases (
  id             SERIAL PRIMARY KEY,
  canonical_name TEXT        NOT NULL,
  alias          TEXT        NOT NULL,
  is_removal     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prevent duplicate rows for the same (canonical_name, alias, is_removal) triple.
CREATE UNIQUE INDEX IF NOT EXISTS idx_country_aliases_unique
  ON public.country_aliases (canonical_name, alias, is_removal);

CREATE INDEX IF NOT EXISTS idx_country_aliases_canonical
  ON public.country_aliases (canonical_name);

ALTER TABLE public.country_aliases ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read aliases (needed for FuzzyMatcher on load).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'country_aliases' AND policyname = 'Authenticated users can read country aliases'
  ) THEN
    CREATE POLICY "Authenticated users can read country aliases"
      ON public.country_aliases FOR SELECT
      USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- Admins can insert aliases.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'country_aliases' AND policyname = 'Admins can insert country aliases'
  ) THEN
    CREATE POLICY "Admins can insert country aliases"
      ON public.country_aliases FOR INSERT
      WITH CHECK (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

-- Admins can delete aliases.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'country_aliases' AND policyname = 'Admins can delete country aliases'
  ) THEN
    CREATE POLICY "Admins can delete country aliases"
      ON public.country_aliases FOR DELETE
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

-- ===================================================================
-- ADMIN RPC: upsert a country alias or baseline removal
-- ===================================================================

CREATE OR REPLACE FUNCTION public.admin_upsert_country_alias(
  p_canonical_name TEXT,
  p_alias          TEXT,
  p_is_removal     BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;

  INSERT INTO country_aliases (canonical_name, alias, is_removal)
  VALUES (p_canonical_name, p_alias, p_is_removal)
  ON CONFLICT (canonical_name, alias, is_removal) DO NOTHING;

  PERFORM _log_admin_action('upsert_country_alias', NULL,
    jsonb_build_object(
      'canonical_name', p_canonical_name,
      'alias', p_alias,
      'is_removal', p_is_removal
    ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_country_alias(TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_country_alias(TEXT, TEXT, BOOLEAN) TO service_role;

-- ===================================================================
-- ADMIN RPC: delete a country alias or baseline removal
-- ===================================================================

CREATE OR REPLACE FUNCTION public.admin_delete_country_alias(
  p_canonical_name TEXT,
  p_alias          TEXT,
  p_is_removal     BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;

  DELETE FROM country_aliases
  WHERE canonical_name = p_canonical_name
    AND alias = p_alias
    AND is_removal = p_is_removal;

  PERFORM _log_admin_action('delete_country_alias', NULL,
    jsonb_build_object(
      'canonical_name', p_canonical_name,
      'alias', p_alias,
      'is_removal', p_is_removal
    ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_country_alias(TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_country_alias(TEXT, TEXT, BOOLEAN) TO service_role;

COMMIT;
