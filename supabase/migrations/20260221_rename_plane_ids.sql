-- Rename plane IDs to avoid trademarked aircraft names.
-- equipped_plane_id lives on account_state (not profiles).
-- owned_cosmetics is the correct column name (not purchased_cosmetics).

UPDATE public.account_state
SET equipped_plane_id = 'plane_warbird'
WHERE equipped_plane_id = 'plane_spitfire';

UPDATE public.account_state
SET equipped_plane_id = 'plane_night_raider'
WHERE equipped_plane_id = 'plane_lancaster';

UPDATE public.account_state
SET equipped_plane_id = 'plane_presidential'
WHERE equipped_plane_id = 'plane_air_force_one';

UPDATE public.account_state
SET equipped_plane_id = 'plane_padraigaer'
WHERE equipped_plane_id = 'plane_bryanair';

-- Also update any owned_cosmetics arrays that reference the old IDs.
UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_spitfire', 'plane_warbird')
WHERE 'plane_spitfire' = ANY(owned_cosmetics);

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_lancaster', 'plane_night_raider')
WHERE 'plane_lancaster' = ANY(owned_cosmetics);

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_air_force_one', 'plane_presidential')
WHERE 'plane_air_force_one' = ANY(owned_cosmetics);

UPDATE public.account_state
SET owned_cosmetics = array_replace(owned_cosmetics, 'plane_bryanair', 'plane_padraigaer')
WHERE 'plane_bryanair' = ANY(owned_cosmetics);
