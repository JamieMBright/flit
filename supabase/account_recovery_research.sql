-- =============================================================================
-- Flit account recovery research queries
-- =============================================================================
-- Purpose:
--   1) Inspect the current persisted account state for a specific username.
--   2) Reconstruct deducible gameplay stats from scores/challenges data.
--   3) Highlight gaps that cannot be reconstructed (notably coin balance).
--
-- Replace jamieb01 if you need to run this for a different user.
-- =============================================================================

-- 1) Current authoritative rows used by app login hydration.
with params as (
  select 'jamieb01'::text as username
),
target as (
  select id, username
  from public.profiles
  where username = (select username from params)
  limit 1
)
select
  p.id,
  p.username,
  p.display_name,
  p.level,
  p.xp,
  p.coins,
  p.games_played,
  p.best_score,
  p.best_time_ms,
  p.total_flight_time_ms,
  p.countries_found,
  p.flags_correct,
  p.capitals_correct,
  p.outlines_correct,
  p.borders_correct,
  p.stats_correct,
  p.best_streak,
  p.updated_at as profile_updated_at,
  ac.avatar_config,
  ac.license_data,
  ac.unlocked_regions,
  ac.owned_avatar_parts,
  ac.owned_cosmetics,
  ac.equipped_plane_id,
  ac.equipped_contrail_id,
  ac.equipped_title_id,
  ac.last_free_reroll_date,
  ac.last_daily_challenge_date,
  ac.daily_streak_data,
  ac.last_daily_result,
  ac.updated_at as account_state_updated_at
from target t
join public.profiles p on p.id = t.id
left join public.account_state ac on ac.user_id = t.id;

-- 2) Rebuild what can be inferred from game logs (scores/challenges).
-- NOTE: this can recover best score/time and total rounds played from scores.
with params as (
  select 'jamieb01'::text as username
),
target as (
  select id
  from public.profiles
  where username = (select username from params)
  limit 1
),
score_agg as (
  select
    s.user_id,
    count(*)::int as inferred_games_played,
    max(s.score)::int as inferred_best_score,
    min(s.time_ms)::int as inferred_best_time_ms,
    sum(s.time_ms)::bigint as inferred_total_time_ms,
    sum(s.rounds_completed)::int as inferred_rounds_completed
  from public.scores s
  join target t on t.id = s.user_id
  group by s.user_id
)
select
  p.username,
  p.games_played as stored_games_played,
  sa.inferred_games_played,
  p.best_score as stored_best_score,
  sa.inferred_best_score,
  p.best_time_ms as stored_best_time_ms,
  sa.inferred_best_time_ms,
  p.total_flight_time_ms as stored_total_flight_time_ms,
  sa.inferred_total_time_ms,
  p.coins as stored_coins,
  null::int as inferred_coins_unavailable
from public.profiles p
left join score_agg sa on sa.user_id = p.id
where p.username = (select username from params);

-- 3) Coin recovery note:
-- Coins cannot be accurately reconstructed from scores/challenges alone because
-- spend events (shop purchases/rerolls/unlocks) and coin grants may occur
-- outside scores. A dedicated coin ledger should be used for exact recovery.

-- 4) Inventory query to locate any potential coin/purchase log tables.
select
  table_schema,
  table_name,
  column_name
from information_schema.columns
where table_schema = 'public'
  and (
    table_name ilike '%coin%'
    or table_name ilike '%purchase%'
    or table_name ilike '%transaction%'
    or table_name ilike '%log%'
    or column_name ilike '%coin%'
    or column_name ilike '%purchase%'
    or column_name ilike '%transaction%'
  )
order by table_name, ordinal_position;

-- 5) Challenge-coin audit using discovered columns.
-- Interprets challenger_coins/challenged_coins as post-match coin deltas.
with params as (
  select 'jamieb01'::text as username
),
target as (
  select id, username, coins
  from public.profiles
  where username = (select username from params)
  limit 1
),
challenge_coin_events as (
  select
    c.id as challenge_id,
    c.completed_at,
    case
      when c.challenger_id = t.id then c.challenger_coins
      when c.challenged_id = t.id then c.challenged_coins
      else null
    end as coin_delta
  from public.challenges c
  join target t
    on c.challenger_id = t.id
    or c.challenged_id = t.id
  where c.status = 'completed'
)
select
  t.username,
  t.coins as stored_profile_coins,
  count(*)::int as completed_challenges_with_coin_entry,
  coalesce(sum(e.coin_delta), 0)::bigint as challenge_coin_delta_sum,
  coalesce(avg(e.coin_delta), 0)::numeric(10,2) as avg_coin_delta_per_match,
  min(e.completed_at) as first_completed_match_at,
  max(e.completed_at) as last_completed_match_at
from target t
left join challenge_coin_events e on true
group by t.username, t.coins;
