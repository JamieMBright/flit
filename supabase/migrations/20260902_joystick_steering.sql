-- Add the opt-in central joystick control without changing existing defaults.
ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS enable_joystick BOOLEAN NOT NULL DEFAULT FALSE;