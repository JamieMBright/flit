-- =============================================================================
-- Flit — Clean flights, apply difficulty scoring, recalculate user stats
-- =============================================================================
-- 1. Removes all scores rows where round_details IS NULL (no round-by-round data)
-- 2. Normalizes all round_details to a consistent format with:
--      country_code, raw_score, and difficulty-adjusted score
-- 3. Applies difficulty multiplier to ALL scores:
--      adjusted_score = round(raw_score * (0.5 + countryDifficulty * 0.5))
--    Multiplier range: 0.51 (USA) → 0.965 (São Tomé)
-- 4. Recalculates every user's profile stats from the corrected scores
--
-- Stats updated:
--   games_played, best_score, best_time_ms, total_flight_time_ms,
--   countries_found, level, xp, flags_correct, capitals_correct,
--   outlines_correct, borders_correct, stats_correct, best_streak,
--   updated_at
--
-- Uses app.skip_stat_protection = 'true' to bypass the monotonic-stats trigger,
-- since stats will decrease after deleting scores.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Bypass the stat-protection trigger so we can decrease stats
-- ---------------------------------------------------------------------------
SET LOCAL app.skip_stat_protection = 'true';

-- ---------------------------------------------------------------------------
-- 2. Delete all scores that have no round-by-round detail data
-- ---------------------------------------------------------------------------
DELETE FROM public.scores
WHERE round_details IS NULL;

-- ---------------------------------------------------------------------------
-- 3. First normalize any scores that had a pre-existing difficulty modifier
--    (raw_score field from a newer app version). Restore raw_score as the
--    base score before re-applying difficulty uniformly in step 5.
-- ---------------------------------------------------------------------------
UPDATE public.scores s
SET
  round_details = (
    SELECT jsonb_agg(
      jsonb_build_object(
        'country_name', r.value ->> 'country_name',
        'clue_type',    r.value ->> 'clue_type',
        'time_ms',      (r.value ->> 'time_ms')::INT,
        'score',        (r.value ->> 'raw_score')::INT,
        'hints_used',   (r.value ->> 'hints_used')::INT,
        'completed',    (r.value ->> 'completed')::BOOLEAN
      )
    )
    FROM jsonb_array_elements(s.round_details) AS r(value)
  ),
  score = (
    SELECT SUM((r.value ->> 'raw_score')::INT)
    FROM jsonb_array_elements(s.round_details) AS r(value)
  )
WHERE s.round_details::text LIKE '%raw_score%';

-- ---------------------------------------------------------------------------
-- 4. Create country name → code → difficulty mapping
-- ---------------------------------------------------------------------------
-- Maps display names used in round_details to ISO codes and difficulty ratings
-- from country_difficulty.dart. Regional areas (UK counties, US states, etc.)
-- use code 'XR' and the default difficulty of 0.55.
CREATE TEMP TABLE country_diff (
  name TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  difficulty DOUBLE PRECISION NOT NULL
) ON COMMIT DROP;

