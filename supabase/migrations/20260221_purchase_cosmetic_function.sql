-- ---------------------------------------------------------------------------
-- Server-side cosmetic purchase function
-- ---------------------------------------------------------------------------
-- Atomically validates the player has enough coins, deducts the cost, and
-- adds the cosmetic to owned_cosmetics. This prevents client-side coin
-- manipulation and race conditions from concurrent purchases.
--
-- Returns JSON: { "success": true/false, "error": "...", "new_balance": N }
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.purchase_cosmetic(
  p_user_id UUID,
  p_cosmetic_id TEXT,
  p_cost INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_coins INT;
  v_owned TEXT[];
  v_new_balance INT;
BEGIN
  -- Validate inputs.
  IF p_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cost');
  END IF;

  IF p_cosmetic_id IS NULL OR p_cosmetic_id = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid cosmetic ID');
  END IF;

  -- Lock the profile row to prevent concurrent purchases.
  SELECT coins INTO v_current_coins
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  -- Check balance.
  IF v_current_coins < p_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient coins',
      'current_balance', v_current_coins,
      'cost', p_cost
    );
  END IF;

  -- Check if already owned.
  SELECT owned_cosmetics INTO v_owned
  FROM public.account_state
  WHERE user_id = p_user_id;

  IF v_owned IS NOT NULL AND p_cosmetic_id = ANY(v_owned) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already owned',
      'current_balance', v_current_coins
    );
  END IF;

  -- Deduct coins.
  v_new_balance := v_current_coins - p_cost;
  UPDATE public.profiles
  SET coins = v_new_balance
  WHERE id = p_user_id;

  -- Add to owned_cosmetics (create account_state row if missing).
  INSERT INTO public.account_state (user_id, owned_cosmetics)
  VALUES (p_user_id, ARRAY[p_cosmetic_id])
  ON CONFLICT (user_id) DO UPDATE
  SET owned_cosmetics = array_append(
    COALESCE(account_state.owned_cosmetics, '{}'),
    p_cosmetic_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'cosmetic_id', p_cosmetic_id
  );
END;
$$;

-- Grant to authenticated users (called from Flutter client via RPC).
GRANT EXECUTE ON FUNCTION public.purchase_cosmetic(UUID, TEXT, INT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_cosmetic(UUID, TEXT, INT)
  TO service_role;
