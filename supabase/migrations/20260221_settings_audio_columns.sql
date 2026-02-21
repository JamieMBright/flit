-- Add sound, notifications, and haptic feedback columns to user_settings.
-- These were previously ephemeral (local widget state only) and are now
-- persisted per-user so they survive app restarts.

ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS sound_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS haptic_enabled BOOLEAN NOT NULL DEFAULT TRUE;
