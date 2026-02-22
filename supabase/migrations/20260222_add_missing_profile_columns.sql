-- Migration: Add missing profile and account_state columns
-- Date: 2026-02-22
-- Description: Adds columns to profiles (clue-type stats, best_streak) and
--   account_state (equipped_title_id, daily_streak_data, last_daily_result)
--   that the Dart code already writes but were absent from the schema.
--   Without these columns, writes silently fail and data resets on refresh.

-- ---------------------------------------------------------------------------
-- 1. profiles — clue-type correctness counters and best streak
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'flags_correct'
  ) THEN
    ALTER TABLE public.profiles
      ADD COLUMN flags_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN capitals_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN outlines_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN borders_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN stats_correct INT NOT NULL DEFAULT 0,
      ADD COLUMN best_streak INT NOT NULL DEFAULT 0;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. account_state — equipped title, daily streak JSONB, last daily result
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'account_state' AND column_name = 'equipped_title_id'
  ) THEN
    ALTER TABLE public.account_state
      ADD COLUMN equipped_title_id TEXT,
      ADD COLUMN daily_streak_data JSONB NOT NULL DEFAULT '{}',
      ADD COLUMN last_daily_result JSONB NOT NULL DEFAULT '{}';
  END IF;
END $$;
