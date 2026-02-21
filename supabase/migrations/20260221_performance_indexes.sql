-- Performance indexes for high-traffic read paths.
-- Run in Supabase SQL Editor or via `supabase db push`.

-- 1. Global leaderboard view scans ALL scores with no WHERE clause.
--    The existing idx_scores_leaderboard leads with (region, ...) which is
--    useless for the unfiltered global scan. This covers the ORDER BY.
CREATE INDEX IF NOT EXISTS idx_scores_global_rank
  ON public.scores (score DESC, time_ms ASC);

-- 2. Daily leaderboard view filters WHERE region = 'daily' AND created_at >= today.
--    Partial index keeps the B-tree small — only daily rows are indexed.
CREATE INDEX IF NOT EXISTS idx_scores_daily_rank
  ON public.scores (created_at, score DESC, time_ms ASC)
  WHERE region = 'daily';

-- 3. Username lookup for friend search (FriendsService.searchUser).
--    Also enforces uniqueness at the DB level.
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username
  ON public.profiles (username);
