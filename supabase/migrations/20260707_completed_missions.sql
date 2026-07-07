-- APPLY-HELD: additive column, applied by the repo owner (not auto-applied).
-- Adds durable server storage for Basic Training / campaign mission completion.
--
-- Why: `completedMissionIds` (training + campaign completion, tracked via
-- completeCampaignMission/completeTrainingMission in account_provider.dart) had
-- NO server column — account_state only carried flight_school_progress. So
-- training completion lived only in the client crash-safe cache and was lost
-- whenever that cache was dropped or a server-side account_state write bumped
-- updated_at (server-wins recovery re-hydrated from a row with no mission data).
-- That re-locked dailies/modes and could block the Level-2 promotion.
--
-- This column is the durable source of truth for WHICH missions are complete
-- (the unlock/promotion gate). Per-mission score/stars stay best-effort in the
-- client and are not required for gating.
--
-- SAFETY / feature-detection: this is an additive column with a default, so it
-- is low-risk. The client feature-detects the account_state columns at load
-- time and DEGRADES GRACEFULLY before this migration is applied — it strips
-- `completed_mission_ids` (and any other unknown column) from the upsert payload
-- so writes still succeed, and falls back to the pre-existing behaviour. After
-- this migration lands, the column is observed on load and begins persisting.
-- No client deploy needs to be gated on this migration.

ALTER TABLE public.account_state
  ADD COLUMN IF NOT EXISTS completed_mission_ids TEXT[] NOT NULL DEFAULT '{}';

-- GIN index for querying players by completed mission (e.g. cohort/funnel
-- analytics: how many pilots finished Basic Training).
CREATE INDEX IF NOT EXISTS idx_account_completed_mission_ids
  ON public.account_state USING gin (completed_mission_ids);
