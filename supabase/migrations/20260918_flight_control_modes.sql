-- Continuous real-time flight control settings.
-- Keep enable_joystick for one release so rollback to the previous client
-- remains possible. New clients write both the legacy flag and these fields.

ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS control_mode TEXT NOT NULL DEFAULT 'classic',
  ADD COLUMN IF NOT EXISTS control_placement TEXT NOT NULL DEFAULT 'lowerCenter',
  ADD COLUMN IF NOT EXISTS clue_trigger TEXT NOT NULL DEFAULT 'button';

-- Migrate the old boolean only where the new column still has its default.
UPDATE public.user_settings
SET control_mode = 'joystick'
WHERE enable_joystick = TRUE AND control_mode = 'classic';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_settings_control_mode_check'
      AND conrelid = 'public.user_settings'::regclass
  ) THEN
    ALTER TABLE public.user_settings
      ADD CONSTRAINT user_settings_control_mode_check
      CHECK (control_mode IN ('classic', 'dPad', 'joystick'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_settings_control_placement_check'
      AND conrelid = 'public.user_settings'::regclass
  ) THEN
    ALTER TABLE public.user_settings
      ADD CONSTRAINT user_settings_control_placement_check
      CHECK (control_placement IN ('left', 'right', 'lowerCenter'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_settings_clue_trigger_check'
      AND conrelid = 'public.user_settings'::regclass
  ) THEN
    ALTER TABLE public.user_settings
      ADD CONSTRAINT user_settings_clue_trigger_check
      CHECK (clue_trigger IN ('button', 'controlDoubleTap'));
  END IF;
END $$;
