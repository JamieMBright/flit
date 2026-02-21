-- Daily streak tracking: stored inside account_state JSONB column
-- No new table needed — daily_streak_data and last_daily_result are
-- stored as JSONB keys within the existing account_state.user_id row.
--
-- Schema for the JSONB keys:
--
-- daily_streak_data: {
--   "current_streak": integer,
--   "longest_streak": integer,
--   "last_completion_date": "YYYY-MM-DD" or null,
--   "total_completed": integer
-- }
--
-- last_daily_result: {
--   "date": "YYYY-MM-DD",
--   "rounds": [
--     {
--       "hints_used": integer (0-4),
--       "completed": boolean,
--       "time_ms": integer,
--       "score": integer
--     }
--   ],
--   "total_score": integer,
--   "total_time_ms": integer,
--   "total_rounds": integer,
--   "theme": string
-- }
--
-- The account_state table already uses JSONB and the Dart client upserts
-- the full row on each save, so no ALTER TABLE is required. This migration
-- exists purely for documentation and to create any supporting views/indexes.

-- Optional: Create a view for daily streak leaderboard
CREATE OR REPLACE VIEW daily_streak_leaderboard AS
SELECT
  a.user_id,
  p.username,
  COALESCE((a.daily_streak_data->>'current_streak')::int, 0) AS current_streak,
  COALESCE((a.daily_streak_data->>'longest_streak')::int, 0) AS longest_streak,
  COALESCE((a.daily_streak_data->>'total_completed')::int, 0) AS total_completed,
  a.daily_streak_data->>'last_completion_date' AS last_completion_date
FROM account_state a
JOIN profiles p ON p.id = a.user_id
WHERE (a.daily_streak_data->>'current_streak')::int > 0
ORDER BY current_streak DESC, longest_streak DESC
LIMIT 100;
