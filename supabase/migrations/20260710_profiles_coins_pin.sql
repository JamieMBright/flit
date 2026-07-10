-- =============================================================================
-- Flit — profiles.coins server-authoritative pin (Section 8a, refined)
-- =============================================================================
-- Finding #5/#10 (client-authoritative economy): the client could write its own
-- coin balance directly. Fix: pin ONLY `coins` on the profiles UPDATE policy so
-- a direct client write is rejected; the SECURITY DEFINER earn_coins /
-- spend_coins RPCs (which derive the actor from auth.uid()) are the only credit
-- and debit paths and bypass RLS as the table owner.
--
-- IMPORTANT — pin `coins` ONLY. `xp` / `level` / `games_played` / `best_score` /
-- best_time and the per-clue counters are NOT pinned here: they have no
-- server-authoritative writer (submit_score inserts a scores row but does not
-- touch profiles progression) and are already guarded against rollback by the
-- monotonic ratchet trigger protect_profile_stats. Pinning them here (as an
-- earlier over-broad policy did) freezes progression AND rejects the client's
-- whole-row profile upsert, because the upsert then always carries a pinned
-- column that changed. This matches the migration 20260706 Section 8a intent.
--
-- Idempotent: DROP POLICY IF EXISTS + CREATE POLICY.
-- =============================================================================

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND COALESCE(coins, 0) = COALESCE(
      (SELECT p.coins FROM public.profiles p WHERE p.id = auth.uid()), 0)
  );
