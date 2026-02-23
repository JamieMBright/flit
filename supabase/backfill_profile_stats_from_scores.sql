-- =============================================================================
-- Flit — Backfill profiles gameplay stats from scores history
-- =============================================================================
-- Recomputes per-user profile gameplay stats from public.scores and writes them
-- into public.profiles.
--
-- This script updates:
--   games_played, best_score, best_time_ms, total_flight_time_ms,
--   countries_found, level, xp, updated_at
--
-- Notes:
-- - XP/game formula matches app logic in AccountNotifier.recordGameCompletion:
--     xp_earned = 50 + (rounds_completed * 10) + floor(score / 100)
-- - Coin rewards are not derivable from scores alone, so profiles.coins is
--   intentionally not modified.
-- =============================================================================

WITH score_agg AS (
  SELECT
    s.user_id,
    COUNT(*)::INT AS games_played,
    MAX(s.score)::INT AS best_score,
    MIN(s.time_ms)::BIGINT AS best_time_ms,
    SUM(s.time_ms)::BIGINT AS total_flight_time_ms,
    SUM(s.rounds_completed)::INT AS countries_found,
    SUM((50 + (s.rounds_completed * 10) + FLOOR(s.score / 100.0))::BIGINT) AS total_xp
  FROM public.scores s
  GROUP BY s.user_id
),
xp_levels AS (
  WITH RECURSIVE xp_progress AS (
    SELECT
      a.user_id,
      1::INT AS level,
      a.total_xp::BIGINT AS xp_remaining
    FROM score_agg a

    UNION ALL

    SELECT
      x.user_id,
      x.level + 1,
      x.xp_remaining - (x.level * 100)
    FROM xp_progress x
    WHERE x.xp_remaining >= (x.level * 100)
  )
  SELECT DISTINCT ON (user_id)
    user_id,
    level,
    xp_remaining::INT AS xp
  FROM xp_progress
  ORDER BY user_id, level DESC
)
UPDATE public.profiles p
SET
  games_played = a.games_played,
  best_score = a.best_score,
  best_time_ms = a.best_time_ms,
  total_flight_time_ms = a.total_flight_time_ms,
  countries_found = a.countries_found,
  level = x.level,
  xp = x.xp,
  updated_at = NOW()
FROM score_agg a
JOIN xp_levels x ON x.user_id = a.user_id
WHERE p.id = a.user_id;
