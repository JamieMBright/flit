-- =============================================================================
-- Flit — Supabase Schema Verification (COMPREHENSIVE)
-- =============================================================================
-- Run this in the Supabase SQL Editor after rebuild.sql to verify all tables,
-- columns, policies, triggers, functions, views, indexes, and constraints exist.
--
-- Returns a single result set: one row per check, with pass/fail status.
-- Any row with status = 'FAIL' means rebuild.sql missed something or the
-- migration was not applied correctly.
-- =============================================================================

DO $$
DECLARE
  _pass INT := 0;
  _fail INT := 0;
  _results TEXT[] := '{}';
  _line TEXT;

BEGIN
  _results := array_append(_results, '========================================');
  _results := array_append(_results, 'Flit Schema Verification — COMPREHENSIVE');
  _results := array_append(_results, '========================================');

  -- =========================================================================
  -- TABLES (16)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Tables (16) ---');

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profiles') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: profiles'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: profiles — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: user_settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: user_settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='account_state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: account_state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: account_state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='scores') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: scores'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: scores — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: friendships — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='matchmaking_pool') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: matchmaking_pool'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: matchmaking_pool — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='coin_activity') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: coin_activity'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: coin_activity — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='player_reports') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: player_reports'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: player_reports — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='announcements') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: announcements'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: announcements — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='feature_flags') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: feature_flags'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: feature_flags — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='admin_audit_log') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: admin_audit_log'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: admin_audit_log — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='app_config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: app_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: app_config — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='economy_config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: economy_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: economy_config — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='gdpr_requests') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: gdpr_requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: gdpr_requests — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='iap_receipts') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: iap_receipts'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: iap_receipts — MISSING'); END IF;

  -- =========================================================================
  -- PROFILES COLUMNS (24)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- profiles columns (24) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='username') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.username'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.username — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='display_name') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.display_name'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.display_name — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='avatar_url') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.avatar_url'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.avatar_url — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='level') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.level'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.level — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='xp') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.xp'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.xp — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='coins') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.coins'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.coins — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='games_played') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.games_played'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.games_played — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='best_score') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.best_score'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.best_score — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='best_time_ms') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.best_time_ms'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.best_time_ms — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='total_flight_time_ms') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.total_flight_time_ms'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.total_flight_time_ms — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='countries_found') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.countries_found'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.countries_found — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='flags_correct') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.flags_correct'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.flags_correct — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='capitals_correct') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.capitals_correct'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.capitals_correct — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='outlines_correct') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.outlines_correct'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.outlines_correct — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='borders_correct') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.borders_correct'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.borders_correct — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='stats_correct') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.stats_correct'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.stats_correct — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='best_streak') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.best_streak'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.best_streak — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='admin_role') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.admin_role'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.admin_role — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='banned_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.banned_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.banned_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='ban_expires_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.ban_expires_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.ban_expires_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='ban_reason') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.ban_reason'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.ban_reason — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.created_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- USER_SETTINGS COLUMNS (13)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- user_settings columns (13) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='turn_sensitivity') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.turn_sensitivity'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.turn_sensitivity — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='invert_controls') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.invert_controls'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.invert_controls — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='enable_night') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.enable_night'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.enable_night — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='map_style') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.map_style'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.map_style — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='english_labels') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.english_labels'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.english_labels — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='difficulty') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.difficulty'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.difficulty — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='sound_enabled') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.sound_enabled'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.sound_enabled — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='music_volume') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.music_volume'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.music_volume — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='effects_volume') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.effects_volume'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.effects_volume — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='notifications_enabled') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.notifications_enabled'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.notifications_enabled — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='haptic_enabled') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.haptic_enabled'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.haptic_enabled — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_settings' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: user_settings.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: user_settings.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- ACCOUNT_STATE COLUMNS (16)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- account_state columns (16) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='avatar_config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.avatar_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.avatar_config — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='license_data') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.license_data'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.license_data — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='unlocked_regions') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.unlocked_regions'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.unlocked_regions — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='owned_avatar_parts') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.owned_avatar_parts'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.owned_avatar_parts — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='owned_cosmetics') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.owned_cosmetics'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.owned_cosmetics — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='equipped_plane_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.equipped_plane_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.equipped_plane_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='equipped_contrail_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.equipped_contrail_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.equipped_contrail_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='equipped_title_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.equipped_title_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.equipped_title_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='last_free_reroll_date') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.last_free_reroll_date'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.last_free_reroll_date — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='last_daily_challenge_date') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.last_daily_challenge_date'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.last_daily_challenge_date — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='daily_streak_data') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.daily_streak_data'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.daily_streak_data — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='last_daily_result') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.last_daily_result'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.last_daily_result — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='free_flight_coins_today') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.free_flight_coins_today'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.free_flight_coins_today — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='free_flight_coin_date') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.free_flight_coin_date'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.free_flight_coin_date — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- SCORES COLUMNS (9)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- scores columns (9) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='score') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.score'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.score — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='time_ms') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.time_ms'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.time_ms — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='region') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.region'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.region — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='rounds_completed') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.rounds_completed'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.rounds_completed — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='round_emojis') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.round_emojis'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.round_emojis — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='round_details') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.round_details'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.round_details — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.created_at — MISSING'); END IF;

  -- =========================================================================
  -- FRIENDSHIPS COLUMNS (6)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- friendships columns (6) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='requester_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.requester_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.requester_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='addressee_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.addressee_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.addressee_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='status') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.status'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.status — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.created_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- CHALLENGES COLUMNS (12)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- challenges columns (12) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='challenger_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.challenger_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.challenger_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='challenger_name') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.challenger_name'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.challenger_name — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='challenged_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.challenged_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.challenged_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='challenged_name') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.challenged_name'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.challenged_name — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='status') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.status'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.status — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='rounds') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.rounds'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.rounds — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='winner_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.winner_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.winner_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='challenger_coins') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.challenger_coins'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.challenger_coins — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='challenged_coins') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.challenged_coins'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.challenged_coins — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.created_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='challenges' AND column_name='completed_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: challenges.completed_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: challenges.completed_at — MISSING'); END IF;

  -- =========================================================================
  -- MATCHMAKING_POOL COLUMNS (11)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- matchmaking_pool columns (11) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='region') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.region'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.region — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='seed') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.seed'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.seed — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='rounds') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.rounds'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.rounds — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='elo_rating') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.elo_rating'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.elo_rating — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='gameplay_version') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.gameplay_version'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.gameplay_version — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.created_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='matched_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.matched_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.matched_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='matched_with') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.matched_with'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.matched_with — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='matchmaking_pool' AND column_name='challenge_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: matchmaking_pool.challenge_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: matchmaking_pool.challenge_id — MISSING'); END IF;

  -- =========================================================================
  -- COIN_ACTIVITY COLUMNS (7)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- coin_activity columns (7) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='username') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.username'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.username — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='coin_amount') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.coin_amount'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.coin_amount — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='source') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.source'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.source — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='balance_after') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.balance_after'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.balance_after — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coin_activity' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: coin_activity.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: coin_activity.created_at — MISSING'); END IF;

  -- =========================================================================
  -- PLAYER_REPORTS COLUMNS (10)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- player_reports columns (10) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='reporter_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.reporter_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.reporter_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='reported_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.reported_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.reported_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='reason') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.reason'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.reason — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='details') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.details'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.details — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='status') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.status'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.status — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='reviewed_by') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.reviewed_by'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.reviewed_by — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='reviewed_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.reviewed_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.reviewed_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='action_taken') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.action_taken'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.action_taken — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='player_reports' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: player_reports.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: player_reports.created_at — MISSING'); END IF;

  -- =========================================================================
  -- ANNOUNCEMENTS COLUMNS (10)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- announcements columns (10) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='title') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.title'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.title — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='body') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.body'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.body — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='type') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.type'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.type — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='priority') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.priority'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.priority — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='is_active') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.is_active'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.is_active — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='starts_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.starts_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.starts_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='expires_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.expires_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.expires_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='created_by') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.created_by'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.created_by — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='announcements' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: announcements.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: announcements.created_at — MISSING'); END IF;

  -- =========================================================================
  -- FEATURE_FLAGS COLUMNS (5)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- feature_flags columns (5) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feature_flags' AND column_name='flag_key') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: feature_flags.flag_key'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: feature_flags.flag_key — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feature_flags' AND column_name='enabled') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: feature_flags.enabled'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: feature_flags.enabled — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feature_flags' AND column_name='description') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: feature_flags.description'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: feature_flags.description — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feature_flags' AND column_name='updated_by') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: feature_flags.updated_by'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: feature_flags.updated_by — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feature_flags' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: feature_flags.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: feature_flags.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- ADMIN_AUDIT_LOG COLUMNS (7)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- admin_audit_log columns (7) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='actor_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.actor_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.actor_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='actor_role') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.actor_role'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.actor_role — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='action') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.action'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.action — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='target_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.target_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.target_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='details') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.details'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.details — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='admin_audit_log' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: admin_audit_log.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: admin_audit_log.created_at — MISSING'); END IF;

  -- =========================================================================
  -- APP_CONFIG COLUMNS (6)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- app_config columns (6) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_config' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: app_config.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: app_config.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_config' AND column_name='min_app_version') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: app_config.min_app_version'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: app_config.min_app_version — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_config' AND column_name='recommended_version') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: app_config.recommended_version'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: app_config.recommended_version — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_config' AND column_name='maintenance_mode') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: app_config.maintenance_mode'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: app_config.maintenance_mode — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_config' AND column_name='maintenance_message') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: app_config.maintenance_message'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: app_config.maintenance_message — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_config' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: app_config.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: app_config.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- ECONOMY_CONFIG COLUMNS (3)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- economy_config columns (3) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='economy_config' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: economy_config.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: economy_config.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='economy_config' AND column_name='config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: economy_config.config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: economy_config.config — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='economy_config' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: economy_config.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: economy_config.updated_at — MISSING'); END IF;

  -- =========================================================================
  -- GDPR_REQUESTS COLUMNS (10)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- gdpr_requests columns (10) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='username') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.username'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.username — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='request_type') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.request_type'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.request_type — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='status') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.status'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.status — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='requested_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.requested_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.requested_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='completed_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.completed_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.completed_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='processed_by') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.processed_by'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.processed_by — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='notes') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.notes'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.notes — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='gdpr_requests' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: gdpr_requests.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: gdpr_requests.created_at — MISSING'); END IF;

  -- =========================================================================
  -- IAP_RECEIPTS COLUMNS (10)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- iap_receipts columns (10) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='product_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.product_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.product_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='platform') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.platform'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.platform — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='receipt_data') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.receipt_data'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.receipt_data — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='is_valid') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.is_valid'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.is_valid — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='amount') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.amount'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.amount — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='currency') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.currency'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.currency — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='transaction_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.transaction_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.transaction_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='iap_receipts' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: iap_receipts.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: iap_receipts.created_at — MISSING'); END IF;

  -- =========================================================================
  -- RLS POLICIES (40)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- RLS Policies (40) ---');

  -- profiles (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Profiles are publicly readable') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Profiles are publicly readable'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Profiles are publicly readable — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Users can insert own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Users can insert own profile'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Users can insert own profile — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Users can read own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Users can read own profile'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Users can read own profile — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Users can update own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Users can update own profile'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Users can update own profile — MISSING'); END IF;

  -- user_settings (3)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_settings' AND policyname='Users can read own settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: user_settings / Users can read own settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: user_settings / Users can read own settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_settings' AND policyname='Users can insert own settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: user_settings / Users can insert own settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: user_settings / Users can insert own settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_settings' AND policyname='Users can update own settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: user_settings / Users can update own settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: user_settings / Users can update own settings — MISSING'); END IF;

  -- account_state (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='account_state' AND policyname='Users can read own account state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Users can read own account state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Users can read own account state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='account_state' AND policyname='Users can insert own account state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Users can insert own account state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Users can insert own account state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='account_state' AND policyname='Users can update own account state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Users can update own account state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Users can update own account state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='account_state' AND policyname='Account state is publicly readable') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Account state is publicly readable'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Account state is publicly readable — MISSING'); END IF;

  -- scores (2)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='scores' AND policyname='Scores are viewable by everyone') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: scores / Scores are viewable by everyone'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: scores / Scores are viewable by everyone — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='scores' AND policyname='Users can insert own scores') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: scores / Users can insert own scores'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: scores / Users can insert own scores — MISSING'); END IF;

  -- friendships (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='friendships' AND policyname='Users can see own friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Users can see own friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Users can see own friendships — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='friendships' AND policyname='Users can send friend requests') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Users can send friend requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Users can send friend requests — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='friendships' AND policyname='Addressee can respond to friend requests') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Addressee can respond to friend requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Addressee can respond to friend requests — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='friendships' AND policyname='Users can remove friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Users can remove friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Users can remove friendships — MISSING'); END IF;

  -- challenges (3)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='challenges' AND policyname='Players can see own challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: challenges / Players can see own challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: challenges / Players can see own challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='challenges' AND policyname='Challenger can create challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: challenges / Challenger can create challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: challenges / Challenger can create challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='challenges' AND policyname='Players can update own challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: challenges / Players can update own challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: challenges / Players can update own challenges — MISSING'); END IF;

  -- matchmaking_pool (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='matchmaking_pool' AND policyname='Users can insert own entries') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Users can insert own entries'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Users can insert own entries — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='matchmaking_pool' AND policyname='Users can read own or matched entries') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Users can read own or matched entries'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Users can read own or matched entries — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='matchmaking_pool' AND policyname='Users can update own entries on match') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Users can update own entries on match'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Users can update own entries on match — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='matchmaking_pool' AND policyname='Allow pool size counting for stats') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Allow pool size counting for stats'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Allow pool size counting for stats — MISSING'); END IF;

  -- coin_activity (2)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coin_activity' AND policyname='Coin activity is publicly readable') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: coin_activity / Coin activity is publicly readable'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: coin_activity / Coin activity is publicly readable — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coin_activity' AND policyname='Users can insert own coin activity') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: coin_activity / Users can insert own coin activity'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: coin_activity / Users can insert own coin activity — MISSING'); END IF;

  -- player_reports (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='player_reports' AND policyname='Users can submit reports') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: player_reports / Users can submit reports'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: player_reports / Users can submit reports — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='player_reports' AND policyname='Users can read own reports') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: player_reports / Users can read own reports'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: player_reports / Users can read own reports — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='player_reports' AND policyname='Admins can read all reports') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: player_reports / Admins can read all reports'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: player_reports / Admins can read all reports — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='player_reports' AND policyname='Admins can update reports') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: player_reports / Admins can update reports'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: player_reports / Admins can update reports — MISSING'); END IF;

  -- announcements (2)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='announcements' AND policyname='Anyone can read active announcements') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: announcements / Anyone can read active announcements'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: announcements / Anyone can read active announcements — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='announcements' AND policyname='Admins can read all announcements') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: announcements / Admins can read all announcements'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: announcements / Admins can read all announcements — MISSING'); END IF;

  -- feature_flags (1)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='feature_flags' AND policyname='Anyone can read feature flags') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: feature_flags / Anyone can read feature flags'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: feature_flags / Anyone can read feature flags — MISSING'); END IF;

  -- admin_audit_log (2)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='admin_audit_log' AND policyname='Owners can read all audit log') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: admin_audit_log / Owners can read all audit log'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: admin_audit_log / Owners can read all audit log — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='admin_audit_log' AND policyname='Moderators can read own audit entries') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: admin_audit_log / Moderators can read own audit entries'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: admin_audit_log / Moderators can read own audit entries — MISSING'); END IF;

  -- app_config (1)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='app_config' AND policyname='Anyone can read app config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: app_config / Anyone can read app config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: app_config / Anyone can read app config — MISSING'); END IF;

  -- economy_config (1)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='economy_config' AND policyname='Economy config is readable by all') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: economy_config / Economy config is readable by all'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: economy_config / Economy config is readable by all — MISSING'); END IF;

  -- gdpr_requests (1)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='gdpr_requests' AND policyname='Admins can manage GDPR requests') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: gdpr_requests / Admins can manage GDPR requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: gdpr_requests / Admins can manage GDPR requests — MISSING'); END IF;

  -- iap_receipts (2)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='iap_receipts' AND policyname='Users read own receipts') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: iap_receipts / Users read own receipts'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: iap_receipts / Users read own receipts — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='iap_receipts' AND policyname='Admins read all receipts') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: iap_receipts / Admins read all receipts'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: iap_receipts / Admins read all receipts — MISSING'); END IF;

  -- =========================================================================
  -- FUNCTIONS (26)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Functions (26) ---');

  -- Utility functions (3)
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='handle_new_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: handle_new_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: handle_new_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='update_updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: update_updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: update_updated_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='protect_profile_stats') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: protect_profile_stats'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: protect_profile_stats — MISSING'); END IF;

  -- Economy functions (5)
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='purchase_cosmetic') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: purchase_cosmetic'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: purchase_cosmetic — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='purchase_avatar_part') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: purchase_avatar_part'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: purchase_avatar_part — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='send_coins') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: send_coins'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: send_coins — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='gift_cosmetic') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: gift_cosmetic'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: gift_cosmetic — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='gift_avatar_part') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: gift_avatar_part'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: gift_avatar_part — MISSING'); END IF;

  -- Game functions (1)
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='expire_stale_challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: expire_stale_challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: expire_stale_challenges — MISSING'); END IF;

  -- Admin functions (16)
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_increment_stat') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_increment_stat'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_increment_stat — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_set_stat') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_set_stat'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_set_stat — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_set_avatar') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_set_avatar'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_set_avatar — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_set_license') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_set_license'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_set_license — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_set_role') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_set_role'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_set_role — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_unlock_all') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_unlock_all'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_unlock_all — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_ban_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_ban_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_ban_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_unban_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_unban_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_unban_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_resolve_report') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_resolve_report'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_resolve_report — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_update_app_config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_update_app_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_update_app_config — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_upsert_announcement') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_upsert_announcement'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_upsert_announcement — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_set_feature_flag') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_set_feature_flag'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_set_feature_flag — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_search_users') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_search_users'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_search_users — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_economy_summary') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_economy_summary'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_economy_summary — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='admin_process_gdpr_request') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_process_gdpr_request'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_process_gdpr_request — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='upsert_economy_config') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: upsert_economy_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: upsert_economy_config — MISSING'); END IF;

  -- Internal helper (1)
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname='_log_admin_action') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: _log_admin_action'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: _log_admin_action — MISSING'); END IF;

  -- =========================================================================
  -- VIEWS (5)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Views (5) ---');

  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='leaderboard_global') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: leaderboard_global'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: leaderboard_global — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='leaderboard_daily') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: leaderboard_daily'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: leaderboard_daily — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='leaderboard_regional') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: leaderboard_regional'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: leaderboard_regional — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='daily_streak_leaderboard') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: daily_streak_leaderboard'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: daily_streak_leaderboard — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='suspicious_activity') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: suspicious_activity'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: suspicious_activity — MISSING'); END IF;

  -- =========================================================================
  -- TRIGGERS (6)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Triggers (6) ---');

  IF EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name='trg_profiles_updated_at' AND event_object_table='profiles') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_profiles_updated_at ON profiles'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_profiles_updated_at ON profiles — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name='trg_user_settings_updated_at' AND event_object_table='user_settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_user_settings_updated_at ON user_settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_user_settings_updated_at ON user_settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name='trg_account_state_updated_at' AND event_object_table='account_state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_account_state_updated_at ON account_state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_account_state_updated_at ON account_state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name='trg_friendships_updated_at' AND event_object_table='friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_friendships_updated_at ON friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_friendships_updated_at ON friendships — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name='trg_protect_profile_stats' AND event_object_table='profiles') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_protect_profile_stats ON profiles'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_protect_profile_stats ON profiles — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON t.tgrelid=c.oid JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='auth' AND c.relname='users' AND t.tgname='on_auth_user_created') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: on_auth_user_created ON auth.users'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: on_auth_user_created ON auth.users — MISSING'); END IF;

  -- =========================================================================
  -- INDEXES (25 non-primary-key)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Indexes (25) ---');

  -- profiles
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_profiles_username') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_profiles_username'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_profiles_username — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_profiles_username_trgm') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_profiles_username_trgm'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_profiles_username_trgm — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_profiles_banned') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_profiles_banned'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_profiles_banned — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='profiles_username_key') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: profiles_username_key (unique)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: profiles_username_key (unique) — MISSING'); END IF;

  -- scores
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_scores_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_scores_leaderboard') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_leaderboard'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_leaderboard — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_scores_daily_rank') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_daily_rank'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_daily_rank — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_scores_global_rank') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_global_rank'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_global_rank — MISSING'); END IF;

  -- friendships
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_friendships_requester') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_friendships_requester'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_friendships_requester — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_friendships_addressee') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_friendships_addressee'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_friendships_addressee — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='friendships_requester_id_addressee_id_key') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: friendships_requester_id_addressee_id_key (unique)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: friendships_requester_id_addressee_id_key (unique) — MISSING'); END IF;

  -- challenges
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_challenges_challenger') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_challenges_challenger'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_challenges_challenger — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_challenges_challenged') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_challenges_challenged'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_challenges_challenged — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_challenges_created') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_challenges_created'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_challenges_created — MISSING'); END IF;

  -- matchmaking_pool
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_matchmaking_unmatched') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_matchmaking_unmatched'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_matchmaking_unmatched — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_matchmaking_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_matchmaking_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_matchmaking_user — MISSING'); END IF;

  -- coin_activity
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_coin_activity_user_time') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_coin_activity_user_time'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_coin_activity_user_time — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_coin_activity_source_time') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_coin_activity_source_time'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_coin_activity_source_time — MISSING'); END IF;

  -- player_reports
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_reports_reported') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_reports_reported'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_reports_reported — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_reports_status') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_reports_status'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_reports_status — MISSING'); END IF;

  -- admin_audit_log
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_audit_log_actor') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_audit_log_actor'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_audit_log_actor — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_audit_log_target') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_audit_log_target'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_audit_log_target — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_audit_log_action') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_audit_log_action'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_audit_log_action — MISSING'); END IF;

  -- iap_receipts
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_iap_receipts_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_iap_receipts_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_iap_receipts_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_iap_receipts_created') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_iap_receipts_created'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_iap_receipts_created — MISSING'); END IF;

  -- =========================================================================
  -- CHECK CONSTRAINTS (17)
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Check Constraints (17) ---');

  -- profiles (6)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='check_coins_non_negative') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: profiles.check_coins_non_negative'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: profiles.check_coins_non_negative — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='check_level_positive') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: profiles.check_level_positive'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: profiles.check_level_positive — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='check_xp_non_negative') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: profiles.check_xp_non_negative'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: profiles.check_xp_non_negative — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='check_username_length') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: profiles.check_username_length'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: profiles.check_username_length — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='check_username_pattern') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: profiles.check_username_pattern'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: profiles.check_username_pattern — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='profiles_admin_role_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: profiles.profiles_admin_role_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: profiles.profiles_admin_role_check — MISSING'); END IF;

  -- scores (2)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='scores' AND constraint_name='chk_score') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: scores.chk_score'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: scores.chk_score — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='scores' AND constraint_name='chk_time') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: scores.chk_time'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: scores.chk_time — MISSING'); END IF;

  -- friendships (2)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='friendships' AND constraint_name='friendships_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: friendships.friendships_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: friendships.friendships_check — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='friendships' AND constraint_name='friendships_status_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: friendships.friendships_status_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: friendships.friendships_status_check — MISSING'); END IF;

  -- challenges (1)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='challenges' AND constraint_name='challenges_status_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: challenges.challenges_status_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: challenges.challenges_status_check — MISSING'); END IF;

  -- player_reports (1)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='player_reports' AND constraint_name='no_self_report') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: player_reports.no_self_report'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: player_reports.no_self_report — MISSING'); END IF;

  -- app_config (1)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='app_config' AND constraint_name='app_config_id_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: app_config.app_config_id_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: app_config.app_config_id_check — MISSING'); END IF;

  -- economy_config (1)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='economy_config' AND constraint_name='economy_config_id_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: economy_config.economy_config_id_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: economy_config.economy_config_id_check — MISSING'); END IF;

  -- gdpr_requests (2)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='gdpr_requests' AND constraint_name='gdpr_requests_request_type_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: gdpr_requests.gdpr_requests_request_type_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: gdpr_requests.gdpr_requests_request_type_check — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='gdpr_requests' AND constraint_name='gdpr_requests_status_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: gdpr_requests.gdpr_requests_status_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: gdpr_requests.gdpr_requests_status_check — MISSING'); END IF;

  -- iap_receipts (1)
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='iap_receipts' AND constraint_name='iap_receipts_platform_check') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: iap_receipts.iap_receipts_platform_check'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: iap_receipts.iap_receipts_platform_check — MISSING'); END IF;

  -- =========================================================================
  -- SECURITY CHECKS
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Security Checks ---');

  -- Verify suspicious_activity view has security_invoker = on
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'public' AND c.relname = 'suspicious_activity'
      AND c.relkind = 'v'
      AND (c.reloptions IS NOT NULL AND 'security_invoker=on' = ANY(c.reloptions))
  ) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  security: suspicious_activity has security_invoker=on');
  ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  security: suspicious_activity missing security_invoker=on');
  END IF;

  -- Verify RLS is enabled on all 16 tables
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='profiles' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: profiles'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: profiles — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='user_settings' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: user_settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: user_settings — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='account_state' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: account_state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: account_state — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='scores' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: scores'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: scores — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='friendships' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: friendships — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='challenges' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: challenges — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='matchmaking_pool' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: matchmaking_pool'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: matchmaking_pool — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='coin_activity' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: coin_activity'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: coin_activity — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='player_reports' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: player_reports'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: player_reports — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='announcements' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: announcements'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: announcements — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='feature_flags' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: feature_flags'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: feature_flags — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='admin_audit_log' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: admin_audit_log'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: admin_audit_log — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='app_config' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: app_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: app_config — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='economy_config' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: economy_config'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: economy_config — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='gdpr_requests' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: gdpr_requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: gdpr_requests — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relname='iap_receipts' AND c.relrowsecurity) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: iap_receipts'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: iap_receipts — DISABLED'); END IF;

  -- =========================================================================
  -- LEGACY DUPLICATE CLEANUP VERIFICATION
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Legacy Duplicate Cleanup ---');

  -- These legacy duplicates should NOT exist (they were cleaned up)
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='chk_coins_non_neg') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles.chk_coins_non_neg (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles.chk_coins_non_neg still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='chk_level_positive') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles.chk_level_positive (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles.chk_level_positive still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='chk_xp_non_negative') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles.chk_xp_non_negative (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles.chk_xp_non_negative still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='chk_username_length') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles.chk_username_length (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles.chk_username_length still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='profiles' AND constraint_name='chk_username_chars') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles.chk_username_chars (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles.chk_username_chars still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='scores' AND constraint_name='chk_score_range') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: scores.chk_score_range (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: scores.chk_score_range still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='scores' AND constraint_name='chk_time_range') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: scores.chk_time_range (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: scores.chk_time_range still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='public' AND table_name='scores' AND constraint_name='chk_rounds_range') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: scores.chk_rounds_range (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: scores.chk_rounds_range still exists — should be removed'); END IF;

  -- Legacy orphaned policies should NOT exist
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Users can view own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles / "Users can view own profile" (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles / "Users can view own profile" still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Admin can read all profiles') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles / "Admin can read all profiles" (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles / "Admin can read all profiles" still exists — should be removed'); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Admin can update any profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  no legacy: profiles / "Admin can update any profile" (removed)'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  legacy: profiles / "Admin can update any profile" still exists — should be removed'); END IF;

  -- =========================================================================
  -- SUMMARY
  -- =========================================================================
  _results := array_append(_results, '');
  _results := array_append(_results, '========================================');
  _results := array_append(_results, 'TOTAL: ' || (_pass + _fail) || ' checks');
  _results := array_append(_results, 'PASS:  ' || _pass);
  _results := array_append(_results, 'FAIL:  ' || _fail);
  IF _fail = 0 THEN
    _results := array_append(_results, 'STATUS: ALL CHECKS PASSED');
  ELSE
    _results := array_append(_results, 'STATUS: ' || _fail || ' FAILURES — review above');
  END IF;
  _results := array_append(_results, '========================================');

  -- Output results
  FOREACH _line IN ARRAY _results LOOP
    RAISE NOTICE '%', _line;
  END LOOP;

END $$;
