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

  -- Helper: check if a table exists
  PROCEDURE check_table(t TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  table: ' || t);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  table: ' || t || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if a column exists on a table
  PROCEDURE check_column(t TEXT, c TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = t AND column_name = c
    ) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  column: ' || t || '.' || c);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  column: ' || t || '.' || c || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if an RLS policy exists
  PROCEDURE check_policy(t TEXT, p TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = p) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  policy: ' || t || ' / ' || p);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  policy: ' || t || ' / ' || p || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if a trigger exists
  PROCEDURE check_trigger(trg TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = trg) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  trigger: ' || trg);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  trigger: ' || trg || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if a function exists
  PROCEDURE check_function(f TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = f AND pronamespace = 'public'::regnamespace) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  function: ' || f);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  function: ' || f || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if a view exists
  PROCEDURE check_view(v TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = v) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  view: ' || v);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  view: ' || v || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if an index exists
  PROCEDURE check_index(i TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = i) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  index: ' || i);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  index: ' || i || ' — MISSING');
    END IF;
  END;
  $p$;

  -- Helper: check if RLS is enabled on a table
  PROCEDURE check_rls(t TEXT)
  LANGUAGE plpgsql AS $p$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = t AND c.relrowsecurity = true
    ) THEN
      _pass := _pass + 1;
      _results := array_append(_results, 'PASS  RLS enabled: ' || t);
    ELSE
      _fail := _fail + 1;
      _results := array_append(_results, 'FAIL  RLS enabled: ' || t || ' — DISABLED');
    END IF;
  END;
  $p$;

