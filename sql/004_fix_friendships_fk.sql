-- 004_fix_friendships_fk.sql
-- Add direct FK constraints from friendships → profiles so PostgREST can
-- resolve embedded resource joins (e.g. profiles!fk_friendships_requester_profiles)
-- without needing to traverse through auth.users.
--
-- This mirrors the existing pattern used for the scores table (fk_scores_profiles).
--
-- Without these FKs, fetchFriends / fetchPendingRequests / fetchSentRequests all
-- fail silently because PostgREST cannot join profiles through an auth.users FK.
--
-- NOTE: Idempotent — safe to re-run.

-- FK: friendships.requester_id → profiles.id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_friendships_requester_profiles'
      AND table_schema = 'public'
      AND table_name = 'friendships'
  ) THEN
    ALTER TABLE public.friendships
      ADD CONSTRAINT fk_friendships_requester_profiles
      FOREIGN KEY (requester_id) REFERENCES public.profiles(id);
  END IF;
END $$;

-- FK: friendships.addressee_id → profiles.id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_friendships_addressee_profiles'
      AND table_schema = 'public'
      AND table_name = 'friendships'
  ) THEN
    ALTER TABLE public.friendships
      ADD CONSTRAINT fk_friendships_addressee_profiles
      FOREIGN KEY (addressee_id) REFERENCES public.profiles(id);
  END IF;
END $$;
