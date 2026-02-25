# Stat Reset Audit — 2026-02-25

> Complete trace of every database read and write path. Covers login, gameplay,
> shop, gifting, daily challenges, periodic refresh, crash recovery, and admin
> operations. Cross-referenced with ARCHITECTURE.md bugs 1-5.

---

## TL;DR

The 5 previously identified bugs (version counter race, abort callback order,
flush mutex, crash-safe cache, ARCHITECTURE doc) **are all fixed in code**.
This audit found **4 new bugs** that can still cause stat regressions:

| # | Severity | Summary |
|---|----------|---------|
| 6 | **HIGH** | Purchase double-deduction: client `spendCoins()` + server RPC both deduct coins, then fire-and-forget reconciliation races the debounced upsert |
| 7 | **HIGH** | `sendCoins` same pattern: DB RPC deducts server-side, then client calls `spendCoins()` writing stale balance via upsert |
| 8 | **MEDIUM** | `_recoverLocalCache` has no monotonic protection for `account_state` — stale crash-safe cache can overwrite server-side streak, cosmetics, license |
| 9 | **LOW** | `_applySnapshot` unconditionally overwrites account_state fields (cosmetics, streak, license) from server — safe only because the `hasPendingWrites` guard is correct, but fragile |
| 10 | **HIGH** | Crash-safe cache coin duplication: `_recoverLocalCache` lets stale local coins overwrite legitimately lower server balance (purchases/gifts on other device) |
| 11 | **HIGH** | `backfill_profile_stats_from_scores.sql` uses blind UPDATE without GREATEST — running on live DB destroys per-clue stats and regresses counters |
| 12 | **LOW** | Admin rename raw `.update()` fails silently on other users (RLS blocks it) — latent admin bug, not a stat reset vector |

---

## Database Read/Write Ordering — Complete Trace

### Phase 1: App Startup (before `runApp`)

```
main()
  1. WidgetsFlutterBinding.ensureInitialized()
  2. GameSettings.loadFromLocal()          ← READ SharedPreferences("game_settings")
     _hydrating = true → blocks writes to Supabase
     Applies audio settings to AudioManager
     _hydrating = false
  3. Supabase.initialize(url, anonKey)     ← Restores JWT from local storage
  4. ErrorService.initialize()
  5. Timer.periodic(60s → ErrorService.flush)
  6. AudioManager.initialize()
  7. WebFlushBridge.register()             ← beforeunload → flush()
  8. runApp(ProviderScope → FlitApp → LoginScreen)
```

**No stat reads or writes in this phase.** GameSettings are read from local
cache for fast first-frame display.

### Phase 2: Auth Gate (LoginScreen)

```
LoginScreen.initState()
  → _checkExistingSession()
    → AuthService.checkExistingAuth()
      → READ Supabase.auth.currentSession    (local JWT cache, no network)
      → READ Supabase.auth.currentUser        (local cache)
      → if session exists:
          → _fetchOrCreateProfile(user)
            → READ profiles WHERE id = user.id  (NETWORK: SELECT *)
            → if null: backfill from user.userMetadata (username, display_name)
          → AccountNotifier.loadFromSupabase(player.id)
            → Phase 3
```

