-- 005_difficulty_config_and_recalibrate.sql
--
-- Adds:
--   1. difficulty_config table — singleton JSONB store for admin difficulty
--      overrides (country ratings + clue weights).
--   2. upsert_difficulty_config() RPC — idempotent upsert.
--   3. recalibrate_scores() RPC — retroactively applies difficulty multipliers
--      to all historical scores using their round_details.
--
-- Idempotent: all objects guarded with IF NOT EXISTS / CREATE OR REPLACE.

-- ─── 1. difficulty_config table ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.difficulty_config (
  id            INT PRIMARY KEY DEFAULT 1,
  -- Per-country difficulty overrides: { "BR": 0.06, "JE": 0.83, ... }
  country_overrides JSONB NOT NULL DEFAULT '{}'::JSONB,
  -- Per-clue-type weight overrides: { "borders": 0.10, "flag": 0.30, ... }
  clue_weights      JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by        UUID REFERENCES auth.users(id)
);

-- Ensure only one row ever exists.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.difficulty_config WHERE id = 1
  ) THEN
    INSERT INTO public.difficulty_config (id) VALUES (1);
  END IF;
END $$;

-- RLS: all authenticated users can read, only service_role can write.
ALTER TABLE public.difficulty_config ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'difficulty_config' AND policyname = 'difficulty_config_select'
  ) THEN
    CREATE POLICY difficulty_config_select ON public.difficulty_config
      FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- ─── 2. upsert_difficulty_config RPC ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.upsert_difficulty_config(
  p_country_overrides JSONB DEFAULT NULL,
  p_clue_weights      JSONB DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.difficulty_config (id, country_overrides, clue_weights, updated_at, updated_by)
  VALUES (
    1,
    COALESCE(p_country_overrides, '{}'::JSONB),
    COALESCE(p_clue_weights, '{}'::JSONB),
    now(),
    auth.uid()
  )
  ON CONFLICT (id) DO UPDATE SET
    country_overrides = COALESCE(p_country_overrides, difficulty_config.country_overrides),
    clue_weights      = COALESCE(p_clue_weights, difficulty_config.clue_weights),
    updated_at        = now(),
    updated_by        = auth.uid();
END;
$$;

-- ─── 3. recalibrate_scores RPC ──────────────────────────────────────────────
--
-- Accepts a JSONB map of country_name → multiplier (computed client-side so
-- the client can resolve names/codes and apply admin overrides).
--
-- For each score row with round_details:
--   - Uses raw_score if present, otherwise treats the existing score as raw.
--   - Applies:  new_score = round(raw_score × multiplier)
--   - Stores raw_score and difficulty_multiplier back into round_details.
--   - Recomputes the total score as the sum of per-round scores.
--
-- Returns the number of score rows updated.

CREATE OR REPLACE FUNCTION public.recalibrate_scores(
  country_multipliers JSONB  -- { "Brazil": 0.53, "Jersey": 0.915, ... }
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  updated_count INT := 0;
  score_row     RECORD;
  new_details   JSONB;
  new_total     INT;
  round_entry   JSONB;
  raw_score     INT;
  multiplier    DOUBLE PRECISION;
  country_name  TEXT;
  new_round_score INT;
BEGIN
  FOR score_row IN
    SELECT id, score, round_details
    FROM public.scores
    WHERE round_details IS NOT NULL
      AND jsonb_array_length(round_details) > 0
  LOOP
    new_details := '[]'::JSONB;
    new_total := 0;

    FOR round_entry IN SELECT * FROM jsonb_array_elements(score_row.round_details)
    LOOP
      country_name := round_entry ->> 'country_name';

      -- Use raw_score if already stored (from a previous recalibration or
      -- from new game sessions), otherwise treat the current score as raw.
      raw_score := COALESCE(
        (round_entry ->> 'raw_score')::INT,
        (round_entry ->> 'score')::INT
      );

      -- Look up the multiplier; default 0.75 for unknown countries.
      multiplier := COALESCE(
        (country_multipliers ->> country_name)::DOUBLE PRECISION,
        0.75
      );

      new_round_score := GREATEST(0, LEAST(10000, ROUND(raw_score * multiplier)::INT));

      -- Merge updated fields into the round entry.
      new_details := new_details || jsonb_build_array(
        round_entry
          || jsonb_build_object('raw_score', raw_score)
          || jsonb_build_object('score', new_round_score)
          || jsonb_build_object('difficulty_multiplier', ROUND(multiplier::NUMERIC, 4))
      );

      new_total := new_total + new_round_score;
    END LOOP;

    -- Cap total score at 100 000 (consistent with client validation).
    new_total := LEAST(new_total, 100000);

    UPDATE public.scores
    SET score         = new_total,
        round_details = new_details
    WHERE id = score_row.id;

    updated_count := updated_count + 1;
  END LOOP;

  RETURN updated_count;
END;
$$;
