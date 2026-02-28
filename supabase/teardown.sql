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
DROP VIEW IF EXISTS public.suspicious_activity CASCADE;
DROP VIEW IF EXISTS public.daily_streak_leaderboard CASCADE;
DROP VIEW IF EXISTS public.leaderboard_regional CASCADE;
DROP VIEW IF EXISTS public.leaderboard_daily CASCADE;
DROP VIEW IF EXISTS public.leaderboard_global CASCADE;

-- Drop triggers (before tables so partial runs are clean).
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
DROP TRIGGER IF EXISTS trg_user_settings_updated_at ON public.user_settings;
DROP TRIGGER IF EXISTS trg_account_state_updated_at ON public.account_state;
DROP TRIGGER IF EXISTS trg_friendships_updated_at ON public.friendships;
DROP TRIGGER IF EXISTS trg_protect_profile_stats ON public.profiles;

-- Drop tables (order matters for foreign keys).
DROP TABLE IF EXISTS public.iap_receipts CASCADE;
DROP TABLE IF EXISTS public.gdpr_requests CASCADE;
DROP TABLE IF EXISTS public.matchmaking_pool CASCADE;
DROP TABLE IF EXISTS public.challenges CASCADE;
DROP TABLE IF EXISTS public.friendships CASCADE;
DROP TABLE IF EXISTS public.scores CASCADE;
DROP TABLE IF EXISTS public.coin_activity CASCADE;
DROP TABLE IF EXISTS public.player_reports CASCADE;
DROP TABLE IF EXISTS public.announcements CASCADE;
DROP TABLE IF EXISTS public.feature_flags CASCADE;
DROP TABLE IF EXISTS public.admin_audit_log CASCADE;
DROP TABLE IF EXISTS public.app_config CASCADE;
DROP TABLE IF EXISTS public.economy_config CASCADE;
DROP TABLE IF EXISTS public.account_state CASCADE;
DROP TABLE IF EXISTS public.user_settings CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop functions.
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.protect_profile_stats() CASCADE;
DROP FUNCTION IF EXISTS public.purchase_cosmetic(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.purchase_avatar_part(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.send_coins(UUID, UUID, INT) CASCADE;
DROP FUNCTION IF EXISTS public.gift_cosmetic(UUID, UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.gift_avatar_part(UUID, UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.expire_stale_challenges() CASCADE;
DROP FUNCTION IF EXISTS public.admin_increment_stat(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_stat(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_avatar(UUID, JSONB) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_license(UUID, JSONB) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_role(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_unlock_all(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.admin_ban_user(UUID, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_unban_user(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.admin_resolve_report(BIGINT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_update_app_config(TEXT, TEXT, BOOLEAN, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_upsert_announcement(BIGINT, TEXT, TEXT, TEXT, INT, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_feature_flag(TEXT, BOOLEAN, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_search_users(TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_economy_summary() CASCADE;
DROP FUNCTION IF EXISTS public.admin_process_gdpr_request(BIGINT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.upsert_economy_config(JSONB) CASCADE;
DROP FUNCTION IF EXISTS public._log_admin_action(TEXT, UUID, JSONB) CASCADE;
