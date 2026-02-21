-- Migration: Add owned_cosmetics column to account_state
-- Date: 2026-02-21
-- Description: Persists purchased shop cosmetics (planes, contrails, companions)
--   so they survive navigation and app restarts. Previously only equipped IDs
--   were stored — owned items were lost on every session.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'account_state'
      AND column_name = 'owned_cosmetics'
  ) THEN
    ALTER TABLE public.account_state
      ADD COLUMN owned_cosmetics TEXT[] NOT NULL DEFAULT '{}';
  END IF;
END $$;
