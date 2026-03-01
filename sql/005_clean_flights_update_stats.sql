-- =============================================================================
-- Flit — Clean flights without round details & recalculate user stats
-- =============================================================================
-- Removes all scores rows where round_details IS NULL (no round-by-round data),
-- then recalculates every affected user's profile stats from the remaining
-- scores history.
--
-- Stats updated:
--   games_played, best_score, best_time_ms, total_flight_time_ms,
--   countries_found, level, xp, flags_correct, capitals_correct,
--   outlines_correct, borders_correct, stats_correct, best_streak,
--   updated_at
--
-- Uses app.skip_stat_protection = 'true' to bypass the monotonic-stats trigger,
-- since stats will decrease after deleting scores.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Bypass the stat-protection trigger so we can decrease stats
-- ---------------------------------------------------------------------------
SET LOCAL app.skip_stat_protection = 'true';

-- ---------------------------------------------------------------------------
-- 2. Delete all scores that have no round-by-round detail data
-- ---------------------------------------------------------------------------
DELETE FROM public.scores
WHERE round_details IS NULL;

-- ---------------------------------------------------------------------------
-- 3. Recalculate profile stats from remaining scores + round_details
-- ---------------------------------------------------------------------------

WITH round_flat AS (
  -- Flatten round_details JSONB arrays into individual round rows
  -- ordered by game (score id) and position within game (ordinality)
  SELECT
    s.user_id,
    s.id                                   AS score_id,
    r.ordinality,
    r.value ->> 'clue_type'                AS clue_type,
    (r.value ->> 'completed')::BOOLEAN     AS completed
  FROM public.scores s,
       jsonb_array_elements(s.round_details) WITH ORDINALITY AS r(value, ordinality)
),
clue_counts AS (
  -- Count completed rounds per clue type per user
  SELECT
    user_id,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'flag'    AND completed), 0)::INT AS flags_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'capital'  AND completed), 0)::INT AS capitals_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'outline'  AND completed), 0)::INT AS outlines_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'borders'  AND completed), 0)::INT AS borders_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'stats'    AND completed), 0)::INT AS stats_correct
  FROM round_flat
  GROUP BY user_id
),
-- Gaps-and-islands approach for best streak:
-- Number each round globally per user, and assign a group ID that increments
-- each time a round is NOT completed. The longest group = best streak.
round_numbered AS (
  SELECT
    user_id,
    completed,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY score_id, ordinality) AS rn,
    SUM(CASE WHEN completed THEN 0 ELSE 1 END)
      OVER (PARTITION BY user_id ORDER BY score_id, ordinality
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS grp
  FROM round_flat
),
streak_calc AS (
  SELECT
    user_id,
    COALESCE(MAX(streak_len), 0)::INT AS best_streak
  FROM (
    SELECT
      user_id,
      grp,
      COUNT(*) AS streak_len
    FROM round_numbered
    WHERE completed = true
    GROUP BY user_id, grp
  ) sub
  GROUP BY user_id
),
score_agg AS (
  -- Aggregate game-level stats from remaining scores
  SELECT
    s.user_id,
    COUNT(*)::INT                       AS games_played,
    MAX(s.score)::INT                   AS best_score,
    MIN(s.time_ms)::BIGINT              AS best_time_ms,
    SUM(s.time_ms)::BIGINT              AS total_flight_time_ms,
    SUM(s.rounds_completed)::INT        AS countries_found,
    SUM(
      (50 + (s.rounds_completed * 10) + FLOOR(s.score / 100.0))::BIGINT
    )                                    AS total_xp
  FROM public.scores s
  GROUP BY s.user_id
),
xp_levels AS (
  -- Recursively compute level + remaining XP from total XP
  WITH RECURSIVE xp_progress AS (
    SELECT
      a.user_id,
      1::INT             AS level,
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
  games_played         = COALESCE(a.games_played, 0),
  best_score           = a.best_score,
  best_time_ms         = a.best_time_ms,
  total_flight_time_ms = COALESCE(a.total_flight_time_ms, 0),
  countries_found      = COALESCE(a.countries_found, 0),
  level                = COALESCE(x.level, 1),
  xp                   = COALESCE(x.xp, 0),
  flags_correct        = COALESCE(c.flags_correct, 0),
  capitals_correct     = COALESCE(c.capitals_correct, 0),
  outlines_correct     = COALESCE(c.outlines_correct, 0),
  borders_correct      = COALESCE(c.borders_correct, 0),
  stats_correct        = COALESCE(c.stats_correct, 0),
  best_streak          = COALESCE(sk.best_streak, 0),
  updated_at           = NOW()
FROM score_agg a
LEFT JOIN xp_levels x    ON x.user_id = a.user_id
LEFT JOIN clue_counts c  ON c.user_id = a.user_id
LEFT JOIN streak_calc sk ON sk.user_id = a.user_id
WHERE p.id = a.user_id;

-- ---------------------------------------------------------------------------
-- 4. Handle users who had ALL their flights deleted (no remaining scores)
-- ---------------------------------------------------------------------------
-- Reset stats to zero for users who previously had scores but now have none.
UPDATE public.profiles p
SET
  games_played         = 0,
  best_score           = NULL,
  best_time_ms         = NULL,
  total_flight_time_ms = 0,
  countries_found      = 0,
  level                = 1,
  xp                   = 0,
  flags_correct        = 0,
  capitals_correct     = 0,
  outlines_correct     = 0,
  borders_correct      = 0,
  stats_correct        = 0,
  best_streak          = 0,
  updated_at           = NOW()
WHERE p.games_played > 0
  AND NOT EXISTS (SELECT 1 FROM public.scores s WHERE s.user_id = p.id);

COMMIT;
