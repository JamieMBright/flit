# PLAN.md — Pre-Launch Bug Fixes

**Priority**: Critical — All must be resolved before launch.
**Date**: 2026-02-22

---

## Bug 1: Share Text Uses Yellow Instead of Orange for 3+ Clues

**Severity**: Low (cosmetic)
**Status**: TODO

### Problem
The share emoji and result circle colors are swapped: yellow shows for 1-2 hints and orange for 3+. The intended mapping is **orange for 1-2 hints** (decent) and **yellow for 3+ hints** (poor).

### Files
| File | Lines | What |
|------|-------|------|
| `lib/data/models/daily_result.dart` | 23-28 | `emoji` getter — share text emoji |
| `lib/features/play/play_screen.dart` | 1803-1809 | Result dialog circle colors |
| `lib/features/daily/daily_challenge_screen.dart` | 1202-1207 | `_roundColor()` for daily results |

### Fix
Swap the emoji and color assignments:
- **0 hints** → green (unchanged)
- **1-2 hints** → orange 🟠 (`\u{1F7E0}`)
- **3+ hints** → yellow 🟡 (`\u{1F7E1}`)
- **Incomplete** → red (unchanged)

Apply swap in all 3 locations consistently.

---

## Bug 2: Wayline Drawing Artefacts

**Severity**: Medium (visual glitch)
**Status**: TODO

### Problem
The wayline drawn from the plane to the tapped point has visual artefacts (kinks, jitter). The line should be a simple straight line from the plane's screen position (~50%x, ~80%y) to the tapped screen point. Current code uses broken great-circle interpolation with a manual heading-based offset that mismatches coordinate spaces.

### Files
| File | Lines | What |
|------|-------|------|
| `lib/game/components/wayline_renderer.dart` | 60-132 | `_drawWayline()` — main drawing logic |
| `lib/game/flit_game.dart` | 959 | Plane fixed screen position `(size.x * 0.5, size.y * 0.8)` |
| `lib/game/flit_game.dart` | 444 | `worldToScreenGlobe()` projection |

### Root Cause
1. Lines 84-94 offset the first point using `visualHeading + turnDirection * 0.4` in screen space — wrong math, wrong coordinate system
2. 30-segment great-circle interpolation is unnecessary for a UI overlay line
3. The start point doesn't match the plane sprite's actual fixed screen position

### Fix
Replace the entire `_drawWayline` method:
1. Start point = plane's fixed screen position `(size.x * 0.5, size.y * 0.8)` — or read from `gameRef.plane.position`
2. End point = `gameRef.worldToScreenGlobe(target)` projected to screen
3. Draw a single straight line between them (no great-circle, no heading offset)
4. Keep paint style (color, width, cap)

---

## Bug 3: Small Island Nations / Overseas Territories Flag Handling

**Severity**: Medium (gameplay correctness)
**Status**: TODO

### Problem
Overseas territories (OTs) like US Minor Outlying Islands (UM), Guam (GU), American Samoa (AS), etc. are included in the country pool but use their parent country's flag. The flag emoji is auto-generated from ISO-2 code (`_countryCodeToFlagEmoji`), which works for territories that have their own flag emoji (GU 🇬🇺, PR 🇵🇷, etc.) but fails for UM 🇺🇲 which shows a US flag, and some territories are too obscure for players.

### Country Data Stats
- **229 total entries** in `CountryData.countries`
- **~20 territories/dependencies** identified: AI, AQ, AS, AW, BM, CW, FK, GI, GU, MS, NC, NF, NU, PM, PN, PR, SH, UM, VG, WF

### Files
| File | Lines | What |
|------|-------|------|
| `lib/game/map/country_data.dart` | 44-76406 | Full country list (229 entries) |
| `lib/game/map/country_data.dart` | 76405 | `getRandomCountry()` — no filtering |
| `lib/game/session/game_session.dart` | 129, 194 | Country selection for random/seeded modes |
| `lib/game/clues/clue_types.dart` | 514-520 | `_countryCodeToFlagEmoji()` |

### Fix
Two-part approach:
1. **Add a territory exclusion list** in `CountryData` — territories that shouldn't appear as game targets unless they have a unique, recognizable flag
2. **Filter `getRandomCountry()`** and seeded selection to skip excluded territories
3. Territories with well-known own flags (PR, GU, GI, BM, etc.) can stay; remove obscure ones (UM, PN, BV, HM, etc.)

---

## Bug 4: Profile Settings Reset on Refresh (Supabase Persistence)

**Severity**: Critical (data loss)
**Status**: TODO

### Problem
All profile settings (avatar, license, streak, gold, shop purchases, equipped items, flight count, overall stats) reset on page refresh/app restart. The code writes to Supabase but the database schema is missing columns, so data is silently lost.

### Root Cause
The `profiles` table is missing columns that code tries to write:
- `flags_correct`, `capitals_correct`, `outlines_correct`, `borders_correct`, `stats_correct`
- `best_streak`

The `account_state` table is missing:
- `equipped_title_id`
- `daily_streak_data` (JSONB)
- `last_daily_result` (JSONB)

### Files
| File | Lines | What |
|------|-------|------|
| `supabase/migrations/20260220_user_preferences.sql` | 25-44 | `profiles` table — missing columns |
| `supabase/migrations/20260220_user_preferences.sql` | 80-106 | `account_state` table — missing columns |
| `lib/data/services/user_preferences_service.dart` | 285-374 | `saveProfile()`, `saveAccountState()` — writes to missing cols |
| `lib/data/providers/account_provider.dart` | 160-850 | State management — loads null values on restart |
| `lib/data/models/player.dart` | 46-53 | Player fields that don't persist |

