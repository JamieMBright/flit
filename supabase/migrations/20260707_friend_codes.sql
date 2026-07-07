-- Friend codes: a short, shareable per-player code so pilots can add each
-- other without knowing an exact username (great for adding real-life friends).
--
-- profiles is publicly readable (see rebuild.sql "Profiles are publicly
-- readable"), so friend-code LOOKUP is a plain indexed .eq('friend_code', …)
-- from the client — no RPC needed. This migration only adds the column, a
-- generator, a one-time backfill, and an insert trigger so every profile
-- (existing and future) has a unique code.
--
-- Codes use a Crockford-style base32 alphabet (no I/L/O/U → no visual
-- ambiguity when typed) and are 6 chars → ~1e9 space, collisions negligible.
--
-- APPLIED TO PRODUCTION 2026-07-07.
-- Safe/additive: nullable column + backfill; where not applied the client
-- feature-detects (friend-code UI hides, username search still works).

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS friend_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_friend_code
  ON public.profiles (friend_code)
  WHERE friend_code IS NOT NULL;

-- Random 6-char code from an unambiguous alphabet.
CREATE OR REPLACE FUNCTION public.gen_friend_code(len INT DEFAULT 6)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; -- Crockford base32
  result   TEXT := '';
  i        INT;
BEGIN
  FOR i IN 1..len LOOP
    result := result || substr(
      alphabet,
      1 + floor(random() * length(alphabet))::int,
      1
    );
  END LOOP;
  RETURN result;
END;
$$;

-- Assign a unique code on insert when one wasn't supplied. The loop retries on
-- the (astronomically rare) collision; the unique index is the hard guard.
CREATE OR REPLACE FUNCTION public.assign_friend_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  candidate TEXT;
BEGIN
  IF NEW.friend_code IS NULL THEN
    LOOP
      candidate := public.gen_friend_code();
      IF NOT EXISTS (
        SELECT 1 FROM public.profiles WHERE friend_code = candidate
      ) THEN
        NEW.friend_code := candidate;
        EXIT;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_friend_code ON public.profiles;
CREATE TRIGGER trg_assign_friend_code
  BEFORE INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_friend_code();

-- Backfill every existing profile that lacks a code.
DO $$
DECLARE
  r         RECORD;
  candidate TEXT;
BEGIN
  FOR r IN SELECT id FROM public.profiles WHERE friend_code IS NULL LOOP
    LOOP
      candidate := public.gen_friend_code();
      BEGIN
        UPDATE public.profiles SET friend_code = candidate WHERE id = r.id;
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        -- retry with a fresh candidate
      END;
    END LOOP;
  END LOOP;
END $$;
