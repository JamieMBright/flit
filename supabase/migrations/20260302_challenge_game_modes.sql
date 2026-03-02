-- Add game_mode support to challenges for multi-mode H2H (Flight School, etc.)

-- Add game_mode column to challenges (defaults to 'flight' for backwards compat)
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS game_mode TEXT NOT NULL DEFAULT 'flight'
    CHECK (game_mode IN ('flight', 'quiz'));

-- Add quiz-specific metadata columns
ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS quiz_category TEXT,
  ADD COLUMN IF NOT EXISTS quiz_mode TEXT;

-- Add game_mode to matchmaking_pool so players only match within the same mode
ALTER TABLE public.matchmaking_pool
  ADD COLUMN IF NOT EXISTS game_mode TEXT NOT NULL DEFAULT 'flight'
    CHECK (game_mode IN ('flight', 'quiz'));

-- Index for filtering challenges by game mode
CREATE INDEX IF NOT EXISTS idx_challenges_game_mode
  ON public.challenges (game_mode);

-- Update matchmaking index to include game_mode
CREATE INDEX IF NOT EXISTS idx_matchmaking_pool_game_mode
  ON public.matchmaking_pool (game_mode, matched_at, elo_rating);