### Fix
1. **Create new SQL migration** `supabase/migrations/20260222_add_missing_profile_columns.sql`:
   ```sql
   ALTER TABLE public.profiles
     ADD COLUMN IF NOT EXISTS flags_correct INT DEFAULT 0,
     ADD COLUMN IF NOT EXISTS capitals_correct INT DEFAULT 0,
     ADD COLUMN IF NOT EXISTS outlines_correct INT DEFAULT 0,
     ADD COLUMN IF NOT EXISTS borders_correct INT DEFAULT 0,
     ADD COLUMN IF NOT EXISTS stats_correct INT DEFAULT 0,
     ADD COLUMN IF NOT EXISTS best_streak INT DEFAULT 0;

   ALTER TABLE public.account_state
     ADD COLUMN IF NOT EXISTS equipped_title_id TEXT,
     ADD COLUMN IF NOT EXISTS daily_streak_data JSONB DEFAULT '{}',
     ADD COLUMN IF NOT EXISTS last_daily_result JSONB DEFAULT '{}';
   ```
2. **Verify** RLS policies cover new columns (they inherit from table-level policies)
3. **Verify** `UserPreferencesService.load()` properly maps all new columns on read

---

## Bug 5: Global Leaderboard Not Updating After Run

**Severity**: High (user-facing stale data)
**Status**: TODO

### Problem
After submitting a score (especially via the offline retry queue), the leaderboard cache is not invalidated, so the leaderboard shows stale data.

### Root Cause
Two code paths for score submission:
1. **Online path** (line 421): Calls `LeaderboardService.instance.invalidateCache()` ✓
2. **Offline retry path** (line 474): Dequeues but **never** invalidates cache ✗

### Files
| File | Lines | What |
|------|-------|------|
| `lib/data/services/user_preferences_service.dart` | 417-427 | Direct score insert (cache invalidated) |
| `lib/data/services/user_preferences_service.dart` | 440-488 | `retryPendingWrites()` (cache NOT invalidated) |
| `lib/data/services/leaderboard_service.dart` | 42-49 | `invalidateCache()` method |

### Fix
After successful retry of a `scores` table insert (line 474, after `_queue.dequeue()`), add:
```dart
if (table == 'scores') {
  LeaderboardService.instance.invalidateCache();
}
```

---

## Bug 6: Usage Stats — Missing `matchmaking_pool` Table Access

**Severity**: High (admin panel broken)
**Status**: TODO

### Problem
The admin stats endpoint and Flutter admin panel fail to query `matchmaking_pool` because:
1. The RLS policies restrict SELECT to `auth.uid() = user_id OR auth.uid() = matched_with`
2. The admin stats endpoint uses the anon key, which has `auth.uid() = NULL`
3. The migration may not have been applied to the live Supabase instance

### Files
| File | Lines | What |
|------|-------|------|
| `supabase/migrations/20260221_matchmaking_pool.sql` | 40-61 | RLS policies (too restrictive for admin) |
| `api/admin/stats.js` | 106, 151 | Anon key query for pool size |
| `lib/features/admin/admin_stats_screen.dart` | 114-118 | Flutter admin query |

### Fix
1. **Add admin bypass RLS policy** in a new migration:
   ```sql
   CREATE POLICY "Admin can read matchmaking pool"
     ON public.matchmaking_pool FOR SELECT
     USING (
       EXISTS (
         SELECT 1 FROM public.profiles
         WHERE id = auth.uid() AND is_admin = true
       )
     );
   ```
   Or use a simpler approach — add a `service_role` policy or use the Supabase service key in the admin stats API.
2. **Alternative**: Use the Supabase service role key in `api/admin/stats.js` instead of the anon key (since it's already behind API key auth)
3. **Verify** the migration has been applied to the live Supabase instance

---

## Bug 7: Admin Error Explorer — Expand & Copy

**Severity**: Low (developer tooling)
**Status**: TODO

### Problem
Error entries in the admin panel and dev overlay can't be expanded to see full messages, and text can't be selected/copied.

### Files
| File | Lines | What |
|------|-------|------|
| `lib/core/services/dev_overlay.dart` | 260-375 | `_buildErrorTile` — error display |
| `lib/core/services/dev_overlay.dart` | 303-314 | Error message `Text` (not selectable) |
| `lib/core/services/dev_overlay.dart` | 316-337 | Stack trace `Text` (not selectable) |
| `lib/core/services/dev_overlay.dart` | 340-356 | Context metadata `Text` (not selectable) |
| `lib/features/admin/admin_screen.dart` | 1062-1170 | `_LogEntryTile` — game log display |
| `lib/features/admin/admin_screen.dart` | 1131, 1144, 1156 | Plain `Text` widgets |

### Fix
**DevOverlay** (`dev_overlay.dart`):
1. Replace `Text` with `SelectableText` for error messages (line 303)
2. Replace `Text` with `SelectableText` for stack traces (line 316)
3. Replace `Text` with `SelectableText` for context metadata (line 340)
4. Add explicit "Copy" icon button in expanded error tile

**Admin Game Log** (`admin_screen.dart`):
1. Convert `_LogEntryTile` from `StatelessWidget` to `StatefulWidget` with expand/collapse
2. Replace `Text` with `SelectableText` for message, data, error fields
3. Remove `maxLines: 5` truncation when expanded
4. Add copy-to-clipboard button

---

## Execution Order

1. **Bug 1** (share colors) — Quick swap, low risk
2. **Bug 5** (leaderboard cache) — One-line fix
3. **Bug 2** (wayline) — Rework drawing method
4. **Bug 7** (error explorer) — UI widget changes
5. **Bug 3** (territory filtering) — Data/logic change
6. **Bug 4** (profile persistence) — SQL migration + verify sync code
7. **Bug 6** (matchmaking RLS) — SQL migration + API key change
