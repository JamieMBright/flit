-- Migration: 20260320_ban_streak_improvements
--
-- Summary of changes (all already applied live):
--
-- 1. profiles table: add banned_by (UUID FK → auth.users) and unban_reason (TEXT)
--    columns to track who issued a ban and the reason for lifting it.
--
-- 2. admin_ban_user: records the calling admin's user ID in banned_by so bans
--    are fully auditable without relying solely on the admin_audit_log table.
--
-- 3. admin_unban_user: accepts an optional p_unban_reason parameter, clears
--    banned_by on unban, persists the unban reason, and includes it in the
--    audit log entry.
--
-- 4. protect_daily_streak trigger: guards account_state.daily_streak_data
--    against stale writes that would otherwise reset streaks. The trigger
--    preserves the highest observed values for current_streak (when a stale
--    write would regress it), longest_streak, and total_completed.

-- ---------------------------------------------------------------------------
-- 1. New columns on profiles
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS banned_by UUID DEFAULT NULL REFERENCES auth.users(id);
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS unban_reason TEXT DEFAULT NULL;

-- ---------------------------------------------------------------------------
-- 2. admin_ban_user — record the banning admin's ID
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_ban_user(
  target_user_id UUID,
  p_reason TEXT,
  p_duration_days INT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_target_role TEXT;
  caller_id UUID;
BEGIN
  caller_id := auth.uid();
  SELECT admin_role INTO v_role FROM profiles WHERE id = caller_id;
  IF v_role IS NULL THEN RAISE EXCEPTION 'Permission denied: not an admin'; END IF;

  -- Moderators: temp-ban only, max 30 days
  IF v_role = 'moderator' THEN
    IF p_duration_days IS NULL THEN
      RAISE EXCEPTION 'Moderators cannot issue permanent bans';
    END IF;
    IF p_duration_days > 30 THEN
      RAISE EXCEPTION 'Moderator ban limit: max 30 days';
    END IF;
  END IF;

  -- Cannot ban other admins unless you are owner
  SELECT admin_role INTO v_target_role FROM profiles WHERE id = target_user_id;
  IF v_target_role IS NOT NULL AND v_role != 'owner' THEN
    RAISE EXCEPTION 'Only owners can ban other admins';
  END IF;

  UPDATE profiles SET
    banned_at = NOW(),
    ban_expires_at = CASE WHEN p_duration_days IS NOT NULL
                     THEN NOW() + (p_duration_days || ' days')::INTERVAL
                     ELSE NULL END,
    ban_reason = p_reason,
    banned_by = caller_id
  WHERE id = target_user_id;

  -- Audit log
  PERFORM _log_admin_action(
    'ban_user',
    target_user_id,
    jsonb_build_object('reason', p_reason, 'duration_days', p_duration_days)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_ban_user(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_ban_user(UUID, TEXT, INT) TO service_role;

-- ---------------------------------------------------------------------------
-- 3. admin_unban_user — accept unban reason, clear banned_by, log reason
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_unban_user(
  target_user_id UUID,
  p_unban_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Only owners can lift bans'; END IF;

  UPDATE profiles SET
    banned_at = NULL,
    ban_expires_at = NULL,
    ban_reason = NULL,
    banned_by = NULL,
    unban_reason = p_unban_reason
  WHERE id = target_user_id;

  PERFORM _log_admin_action('unban_user', target_user_id, jsonb_build_object(
    'unban_reason', p_unban_reason
  ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_unban_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unban_user(UUID, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- 4. protect_daily_streak trigger on account_state
-- ---------------------------------------------------------------------------

-- Prevent stale writes from overwriting daily streak data
CREATE OR REPLACE FUNCTION protect_daily_streak_data()
RETURNS TRIGGER AS $$
DECLARE
  old_streak JSONB;
  new_streak JSONB;
  old_current INT;
  new_current INT;
  old_longest INT;
  new_longest INT;
  old_total INT;
  new_total INT;
  old_date TEXT;
  new_date TEXT;
BEGIN
  old_streak := COALESCE(OLD.daily_streak_data, '{}'::jsonb);
  new_streak := COALESCE(NEW.daily_streak_data, '{}'::jsonb);

  old_current := COALESCE((old_streak->>'current_streak')::int, 0);
  new_current := COALESCE((new_streak->>'current_streak')::int, 0);
  old_longest := COALESCE((old_streak->>'longest_streak')::int, 0);
  new_longest := COALESCE((new_streak->>'longest_streak')::int, 0);
  old_total   := COALESCE((old_streak->>'total_completed')::int, 0);
  new_total   := COALESCE((new_streak->>'total_completed')::int, 0);
  old_date    := old_streak->>'last_completion_date';
  new_date    := new_streak->>'last_completion_date';

  IF new_date IS NOT NULL AND old_date IS NOT NULL
     AND new_date <= old_date AND new_current < old_current THEN
    new_current := old_current;
  END IF;

  new_longest := GREATEST(old_longest, new_longest);
  new_total   := GREATEST(old_total, new_total);

  NEW.daily_streak_data := jsonb_build_object(
    'current_streak', new_current,
    'longest_streak', new_longest,
    'last_completion_date', COALESCE(new_date, old_date),
    'total_completed', new_total
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS protect_daily_streak ON account_state;
CREATE TRIGGER protect_daily_streak
  BEFORE UPDATE ON account_state
  FOR EACH ROW
  EXECUTE FUNCTION protect_daily_streak_data();
