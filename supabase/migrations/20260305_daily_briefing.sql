-- Daily Flight Briefing scores table.
--
-- Stores one row per player per day. The unique constraint on
-- (user_id, date_key) enforces the "one attempt per day" rule at the
-- database level.

create table if not exists public.daily_briefing_scores (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  date_key   text not null,            -- 'YYYY-MM-DD'
  score      int  not null default 0,
  time_ms    int  not null default 0,
  level_id   text not null,            -- flight school level id (e.g. 'europe')
  category   text not null,            -- quiz category name
  difficulty text not null,            -- easy / medium / hard
  mode       text not null,            -- allStates / timeTrial / rapidFire
  created_at timestamptz not null default now()
);

-- One attempt per player per day.
alter table public.daily_briefing_scores
  add constraint daily_briefing_scores_user_date_unique
  unique (user_id, date_key);

-- Fast leaderboard lookup: top scores for a given day.
create index if not exists idx_daily_briefing_scores_date_score
  on public.daily_briefing_scores (date_key, score desc);

-- Player history lookup.
create index if not exists idx_daily_briefing_scores_user
  on public.daily_briefing_scores (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------

alter table public.daily_briefing_scores enable row level security;

-- Anyone can read all scores (leaderboard is public).
create policy "Anyone can read daily briefing scores"
  on public.daily_briefing_scores
  for select
  using (true);

-- Authenticated users can insert their own scores only.
create policy "Users can insert own daily briefing scores"
  on public.daily_briefing_scores
  for insert
  with check (auth.uid() = user_id);

-- Users can update their own scores (not expected, but safe).
create policy "Users can update own daily briefing scores"
  on public.daily_briefing_scores
  for update
  using (auth.uid() = user_id);
