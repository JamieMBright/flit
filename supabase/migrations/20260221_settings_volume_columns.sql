-- Add separate music and effects volume columns to user_settings.
-- Both are 0.0–1.0 multipliers; default 1.0 (full volume).
-- These allow users to independently control background music and
-- game effects (engine sounds, SFX) volume levels.

ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS music_volume DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS effects_volume DOUBLE PRECISION NOT NULL DEFAULT 1.0;