-- Populate from the full _defaultCountryDifficulty map.
-- Only countries that appear in existing round_details need entries here,
-- plus a catch-all default of 0.55 for any unmatched names.
-- This table should be extended when new countries appear in the game.
INSERT INTO country_diff (name, code, difficulty) VALUES
  -- Very Easy (0.00–0.15)
  ('United States', 'US', 0.02),
  ('China', 'CN', 0.04),
  ('Russia', 'RU', 0.05),
  ('Australia', 'AU', 0.05),
  ('Brazil', 'BR', 0.06),
  ('India', 'IN', 0.07),
  ('Canada', 'CA', 0.08),
  ('United Kingdom', 'GB', 0.08),
  ('Japan', 'JP', 0.09),
  ('France', 'FR', 0.10),
  ('Italy', 'IT', 0.10),
  ('Germany', 'DE', 0.11),
  ('Mexico', 'MX', 0.12),
  ('Egypt', 'EG', 0.12),
  ('South Africa', 'ZA', 0.13),
  -- Easy (0.15–0.30)
  ('Spain', 'ES', 0.15),
  ('South Korea', 'KR', 0.16),
  ('Argentina', 'AR', 0.17),
  ('Saudi Arabia', 'SA', 0.17),
  ('Turkey', 'TR', 0.18),
  ('Indonesia', 'ID', 0.18),
  ('Thailand', 'TH', 0.19),
  ('Nigeria', 'NG', 0.20),
  ('Sweden', 'SE', 0.20),
  ('Norway', 'NO', 0.21),
  ('Poland', 'PL', 0.22),
  ('Greece', 'GR', 0.22),
  ('New Zealand', 'NZ', 0.23),
  ('Colombia', 'CO', 0.23),
  ('Philippines', 'PH', 0.24),
  ('Pakistan', 'PK', 0.24),
  ('Iran', 'IR', 0.25),
  ('Peru', 'PE', 0.25),
  ('Ukraine', 'UA', 0.26),
  ('Chile', 'CL', 0.26),
  ('Venezuela', 'VE', 0.27),
  ('Cuba', 'CU', 0.27),
  ('Ireland', 'IE', 0.28),
  ('Israel', 'IL', 0.28),
  ('Finland', 'FI', 0.28),
  ('Portugal', 'PT', 0.29),
  ('Switzerland', 'CH', 0.29),
  ('Denmark', 'DK', 0.30),
  ('Austria', 'AT', 0.30),
  -- Medium (0.30–0.50)
  ('Belgium', 'BE', 0.31),
  ('Netherlands', 'NL', 0.31),
  ('Czech Republic', 'CZ', 0.32),
  ('Romania', 'RO', 0.33),
  ('Hungary', 'HU', 0.33),
  ('Kenya', 'KE', 0.34),
  ('Ethiopia', 'ET', 0.34),
  ('Morocco', 'MA', 0.35),
  ('Iraq', 'IQ', 0.35),
  ('Afghanistan', 'AF', 0.36),
  ('Malaysia', 'MY', 0.36),
  ('North Korea', 'KP', 0.37),
  ('Singapore', 'SG', 0.37),
  ('Vietnam', 'VN', 0.38),
  ('Tanzania', 'TZ', 0.38),
  ('Greenland', 'GL', 0.39),
  ('Bangladesh', 'BD', 0.39),
  ('Sri Lanka', 'LK', 0.39),
  ('Kazakhstan', 'KZ', 0.40),
  ('Myanmar', 'MM', 0.40),
  ('Algeria', 'DZ', 0.40),
  ('Sudan', 'SD', 0.41),
  ('Ghana', 'GH', 0.41),
  ('Costa Rica', 'CR', 0.42),
  ('Panama', 'PA', 0.42),
  ('Ecuador', 'EC', 0.42),
  ('Uruguay', 'UY', 0.43),
  ('Jamaica', 'JM', 0.43),
  ('Nepal', 'NP', 0.43),
  ('Libya', 'LY', 0.44),
  ('Jordan', 'JO', 0.44),
  ('DR Congo', 'CD', 0.44),
  ('Syria', 'SY', 0.45),
  ('Lebanon', 'LB', 0.45),
  ('Hong Kong', 'HK', 0.45),
  ('Iceland', 'IS', 0.45),
  ('Serbia', 'RS', 0.46),
  ('Puerto Rico', 'PR', 0.46),
  ('Croatia', 'HR', 0.46),
  ('Tunisia', 'TN', 0.47),
  ('Bolivia', 'BO', 0.47),
  ('Paraguay', 'PY', 0.47),
  ('Guatemala', 'GT', 0.48),
  ('Dominican Rep.', 'DO', 0.48),
  ('Honduras', 'HN', 0.48),
  ('El Salvador', 'SV', 0.49),
  ('Nicaragua', 'NI', 0.49),
  ('Taiwan', 'TW', 0.49),
  ('Bulgaria', 'BG', 0.50),
  -- Hard (0.50–0.70)
  ('Cameroon', 'CM', 0.50),
  ('UAE', 'AE', 0.50),
  ('Cambodia', 'KH', 0.51),
  ('Qatar', 'QA', 0.51),
  ('Uzbekistan', 'UZ', 0.52),
  ('Lithuania', 'LT', 0.52),
  ('Latvia', 'LV', 0.53),
  ('Estonia', 'EE', 0.53),
  ('Slovenia', 'SI', 0.53),
  ('Slovakia', 'SK', 0.54),
  ('Bosnia', 'BA', 0.54),
  ('Albania', 'AL', 0.55),
  ('North Macedonia', 'MK', 0.55),
  ('Montenegro', 'ME', 0.56),
  ('Kosovo', 'XK', 0.56),
  ('Cyprus', 'CY', 0.56),
  ('Northern Cyprus', 'CY', 0.56),
  ('Mongolia', 'MN', 0.57),
  ('Laos', 'LA', 0.57),
  ('Oman', 'OM', 0.57),
  ('Kuwait', 'KW', 0.58),
  ('Bahrain', 'BH', 0.58),
  ('Palestine', 'PS', 0.58),
  ('Luxembourg', 'LU', 0.58),
  ('Madagascar', 'MG', 0.59),
  ('Mali', 'ML', 0.59),
  ('Burkina Faso', 'BF', 0.59),
  ('Senegal', 'SN', 0.60),
  ('Niger', 'NE', 0.60),
  ('Chad', 'TD', 0.60),
  ('Cote d''Ivoire', 'CI', 0.61),
  ('Mozambique', 'MZ', 0.61),
  ('Malawi', 'MW', 0.62),
  ('Zambia', 'ZM', 0.62),
  ('Zimbabwe', 'ZW', 0.62),
  ('Botswana', 'BW', 0.63),
  ('Namibia', 'NA', 0.63),
  ('Angola', 'AO', 0.63),
  ('Uganda', 'UG', 0.64),
  ('Rwanda', 'RW', 0.64),
  ('Tajikistan', 'TJ', 0.64),
  ('Kyrgyzstan', 'KG', 0.64),
  ('Turkmenistan', 'TM', 0.65),
  ('Georgia', 'GE', 0.65),
  ('Armenia', 'AM', 0.65),
  ('Azerbaijan', 'AZ', 0.66),
  ('Moldova', 'MD', 0.66),
  ('Belarus', 'BY', 0.66),
  ('Papua New Guinea', 'PG', 0.67),
  ('Fiji', 'FJ', 0.67),
  ('Haiti', 'HT', 0.67),
  ('Trinidad and Tobago', 'TT', 0.68),
  ('Bahamas', 'BS', 0.68),
  ('Guyana', 'GY', 0.68),
  ('Suriname', 'SR', 0.68),
  ('Belize', 'BZ', 0.69),
  ('Barbados', 'BB', 0.69),
  ('Guinea', 'GN', 0.69),
  ('Sierra Leone', 'SL', 0.70),
  ('Liberia', 'LR', 0.70),
  -- Very Hard (0.70–0.85)
  ('Malta', 'MT', 0.70),
  ('Congo (Republic)', 'CG', 0.71),
  ('Djibouti', 'DJ', 0.71),
  ('Eritrea', 'ER', 0.71),
  ('Central African Republic', 'CF', 0.72),
  ('Somalia', 'SO', 0.72),
  ('South Sudan', 'SS', 0.72),
  ('Burundi', 'BI', 0.73),
  ('Mauritania', 'MR', 0.73),
  ('Togo', 'TG', 0.73),
  ('Benin', 'BJ', 0.73),
  ('Gabon', 'GA', 0.74),
  ('Equatorial Guinea', 'GQ', 0.74),
  ('Lesotho', 'LS', 0.74),
  ('Eswatini', 'SZ', 0.75),
  ('Gambia', 'GM', 0.75),
  ('Guinea-Bissau', 'GW', 0.75),
  ('Cape Verde', 'CV', 0.76),
  ('Mauritius', 'MU', 0.76),
  ('Western Sahara', 'EH', 0.76),
  ('Bhutan', 'BT', 0.77),
  ('Maldives', 'MV', 0.77),
  ('Timor-Leste', 'TL', 0.77),
  ('Samoa', 'WS', 0.78),
  ('Brunei', 'BN', 0.78),
  ('Grenada', 'GD', 0.78),
  ('Antigua and Barb.', 'AG', 0.79),
  ('Dominica', 'DM', 0.79),
  ('Saint Lucia', 'LC', 0.79),
  ('Saint Kitts and Nevis', 'KN', 0.80),
  ('Saint Vincent', 'VC', 0.80),
  ('Seychelles', 'SC', 0.80),
  ('Aruba', 'AW', 0.80),
  ('Curaçao', 'CW', 0.81),
  ('Macau', 'MO', 0.81),
  ('Gibraltar', 'GI', 0.81),
  ('San Marino', 'SM', 0.82),
  ('Liechtenstein', 'LI', 0.82),
  ('Monaco', 'MC', 0.82),
  ('Andorra', 'AD', 0.83),
  ('Isle of Man', 'IM', 0.83),
  ('Guernsey', 'GG', 0.83),
  ('Jersey', 'JE', 0.83),
  ('Faroe Islands', 'FO', 0.84),
  ('Åland', 'AX', 0.84),
  ('Bermuda', 'BM', 0.84),
  ('Falkland Islands', 'FK', 0.84),
  -- Extreme (0.85–1.00)
  ('New Caledonia', 'NC', 0.85),
  ('Guam', 'GU', 0.85),
  ('Vatican City', 'VA', 0.85),
  ('Somaliland', 'XS', 0.85),
  ('Cook Is.', 'CK', 0.86),
  ('Kiribati', 'KI', 0.87),
  ('Tonga', 'TO', 0.87),
  ('Micronesia', 'FM', 0.88),
  ('Marshall Islands', 'MH', 0.88),
  ('Solomon Islands', 'SB', 0.88),
  ('Vanuatu', 'VU', 0.89),
  ('Nauru', 'NR', 0.90),
  ('Tuvalu', 'TV', 0.91),
  ('Palau', 'PW', 0.92),
  ('Comoros', 'KM', 0.92),
  ('São Tomé and Principe', 'ST', 0.93),
  -- Regional / special (default difficulty)
  ('Unseen', '', 0.55);

