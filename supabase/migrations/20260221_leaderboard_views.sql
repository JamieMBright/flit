-- Migration: Leaderboard views
-- Date: 2026-02-21
-- Description: Creates SQL views for efficient leaderboard queries.
--   Global all-time, daily, and regional views pre-compute rank via
--   window functions so the client can fetch ranked results directly.

-- ---------------------------------------------------------------------------
-- 1. leaderboard_global — all-time top scores ranked globally
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW leaderboard_global AS
SELECT s.user_id, p.username, p.level, p.avatar_url,
       s.score, s.time_ms, s.region, s.created_at,
       ROW_NUMBER() OVER (ORDER BY s.score DESC, s.time_ms ASC) as rank
FROM scores s
JOIN profiles p ON s.user_id = p.id
ORDER BY s.score DESC, s.time_ms ASC;

-- ---------------------------------------------------------------------------
-- 2. leaderboard_daily — today's scores only (resets at midnight UTC)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW leaderboard_daily AS
SELECT s.user_id, p.username, p.level, p.avatar_url,
       s.score, s.time_ms, s.region, s.created_at,
       ROW_NUMBER() OVER (ORDER BY s.score DESC, s.time_ms ASC) as rank
FROM scores s
JOIN profiles p ON s.user_id = p.id
WHERE s.created_at >= CURRENT_DATE
ORDER BY s.score DESC, s.time_ms ASC;

-- ---------------------------------------------------------------------------
-- 3. leaderboard_regional — per-region ranks (filter by region in the query)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW leaderboard_regional AS
SELECT s.user_id, p.username, p.level, p.avatar_url,
       s.score, s.time_ms, s.region, s.created_at,
       ROW_NUMBER() OVER (PARTITION BY s.region ORDER BY s.score DESC, s.time_ms ASC) as rank
FROM scores s
JOIN profiles p ON s.user_id = p.id
ORDER BY s.region, s.score DESC, s.time_ms ASC;
