-- Migration: Border Display Settings
-- Date: 2026-03-19
-- Purpose: Persist per-country border rendering overrides (tiny-area markers,
--          smoothing iterations, etc.) so admins can tune map appearance
--          without code changes. Also seeds the initial tiny-country list.
-- Idempotent: safe to re-run (IF NOT EXISTS / CREATE OR REPLACE throughout)

BEGIN;

-- ===================================================================
-- BORDER DISPLAY SETTINGS TABLE
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.border_display_settings (
  id              SERIAL PRIMARY KEY,
  country_code    TEXT        NOT NULL,
  country_name    TEXT        NOT NULL,
  always_tiny     BOOLEAN     NOT NULL DEFAULT FALSE,
  smoothing_iters INT         NOT NULL DEFAULT 2,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One row per country code.
CREATE UNIQUE INDEX IF NOT EXISTS idx_border_display_country_code
  ON public.border_display_settings (country_code);

ALTER TABLE public.border_display_settings ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read settings (needed by map renderers).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'border_display_settings' AND policyname = 'Authenticated users can read border display settings'
  ) THEN
    CREATE POLICY "Authenticated users can read border display settings"
      ON public.border_display_settings FOR SELECT
      USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- Admins can insert/update settings.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'border_display_settings' AND policyname = 'Admins can manage border display settings'
  ) THEN
    CREATE POLICY "Admins can manage border display settings"
      ON public.border_display_settings FOR ALL
      USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND admin_role IS NOT NULL
      ));
  END IF;
END $$;

-- ===================================================================
-- SEED: Initial tiny-country list
-- All micro-states, small islands, and territories that should always
-- render with expanded markers on map views.
-- ===================================================================

