-- =============================================================================
-- Flit — Backend Security Hardening (WAVE 3)
-- =============================================================================
-- Source: launch-readiness security audit. Closes: privilege escalation /
-- infinite coins / self-unban, forgeable scores, coin-theft via caller-supplied
-- ids, unguarded economy config, ELO/inventory forgery, over-broad RLS, and the
-- Postgres "EXECUTE to PUBLIC" default that exposes every SECURITY DEFINER RPC
-- to anon/authenticated.
--
-- =============================================================================
--  !!! APPLY-HELD — DO NOT RUN THIS MIGRATION BEFORE THE CLIENT PR IS DEPLOYED
-- =============================================================================
-- This is a COORDINATED client + server change against a LIVE production DB.
-- Sections 1–7 are safe to apply ONLY AFTER the matching client PR has shipped
-- and rolled out, because the client must already:
--   * route score submission through submit_score() (with a direct-insert
--     fallback for the transition), and
--   * tolerate the auth.uid()-authoritative coin/economy RPCs.
-- The client PR is transition-safe on BOTH the un-hardened (today) and hardened
-- (post-apply) schema: every new RPC call feature-detects the function and
-- falls back to the current direct-write path when it is missing (42883 /
-- PGRST202). So the ORDER is mandatory:
--
--   (1) Ship the client PR (feature-detect + fallback everywhere).
--   (2) Confirm clients are updated (telemetry / store rollout complete).
--   (3) Apply THIS migration (sections 1–7).
--   (4) Review + optionally enable Section 8 (the final economy/inventory
--       LOCKDOWN) once you have confirmed every coin / xp / inventory write
--       path is routed through an RPC. Section 8 is intentionally left as a
--       commented, owner-reviewed block — running sections 1–7 does NOT apply
--       it.
--
-- Every statement is idempotent (CREATE OR REPLACE / IF (NOT) EXISTS guards),
-- so re-running is safe. Nothing here is destructive.
-- =============================================================================


-- =============================================================================
-- SECTION 1 (ACTIVE) — profiles: pin privileged columns on client UPDATE
-- -----------------------------------------------------------------------------
-- FINDING #1 (privilege escalation / self-unban): the profiles UPDATE policy is
-- USING(auth.uid()=id) with NO WITH CHECK, and protect_profile_stats() does not
-- guard admin_role or ban columns. A user can PATCH their own row to
-- admin_role='owner' or clear banned_at.
--
-- Fix: a BEFORE UPDATE trigger that force-pins the privileged identity/ban
-- columns to their OLD values on ANY write that does NOT come from a vetted
-- SECURITY DEFINER admin RPC. The three admin RPCs that legitimately mutate
-- these columns (admin_set_role / admin_ban_user / admin_unban_user) opt in by
-- setting a transaction-local session flag before their UPDATE; the trigger
-- honours that flag. A normal PostgREST client UPDATE never sets the flag, so
-- admin_role and every ban column become immutable from the client.
--
-- NOTE: coins / level / xp / best_score are NOT pinned here — they still flow
-- through the client's whole-row profile upsert today. Their server-authoritative
-- lockdown is Section 8 (deferred), enabled after the client routes all coin/xp
-- writes through RPCs. This section closes the SEVERE escalation + self-unban
-- holes immediately, with zero client impact (the client never writes these
-- columns).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Vetted admin RPCs set this transaction-local flag immediately before their
  -- UPDATE. Anything else (a raw client PATCH) leaves it unset and gets pinned.
  IF current_setting('app.allow_privileged_profile_write', true) = 'on' THEN
    RETURN NEW;
  END IF;

  -- Force privileged/security columns back to their stored values. A client can
  -- never escalate its role, ban/unban itself, or rewrite ban metadata.
  NEW.admin_role     := OLD.admin_role;
  NEW.banned_at      := OLD.banned_at;
  NEW.ban_expires_at := OLD.ban_expires_at;
  NEW.ban_reason     := OLD.ban_reason;
  NEW.banned_by      := OLD.banned_by;
  NEW.unban_reason   := OLD.unban_reason;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_privileged ON public.profiles;
CREATE TRIGGER trg_protect_profile_privileged
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privileged_columns();

-- Redefine the three admin RPCs that legitimately write the pinned columns so
-- they opt in to the bypass. Bodies are otherwise byte-for-byte identical to
-- rebuild.sql; only the `set_config(...)` line before the UPDATE is new.

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

  -- IS DISTINCT FROM correctly rejects NULL (non-admin) callers; a bare
  -- `v_role != 'owner'` evaluates to NULL for NULL v_role and FAILS OPEN.
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can manage roles';
  END IF;

  IF p_role IS NOT NULL AND p_role NOT IN ('moderator', 'collaborator', 'owner') THEN
    RAISE EXCEPTION 'Invalid role: must be NULL, moderator, collaborator, or owner';
  END IF;

  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;

  -- Opt in to the privileged-column bypass for this UPDATE only.
  PERFORM set_config('app.allow_privileged_profile_write', 'on', true);
  UPDATE public.profiles SET admin_role = p_role WHERE id = target_user_id;
