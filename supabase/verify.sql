-- =============================================================================
-- Flit — Supabase Schema Verification
-- =============================================================================
-- Run this in the Supabase SQL Editor after rebuild.sql to verify all tables,
-- columns, policies, triggers, functions, views, and indexes exist.
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

  -- ------- TABLES (7) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Tables (7) ---');

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profiles') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: profiles'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: profiles — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: user_settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: user_settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='account_state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: account_state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: account_state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='scores') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: scores'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: scores — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: friendships — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='matchmaking_pool') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  table: matchmaking_pool'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  table: matchmaking_pool — MISSING'); END IF;

  -- ------- PROFILES COLUMNS (21) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- profiles columns (21) ---');

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
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.created_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: profiles.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: profiles.updated_at — MISSING'); END IF;

  -- ------- USER_SETTINGS COLUMNS (13) -------
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

  -- ------- ACCOUNT_STATE COLUMNS (14) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- account_state columns (14) ---');

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
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='account_state' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: account_state.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: account_state.updated_at — MISSING'); END IF;

  -- ------- SCORES COLUMNS (7) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- scores columns (7) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='user_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.user_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.user_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='score') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.score'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.score — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='time_ms') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.time_ms'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.time_ms — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='region') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.region'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.region — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='rounds_completed') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.rounds_completed'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.rounds_completed — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='scores' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: scores.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: scores.created_at — MISSING'); END IF;

  -- ------- FRIENDSHIPS COLUMNS (6) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- friendships columns (6) ---');

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='requester_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.requester_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.requester_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='addressee_id') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.addressee_id'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.addressee_id — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='status') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.status'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.status — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='created_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.created_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.created_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='friendships' AND column_name='updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  column: friendships.updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  column: friendships.updated_at — MISSING'); END IF;

  -- ------- CHALLENGES COLUMNS (12) -------
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

  -- ------- MATCHMAKING_POOL COLUMNS (11) -------
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

  -- ------- RLS ENABLED (7) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- RLS enabled (7) ---');

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'profiles' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: profiles'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: profiles — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'user_settings' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: user_settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: user_settings — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'account_state' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: account_state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: account_state — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'scores' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: scores'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: scores — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'friendships' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: friendships — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'challenges' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: challenges — DISABLED'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'matchmaking_pool' AND c.relrowsecurity = true) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  RLS enabled: matchmaking_pool'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  RLS enabled: matchmaking_pool — DISABLED'); END IF;

  -- ------- ALL RLS POLICIES (25) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- RLS policies (25) ---');

  -- profiles (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can read own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Users can read own profile'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Users can read own profile — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can insert own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Users can insert own profile'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Users can insert own profile — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can update own profile') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Users can update own profile'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Users can update own profile — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Profiles are publicly readable') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: profiles / Profiles are publicly readable'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: profiles / Profiles are publicly readable — MISSING'); END IF;

  -- user_settings (3)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_settings' AND policyname = 'Users can read own settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: user_settings / Users can read own settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: user_settings / Users can read own settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_settings' AND policyname = 'Users can insert own settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: user_settings / Users can insert own settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: user_settings / Users can insert own settings — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_settings' AND policyname = 'Users can update own settings') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: user_settings / Users can update own settings'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: user_settings / Users can update own settings — MISSING'); END IF;

  -- account_state (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'account_state' AND policyname = 'Users can read own account state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Users can read own account state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Users can read own account state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'account_state' AND policyname = 'Users can insert own account state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Users can insert own account state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Users can insert own account state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'account_state' AND policyname = 'Users can update own account state') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Users can update own account state'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Users can update own account state — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'account_state' AND policyname = 'Account state is publicly readable') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: account_state / Account state is publicly readable'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: account_state / Account state is publicly readable — MISSING'); END IF;

  -- scores (2)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'scores' AND policyname = 'Scores are viewable by everyone') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: scores / Scores are viewable by everyone'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: scores / Scores are viewable by everyone — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'scores' AND policyname = 'Users can insert own scores') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: scores / Users can insert own scores'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: scores / Users can insert own scores — MISSING'); END IF;

  -- friendships (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'friendships' AND policyname = 'Users can see own friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Users can see own friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Users can see own friendships — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'friendships' AND policyname = 'Users can send friend requests') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Users can send friend requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Users can send friend requests — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'friendships' AND policyname = 'Addressee can respond to friend requests') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Addressee can respond to friend requests'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Addressee can respond to friend requests — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'friendships' AND policyname = 'Users can remove friendships') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: friendships / Users can remove friendships'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: friendships / Users can remove friendships — MISSING'); END IF;

  -- challenges (3)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'challenges' AND policyname = 'Players can see own challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: challenges / Players can see own challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: challenges / Players can see own challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'challenges' AND policyname = 'Challenger can create challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: challenges / Challenger can create challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: challenges / Challenger can create challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'challenges' AND policyname = 'Players can update own challenges') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: challenges / Players can update own challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: challenges / Players can update own challenges — MISSING'); END IF;

  -- matchmaking_pool (4)
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'matchmaking_pool' AND policyname = 'Users can insert own entries') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Users can insert own entries'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Users can insert own entries — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'matchmaking_pool' AND policyname = 'Users can read own or matched entries') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Users can read own or matched entries'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Users can read own or matched entries — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'matchmaking_pool' AND policyname = 'Users can update own entries on match') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Users can update own entries on match'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Users can update own entries on match — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'matchmaking_pool' AND policyname = 'Allow pool size counting for stats') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  policy: matchmaking_pool / Allow pool size counting for stats'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  policy: matchmaking_pool / Allow pool size counting for stats — MISSING'); END IF;

  -- ------- TRIGGERS (5) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Triggers (5) ---');

  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: on_auth_user_created'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: on_auth_user_created — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_profiles_updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_profiles_updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_profiles_updated_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_user_settings_updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_user_settings_updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_user_settings_updated_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_account_state_updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_account_state_updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_account_state_updated_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_friendships_updated_at') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  trigger: trg_friendships_updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  trigger: trg_friendships_updated_at — MISSING'); END IF;

  -- ------- FUNCTIONS (9) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Functions (9) ---');

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: handle_new_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: handle_new_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: update_updated_at'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: update_updated_at — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'purchase_cosmetic' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: purchase_cosmetic'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: purchase_cosmetic — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'purchase_avatar_part' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: purchase_avatar_part'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: purchase_avatar_part — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'send_coins' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: send_coins'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: send_coins — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'gift_cosmetic' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: gift_cosmetic'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: gift_cosmetic — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'gift_avatar_part' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: gift_avatar_part'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: gift_avatar_part — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'expire_stale_challenges' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: expire_stale_challenges'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: expire_stale_challenges — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_increment_stat' AND pronamespace = 'public'::regnamespace) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  function: admin_increment_stat'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  function: admin_increment_stat — MISSING'); END IF;

  -- ------- VIEWS (4) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Views (4) ---');

  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'leaderboard_global') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: leaderboard_global'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: leaderboard_global — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'leaderboard_daily') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: leaderboard_daily'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: leaderboard_daily — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'leaderboard_regional') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: leaderboard_regional'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: leaderboard_regional — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'daily_streak_leaderboard') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  view: daily_streak_leaderboard'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  view: daily_streak_leaderboard — MISSING'); END IF;

  -- ------- VIEW SECURITY INVOKER (4) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- View security_invoker (4) ---');

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='leaderboard_global' AND c.relkind='v' AND (SELECT COALESCE((reloptions::text[] @> ARRAY['security_invoker=on']::text[]) OR (reloptions::text[] @> ARRAY['security_invoker=true']::text[]), false) FROM pg_class WHERE relname='leaderboard_global' AND relnamespace='public'::regnamespace)) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  security_invoker: leaderboard_global'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  security_invoker: leaderboard_global — NOT SET'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='leaderboard_daily' AND c.relkind='v' AND (SELECT COALESCE((reloptions::text[] @> ARRAY['security_invoker=on']::text[]) OR (reloptions::text[] @> ARRAY['security_invoker=true']::text[]), false) FROM pg_class WHERE relname='leaderboard_daily' AND relnamespace='public'::regnamespace)) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  security_invoker: leaderboard_daily'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  security_invoker: leaderboard_daily — NOT SET'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='leaderboard_regional' AND c.relkind='v' AND (SELECT COALESCE((reloptions::text[] @> ARRAY['security_invoker=on']::text[]) OR (reloptions::text[] @> ARRAY['security_invoker=true']::text[]), false) FROM pg_class WHERE relname='leaderboard_regional' AND relnamespace='public'::regnamespace)) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  security_invoker: leaderboard_regional'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  security_invoker: leaderboard_regional — NOT SET'); END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='daily_streak_leaderboard' AND c.relkind='v' AND (SELECT COALESCE((reloptions::text[] @> ARRAY['security_invoker=on']::text[]) OR (reloptions::text[] @> ARRAY['security_invoker=true']::text[]), false) FROM pg_class WHERE relname='daily_streak_leaderboard' AND relnamespace='public'::regnamespace)) THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  security_invoker: daily_streak_leaderboard'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  security_invoker: daily_streak_leaderboard — NOT SET'); END IF;

  -- ------- INDEXES (12) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Indexes (12) ---');

  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_scores_leaderboard') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_leaderboard'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_leaderboard — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_scores_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_user — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_scores_global_rank') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_global_rank'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_global_rank — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_scores_daily_rank') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_scores_daily_rank'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_scores_daily_rank — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_profiles_username') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_profiles_username'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_profiles_username — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_friendships_requester') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_friendships_requester'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_friendships_requester — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_friendships_addressee') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_friendships_addressee'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_friendships_addressee — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_challenges_challenger') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_challenges_challenger'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_challenges_challenger — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_challenges_challenged') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_challenges_challenged'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_challenges_challenged — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_challenges_created') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_challenges_created'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_challenges_created — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_matchmaking_unmatched') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_matchmaking_unmatched'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_matchmaking_unmatched — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_matchmaking_user') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  index: idx_matchmaking_user'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  index: idx_matchmaking_user — MISSING'); END IF;

  -- ------- CONSTRAINTS (7) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Constraints (7) ---');

  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_score') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: chk_score'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: chk_score — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_time') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: chk_time'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: chk_time — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_username_length') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: check_username_length'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: check_username_length — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_username_pattern') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: check_username_pattern'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: check_username_pattern — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_level_positive') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: check_level_positive'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: check_level_positive — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_xp_non_negative') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: check_xp_non_negative'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: check_xp_non_negative — MISSING'); END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_coins_non_negative') THEN _pass:=_pass+1; _results:=array_append(_results,'PASS  constraint: check_coins_non_negative'); ELSE _fail:=_fail+1; _results:=array_append(_results,'FAIL  constraint: check_coins_non_negative — MISSING'); END IF;

  -- ------- SUMMARY -------
  _results := array_append(_results, '');
  _results := array_append(_results, '========================================');
  _results := array_append(_results, 'PASSED: ' || _pass || '  FAILED: ' || _fail);
  IF _fail = 0 THEN
    _results := array_append(_results, 'ALL CHECKS PASSED');
  ELSE
    _results := array_append(_results, 'SCHEMA IS INCOMPLETE — fix failures above');
  END IF;
  _results := array_append(_results, '========================================');

  -- Print results via RAISE NOTICE (visible in SQL Editor "Messages" tab).
  FOREACH _line IN ARRAY _results LOOP
    RAISE NOTICE '%', _line;
  END LOOP;