INSERT INTO public.border_display_settings (country_code, country_name, always_tiny, notes) VALUES
  -- European micro-states
  ('AD', 'Andorra',                       TRUE, 'European micro-state'),
  ('GI', 'Gibraltar',                     TRUE, 'British Overseas Territory'),
  ('GG', 'Guernsey',                      TRUE, 'Crown dependency'),
  ('IM', 'Isle of Man',                   TRUE, 'Crown dependency'),
  ('JE', 'Jersey',                        TRUE, 'Crown dependency'),
  ('LI', 'Liechtenstein',                 TRUE, 'European micro-state'),
  ('LU', 'Luxembourg',                    TRUE, 'Small European state'),
  ('MC', 'Monaco',                        TRUE, 'European micro-state'),
  ('MT', 'Malta',                         TRUE, 'Small island state'),
  ('SM', 'San Marino',                    TRUE, 'European micro-state'),
  ('VA', 'Vatican City',                  TRUE, 'European micro-state'),
  -- Asian small states
  ('BH', 'Bahrain',                       TRUE, 'Small island state'),
  ('BN', 'Brunei',                        TRUE, 'Small Asian state'),
  ('MV', 'Maldives',                      TRUE, 'Island micro-state'),
  ('QA', 'Qatar',                         TRUE, 'Small peninsula state'),
  ('SG', 'Singapore',                     TRUE, 'City-state'),
  ('TL', 'Timor-Leste',                   TRUE, 'Small island state'),
  -- African island/small states
  ('CV', 'Cape Verde',                    TRUE, 'Island nation'),
  ('KM', 'Comoros',                       TRUE, 'Island nation'),
  ('DJ', 'Djibouti',                      TRUE, 'Small African state'),
  ('GQ', 'Equatorial Guinea',             TRUE, 'Small African state'),
  ('GM', 'Gambia',                        TRUE, 'Small African state'),
  ('GW', 'Guinea-Bissau',                 TRUE, 'Small African state'),
  ('LS', 'Lesotho',                       TRUE, 'Small African enclave'),
  ('MU', 'Mauritius',                     TRUE, 'Island nation'),
  ('RW', 'Rwanda',                        TRUE, 'Small African state'),
  ('ST', 'São Tomé and Príncipe',         TRUE, 'Island nation'),
  ('SC', 'Seychelles',                    TRUE, 'Island nation'),
  ('SZ', 'Eswatini',                      TRUE, 'Small African state'),
  -- Pacific / Oceania island nations
  ('FJ', 'Fiji',                          TRUE, 'Pacific island nation'),
  ('FM', 'Micronesia',                    TRUE, 'Pacific island nation'),
  ('KI', 'Kiribati',                      TRUE, 'Pacific island nation'),
  ('MH', 'Marshall Islands',              TRUE, 'Pacific island nation'),
  ('NR', 'Nauru',                         TRUE, 'Pacific island nation'),
  ('PW', 'Palau',                         TRUE, 'Pacific island nation'),
  ('SB', 'Solomon Islands',               TRUE, 'Pacific island nation'),
  ('TO', 'Tonga',                         TRUE, 'Pacific island nation'),
  ('TV', 'Tuvalu',                        TRUE, 'Pacific island nation'),
  ('VU', 'Vanuatu',                       TRUE, 'Pacific island nation'),
  ('WS', 'Samoa',                         TRUE, 'Pacific island nation'),
  -- Caribbean island nations
  ('AG', 'Antigua and Barbuda',           TRUE, 'Caribbean island nation'),
  ('BB', 'Barbados',                      TRUE, 'Caribbean island nation'),
  ('DM', 'Dominica',                      TRUE, 'Caribbean island nation'),
  ('GD', 'Grenada',                       TRUE, 'Caribbean island nation'),
  ('KN', 'Saint Kitts and Nevis',         TRUE, 'Caribbean island nation'),
  ('LC', 'Saint Lucia',                   TRUE, 'Caribbean island nation'),
  ('VC', 'Saint Vincent and the Grenadines', TRUE, 'Caribbean island nation'),
  ('TT', 'Trinidad and Tobago',           TRUE, 'Caribbean island nation'),
  -- Middle East small states
  ('KW', 'Kuwait',                        TRUE, 'Small Middle East state'),
  ('LB', 'Lebanon',                       TRUE, 'Small Middle East state'),
  ('PS', 'Palestine',                     TRUE, 'Small Middle East territory'),
  -- Other small states
  ('BT', 'Bhutan',                        TRUE, 'Small Himalayan state'),
  ('SV', 'El Salvador',                   TRUE, 'Small Central American state'),
  ('BZ', 'Belize',                        TRUE, 'Small Central American state')
ON CONFLICT (country_code) DO NOTHING;

-- ===================================================================
-- ADMIN RPC: upsert border display settings
-- ===================================================================

CREATE OR REPLACE FUNCTION public.admin_upsert_border_display(
  p_country_code    TEXT,
  p_country_name    TEXT,
  p_always_tiny     BOOLEAN DEFAULT FALSE,
  p_smoothing_iters INT     DEFAULT 2,
  p_notes           TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT admin_role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'Not an admin'; END IF;

  INSERT INTO border_display_settings (country_code, country_name, always_tiny, smoothing_iters, notes)
  VALUES (p_country_code, p_country_name, p_always_tiny, p_smoothing_iters, p_notes)
  ON CONFLICT (country_code) DO UPDATE SET
    country_name    = EXCLUDED.country_name,
    always_tiny     = EXCLUDED.always_tiny,
    smoothing_iters = EXCLUDED.smoothing_iters,
    notes           = EXCLUDED.notes,
    updated_at      = NOW();

  PERFORM _log_admin_action('upsert_border_display', NULL,
    jsonb_build_object(
      'country_code', p_country_code,
      'country_name', p_country_name,
      'always_tiny', p_always_tiny,
      'smoothing_iters', p_smoothing_iters
    ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_border_display(TEXT, TEXT, BOOLEAN, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_border_display(TEXT, TEXT, BOOLEAN, INT, TEXT) TO service_role;

COMMIT;