END;
$$;

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

  IF v_role = 'moderator' THEN
    IF p_duration_days IS NULL THEN
      RAISE EXCEPTION 'Moderators cannot issue permanent bans';
    END IF;
    IF p_duration_days > 30 THEN
      RAISE EXCEPTION 'Moderator ban limit: max 30 days';
    END IF;
  END IF;

  SELECT admin_role INTO v_target_role FROM profiles WHERE id = target_user_id;
  IF v_target_role IS NOT NULL AND v_role != 'owner' THEN
    RAISE EXCEPTION 'Only owners can ban other admins';
  END IF;

  PERFORM set_config('app.allow_privileged_profile_write', 'on', true);
  UPDATE profiles SET
    banned_at = NOW(),
    ban_expires_at = CASE WHEN p_duration_days IS NOT NULL
                     THEN NOW() + (p_duration_days || ' days')::INTERVAL
                     ELSE NULL END,
    ban_reason = p_reason,
    banned_by = caller_id
  WHERE id = target_user_id;

  PERFORM _log_admin_action(
    'ban_user',
    target_user_id,
    jsonb_build_object('reason', p_reason, 'duration_days', p_duration_days)
  );
END;
$$;

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
  -- IS DISTINCT FROM rejects NULL-role callers (bare != fails open on NULL).
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Only owners can lift bans'; END IF;

  PERFORM set_config('app.allow_privileged_profile_write', 'on', true);
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


