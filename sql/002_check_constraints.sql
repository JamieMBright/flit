-- 002_check_constraints.sql
-- Add server-side CHECK constraints to the Flit database
-- Purpose: Enforce data integrity at the database level for critical fields
-- This migration adds validation constraints that mirror client-side validation rules

-- Profiles table constraints

-- profiles.username: Length between 3 and 20 characters, alphanumeric + underscores
ALTER TABLE profiles
ADD CONSTRAINT check_username_length CHECK (
  LENGTH(username) >= 3 AND LENGTH(username) <= 20
);

ALTER TABLE profiles
ADD CONSTRAINT check_username_pattern CHECK (
  username ~ '^[a-zA-Z0-9_]+$'
);

-- profiles.level: Must be >= 1
ALTER TABLE profiles
ADD CONSTRAINT check_level_positive CHECK (
  level >= 1
);

-- profiles.xp: Must be >= 0
ALTER TABLE profiles
ADD CONSTRAINT check_xp_non_negative CHECK (
  xp >= 0
);

-- profiles.coins: Must be >= 0
ALTER TABLE profiles
ADD CONSTRAINT check_coins_non_negative CHECK (
  coins >= 0
);

-- Scores table constraints

-- scores.score: Between 0 and 100000
ALTER TABLE scores
ADD CONSTRAINT check_score_range CHECK (
  score >= 0 AND score <= 100000
);

-- scores.time_ms: Between 1 and 3599999 (>0 and <1 hour)
ALTER TABLE scores
ADD CONSTRAINT check_time_ms_range CHECK (
  time_ms >= 1 AND time_ms <= 3599999
);

-- scores.rounds_completed: Between 1 and 50
ALTER TABLE scores
ADD CONSTRAINT check_rounds_completed_range CHECK (
  rounds_completed >= 1 AND rounds_completed <= 50
);