-- NOTE: Regional area names (e.g. "City of Edinburgh", "Kildare", "Sligo")
-- are not listed here — they use the COALESCE default of 0.55 in the query.

-- ---------------------------------------------------------------------------
-- 5. Apply difficulty multiplier to ALL round_details
-- ---------------------------------------------------------------------------
-- Formula: adjusted_score = round(raw_score * (0.5 + countryDifficulty * 0.5))
-- Stores original score as raw_score, adjusted as score, adds country_code.
UPDATE public.scores s
SET
  round_details = (
    SELECT jsonb_agg(
      jsonb_build_object(
        'country_name', r.value ->> 'country_name',
        'country_code', COALESCE(cd.code, ''),
        'clue_type',    r.value ->> 'clue_type',
        'time_ms',      (r.value ->> 'time_ms')::INT,
        'raw_score',    (r.value ->> 'score')::INT,
        'score',        ROUND((r.value ->> 'score')::NUMERIC
                          * (0.5 + COALESCE(cd.difficulty, 0.55) * 0.5)),
        'hints_used',   (r.value ->> 'hints_used')::INT,
        'completed',    (r.value ->> 'completed')::BOOLEAN
      )
    )
    FROM jsonb_array_elements(s.round_details) AS r(value)
    LEFT JOIN country_diff cd ON cd.name = r.value ->> 'country_name'
  ),
  score = (
    SELECT SUM(ROUND((r.value ->> 'score')::NUMERIC
                * (0.5 + COALESCE(cd.difficulty, 0.55) * 0.5)))::INT
    FROM jsonb_array_elements(s.round_details) AS r(value)
    LEFT JOIN country_diff cd ON cd.name = r.value ->> 'country_name'
  );

