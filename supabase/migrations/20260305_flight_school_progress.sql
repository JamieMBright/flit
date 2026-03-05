-- Add flight_school_progress JSONB column to account_state.
-- Stores per-level progress: best_score, best_time_ms, completions, attempts.
-- Example: {"us_states": {"best_score": 45000, "best_time_ms": 120000, "completions": 5, "attempts": 8}}

ALTER TABLE public.account_state
  ADD COLUMN IF NOT EXISTS flight_school_progress JSONB NOT NULL DEFAULT '{}';

-- Index for querying players with progress on specific levels
CREATE INDEX IF NOT EXISTS idx_account_flight_school_progress
  ON public.account_state USING gin (flight_school_progress);
