-- Coin-pack IAP groundwork: server-side catalog only.
--
-- The coin_packs table mirrors CoinPackCatalog on the client
-- (lib/data/models/coin_pack.dart) so a future receipt-validation edge
-- function has an authoritative price list. There is NO purchase flow /
-- store integration yet — the client's CoinPackGateway is a stub and the
-- shop renders the packs as "coming soon".
--
-- NOT YET APPLIED. The client never reads this table today (it ships a
-- hardcoded catalog copy), so applying is zero-risk and non-urgent.

CREATE TABLE IF NOT EXISTS public.coin_packs (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  coins       INT NOT NULL CHECK (coins > 0),
  usd_price   NUMERIC(6,2) NOT NULL CHECK (usd_price >= 0),
  bonus_label TEXT,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0
);

ALTER TABLE public.coin_packs ENABLE ROW LEVEL SECURITY;

-- Catalog is public read-only; writes via service role / dashboard only.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'coin_packs' AND policyname = 'Coin packs are publicly readable'
  ) THEN
    CREATE POLICY "Coin packs are publicly readable"
      ON public.coin_packs FOR SELECT USING (true);
  END IF;
END $$;

-- Seed the launch catalog (keep in sync with CoinPackCatalog.packs).
INSERT INTO public.coin_packs (id, name, coins, usd_price, bonus_label, sort_order)
VALUES
  ('coin_pack_pocket', 'Pocket Change',  500,  1.99, NULL,          1),
  ('coin_pack_duffel', 'Duffel Bag',    1500,  4.99, '+20% bonus',  2),
  ('coin_pack_crate',  'Cargo Crate',   4000,  9.99, '+60% bonus',  3),
  ('coin_pack_vault',  'Sky Vault',    10000, 19.99, 'Best value',  4)
ON CONFLICT (id) DO NOTHING;
