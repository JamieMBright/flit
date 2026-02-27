-- Migration: Admin & Moderation Feature Set (sections 16-26)
-- Date: 2026-02-27
-- Prerequisites: profiles.admin_role column must exist, coin_activity table must exist
-- Idempotent: safe to re-run (IF NOT EXISTS / CREATE OR REPLACE throughout)

BEGIN;

-- ===================================================================
-- 16. ADMIN AUDIT LOG
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id     UUID NOT NULL REFERENCES auth.users(id),
  actor_role   TEXT NOT NULL,
  action       TEXT NOT NULL,
  target_id    UUID REFERENCES auth.users(id),
  details      JSONB NOT NULL DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON public.admin_audit_log (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON public.admin_audit_log (target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON public.admin_audit_log (action, created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'admin_audit_log' AND policyname = 'Owners can read all audit log'
  ) THEN
    CREATE POLICY "Owners can read all audit log"
      ON public.admin_audit_log FOR SELECT
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role = 'owner'
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'admin_audit_log' AND policyname = 'Moderators can read own audit entries'
  ) THEN
    CREATE POLICY "Moderators can read own audit entries"
      ON public.admin_audit_log FOR SELECT
      USING (actor_id = auth.uid() AND EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public._log_admin_action(
  p_action TEXT,
  p_target_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RETURN; END IF;
  INSERT INTO admin_audit_log (actor_id, actor_role, action, target_id, details)
  VALUES (auth.uid(), v_role, p_action, p_target_id, p_details);
END;
$$;

GRANT EXECUTE ON FUNCTION public._log_admin_action(TEXT, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public._log_admin_action(TEXT, UUID, JSONB) TO service_role;


-- ===================================================================
-- 17. BAN SYSTEM
-- ===================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS banned_at      TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ban_expires_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS ban_reason     TEXT DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_banned
  ON public.profiles (banned_at) WHERE banned_at IS NOT NULL;

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
  v_expires TIMESTAMPTZ;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
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

  v_expires := CASE
    WHEN p_duration_days IS NOT NULL
    THEN NOW() + (p_duration_days || ' days')::INTERVAL
    ELSE NULL
  END;

  UPDATE profiles SET
    banned_at = NOW(),
    ban_expires_at = v_expires,
    ban_reason = p_reason
  WHERE id = target_user_id;

  PERFORM _log_admin_action(
    'ban_user', target_user_id,
    jsonb_build_object('reason', p_reason, 'duration_days', p_duration_days)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_ban_user(UUID, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_ban_user(UUID, TEXT, INT) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_unban_user(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Only owners can lift bans'; END IF;

  UPDATE profiles SET banned_at = NULL, ban_expires_at = NULL, ban_reason = NULL
  WHERE id = target_user_id;

  PERFORM _log_admin_action('unban_user', target_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_unban_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unban_user(UUID) TO service_role;


-- ===================================================================
-- 18. PLAYER REPORTS
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.player_reports (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL,
  details       TEXT,
  status        TEXT NOT NULL DEFAULT 'pending',
  reviewed_by   UUID REFERENCES auth.users(id),
  reviewed_at   TIMESTAMPTZ,
  action_taken  TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT no_self_report CHECK (reporter_id != reported_id)
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.player_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported ON public.player_reports (reported_id);

ALTER TABLE public.player_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Users can submit reports'
  ) THEN
    CREATE POLICY "Users can submit reports"
      ON public.player_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Users can read own reports'
  ) THEN
    CREATE POLICY "Users can read own reports"
      ON public.player_reports FOR SELECT USING (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Admins can read all reports'
  ) THEN
    CREATE POLICY "Admins can read all reports"
      ON public.player_reports FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_reports' AND policyname = 'Admins can update reports'
  ) THEN
    CREATE POLICY "Admins can update reports"
      ON public.player_reports FOR UPDATE
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id BIGINT, p_status TEXT, p_action_taken TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT; v_target UUID;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  IF p_status NOT IN ('actioned', 'dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT reported_id INTO v_target FROM player_reports WHERE id = p_report_id;

  UPDATE player_reports SET
    status = p_status, reviewed_by = auth.uid(),
    reviewed_at = NOW(), action_taken = p_action_taken
  WHERE id = p_report_id;

  PERFORM _log_admin_action('resolve_report', v_target,
    jsonb_build_object('report_id', p_report_id, 'status', p_status, 'action', p_action_taken));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_report(BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(BIGINT, TEXT, TEXT) TO service_role;


-- ===================================================================
-- 19. APP CONFIG (singleton)
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.app_config (
  id                   INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  min_app_version      TEXT NOT NULL DEFAULT 'v1.0',
  recommended_version  TEXT NOT NULL DEFAULT 'v1.0',
  maintenance_mode     BOOLEAN NOT NULL DEFAULT FALSE,
  maintenance_message  TEXT DEFAULT NULL,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'app_config' AND policyname = 'Anyone can read app config'
  ) THEN
    CREATE POLICY "Anyone can read app config" ON public.app_config FOR SELECT USING (true);
  END IF;
END $$;

INSERT INTO public.app_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

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
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  UPDATE app_config SET
    min_app_version = COALESCE(p_min_version, min_app_version),
    recommended_version = COALESCE(p_recommended_version, recommended_version),
    maintenance_mode = COALESCE(p_maintenance_mode, maintenance_mode),
    maintenance_message = COALESCE(p_maintenance_message, maintenance_message),
    updated_at = NOW()
  WHERE id = 1;

  PERFORM _log_admin_action('update_app_config', NULL,
    jsonb_build_object('min_version', p_min_version, 'recommended_version', p_recommended_version, 'maintenance_mode', p_maintenance_mode));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_app_config(TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_app_config(TEXT, TEXT, BOOLEAN, TEXT) TO service_role;


-- ===================================================================
-- 20. ANNOUNCEMENTS
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.announcements (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  type          TEXT NOT NULL DEFAULT 'info',
  priority      INT NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at     TIMESTAMPTZ DEFAULT NULL,
  expires_at    TIMESTAMPTZ DEFAULT NULL,
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'announcements' AND policyname = 'Anyone can read active announcements'
  ) THEN
    CREATE POLICY "Anyone can read active announcements"
      ON public.announcements FOR SELECT USING (
        is_active = TRUE
        AND (starts_at IS NULL OR starts_at <= NOW())
        AND (expires_at IS NULL OR expires_at > NOW())
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'announcements' AND policyname = 'Admins can read all announcements'
  ) THEN
    CREATE POLICY "Admins can read all announcements"
      ON public.announcements FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_upsert_announcement(
  p_id BIGINT DEFAULT NULL, p_title TEXT DEFAULT NULL, p_body TEXT DEFAULT NULL,
  p_type TEXT DEFAULT 'info', p_priority INT DEFAULT 0, p_is_active BOOLEAN DEFAULT TRUE,
  p_starts_at TIMESTAMPTZ DEFAULT NULL, p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT; v_id BIGINT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;
  IF v_role = 'moderator' AND p_type NOT IN ('info') THEN
    RAISE EXCEPTION 'Moderators can only create info announcements';
  END IF;

  IF p_id IS NOT NULL THEN
    UPDATE announcements SET
      title = COALESCE(p_title, title), body = COALESCE(p_body, body),
      type = COALESCE(p_type, type), priority = COALESCE(p_priority, priority),
      is_active = COALESCE(p_is_active, is_active),
      starts_at = p_starts_at, expires_at = p_expires_at
    WHERE id = p_id RETURNING announcements.id INTO v_id;
  ELSE
    INSERT INTO announcements (title, body, type, priority, is_active, starts_at, expires_at, created_by)
    VALUES (p_title, p_body, p_type, p_priority, p_is_active, p_starts_at, p_expires_at, auth.uid())
    RETURNING announcements.id INTO v_id;
  END IF;

  PERFORM _log_admin_action(
    CASE WHEN p_id IS NOT NULL THEN 'update_announcement' ELSE 'create_announcement' END,
    NULL, jsonb_build_object('announcement_id', v_id, 'title', p_title, 'type', p_type));
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_announcement(BIGINT, TEXT, TEXT, TEXT, INT, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_announcement(BIGINT, TEXT, TEXT, TEXT, INT, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;


-- ===================================================================
-- 21. FEATURE FLAGS
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.feature_flags (
  flag_key     TEXT PRIMARY KEY,
  enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  description  TEXT,
  updated_by   UUID REFERENCES auth.users(id),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'feature_flags' AND policyname = 'Anyone can read feature flags'
  ) THEN
    CREATE POLICY "Anyone can read feature flags" ON public.feature_flags FOR SELECT USING (true);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_feature_flag(
  p_flag_key TEXT, p_enabled BOOLEAN, p_description TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;

  INSERT INTO feature_flags (flag_key, enabled, description, updated_by, updated_at)
  VALUES (p_flag_key, p_enabled, p_description, auth.uid(), NOW())
  ON CONFLICT (flag_key) DO UPDATE SET
    enabled = EXCLUDED.enabled,
    description = COALESCE(EXCLUDED.description, feature_flags.description),
    updated_by = EXCLUDED.updated_by, updated_at = NOW();

  PERFORM _log_admin_action('set_feature_flag', NULL,
    jsonb_build_object('flag_key', p_flag_key, 'enabled', p_enabled));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_feature_flag(TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_feature_flag(TEXT, BOOLEAN, TEXT) TO service_role;

-- Seed initial flags
INSERT INTO public.feature_flags (flag_key, enabled, description) VALUES
  ('matchmaking_enabled', true, 'Async H2H matchmaking'),
  ('ads_enabled', true, 'Show ads to free-tier users'),
  ('gifting_enabled', true, 'Player-to-player coin/cosmetic gifting'),
  ('daily_scramble_enabled', true, 'Daily challenge mode'),
  ('shop_enabled', true, 'In-app shop'),
  ('leaderboard_enabled', true, 'Public leaderboards')
ON CONFLICT (flag_key) DO NOTHING;


-- ===================================================================
-- 22. FUZZY SEARCH (pg_trgm)
-- ===================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
  ON public.profiles USING gin (username gin_trgm_ops);

CREATE OR REPLACE FUNCTION public.admin_search_users(
  p_query TEXT, p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id UUID, username TEXT, display_name TEXT, level INT, coins INT,
  games_played INT, admin_role TEXT, banned_at TIMESTAMPTZ, created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT profiles.admin_role INTO v_role FROM profiles WHERE profiles.id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;

  RETURN QUERY
  SELECT p.id, p.username, p.display_name, p.level, p.coins,
         p.games_played, p.admin_role, p.banned_at, p.created_at
  FROM profiles p
  WHERE p.username ILIKE '%' || p_query || '%'
     OR p.display_name ILIKE '%' || p_query || '%'
     OR p.id::TEXT = p_query
  ORDER BY
    CASE WHEN p.username ILIKE p_query THEN 0 ELSE 1 END,
    similarity(p.username, p_query) DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_search_users(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_users(TEXT, INT) TO service_role;


-- ===================================================================
-- 23. SUSPICIOUS ACTIVITY VIEW
-- ===================================================================

CREATE OR REPLACE VIEW suspicious_activity AS
SELECT
  p.id, p.username, p.level, p.coins, p.games_played, p.banned_at,
  (SELECT COUNT(*) FROM scores s WHERE s.user_id = p.id
     AND s.created_at > NOW() - INTERVAL '24 hours') AS games_24h,
  (SELECT COALESCE(SUM(c.coin_amount), 0) FROM coin_activity c WHERE c.user_id = p.id
     AND c.coin_amount > 0 AND c.created_at > NOW() - INTERVAL '24 hours') AS coins_earned_24h,
  p.created_at
FROM profiles p
WHERE
  (SELECT COUNT(*) FROM scores s WHERE s.user_id = p.id
     AND s.created_at > NOW() - INTERVAL '24 hours') > 100
  OR (SELECT COALESCE(SUM(c.coin_amount), 0) FROM coin_activity c WHERE c.user_id = p.id
     AND c.coin_amount > 0 AND c.created_at > NOW() - INTERVAL '24 hours') > 1500
  OR p.best_score >= 99000;


-- ===================================================================
-- 24. GDPR REQUEST TRACKING
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.gdpr_requests (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL,
  username TEXT,
  request_type TEXT NOT NULL CHECK (request_type IN ('export', 'delete')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES auth.users(id),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.gdpr_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'gdpr_requests' AND policyname = 'Admins can manage GDPR requests'
  ) THEN
    CREATE POLICY "Admins can manage GDPR requests"
      ON public.gdpr_requests FOR ALL
      USING ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_process_gdpr_request(
  p_request_id BIGINT, p_status TEXT, p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role != 'owner' THEN RAISE EXCEPTION 'Only owners can process GDPR requests'; END IF;

  UPDATE gdpr_requests SET
    status = p_status,
    completed_at = CASE WHEN p_status IN ('completed', 'failed') THEN NOW() ELSE NULL END,
    processed_by = auth.uid(),
    notes = COALESCE(p_notes, notes)
  WHERE id = p_request_id;

  PERFORM _log_admin_action('process_gdpr_request',
    (SELECT user_id FROM gdpr_requests WHERE id = p_request_id),
    jsonb_build_object('request_id', p_request_id, 'status', p_status));
END;
$$;


-- ===================================================================
-- 25. ECONOMY HEALTH DASHBOARD RPC
-- ===================================================================

CREATE OR REPLACE FUNCTION public.admin_economy_summary()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT; v_result JSON;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Permission denied: not an admin'; END IF;

  SELECT json_build_object(
    'total_coins', COALESCE(SUM(coins), 0),
    'avg_coins', COALESCE(ROUND(AVG(coins)::numeric, 1), 0),
    'median_coins', COALESCE((SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY coins) FROM profiles), 0),
    'max_coins', COALESCE(MAX(coins), 0),
    'total_players', COUNT(*),
    'players_with_coins', COUNT(*) FILTER (WHERE coins > 0)
  ) INTO v_result FROM profiles;

  RETURN v_result;
END;
$$;


-- ===================================================================
-- 26. IAP RECEIPTS (scaffolding)
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.iap_receipts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  product_id TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  receipt_data TEXT,
  is_valid BOOLEAN DEFAULT FALSE,
  amount INT NOT NULL DEFAULT 0,
  currency TEXT DEFAULT 'gold',
  transaction_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.iap_receipts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'iap_receipts' AND policyname = 'Users read own receipts'
  ) THEN
    CREATE POLICY "Users read own receipts"
      ON public.iap_receipts FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'iap_receipts' AND policyname = 'Admins read all receipts'
  ) THEN
    CREATE POLICY "Admins read all receipts"
      ON public.iap_receipts FOR SELECT
      USING ((SELECT admin_role FROM public.profiles WHERE id = auth.uid()) IS NOT NULL);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_iap_receipts_user ON public.iap_receipts (user_id);
CREATE INDEX IF NOT EXISTS idx_iap_receipts_created ON public.iap_receipts (created_at DESC);

COMMIT;
