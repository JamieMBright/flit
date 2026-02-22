-- =============================================================================
-- Flit — Supabase Schema Teardown (DESTRUCTIVE)
-- =============================================================================
-- WARNING: This drops ALL Flit tables, views, functions, and triggers.
-- All user data will be PERMANENTLY DELETED.
--
-- Only use this when you want a complete fresh start. Auth users in
-- auth.users are NOT deleted (that's managed by Supabase Auth).
--
-- After running this, run rebuild.sql to recreate the schema.
-- =============================================================================

-- Drop views first (they depend on tables).
DROP VIEW IF EXISTS daily_streak_leaderboard CASCADE;
DROP VIEW IF EXISTS leaderboard_regional CASCADE;
DROP VIEW IF EXISTS leaderboard_daily CASCADE;
DROP VIEW IF EXISTS leaderboard_global CASCADE;

-- Drop tables (order matters for foreign keys).
DROP TABLE IF EXISTS public.matchmaking_pool CASCADE;
DROP TABLE IF EXISTS public.challenges CASCADE;
DROP TABLE IF EXISTS public.friendships CASCADE;
DROP TABLE IF EXISTS public.scores CASCADE;
DROP TABLE IF EXISTS public.account_state CASCADE;
DROP TABLE IF EXISTS public.user_settings CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop functions.
DROP FUNCTION IF EXISTS public.admin_increment_stat(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.purchase_cosmetic(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.expire_stale_challenges() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Drop the auth trigger (the function was already dropped above).
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