BEGIN
  _results := array_append(_results, '========================================');
  _results := array_append(_results, 'Flit Schema Verification — COMPREHENSIVE');
  _results := array_append(_results, '========================================');

  -- ------- TABLES -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Tables (7) ---');
  CALL check_table('profiles');
  CALL check_table('user_settings');
  CALL check_table('account_state');
  CALL check_table('scores');
  CALL check_table('friendships');
  CALL check_table('challenges');
  CALL check_table('matchmaking_pool');

  -- ------- PROFILES COLUMNS (21) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- profiles columns (21) ---');
  CALL check_column('profiles', 'id');
  CALL check_column('profiles', 'username');
  CALL check_column('profiles', 'display_name');
  CALL check_column('profiles', 'avatar_url');
  CALL check_column('profiles', 'level');
  CALL check_column('profiles', 'xp');
  CALL check_column('profiles', 'coins');
  CALL check_column('profiles', 'games_played');
  CALL check_column('profiles', 'best_score');
  CALL check_column('profiles', 'best_time_ms');
  CALL check_column('profiles', 'total_flight_time_ms');
  CALL check_column('profiles', 'countries_found');
  CALL check_column('profiles', 'flags_correct');
  CALL check_column('profiles', 'capitals_correct');
  CALL check_column('profiles', 'outlines_correct');
  CALL check_column('profiles', 'borders_correct');
  CALL check_column('profiles', 'stats_correct');
  CALL check_column('profiles', 'best_streak');
  CALL check_column('profiles', 'admin_role');
  CALL check_column('profiles', 'created_at');
  CALL check_column('profiles', 'updated_at');

  -- ------- USER_SETTINGS COLUMNS (13) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- user_settings columns (13) ---');
  CALL check_column('user_settings', 'user_id');
  CALL check_column('user_settings', 'turn_sensitivity');
  CALL check_column('user_settings', 'invert_controls');
  CALL check_column('user_settings', 'enable_night');
  CALL check_column('user_settings', 'map_style');
  CALL check_column('user_settings', 'english_labels');
  CALL check_column('user_settings', 'difficulty');
  CALL check_column('user_settings', 'sound_enabled');
  CALL check_column('user_settings', 'music_volume');
  CALL check_column('user_settings', 'effects_volume');
  CALL check_column('user_settings', 'notifications_enabled');
  CALL check_column('user_settings', 'haptic_enabled');
  CALL check_column('user_settings', 'updated_at');

  -- ------- ACCOUNT_STATE COLUMNS (14) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- account_state columns (14) ---');
  CALL check_column('account_state', 'user_id');
  CALL check_column('account_state', 'avatar_config');
  CALL check_column('account_state', 'license_data');
  CALL check_column('account_state', 'unlocked_regions');
  CALL check_column('account_state', 'owned_avatar_parts');
  CALL check_column('account_state', 'owned_cosmetics');
  CALL check_column('account_state', 'equipped_plane_id');
  CALL check_column('account_state', 'equipped_contrail_id');
  CALL check_column('account_state', 'equipped_title_id');
  CALL check_column('account_state', 'last_free_reroll_date');
  CALL check_column('account_state', 'last_daily_challenge_date');
  CALL check_column('account_state', 'daily_streak_data');
  CALL check_column('account_state', 'last_daily_result');
  CALL check_column('account_state', 'updated_at');

  -- ------- SCORES COLUMNS (7) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- scores columns (7) ---');
  CALL check_column('scores', 'id');
  CALL check_column('scores', 'user_id');
  CALL check_column('scores', 'score');
  CALL check_column('scores', 'time_ms');
  CALL check_column('scores', 'region');
  CALL check_column('scores', 'rounds_completed');
  CALL check_column('scores', 'created_at');

  -- ------- FRIENDSHIPS COLUMNS (6) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- friendships columns (6) ---');
  CALL check_column('friendships', 'id');
  CALL check_column('friendships', 'requester_id');
  CALL check_column('friendships', 'addressee_id');
  CALL check_column('friendships', 'status');
  CALL check_column('friendships', 'created_at');
  CALL check_column('friendships', 'updated_at');

  -- ------- CHALLENGES COLUMNS (12) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- challenges columns (12) ---');
  CALL check_column('challenges', 'id');
  CALL check_column('challenges', 'challenger_id');
  CALL check_column('challenges', 'challenger_name');
  CALL check_column('challenges', 'challenged_id');
  CALL check_column('challenges', 'challenged_name');
  CALL check_column('challenges', 'status');
  CALL check_column('challenges', 'rounds');
  CALL check_column('challenges', 'winner_id');
  CALL check_column('challenges', 'challenger_coins');
  CALL check_column('challenges', 'challenged_coins');
  CALL check_column('challenges', 'created_at');
  CALL check_column('challenges', 'completed_at');

  -- ------- MATCHMAKING_POOL COLUMNS (11) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- matchmaking_pool columns (11) ---');
  CALL check_column('matchmaking_pool', 'id');
  CALL check_column('matchmaking_pool', 'user_id');
  CALL check_column('matchmaking_pool', 'region');
  CALL check_column('matchmaking_pool', 'seed');
  CALL check_column('matchmaking_pool', 'rounds');
  CALL check_column('matchmaking_pool', 'elo_rating');
  CALL check_column('matchmaking_pool', 'gameplay_version');
  CALL check_column('matchmaking_pool', 'created_at');
  CALL check_column('matchmaking_pool', 'matched_at');
  CALL check_column('matchmaking_pool', 'matched_with');
  CALL check_column('matchmaking_pool', 'challenge_id');

  -- ------- RLS ENABLED (7) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- RLS enabled (7) ---');
  CALL check_rls('profiles');
  CALL check_rls('user_settings');
  CALL check_rls('account_state');
  CALL check_rls('scores');
  CALL check_rls('friendships');
  CALL check_rls('challenges');
  CALL check_rls('matchmaking_pool');

  -- ------- ALL RLS POLICIES (24) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- RLS policies (24) ---');
  -- profiles (4)
  CALL check_policy('profiles', 'Users can read own profile');
  CALL check_policy('profiles', 'Users can insert own profile');
  CALL check_policy('profiles', 'Users can update own profile');
  CALL check_policy('profiles', 'Profiles are publicly readable');
  -- user_settings (3)
  CALL check_policy('user_settings', 'Users can read own settings');
  CALL check_policy('user_settings', 'Users can insert own settings');
  CALL check_policy('user_settings', 'Users can update own settings');
  -- account_state (3)
  CALL check_policy('account_state', 'Users can read own account state');
  CALL check_policy('account_state', 'Users can insert own account state');
  CALL check_policy('account_state', 'Users can update own account state');
  -- scores (2)
  CALL check_policy('scores', 'Scores are viewable by everyone');
  CALL check_policy('scores', 'Users can insert own scores');
  -- friendships (4)
  CALL check_policy('friendships', 'Users can see own friendships');
  CALL check_policy('friendships', 'Users can send friend requests');
  CALL check_policy('friendships', 'Addressee can respond to friend requests');
  CALL check_policy('friendships', 'Users can remove friendships');
  -- challenges (3)
  CALL check_policy('challenges', 'Players can see own challenges');
  CALL check_policy('challenges', 'Challenger can create challenges');
  CALL check_policy('challenges', 'Players can update own challenges');
  -- matchmaking_pool (4)
  CALL check_policy('matchmaking_pool', 'Users can insert own entries');
  CALL check_policy('matchmaking_pool', 'Users can read own or matched entries');
  CALL check_policy('matchmaking_pool', 'Users can update own entries on match');
  CALL check_policy('matchmaking_pool', 'Allow pool size counting for stats');

  -- ------- TRIGGERS (5) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Triggers (5) ---');
  CALL check_trigger('on_auth_user_created');
  CALL check_trigger('trg_profiles_updated_at');
  CALL check_trigger('trg_user_settings_updated_at');
  CALL check_trigger('trg_account_state_updated_at');
  CALL check_trigger('trg_friendships_updated_at');

  -- ------- FUNCTIONS (9) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Functions (9) ---');
  CALL check_function('handle_new_user');
  CALL check_function('update_updated_at');
  CALL check_function('purchase_cosmetic');
  CALL check_function('purchase_avatar_part');
  CALL check_function('send_coins');
  CALL check_function('gift_cosmetic');
  CALL check_function('gift_avatar_part');
  CALL check_function('expire_stale_challenges');
  CALL check_function('admin_increment_stat');

  -- ------- VIEWS (4) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Views (4) ---');
  CALL check_view('leaderboard_global');
  CALL check_view('leaderboard_daily');
  CALL check_view('leaderboard_regional');
  CALL check_view('daily_streak_leaderboard');

  -- ------- INDEXES (11) -------
  _results := array_append(_results, '');
  _results := array_append(_results, '--- Indexes (11) ---');
  CALL check_index('idx_scores_leaderboard');
  CALL check_index('idx_scores_user');
  CALL check_index('idx_scores_global_rank');
  CALL check_index('idx_scores_daily_rank');
  CALL check_index('idx_profiles_username');
  CALL check_index('idx_friendships_requester');
  CALL check_index('idx_friendships_addressee');
  CALL check_index('idx_challenges_challenger');
  CALL check_index('idx_challenges_challenged');
  CALL check_index('idx_matchmaking_unmatched');
  CALL check_index('idx_matchmaking_user');

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
  DECLARE
    line TEXT;
  BEGIN
    FOREACH line IN ARRAY _results LOOP
      RAISE NOTICE '%', line;
    END LOOP;
  END;
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

  -- Auth trigger
  SELECT 'trigger', 'on_auth_user_created',
    EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='on_auth_user_created')

  UNION ALL

  -- RLS enabled
  SELECT 'rls', t,
    EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=t AND c.relrowsecurity)
  FROM unnest(ARRAY['profiles','user_settings','account_state','scores','friendships','challenges','matchmaking_pool']) t
)
SELECT
  CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status,
  category,
  name
FROM checks
ORDER BY ok, category, name;
