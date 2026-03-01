-- 006_add_collaborator_role.sql
--
-- Adds the 'collaborator' admin role tier between moderator and owner.
--
-- Collaborators can edit difficulty ratings, feature flags, announcements,
-- and app config, but cannot touch the economy or perform destructive
-- actions (perma-ban, unban, role management).
--
-- Idempotent: uses DROP + re-add pattern for CHECK constraints.

-- ─── 1. Update profiles.admin_role CHECK constraint ─────────────────────────

-- Drop the old constraint (allows NULL, 'moderator', 'owner').
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_admin_role_check;

-- Add the updated constraint (allows NULL, 'moderator', 'collaborator', 'owner').
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_admin_role_check
    CHECK (admin_role IS NULL OR admin_role IN ('moderator', 'collaborator', 'owner'));

-- ─── 2. Update admin_set_role RPC to accept 'collaborator' ──────────────────

CREATE OR REPLACE FUNCTION public.admin_set_role(
  target_user_id UUID,
  p_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role
  FROM public.profiles WHERE id = auth.uid();

  IF v_role != 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can manage roles';
  END IF;

  -- Validate role value.
  IF p_role IS NOT NULL AND p_role NOT IN ('moderator', 'collaborator', 'owner') THEN
    RAISE EXCEPTION 'Invalid role: must be NULL, moderator, collaborator, or owner';
  END IF;

  -- Prevent demoting self.
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;

  UPDATE public.profiles SET admin_role = p_role WHERE id = target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_role(UUID, TEXT) TO service_role;