-- =============================================================================
-- SECTION 2 (ACTIVE) — coin RPCs: actor = auth.uid(), never a caller parameter
-- -----------------------------------------------------------------------------
-- FINDING #3 (coin theft): send_coins/purchase_*/gift_* trust the sender/user/
-- gifter id PARAMETER, so a JWT holder can spend from or credit any account.
--
-- Fix: force the acting account to auth.uid() and IGNORE the caller-supplied id.
-- Signatures are UNCHANGED (the id parameter is still accepted for wire
-- compatibility with today's clients — it is simply overridden), so existing
-- clients keep working before and after apply. Recipients (gifts/transfers) are
-- still taken from parameters, which is correct — you choose who to gift.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.purchase_cosmetic(
  p_user_id UUID,
  p_cosmetic_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_user_id ignored
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;

  SELECT coins INTO v_current_coins
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current_coins, 'cost', p_cost);
  END IF;

  SELECT owned_cosmetics INTO v_owned
  FROM public.account_state WHERE user_id = v_user_id;

  IF v_owned IS NOT NULL AND p_cosmetic_id = ANY(v_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already owned',
      'current_balance', v_current_coins);
  END IF;

  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_user_id;

  INSERT INTO public.account_state (user_id, owned_cosmetics)
  VALUES (v_user_id, ARRAY[p_cosmetic_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_cosmetics = array_append(
    COALESCE(account_state.owned_cosmetics, '{}'), p_cosmetic_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'cosmetic_id', p_cosmetic_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.purchase_avatar_part(
  p_user_id UUID,
  p_part_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_user_id ignored
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_part_id IS NULL OR p_part_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid part ID');
  END IF;

  SELECT coins INTO v_current_coins
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current_coins, 'cost', p_cost);
  END IF;

  SELECT owned_avatar_parts INTO v_owned
  FROM public.account_state WHERE user_id = v_user_id;

  IF v_owned IS NOT NULL AND p_part_id = ANY(v_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already owned',
      'current_balance', v_current_coins);
  END IF;

  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_user_id;

  INSERT INTO public.account_state (user_id, owned_avatar_parts)
  VALUES (v_user_id, ARRAY[p_part_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_avatar_parts = array_append(
    COALESCE(account_state.owned_avatar_parts, '{}'), p_part_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'part_id', p_part_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_coins(
  p_sender_id UUID,
  p_recipient_id UUID,
  p_amount INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_sender_id ignored
  v_sender_coins INT;
  v_recipient_coins INT;
  v_sender_balance INT;
  v_sender_username TEXT;
  v_recipient_username TEXT;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;
  IF v_sender_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send coins to yourself');
  END IF;

  SELECT coins INTO v_sender_coins
  FROM public.profiles WHERE id = v_sender_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sender not found');
  END IF;
  IF v_sender_coins < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_sender_coins);
  END IF;

  SELECT coins INTO v_recipient_coins
  FROM public.profiles WHERE id = p_recipient_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient not found');
  END IF;

  v_sender_balance := v_sender_coins - p_amount;
  UPDATE public.profiles SET coins = v_sender_balance WHERE id = v_sender_id;
  UPDATE public.profiles SET coins = v_recipient_coins + p_amount WHERE id = p_recipient_id;

  SELECT username INTO v_sender_username FROM public.profiles WHERE id = v_sender_id;
  SELECT username INTO v_recipient_username FROM public.profiles WHERE id = p_recipient_id;

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (v_sender_id, COALESCE(NULLIF(v_sender_username, ''), v_sender_id::TEXT),
    -p_amount, 'gift_sent', v_sender_balance);

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (p_recipient_id, COALESCE(NULLIF(v_recipient_username, ''), p_recipient_id::TEXT),
    p_amount, 'gift_received', v_recipient_coins + p_amount);

  RETURN jsonb_build_object('success', true,
    'sender_balance', v_sender_balance, 'amount', p_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public.gift_cosmetic(
  p_gifter_id UUID,
  p_recipient_id UUID,
  p_cosmetic_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gifter_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_gifter_id ignored
  v_gifter_coins INT;
  v_recipient_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_gifter_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;
  IF v_gifter_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot gift to yourself');
  END IF;

  SELECT coins INTO v_gifter_coins
  FROM public.profiles WHERE id = v_gifter_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gifter not found');
  END IF;
  IF v_gifter_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_gifter_coins, 'cost', p_cost);
  END IF;

  SELECT owned_cosmetics INTO v_recipient_owned
  FROM public.account_state WHERE user_id = p_recipient_id;
  IF v_recipient_owned IS NOT NULL AND p_cosmetic_id = ANY(v_recipient_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient already owns this');
  END IF;

  v_new_balance := v_gifter_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_gifter_id;

  INSERT INTO public.account_state (user_id, owned_cosmetics)
  VALUES (p_recipient_id, ARRAY[p_cosmetic_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_cosmetics = array_append(
    COALESCE(account_state.owned_cosmetics, '{}'), p_cosmetic_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'cosmetic_id', p_cosmetic_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.gift_avatar_part(
  p_gifter_id UUID,
  p_recipient_id UUID,
  p_part_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gifter_id UUID := auth.uid();  -- actor is ALWAYS the caller; p_gifter_id ignored
  v_gifter_coins INT;
  v_recipient_owned TEXT[];
  v_new_balance INT;
BEGIN
  IF v_gifter_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;
  IF p_part_id IS NULL OR p_part_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid part ID');
  END IF;
  IF v_gifter_id = p_recipient_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot gift to yourself');
  END IF;

  SELECT coins INTO v_gifter_coins
  FROM public.profiles WHERE id = v_gifter_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gifter not found');
  END IF;
  IF v_gifter_coins < p_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_gifter_coins, 'cost', p_cost);
  END IF;

  SELECT owned_avatar_parts INTO v_recipient_owned
  FROM public.account_state WHERE user_id = p_recipient_id;
  IF v_recipient_owned IS NOT NULL AND p_part_id = ANY(v_recipient_owned) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipient already owns this');
  END IF;

  v_new_balance := v_gifter_coins - p_cost;
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_gifter_id;

  INSERT INTO public.account_state (user_id, owned_avatar_parts)
  VALUES (p_recipient_id, ARRAY[p_part_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_avatar_parts = array_append(
    COALESCE(account_state.owned_avatar_parts, '{}'), p_part_id
  );

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance,
    'part_id', p_part_id);
END;
$$;


-- =============================================================================
-- SECTION 3 (ACTIVE) — server-authoritative generic coin earn / spend RPCs
-- -----------------------------------------------------------------------------
-- FINDING #1/#3 (coin authority): today the client persists coins by writing
-- the whole profiles row (coins column) directly, so any balance is forgeable.
-- These RPCs give a legitimate, auth.uid()-scoped, audited path for generic
-- coin earn/spend so the client can stop writing coins directly and Section 8
-- can eventually pin the coins column.
--
--   * earn_coins:  credits the CALLER only, capped per call, logs coin_activity.
--     NOTE: the amount still originates client-side, so this is NOT a full
--     anti-inflation control — it bounds/audits/authenticates the credit. True
--     reward re-computation requires server-side game validation (out of scope;
--     tracked for a later wave).
--   * spend_coins: atomically checks the CALLER's balance server-side and
--     refuses to overspend / go negative — a real integrity gain over the
--     client-authoritative debit.
--
-- Both set the Section-1 privileged-write flag is NOT needed (coins is not a
-- pinned column yet); they set the Section-8 coin-write flag so they already
-- bypass the (future) coins pin the moment the owner enables it.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.earn_coins(
  p_amount INT,
  p_source TEXT DEFAULT 'coins_earned'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_username TEXT;
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;
  -- Sanity cap: no single legitimate reward approaches this. Blocks absurd grants.
  IF p_amount > 100000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount exceeds per-call cap');
  END IF;

  -- Forward-compat: bypass the (deferred) Section-8 coins pin when enabled.
  PERFORM set_config('app.allow_coin_write', 'on', true);

  UPDATE public.profiles
  SET coins = COALESCE(coins, 0) + p_amount
  WHERE id = v_user_id
  RETURNING coins, username INTO v_new_balance, v_username;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (v_user_id, COALESCE(NULLIF(v_username, ''), v_user_id::TEXT),
    p_amount, LEFT(COALESCE(NULLIF(TRIM(p_source), ''), 'coins_earned'), 64), v_new_balance);

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance);
END;
$$;

CREATE OR REPLACE FUNCTION public.spend_coins(
  p_amount INT,
  p_source TEXT DEFAULT 'coins_spent'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_username TEXT;
  v_current INT;
  v_new_balance INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  SELECT coins INTO v_current
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;
  IF v_current < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient coins',
      'current_balance', v_current);
  END IF;

  v_new_balance := v_current - p_amount;

  PERFORM set_config('app.allow_coin_write', 'on', true);
  UPDATE public.profiles SET coins = v_new_balance WHERE id = v_user_id
  RETURNING username INTO v_username;

  INSERT INTO public.coin_activity (user_id, username, coin_amount, source, balance_after)
  VALUES (v_user_id, COALESCE(NULLIF(v_username, ''), v_user_id::TEXT),
    -p_amount, LEFT(COALESCE(NULLIF(TRIM(p_source), ''), 'coins_spent'), 64), v_new_balance);

  RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance);
END;
$$;


-- =============================================================================
-- SECTION 4 (ACTIVE) — server-authoritative score submission
-- -----------------------------------------------------------------------------
-- FINDING #2 (forgeable scores): scores rows are inserted directly by the client
-- with only a CHECK(score 0..100000). Any JWT holder can insert a perfect score.
--
-- Fix: submit_score() forces user_id = auth.uid(), re-validates bounds
-- server-side, and inserts. The client prefers this RPC and falls back to the
-- (still-granted, for the transition) direct INSERT when the function is
-- missing. Dropping the client INSERT grant is Section 8 (deferred) — do it only
-- after every client is on the RPC path.
--
-- One-per-day-per-mode is intentionally NOT enforced here: `scores` is an
-- append-only leaderboard feed deduped to best-per-user by the leaderboard view,
-- and multiple plays per day are legitimate. (Left as a documented future rule.)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.submit_score(
  p_score INT,
  p_time_ms BIGINT,
  p_region TEXT,
  p_rounds_completed INT DEFAULT 0,
  p_round_emojis TEXT DEFAULT NULL,
  p_round_details JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_score INT;
  v_time_ms BIGINT;
  v_rounds INT;
  v_region TEXT;
  v_id BIGINT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Server-side bounds (mirror the table CHECK + client clamp; authoritative).
  v_score   := GREATEST(0, LEAST(COALESCE(p_score, 0), 100000));
  v_time_ms := GREATEST(1, LEAST(COALESCE(p_time_ms, 1), 3600000));
  v_rounds  := GREATEST(0, LEAST(COALESCE(p_rounds_completed, 0), 100000));
  v_region  := LEFT(COALESCE(NULLIF(TRIM(p_region), ''), 'world'), 64);

  INSERT INTO public.scores
    (user_id, score, time_ms, region, rounds_completed, round_emojis, round_details)
  VALUES
    (v_user_id, v_score, v_time_ms, v_region, v_rounds, p_round_emojis, p_round_details)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id,
    'score', v_score, 'region', v_region);
END;
$$;


-- =============================================================================
-- SECTION 5 (ACTIVE) — economy_config: owner-gate + lock down
-- -----------------------------------------------------------------------------
-- FINDING #4: upsert_economy_config is SECURITY DEFINER with NO admin check and
-- relies on the PUBLIC default EXECUTE grant, so ANY authenticated (or, pre-sweep,
-- anon) user can overwrite global coin rewards + shop pricing.
--
-- Fix: in-body owner check + explicit REVOKE from PUBLIC/anon and GRANT to
-- authenticated only (the owner is an authenticated JWT user; the body gates it).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.upsert_economy_config(new_config JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM public.profiles WHERE id = auth.uid();
  -- IS DISTINCT FROM rejects NULL-role callers; a bare `!= 'owner'` returns
  -- NULL for a normal (NULL admin_role) user and would FAIL OPEN.
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can edit the economy config';
  END IF;

  INSERT INTO public.economy_config (id, config, updated_at)
  VALUES (1, new_config, NOW())
  ON CONFLICT (id) DO UPDATE SET config = new_config, updated_at = NOW();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.upsert_economy_config(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.upsert_economy_config(JSONB) FROM anon;
GRANT  EXECUTE ON FUNCTION public.upsert_economy_config(JSONB) TO authenticated;


-- =============================================================================
-- SECTION 5b (ACTIVE) — close fail-open owner checks (privilege escalation)
-- -----------------------------------------------------------------------------
-- BONUS FINDING surfaced while verifying finding #1/#4: several owner-gated
-- SECURITY DEFINER functions guard with `IF v_role != 'owner' THEN RAISE`.
-- For a normal user, admin_role is NULL, so `NULL != 'owner'` evaluates to NULL
-- (NOT true) and the RAISE is SKIPPED — the function FAILS OPEN. Proven on a
-- scratch DB: a NULL-role user could grant roles to other users, unlock-all,
-- unban, toggle feature flags, and overwrite difficulty/economy config.
--
-- Fix: replace the guard with `IF v_role IS DISTINCT FROM 'owner'`, which is
-- TRUE for NULL. Bodies below are extracted VERBATIM from rebuild.sql; only the
-- guard line is changed (admin_set_role / admin_unban_user / upsert_economy_config
-- are fixed in Sections 1 & 5; admin_ban_user already NULL-guards separately).
-- =============================================================================

-- admin_unlock_all: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.admin_unlock_all(
  target_user_id UUID
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

  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Permission denied: only owners can unlock all';
  END IF;

  -- Unlock all avatar parts: merge with existing.
  UPDATE public.account_state
  SET owned_avatar_parts = (
    SELECT ARRAY(
      SELECT DISTINCT unnest(owned_avatar_parts || ARRAY[
        -- All paid eye variants
        'eyes_variant14','eyes_variant15','eyes_variant16','eyes_variant17',
        'eyes_variant18','eyes_variant19','eyes_variant20','eyes_variant21',
        'eyes_variant22','eyes_variant23','eyes_variant24','eyes_variant25','eyes_variant26',
        -- All paid hair colors
        'hairColor_green','hairColor_teal','hairColor_pink','hairColor_purple',
        -- All paid glasses
        'glasses_variant01','glasses_variant02','glasses_variant03','glasses_variant04','glasses_variant05',
        -- All paid earrings
        'earrings_variant01','earrings_variant02','earrings_variant03',
        'earrings_variant04','earrings_variant05','earrings_variant06',
        -- All paid hair styles (short06-19, long06-26)
        'hair_short06','hair_short07','hair_short08','hair_short09','hair_short10',
        'hair_short11','hair_short12','hair_short13','hair_short14','hair_short15',
        'hair_short16','hair_short17','hair_short18','hair_short19',
        'hair_long06','hair_long07','hair_long08','hair_long09','hair_long10',
        'hair_long11','hair_long12','hair_long13','hair_long14','hair_long15',
        'hair_long16','hair_long17','hair_long18','hair_long19','hair_long20',
        'hair_long21','hair_long22','hair_long23','hair_long24','hair_long25','hair_long26',
        -- All paid eyebrow variants
        'eyebrows_variant09','eyebrows_variant10','eyebrows_variant11',
        'eyebrows_variant12','eyebrows_variant13','eyebrows_variant14','eyebrows_variant15',
        -- All paid mouth variants
        'mouth_variant16','mouth_variant17','mouth_variant18','mouth_variant19','mouth_variant20',
        'mouth_variant21','mouth_variant22','mouth_variant23','mouth_variant24','mouth_variant25',
        'mouth_variant26','mouth_variant27','mouth_variant28','mouth_variant29','mouth_variant30'
      ])
    )
  ),
  updated_at = NOW()
  WHERE user_id = target_user_id;

  -- Unlock all cosmetics (planes, contrails, companions).
  UPDATE public.account_state
  SET owned_cosmetics = (
    SELECT ARRAY(
      SELECT DISTINCT unnest(owned_cosmetics || ARRAY[
        'plane_paper','plane_prop','plane_padraigaer','plane_seaplane',
        'plane_jet','plane_red_baron','plane_rocket','plane_warbird',
        'plane_night_raider','plane_concorde_classic','plane_stealth',
        'plane_presidential','plane_golden_jet','plane_diamond_concorde',
        'plane_platinum_eagle',
        'contrail_fire','contrail_rainbow','contrail_sparkle','contrail_neon',
        'contrail_gold_dust','contrail_aurora','contrail_chemtrails',
        'companion_pidgey','companion_sparrow','companion_eagle',
        'companion_parrot','companion_phoenix','companion_dragon',
        'companion_charizard'
      ])
    )
  ),
  updated_at = NOW()
  WHERE user_id = target_user_id;
END;
$$;

-- admin_update_app_config: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.admin_update_app_config(
  p_min_version TEXT DEFAULT NULL,
  p_recommended_version TEXT DEFAULT NULL,
  p_maintenance_mode BOOLEAN DEFAULT NULL,
  p_maintenance_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  UPDATE app_config SET
    min_app_version = COALESCE(p_min_version, min_app_version),
    recommended_version = COALESCE(p_recommended_version, recommended_version),
    maintenance_mode = COALESCE(p_maintenance_mode, maintenance_mode),
    maintenance_message = COALESCE(p_maintenance_message, maintenance_message),
    updated_at = NOW()
  WHERE id = 1;

  PERFORM _log_admin_action(
    'update_app_config',
    NULL,
    jsonb_build_object(
      'min_version', p_min_version,
      'recommended_version', p_recommended_version,
      'maintenance_mode', p_maintenance_mode
    )
  );
END;
$$;

-- admin_set_feature_flag: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.admin_set_feature_flag(
  p_flag_key TEXT,
  p_enabled BOOLEAN,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  INSERT INTO feature_flags (flag_key, enabled, description, updated_by, updated_at)
  VALUES (p_flag_key, p_enabled, p_description, auth.uid(), NOW())
  ON CONFLICT (flag_key) DO UPDATE SET
    enabled = EXCLUDED.enabled,
    description = COALESCE(EXCLUDED.description, feature_flags.description),
    updated_by = EXCLUDED.updated_by,
    updated_at = NOW();

  PERFORM _log_admin_action(
    'set_feature_flag',
    NULL,
    jsonb_build_object('flag_key', p_flag_key, 'enabled', p_enabled)
  );
END;
$$;

-- admin_process_gdpr_request: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.admin_process_gdpr_request(
  p_request_id BIGINT,
  p_status TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Only owners can process GDPR requests';
  END IF;

  UPDATE gdpr_requests SET
    status = p_status,
    completed_at = CASE WHEN p_status IN ('completed', 'failed') THEN NOW() ELSE NULL END,
    processed_by = auth.uid(),
    notes = COALESCE(p_notes, notes)
  WHERE id = p_request_id;

  PERFORM _log_admin_action('process_gdpr_request', (SELECT user_id FROM gdpr_requests WHERE id = p_request_id), jsonb_build_object('request_id', p_request_id, 'status', p_status));
END;
$$;

-- upsert_difficulty_config: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.upsert_difficulty_config(
  p_country_overrides JSONB,
  p_clue_weights JSONB
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  INSERT INTO remote_config (key, value, updated_at)
  VALUES (
    'difficulty_config',
    jsonb_build_object(
      'country_overrides', p_country_overrides,
      'clue_weights', p_clue_weights
    ),
    NOW()
  )
  ON CONFLICT (key) DO UPDATE SET
    value = jsonb_build_object(
      'country_overrides', p_country_overrides,
      'clue_weights', p_clue_weights
    ),
    updated_at = NOW();

  PERFORM _log_admin_action(
    'upsert_difficulty_config',
    NULL,
    jsonb_build_object(
      'country_count', jsonb_array_length(
        COALESCE((SELECT jsonb_agg(k) FROM jsonb_object_keys(p_country_overrides) AS k), '[]'::jsonb)
      ),
      'clue_weight_count', jsonb_array_length(
        COALESCE((SELECT jsonb_agg(k) FROM jsonb_object_keys(p_clue_weights) AS k), '[]'::jsonb)
      )
    )
  );
END;
$$;

-- recalibrate_scores: fail-open guard -> IS DISTINCT FROM
CREATE OR REPLACE FUNCTION public.recalibrate_scores(
  country_multipliers JSONB
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_count INT := 0;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  -- Placeholder: log the recalibration request.
  -- Full implementation will iterate round_details to apply multipliers.
  PERFORM _log_admin_action(
    'recalibrate_scores',
    NULL,
    jsonb_build_object(
      'country_count', (SELECT count(*) FROM jsonb_object_keys(country_multipliers)),
      'scores_updated', v_count
    )
  );

  RETURN v_count;
END;
$$;



-- =============================================================================
-- SECTION 6 (ACTIVE) — RLS WITH CHECK tightening (identity/ownership pins)
-- -----------------------------------------------------------------------------
-- FINDING #5/#6: several UPDATE policies have USING but no WITH CHECK (or
-- WITH CHECK(true)), so the post-update row is unconstrained.
--
-- These ACTIVE pins add WITH CHECK clauses that keep a row OWNED BY / SCOPED TO
-- the caller after an update — they do NOT restrict which business columns
-- (winner_id, status, owned_cosmetics, …) can change, so they are safe for
-- today's clients. The stronger economy/result-column pins (winner_id + status
-- immutability, inventory anti-tamper) are Section 8 (deferred), gated on the
-- client routing all result/inventory writes through RPCs.
-- =============================================================================

-- challenges: post-update row must still belong to the caller as a participant.
DROP POLICY IF EXISTS "Players can update own challenges" ON public.challenges;
CREATE POLICY "Players can update own challenges"
  ON public.challenges FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challenged_id)
  WITH CHECK (auth.uid() = challenger_id OR auth.uid() = challenged_id);

-- h2h_challenges: same ownership pin.
DROP POLICY IF EXISTS "h2h_challenges_update_own" ON public.h2h_challenges;
CREATE POLICY "h2h_challenges_update_own"
  ON public.h2h_challenges FOR UPDATE
  USING (auth.uid() = challenger_id OR auth.uid() = challenged_id)
  WITH CHECK (auth.uid() = challenger_id OR auth.uid() = challenged_id);

-- account_state: post-update row must still be the caller's own row.
DROP POLICY IF EXISTS "Users can update own account state" ON public.account_state;
CREATE POLICY "Users can update own account state"
  ON public.account_state FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- matchmaking_pool: was WITH CHECK(true) — anyone could stamp any row into any
-- state. Constrain the post-update row to one the caller owns OR has claimed
-- as the matcher (matched_with = self). Preserves both legitimate client paths:
--   * updating your OWN entry to record the match (user_id = self), and
--   * claiming an opponent's unmatched entry (matched_with = self).
DROP POLICY IF EXISTS "Users can update own entries on match" ON public.matchmaking_pool;
CREATE POLICY "Users can update own entries on match"
  ON public.matchmaking_pool FOR UPDATE
  USING (auth.uid() = user_id OR matched_at IS NULL)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = matched_with);


-- =============================================================================
-- SECTION 7 (ACTIVE) — blanket EXECUTE lockdown + explicit re-grant allowlist
-- -----------------------------------------------------------------------------
-- FINDING #7: Postgres grants EXECUTE to PUBLIC by default, so EVERY function in
-- schema public (including all SECURITY DEFINER RPCs) is reachable by anon and
-- authenticated regardless of the explicit GRANTs in rebuild.sql/migrations.
--
-- Fix: revoke the PUBLIC + anon default, stop future functions inheriting it,
-- then GRANT EXECUTE back to `authenticated` for ONLY the functions clients
-- legitimately call. Internal helpers (_log_admin_action, _get_or_seed_rating)
-- and trigger functions are deliberately NOT re-granted — they run inside other
-- SECURITY DEFINER functions as the definer/owner and need no caller grant.
--
-- Every SECURITY DEFINER function on this list performs its own in-body auth
-- (auth.uid() ownership or admin_role check), so `authenticated` EXECUTE is safe;
-- the grant just makes the function reachable, the body decides who may act.
-- =============================================================================

-- 7a. Remove the default "everyone can execute" grant, now and for the future.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- (anon default is already empty; be explicit so future functions never leak.)

-- 7b. Re-grant EXECUTE to `authenticated` for the exact client/owner allowlist.
--     Tolerant by-name grant: for each allowlisted NAME, grant every existing
--     overload found in this database. This avoids aborting when a hardcoded
--     signature drifts from the deployed one (e.g. a param type differs) — a
--     name that doesn't exist is simply skipped. The function BODY still decides
--     who may act; this grant only makes the function reachable by authenticated.
DO $grant_allowlist$
DECLARE
  allow text[] := ARRAY[
    -- Coins / economy (self-scoped or owner-gated in body)
    'earn_coins','spend_coins','purchase_cosmetic','purchase_avatar_part',
    'send_coins','gift_cosmetic','gift_avatar_part','upsert_economy_config',
    'upsert_difficulty_config','recalibrate_scores','admin_economy_summary',
    -- Scores / gameplay results
    'submit_score',
    -- Challenges / H2H / matchmaking / ratings / claims
    'claim_challenge_coins','claim_h2h_coins','claim_daily_champion',
    'submit_challenge_round','apply_challenge_rating','apply_sortie_rating',
    'match_pool_entry','expire_stale_challenges',
    -- Social (block / unblock — self-scoped in body)
    'block_user','unblock_user',
    -- Admin panel (every one re-checks admin_role in body)
    'admin_increment_stat','admin_set_stat','admin_set_license','admin_set_avatar',
    'admin_set_role','admin_unlock_all','admin_ban_user','admin_unban_user',
    'admin_resolve_report','admin_resolve_clue_report','admin_update_app_config',
    'admin_upsert_announcement','admin_set_feature_flag','admin_search_users',
    'admin_upsert_country_alias','admin_delete_country_alias',
    'admin_upsert_border_display','admin_process_gdpr_request'
  ];
  r record;
  granted int := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(allow)
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
    granted := granted + 1;
  END LOOP;
  RAISE NOTICE 'Section 7: granted EXECUTE to authenticated on % function overloads', granted;
END $grant_allowlist$;

-- service_role: explicit GRANT ... TO service_role lines in rebuild.sql/migrations
-- are unaffected by the PUBLIC/anon revokes above (revoking PUBLIC does not touch
-- explicit role grants). No service_role re-grants are required here.


-- =============================================================================
-- SECTION 8 (DEFERRED — DO NOT UNCOMMENT UNTIL THE CLIENT ROUTES *EVERY* COIN /
--            XP / INVENTORY / RESULT WRITE THROUGH AN RPC)
-- -----------------------------------------------------------------------------
-- Running Sections 1–7 does NOT execute anything below. These are the FINAL
-- economy/inventory LOCKDOWNS. Each will BREAK the app if enabled before the
-- corresponding client write path is fully RPC-routed, because today the client
-- still writes these values directly (whole-row profile upsert, optimistic
-- account_state upsert, direct challenge result UPDATE, direct scores INSERT).
--
-- OWNER CHECKLIST before enabling each block:
--   [ ] 8a coins/xp pin  → confirm addCoins/spendCoins AND every direct coin-set
--                           site (refund reverts, resets, reconciles) route
--                           through earn_coins/spend_coins, and coins/level/xp/
--                           best_score are removed from the client profile upsert.
--   [ ] 8b inventory pin → confirm ALL owned_cosmetics / owned_avatar_parts /
--                           unlocked_regions / license_data writes route through
--                           purchase_*/gift_*/admin_* RPCs (no optimistic direct
--                           account_state array writes remain).
--   [ ] 8c result pin    → confirm winner_id + status are only ever written by
--                           submit_challenge_round / claim_* RPCs.
--   [ ] 8d scores insert → confirm 100% of clients use submit_score().
--
-- ---- 8a. Pin coins / level / xp / best_score to server-authoritative --------
-- Extends protect_profile_privileged_columns() (or add a companion trigger) to
-- also pin these unless app.allow_coin_write='on' (earn_coins/spend_coins set
-- it). Sketch:
--
--   CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns()
--   RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $fn$
--   BEGIN
--     IF current_setting('app.allow_privileged_profile_write', true) = 'on' THEN
--       RETURN NEW;
--     END IF;
--     NEW.admin_role := OLD.admin_role;
--     NEW.banned_at := OLD.banned_at; NEW.ban_expires_at := OLD.ban_expires_at;
--     NEW.ban_reason := OLD.ban_reason; NEW.banned_by := OLD.banned_by;
--     NEW.unban_reason := OLD.unban_reason;
--     -- Economy columns: only coin/xp RPCs may change them.
--     IF current_setting('app.allow_coin_write', true) <> 'on' THEN
--       NEW.coins := OLD.coins;
--     END IF;
--     RETURN NEW;
--   END; $fn$;
--   -- (level/xp/best_score already ratchet monotonically via protect_profile_stats;
--   --  add an equivalent RPC-gated pin here if you want them fully server-owned.)
--
-- ---- 8b. account_state inventory anti-tamper --------------------------------
-- A BEFORE UPDATE trigger on account_state pinning owned_cosmetics /
-- owned_avatar_parts / unlocked_regions / license_data to OLD unless a
-- purchase_*/gift_*/admin_* RPC set an app.allow_inventory_write flag. (Those
-- RPCs write via their own SECURITY DEFINER path today; add the flag when you
-- enable this.)
--
-- ---- 8c. challenges / h2h_challenges result pin -----------------------------
-- Add to the Section-6 WITH CHECK (or a trigger): winner_id and status may only
-- change to a valid transition, and only via submit_challenge_round / claim_*.
-- Simplest: revoke direct UPDATE of winner_id/status by pinning them in a
-- BEFORE UPDATE trigger unless an app.allow_result_write flag is set by the RPC.
--
-- ---- 8d. drop the direct client scores INSERT grant -------------------------
--   DROP POLICY IF EXISTS "Users can insert own scores" ON public.scores;
--   -- submit_score() (SECURITY DEFINER) becomes the ONLY insert path.
--
-- =============================================================================
-- END SECTION 8 (deferred)
-- =============================================================================
