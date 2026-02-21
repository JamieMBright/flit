-- Rename plane IDs in user profiles to avoid trademarked aircraft names.
-- This updates any saved equipped_plane_id values to the new fictional names.

UPDATE public.profiles
SET equipped_plane_id = 'plane_warbird'
WHERE equipped_plane_id = 'plane_spitfire';

UPDATE public.profiles
SET equipped_plane_id = 'plane_night_raider'
WHERE equipped_plane_id = 'plane_lancaster';

UPDATE public.profiles
SET equipped_plane_id = 'plane_presidential'
WHERE equipped_plane_id = 'plane_air_force_one';

UPDATE public.profiles
SET equipped_plane_id = 'plane_padraigaer'
WHERE equipped_plane_id = 'plane_bryanair';

-- Also update any purchased_cosmetics arrays that reference the old IDs.
UPDATE public.account_state
SET purchased_cosmetics = array_replace(purchased_cosmetics, 'plane_spitfire', 'plane_warbird')
WHERE 'plane_spitfire' = ANY(purchased_cosmetics);

UPDATE public.account_state
SET purchased_cosmetics = array_replace(purchased_cosmetics, 'plane_lancaster', 'plane_night_raider')
WHERE 'plane_lancaster' = ANY(purchased_cosmetics);

UPDATE public.account_state
SET purchased_cosmetics = array_replace(purchased_cosmetics, 'plane_air_force_one', 'plane_presidential')
WHERE 'plane_air_force_one' = ANY(purchased_cosmetics);

UPDATE public.account_state
SET purchased_cosmetics = array_replace(purchased_cosmetics, 'plane_bryanair', 'plane_padraigaer')
WHERE 'plane_bryanair' = ANY(purchased_cosmetics);