END;
$$;

-- Also return results as a queryable table for convenience.
WITH checks AS (
  -- Tables
  SELECT 'table' as category, t as name,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=t) as ok
  FROM unnest(ARRAY['profiles','user_settings','account_state','scores','friendships','challenges','matchmaking_pool']) t

  UNION ALL

  -- Functions
  SELECT 'function', f,
    EXISTS (SELECT 1 FROM pg_proc WHERE proname=f AND pronamespace='public'::regnamespace)
  FROM unnest(ARRAY['handle_new_user','update_updated_at','purchase_cosmetic','purchase_avatar_part','send_coins','gift_cosmetic','gift_avatar_part','expire_stale_challenges','admin_increment_stat']) f

  UNION ALL

  -- Views
  SELECT 'view', v,
    EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name=v)
  FROM unnest(ARRAY['leaderboard_global','leaderboard_daily','leaderboard_regional','daily_streak_leaderboard']) v

  UNION ALL

  -- Triggers
  SELECT 'trigger', tg,
    EXISTS (SELECT 1 FROM pg_trigger WHERE tgname=tg)
  FROM unnest(ARRAY['on_auth_user_created','trg_profiles_updated_at','trg_user_settings_updated_at','trg_account_state_updated_at','trg_friendships_updated_at']) tg

  UNION ALL

  -- Constraints
  SELECT 'constraint', c,
    EXISTS (SELECT 1 FROM pg_constraint WHERE conname=c)
  FROM unnest(ARRAY['chk_score','chk_time','check_username_length','check_username_pattern','check_level_positive','check_xp_non_negative','check_coins_non_negative']) c

  UNION ALL

  -- RLS enabled
  SELECT 'rls', t,
    EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=t AND c.relrowsecurity)
  FROM unnest(ARRAY['profiles','user_settings','account_state','scores','friendships','challenges','matchmaking_pool']) t

  UNION ALL

  -- View security_invoker
  SELECT 'security_invoker', v,
    COALESCE((SELECT reloptions::text[] @> ARRAY['security_invoker=on']::text[] OR reloptions::text[] @> ARRAY['security_invoker=true']::text[] FROM pg_class WHERE relname=v AND relnamespace='public'::regnamespace), false)
  FROM unnest(ARRAY['leaderboard_global','leaderboard_daily','leaderboard_regional','daily_streak_leaderboard']) v
)
SELECT
  CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status,
  category,
  name
FROM checks
ORDER BY ok, category, name;