**Key observation:** `_fetchOrCreateProfile` reads the profile but does NOT
write stats. It only backfills `username` and `display_name` if the profile
row is missing (race during signup where trigger hasn't fired yet).

### Phase 3: Data Load (the critical phase)

```
AccountNotifier.loadFromSupabase(userId)
  1. _prefs.clearDirtyFlags()             ← Cancel stale debounced writes
     _profileDirty = false
     _settingsDirty = false
     _accountStateDirty = false
     _pendingProfile = null               ← Any queued writes from prior session: GONE
     Version counters bumped              ← In-flight .then() callbacks won't clear flags
  2. _userId = userId
  3. _supabaseLoaded = false              ← BLOCKS all writes until step 8

  4. Retry loop (up to 3 attempts, backoff 1s/2s/4s):
     _prefs.load(userId)
       → _ensureQueueInitialised()        ← Init SharedPreferences + offline queue
       → Future.wait([                    ← PARALLEL NETWORK READS
           SELECT * FROM profiles        WHERE id = userId
           SELECT * FROM user_settings   WHERE user_id = userId
           SELECT * FROM account_state   WHERE user_id = userId
         ])
       → _recoverLocalCache(profiles)     ← READ SharedPreferences("crash_safe_profile")
         if cached data user_id matches:
           merged = {...serverData, ...localData}
           Monotonic fields: max(server, local) for games_played, level, xp, etc.
           best_score: max(server, local)
           best_time_ms: min(server, local)
           ⚠ BUG 8: NO monotonic protection for account_state fields
       → _recoverLocalCache(settings)     ← READ SharedPreferences("crash_safe_settings")
       → _recoverLocalCache(account_state) ← READ SharedPreferences("crash_safe_account_state")
       → Returns UserPreferencesSnapshot

  5. _applySnapshot(snapshot, hydrateSettings: true)
     → serverPlayer = snapshot.toPlayer()
       Default fallbacks: level=1, xp=0, coins=100 (new player), gamesPlayed=0
     → if local.id == serverPlayer.id (returning user):
         Monotonic merge: max(local, server) for all accumulator stats
         Coins: server value wins (NOT protected)
         bestScore: max(local, server)
         bestTime: min(local, server)
       else (first load, id=''):
         Use serverPlayer as-is (no merge)
     → state = AccountState(player, avatar, license, streak, cosmetics, ...)
       ⚠ Account state fields are UNCONDITIONALLY set from server

  6. _supabaseLoaded = true               ← WRITES NOW ENABLED

  7. GameSettings.hydrateFrom(...)         ← Overwrites local settings with server
     _hydrating = true (blocks write-back loop)
     Sets all settings fields
     _saveToLocal()                        ← WRITE SharedPreferences("game_settings")
     _hydrating = false

  8. _startPeriodicRefresh()              ← Timer every 5 min → refreshFromServer()
```

### Phase 4: Gameplay (game in progress)

```
PlayScreen._startNewGame()
  → GameSession.random()                  ← No DB reads/writes
  → _elapsed = Duration.zero
  → _cumulativeTime = Duration.zero
  → _roundResults.clear()
  → _hintTier = 0

During gameplay:
  → _session.recordPosition()             ← No DB writes (local accumulator)
  → Timer: _elapsed updates               ← No DB writes

Round completion (_advanceRound):
  → _session.complete(hintsUsed, fuelFrac)
  → _totalScore += _session.score         ← Local accumulator
  → _roundResults.add(...)                ← Local accumulator
  → Next round starts                     ← No DB writes
```

**No database writes during active gameplay.** All stats accumulate locally
until game completion.

### Phase 5: Game Completion (CRITICAL write path)

```
_completeLanding() or _recordAbort()
  1. widget.onComplete?.call(_totalScore)  ← Daily streak callback FIRST
  2. widget.onDailyComplete?.call(result)  ← Daily result callback FIRST
     These fire _syncAccountState() → saveAccountState() → marks dirty

  3. await recordGameCompletion(...)       ← The main stat write
     ├── incrementGamesPlayed()           → state.gamesPlayed++        → _syncProfile()
     ├── updateBestScore(score)           → if higher: state.bestScore → _syncProfile()
     ├── updateBestTime(elapsed)          → if lower: state.bestTime   → _syncProfile()
     ├── addFlightTime(elapsed)           → state.totalFlightTime +=   → _syncProfile()
     ├── incrementCountriesFound(rounds)  → state.countriesFound +=    → _syncProfile()
     ├── recordClueAnswers(...)           → state.*Correct +=          → _syncProfile()
     ├── updateBestStreak(streak)         → if higher: state.bestStreak → _syncProfile()
     ├── addXp(xp)                        → state.xp +=, level-up?    → _syncProfile()
     ├── addCoins(reward)                 → state.coins += (boosted)   → _syncProfile()
     │   └── _logCoinActivity()           → fire-and-forget INSERT coin_activity
     ├── await _prefs.saveGameResult()    → INSERT INTO scores (NETWORK, immediate)
     └── await _prefs.flush()             → IMMEDIATE UPSERT profiles, account_state
                                            (cancels debounce timer, flushes NOW)
```

**Each `_syncProfile()` call:**
1. `_profileWriteVersion++`
2. `_profileDirty = true`
3. `_pendingProfile = {ALL fields from current state}`  ← REPLACES previous
4. `_cacheLocally("crash_safe_profile", _pendingProfile)` ← WRITE SharedPreferences
5. `_scheduleSave()` → cancels + restarts 2s debounce timer

By the time `flush()` runs, `_pendingProfile` contains the FINAL accumulated
state after all mutations. The debounce timer is killed. One upsert carries
everything. Version counter ensures that if a new write happens during the
network round-trip, the dirty flag stays set.

### Phase 6: Periodic Refresh (every 5 minutes)

```
refreshFromServer()
  → if hasPendingWrites || hasPendingOfflineWrites:
      await flush()                        ← Push local changes first
  → if STILL has pending writes:
      return                               ← DON'T overwrite local with stale server
  → snapshot = await _prefs.load(userId)   ← NETWORK: SELECT from 3 tables
  → _applySnapshot(snapshot, hydrateSettings: false)
    Monotonic merge for profile stats
    Server wins for coins
    ⚠ Unconditional overwrite for account_state (but safe because dirty check above)
```

### Phase 7: Shop Purchases (PROBLEMATIC)

```
purchaseCosmetic(cosmeticId, cost)
  1. spendCoins(cost)                     → state.coins -= cost
     → _syncProfile()                     → saveProfile({coins: localBalance - cost})
     → schedules 2s debounce write

  2. state.ownedCosmetics += cosmeticId
     → _syncAccountState()

  3. _serverValidatePurchase(cosmeticId, cost)  ← FIRE-AND-FORGET async
     → RPC: purchase_cosmetic(userId, cosmeticId, cost)
       Server atomically: coins -= cost, cosmetics += cosmeticId
       Returns {success: true, new_balance: serverBalance}
     → Reconciliation: if serverBalance != localCoins:
         state.coins = serverBalance       ← OVERWRITES local
         _logCoinActivity(delta, 'server_balance_reconcile')
         ⚠ Does NOT call _syncProfile() after reconciliation!
```

#### BUG 6 — Purchase Double-Deduction Race

**Scenario:**
```
Time 0: Server=500, Client=500
Time 1: purchaseCosmetic(100)
         spendCoins(100) → Client=400 → saveProfile({coins:400}) → 2s debounce starts
Time 2: _serverValidatePurchase fires → RPC atomically: 500-100=400 → returns 400
Time 3: Reconciliation: serverBalance(400) == localCoins(400) → no-op ✓
Time 4: Debounce fires → UPSERT SET coins=400 → OK (matches) ✓
```

**This case is fine.** But with concurrent operations:

```
Time 0: Server=500, Client=500
Time 1: purchaseCosmetic(100)
         spendCoins(100) → Client=400 → saveProfile({coins:400}) → debounce starts
Time 2: Player completes a game → addCoins(50) → Client=450 → saveProfile({coins:450})
         (replaces _pendingProfile with {coins:450})
Time 3: Debounce fires → UPSERT SET coins=450 → Server goes from 500 to 450
Time 4: RPC returns: Server had 500, atomically 500-100=400. But upsert at Time 3
         already set server to 450. RPC reads 450 → 450-100=350.
         Reconciliation: serverBalance(350) != localCoins(450) → set local to 350.
Time 5: _syncProfile() → saveProfile({coins:350}) → debounce → UPSERT SET coins=350
```

**Result:** Player started with 500, earned 50, spent 100. Expected: 450. Got: 350.
**Lost 100 coins.** The purchase cost was applied twice (once by upsert, once by RPC).

The root cause: **coins are being modified by TWO independent paths** (client upsert
and server RPC) without coordination. The client upsert is a blind `SET coins = X`
while the RPC atomically decrements from the current server value.

### Phase 8: Sending Coins to Friends (SAME PROBLEM)

```
sendCoins flow:
  1. FriendsService.sendCoins() → RPC: send_coins(sender, recipient, amount)
     Server atomically: sender.coins -= amount, recipient.coins += amount
     Returns {success: true, sender_balance: X}
  2. if ok: accountProvider.spendCoins(amount)
     → state.coins -= amount → _syncProfile() → saveProfile({coins: localBalance})
     ⚠ sender_balance from RPC response is IGNORED
```

#### BUG 7 — sendCoins Double-Deduction

```
Time 0: Server=500, Client=500
Time 1: sendCoins RPC starts → network round-trip...
Time 2: RPC returns success → server: 400 (atomically deducted)
Time 3: spendCoins(100) → Client: 400 → saveProfile({coins:400})
Time 4: Debounce fires → UPSERT SET coins=400 → Server stays 400 ✓
```

**Clean case is OK**, but with concurrent changes:

```
Time 0: Server=500, Client=500
Time 1: sendCoins RPC starts
Time 2: Meanwhile, game completes → addCoins(50) → Client=550 → saveProfile({coins:550})
Time 3: Debounce fires → UPSERT SET coins=550 → Server: 550
Time 4: RPC arrives (was reading 500, atomically 500-100=400)
         But server was already 550 from step 3. The RPC read started before
         the upsert, so it reads 500. Wait — RPCs use transactions. The RPC
         will see 500 if it started before the upsert committed, or 550 if after.
```

The exact outcome depends on PostgreSQL transaction isolation. With default
READ COMMITTED, the RPC's SELECT within the function sees the latest committed
value. If the upsert committed before the RPC's SELECT, it reads 550 and
deducts to 450. Then `spendCoins(100)` sets client to 450 → upsert writes 450.
Player net: started 500, earned 50, sent 100 = expected 450. Got 450. ✓

If the upsert commits AFTER the RPC reads (rare but possible):
- RPC reads 500, deducts to 400. Server: 400.
- Upsert writes 550. Server: 550 (overwrites RPC's deduction!).
- spendCoins(100) → client: 450 → next debounce → upsert writes 450. Server: 450.
- **Player should have 450 (500+50-100). Got 450.** ✓ in this case.

But the recipient got their coins from the RPC. So the total coins in the
system increased (donor lost 50, but only the RPC deducted from the donor's
actual balance which was then overwritten).

**The key issue is that `sender_balance` from the RPC is ignored**, so any
balance reconciliation that should happen doesn't.

---

## Previously Known Bugs — Status

### BUG 1 — Flush `.then()` race silently drops writes
**STATUS: FIXED** ✓

`user_preferences_service.dart:226-228`: Three write-version counters
(`_profileWriteVersion`, `_settingsWriteVersion`, `_accountStateWriteVersion`)
are captured at flush start and checked in the `.then()` callback. Dirty flags
are only cleared if the version is unchanged. If a new `saveProfile()` call
happens during the network round-trip, the version increments and the dirty
flag stays set, ensuring the next flush picks up the newer data.

### BUG 2 — Abort path fires daily callbacks AFTER flush
**STATUS: FIXED** ✓

`play_screen.dart:1110-1141`: In `_recordAbort()`, daily callbacks
(`widget.onComplete`, `widget.onDailyComplete`) now fire BEFORE
`recordGameCompletion()` (line 1146), matching the ordering in
`_completeLanding()`. Both daily streak and daily result are dirty
before the `flush()` inside `recordGameCompletion()`.

### BUG 3 — No flush mutex allows concurrent writes
**STATUS: FIXED** ✓

`user_preferences_service.dart:252`: `Completer<void>? _flushLock`. Acquired
at the start of `_flush()` (line 829), any concurrent call awaits the
existing completer (line 820), released in `finally` block (line 937).

### BUG 4 — Crash-safe cache stale overwrite
**STATUS: FIXED** ✓

Same version-counter mechanism as BUG 1. `_clearLocalCache` only runs when
`_profileWriteVersion == versionAtFlush` (line 871). If a new write happened
during the flush, the cache persists for the next load.

### BUG 5 — ARCHITECTURE.md Flow 8 wrong callback order
**STATUS: NOT FIXED** (docs only, low severity)

The ARCHITECTURE.md document still shows the old ordering where daily
callbacks fired after `recordGameCompletion`. The code is correct but the
docs are stale.

---

## New Bugs Found

### BUG 6 — Purchase Double-Deduction Race (HIGH)

**File:** `account_provider.dart:791-848`

**Root cause:** `purchaseCosmetic()` and `purchaseAvatarPart()` both:
1. Call `spendCoins(cost)` which deducts from local state and queues a
   debounced upsert (`SET coins = localBalance`)
2. Fire-and-forget an RPC (`purchase_cosmetic` / `purchase_avatar_part`) which
   atomically deducts from the server balance

If the debounced upsert fires BEFORE the RPC reads the server balance, the
RPC deducts from the already-reduced balance, causing a double deduction.

Additionally, the reconciliation at lines 823-832 sets `state.coins =
serverBalance` but does NOT call `_syncProfile()`. This means the reconciled
balance is in memory but NOT queued for persistence. The next `_syncProfile()`
from any other mutation will persist it, but there's a window where the local
state shows the correct balance but the pending upsert payload still has the
pre-reconciliation value.

**Fix:** Remove `spendCoins()` from the purchase methods entirely. Instead:
1. Apply the coin deduction optimistically in local state only (no
   `_syncProfile()`)
2. Await the RPC
3. On success: set `state.coins = serverBalance` and call `_syncProfile()`
4. On failure: revert the optimistic deduction

Or simpler: make the RPC the only deduction path (await it, use `new_balance`).

### BUG 7 — sendCoins Ignores Server Balance (HIGH)

**File:** `friends_screen.dart:653-665`

**Root cause:** After the `send_coins` RPC succeeds, the code calls
`accountProvider.spendCoins(amount)` (a local deduction + upsert) instead of
using the `sender_balance` returned by the RPC.

The RPC returns `{'success': true, 'sender_balance': X, 'amount': N}` but
`FriendsService.sendCoins()` returns only `bool` (line 561), discarding the
balance info.

**Fix:** Return the full RPC result from `sendCoins()`. In `friends_screen.dart`,
use `sender_balance` to set the authoritative coin balance instead of calling
`spendCoins()`.

### BUG 8 — Crash-Safe Cache Missing Account State Protection (MEDIUM)

**File:** `user_preferences_service.dart:755`

**Root cause:** `_recoverLocalCache` only applies monotonic stat protection for
the `_kLocalProfile` key. The `_kLocalSettings` and `_kLocalAccountState`
caches use a blind `{...serverData, ...localData}` merge with no field-level
guards.

**Scenario:** Player on Device A has the crash-safe account_state cache from
a session where daily_streak was 5. Player completes a daily on Device B,
advancing streak to 6 on the server. Player returns to Device A. The stale
local cache overwrites `daily_streak_data` from 6 back to 5.

**Affected fields:** `daily_streak_data`, `license_data`, `owned_cosmetics`,
`owned_avatar_parts`, `avatar_config`, `equipped_plane_id`,
`equipped_contrail_id`, `last_daily_challenge_date`, `last_daily_result`.

**Fix:** Add monotonic/merge-safe logic for account_state fields:
- `daily_streak_data.currentStreak`: max(server, local)
- `daily_streak_data.longestStreak`: max(server, local)
- `daily_streak_data.totalCompleted`: max(server, local)
- `owned_cosmetics`: union(server, local)
- `owned_avatar_parts`: union(server, local)
- `unlocked_regions`: union(server, local)

### BUG 9 — `_applySnapshot` Account State Unconditional Overwrite (LOW)

**File:** `account_provider.dart:304-318`

**Root cause:** `_applySnapshot()` unconditionally sets ALL account_state
fields from the server snapshot, with no monotonic merge. Profile stats
get the `max()` merge (lines 260-301) but account_state fields don't.

**Why it's LOW and not MEDIUM:** The `hasPendingWrites` guard in
`refreshFromServer()` (line 381) correctly prevents overwriting dirty local
state. For the guard to fail, `_accountStateDirty` would need to be `false`
while the local state is actually ahead of the server. This can only happen
if the flush succeeded (so the server is up-to-date) or if `clearDirtyFlags()`
was called (only at start of `loadFromSupabase()` which immediately overwrites
everything anyway).

**Risk:** If a new write path is added that modifies account_state but forgets
to call `_syncAccountState()`, the dirty flag won't be set and the periodic
refresh will overwrite the change. Currently all write paths correctly call
`_syncAccountState()`, so this is defense-in-depth.

---

## All Database Write Paths — Complete Inventory

### Client → Supabase (via debounced upsert)

| Path | Table | Trigger |
|------|-------|---------|
| `_syncProfile()` | `profiles` | Every stat mutation, coin change, username edit |
| `_syncAccountState()` | `account_state` | Avatar, license, cosmetics, equips, streak, daily |
| `_syncToSupabase()` (GameSettings) | `user_settings` | Any settings change |
| `saveGameResult()` | `scores` | Game completion (immediate, not debounced) |
| `saveCoinActivity()` | `coin_activity` | Coin earn/spend (fire-and-forget) |

### Client → Supabase (via RPC)

| Path | Function | What it modifies |
|------|----------|-----------------|
| Shop purchase | `purchase_cosmetic` | profiles.coins, account_state.owned_cosmetics |
| Avatar part purchase | `purchase_avatar_part` | profiles.coins, account_state.owned_avatar_parts |
| Send coins | `send_coins` | Two profiles.coins rows + coin_activity |
| Gift cosmetic | `gift_cosmetic` | profiles.coins + account_state.owned_cosmetics |
| Gift avatar part | `gift_avatar_part` | profiles.coins + account_state.owned_avatar_parts |
| Admin increment | `admin_increment_stat` | profiles.{column} (bypasses trigger) |
| Admin set | `admin_set_stat` | profiles.{column} (bypasses trigger) |

### Server-Side Triggers

| Trigger | Table | Action |
|---------|-------|--------|
| `handle_new_user` | auth.users → profiles, user_settings, account_state | INSERT defaults |
| `update_updated_at` | profiles, user_settings, account_state, friendships | SET updated_at |
| `protect_profile_stats` | profiles (BEFORE UPDATE) | Monotonic stat protection: GREATEST for counters, GREATEST for best_score, LEAST for best_time_ms. Coins excluded. Bypassable via `app.skip_stat_protection`. |

### The Monotonic Protection Stack

Stats are protected at THREE levels:

1. **Client-side `_applySnapshot()`** — `math.max()` merge prevents stale
   server data from overwriting local counters during periodic refresh
2. **Client-side `_recoverLocalCache()`** — `max()` merge prevents stale
   crash-safe cache from overwriting server data on next login
3. **Server-side `protect_profile_stats` trigger** — `GREATEST()` prevents
   any UPDATE from decreasing counters, regardless of source

**Coins are deliberately excluded from all three levels** (server-authoritative,
consumable). This is correct design, but it means coin bugs (6 and 7) have no
safety net.

---

## Recommendations

### Priority 1 — Fix purchase coin flow (BUG 6)

```dart
// account_provider.dart — purchaseCosmetic()
Future<bool> purchaseCosmetic(String cosmeticId, int cost) async {
  if (state.currentPlayer.coins < cost) return false;
  // Optimistic local deduction (no _syncProfile)
  state = state.copyWith(
    currentPlayer: state.currentPlayer.copyWith(
      coins: state.currentPlayer.coins - cost,
    ),
    ownedCosmetics: {...state.ownedCosmetics, cosmeticId},
  );
  // Let server be authoritative
  try {
    final result = await Supabase.instance.client.rpc('purchase_cosmetic', ...);
    if (result['success'] == true) {
      final serverBalance = result['new_balance'] as int;
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(coins: serverBalance),
      );
      _syncProfile();  // Persist the SERVER-reconciled balance
      _syncAccountState();
      return true;
    } else {
      // Revert
      state = state.copyWith(
        currentPlayer: state.currentPlayer.copyWith(
          coins: state.currentPlayer.coins + cost,
        ),
        ownedCosmetics: state.ownedCosmetics.difference({cosmeticId}),
      );
      return false;
    }
  } catch (e) {
    // Offline fallback: keep optimistic state, sync will push it
    _syncProfile();
    _syncAccountState();
    return true;
  }
}
```

### Priority 2 — Fix sendCoins balance reconciliation (BUG 7)

Change `FriendsService.sendCoins()` to return the `sender_balance` from the
RPC. In `friends_screen.dart`, use it to set coins instead of calling
`spendCoins()`.

### Priority 3 — Add account_state monotonic protection (BUG 8)

In `_recoverLocalCache()`, when `key == _kLocalAccountState`:
- Union-merge set fields: `owned_cosmetics`, `owned_avatar_parts`,
  `unlocked_regions`
- Max-merge streak fields: parse `daily_streak_data` and take max of
  `currentStreak`, `longestStreak`, `totalCompleted`

### Priority 4 — Fix crash-safe cache coin duplication (BUG 10)

In `_recoverLocalCache()`, after the `{...serverData, ...localData}` merge,
force coins to be server-authoritative:
```dart
if (key == _kLocalProfile) {
  // ... existing monotonic fields ...
  // Coins: always trust server (coins are consumable, not monotonic)
  merged['coins'] = serverData['coins'] ?? localData['coins'];
}
```

### Priority 5 — Make backfill script safe (BUG 11)

Change `backfill_profile_stats_from_scores.sql` to use `GREATEST()`:
```sql
UPDATE public.profiles p
SET
  games_played = GREATEST(p.games_played, a.games_played),
  best_score = GREATEST(p.best_score, a.best_score),
  best_time_ms = LEAST(p.best_time_ms, a.best_time_ms),
  ...
```

### Priority 6 — Update ARCHITECTURE.md (BUG 5 + new findings)

Update Flow 8 callback ordering and add these new findings to the known
bugs section.

---

## BUG 10 — Crash-Safe Cache Coin Duplication (HIGH)

**File:** `user_preferences_service.dart:754`

**Root cause:** `_recoverLocalCache()` uses `{...serverData, ...localData}` for
the profile merge. While monotonic stat fields are protected with `max()`,
coins are NOT protected. A locally cached higher coin value from before a crash
will overwrite the server's legitimate lower balance.

**Scenario:**
```
1. Device A: coins=500. Crash-safe cache written. App force-killed.
2. Device B: Player buys item for 200 coins → server: 300
3. Device A reopened: loadFromSupabase()
   → server returns {coins: 300}
   → _recoverLocalCache reads local {coins: 500}
   → merged = {...{coins:300}, ...{coins:500}} = {coins: 500}
4. _applySnapshot: coins are server-authoritative but the "server data"
   is already the merged result with local coins = 500
5. Player magically got 200 coins back
```

This is a **coin duplication exploit** achievable by force-killing the app at
the right moment, then spending on another device.

**Fix:** After the merge, force `merged['coins'] = serverData['coins']`.

## BUG 11 — Backfill Script Destructive on Live DB (HIGH)

**File:** `supabase/backfill_profile_stats_from_scores.sql:54`

**Root cause:** The backfill script uses blind `SET` without `GREATEST()`.
Running this on a live database will:
- Overwrite `games_played`, `best_score`, `best_time_ms`, `total_flight_time_ms`,
  `countries_found`, `level`, `xp` with values derived purely from the `scores` table
- NOT update `flags_correct`, `capitals_correct`, `outlines_correct`,
  `borders_correct`, `stats_correct`, `best_streak` (not in scores table) —
  these survive, but the profile row is still touched so `updated_at` changes
- NOT protect against regression (no `GREATEST`)

**Mitigation:** The script has a header comment saying "Recovery/backfill
purposes only" but no safety checks prevent running it against production.

**Fix:** Use `GREATEST(p.field, a.field)` for all SET clauses.

## BUG 12 — Admin Rename Fails Silently (LOW)

**File:** `admin_screen.dart:425`

The admin screen's "Rename User" function uses a raw `.update()` which is
subject to RLS. The only UPDATE policy on `profiles` is `auth.uid() = id`.
An admin cannot update another user's row. The rename fails silently.

**Fix:** Create an `admin_rename_user` RPC with `SECURITY DEFINER`.
