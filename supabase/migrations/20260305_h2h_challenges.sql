-- H2H Flight School Challenges (best-of-3)
-- Each challenge has 3 rounds with level, category, difficulty, and a
-- deterministic seed so both players get the same questions.

create table if not exists public.h2h_challenges (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references auth.users(id) on delete cascade,
  challenger_name text not null default '',
  challenged_id uuid not null references auth.users(id) on delete cascade,
  challenged_name text not null default '',
  rounds jsonb not null default '[]'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'in_progress', 'completed', 'declined', 'expired')),
  winner_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- Indexes for common queries
create index if not exists idx_h2h_challenges_challenger
  on public.h2h_challenges (challenger_id);

create index if not exists idx_h2h_challenges_challenged
  on public.h2h_challenges (challenged_id);

create index if not exists idx_h2h_challenges_status
  on public.h2h_challenges (status);

create index if not exists idx_h2h_challenges_created
  on public.h2h_challenges (created_at desc);

-- RLS: enable row-level security
alter table public.h2h_challenges enable row level security;

-- Policy: players can read challenges they are part of
create policy "h2h_challenges_select_own"
  on public.h2h_challenges
  for select
  using (
    auth.uid() = challenger_id or auth.uid() = challenged_id
  );

-- Policy: authenticated users can create challenges where they are the challenger
create policy "h2h_challenges_insert_own"
  on public.h2h_challenges
  for insert
  with check (
    auth.uid() = challenger_id
  );

-- Policy: participants can update challenges they are part of
-- (for accepting, declining, submitting scores, completing)
create policy "h2h_challenges_update_own"
  on public.h2h_challenges
  for update
  using (
    auth.uid() = challenger_id or auth.uid() = challenged_id
  );