-- ---------------------------------------------------------------------------
-- 6. Recalculate profile stats from difficulty-adjusted scores
-- ---------------------------------------------------------------------------
WITH round_flat AS (
  SELECT
    s.user_id, s.id AS score_id, r.ordinality,
    r.value ->> 'clue_type' AS clue_type,
    (r.value ->> 'completed')::BOOLEAN AS completed
  FROM public.scores s,
       jsonb_array_elements(s.round_details) WITH ORDINALITY AS r(value, ordinality)
),
clue_counts AS (
  SELECT
    user_id,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'flag'    AND completed), 0)::INT AS flags_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'capital'  AND completed), 0)::INT AS capitals_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'outline'  AND completed), 0)::INT AS outlines_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'borders'  AND completed), 0)::INT AS borders_correct,
    COALESCE(COUNT(*) FILTER (WHERE clue_type = 'stats'    AND completed), 0)::INT AS stats_correct
  FROM round_flat
  GROUP BY user_id
),
round_numbered AS (
  SELECT
    user_id, completed,
    SUM(CASE WHEN completed THEN 0 ELSE 1 END)
      OVER (PARTITION BY user_id ORDER BY score_id, ordinality
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS grp
  FROM round_flat
),
streak_calc AS (
  SELECT user_id, COALESCE(MAX(streak_len), 0)::INT AS best_streak
  FROM (
    SELECT user_id, grp, COUNT(*) AS streak_len
    FROM round_numbered WHERE completed = true
    GROUP BY user_id, grp
  ) sub
  GROUP BY user_id
),
score_agg AS (
  SELECT
    s.user_id,
    COUNT(*)::INT AS games_played,
    MAX(s.score)::INT AS best_score,
    MIN(s.time_ms)::BIGINT AS best_time_ms,
    SUM(s.time_ms)::BIGINT AS total_flight_time_ms,
    SUM(s.rounds_completed)::INT AS countries_found,
    SUM((50 + (s.rounds_completed * 10) + FLOOR(s.score / 100.0))::BIGINT) AS total_xp
  FROM public.scores s
  GROUP BY s.user_id
),
xp_levels AS (
  WITH RECURSIVE xp_progress AS (
    SELECT a.user_id, 1::INT AS level, a.total_xp::BIGINT AS xp_remaining
    FROM score_agg a
    UNION ALL
    SELECT x.user_id, x.level + 1, x.xp_remaining - (x.level * 100)
    FROM xp_progress x WHERE x.xp_remaining >= (x.level * 100)
  )
  SELECT DISTINCT ON (user_id) user_id, level, xp_remaining::INT AS xp
  FROM xp_progress ORDER BY user_id, level DESC
)
UPDATE public.profiles p
SET
  games_played         = COALESCE(a.games_played, 0),
  best_score           = a.best_score,
  best_time_ms         = a.best_time_ms,
  total_flight_time_ms = COALESCE(a.total_flight_time_ms, 0),
  countries_found      = COALESCE(a.countries_found, 0),
  level                = COALESCE(x.level, 1),
  xp                   = COALESCE(x.xp, 0),
  flags_correct        = COALESCE(c.flags_correct, 0),
  capitals_correct     = COALESCE(c.capitals_correct, 0),
  outlines_correct     = COALESCE(c.outlines_correct, 0),
  borders_correct      = COALESCE(c.borders_correct, 0),
  stats_correct        = COALESCE(c.stats_correct, 0),
  best_streak          = COALESCE(sk.best_streak, 0),
  updated_at           = NOW()
FROM score_agg a
LEFT JOIN xp_levels x    ON x.user_id = a.user_id
LEFT JOIN clue_counts c  ON c.user_id = a.user_id
LEFT JOIN streak_calc sk ON sk.user_id = a.user_id
WHERE p.id = a.user_id;

-- ---------------------------------------------------------------------------
-- 7. Handle users who had ALL their flights deleted (no remaining scores)
-- ---------------------------------------------------------------------------
UPDATE public.profiles p
SET
  games_played = 0, best_score = NULL, best_time_ms = NULL,
  total_flight_time_ms = 0, countries_found = 0,
  level = 1, xp = 0,
  flags_correct = 0, capitals_correct = 0, outlines_correct = 0,
  borders_correct = 0, stats_correct = 0, best_streak = 0,
  updated_at = NOW()
WHERE p.games_played > 0
  AND NOT EXISTS (SELECT 1 FROM public.scores s WHERE s.user_id = p.id);

COMMIT;
