-- 002_check_constraints.sql
-- Add server-side CHECK constraints to the Flit database
-- Purpose: Enforce data integrity at the database level for critical fields
-- This migration adds validation constraints that mirror client-side validation rules
--
-- NOTE: Idempotent — safe to re-run (IF NOT EXISTS guards on all constraints).
-- The username constraints allow NULL (new users from auth trigger don't have
-- a username yet; it's set during onboarding).

-- Profiles table constraints

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_username_length') THEN
    ALTER TABLE profiles ADD CONSTRAINT check_username_length
      CHECK (username IS NULL OR (LENGTH(username) >= 3 AND LENGTH(username) <= 20));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_username_pattern') THEN
    ALTER TABLE profiles ADD CONSTRAINT check_username_pattern
      CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9_]+$');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_level_positive') THEN
    ALTER TABLE profiles ADD CONSTRAINT check_level_positive
      CHECK (level >= 1);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_xp_non_negative') THEN
    ALTER TABLE profiles ADD CONSTRAINT check_xp_non_negative
      CHECK (xp >= 0);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_coins_non_negative') THEN
    ALTER TABLE profiles ADD CONSTRAINT check_coins_non_negative
      CHECK (coins >= 0);
  END IF;
END $$;

-- Scores table constraints (only add if the base migration's chk_* don't exist)

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_score_range')
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_score') THEN
    ALTER TABLE scores ADD CONSTRAINT check_score_range
      CHECK (score >= 0 AND score <= 100000);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_time_ms_range')
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_time') THEN
    ALTER TABLE scores ADD CONSTRAINT check_time_ms_range
      CHECK (time_ms >= 1 AND time_ms <= 3599999);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_rounds_completed_range') THEN
    ALTER TABLE scores ADD CONSTRAINT check_rounds_completed_range
      CHECK (rounds_completed >= 1 AND rounds_completed <= 50);
  END IF;
END $$;
