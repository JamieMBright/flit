# Flit Codebase Audit — Full Findings & Remediation Plan

**Date:** 2026-03-01
**Scope:** All 231 Dart files, 1 GLSL shader, all scripts, tests, CI/CD, SQL, Supabase config, Vercel API
**Total Issues Found:** ~400

---

## Summary by Severity

| Severity | Count | Description |
|----------|-------|-------------|
| **Critical** | 4 | Will cause crashes or entire subsystems are non-functional |
| **High** | 62 | Visible bugs, data loss risks, security concerns, dead features |
| **Medium** | 118 | Behavioral bugs, race conditions, inconsistencies, incomplete features |
| **Low** | ~216 | Style issues, minor redundancy, cosmetic inconsistencies |

---

## Table of Contents

1. [Critical — Crashes & Non-Functional Systems](#1-critical)
2. [Data Integrity & Race Conditions](#2-data-integrity--race-conditions)
3. [Security & Privacy](#3-security--privacy)
4. [Dead Code & Incomplete Features](#4-dead-code--incomplete-features)
5. [Bugs — Logic Errors](#5-bugs--logic-errors)
6. [Deserialization Safety](#6-deserialization-safety)
7. [Performance](#7-performance)
8. [Redundant / Duplicated Code](#8-redundant--duplicated-code)
9. [Stale Code & Maintenance Hazards](#9-stale-code--maintenance-hazards)
10. [Test Coverage Gaps](#10-test-coverage-gaps)
11. [CI/CD & Infrastructure](#11-cicd--infrastructure)
12. [Avatar System](#12-avatar-system)
13. [Style & Deprecated API](#13-style--deprecated-api)

---

## 1. Critical

Issues that cause compilation failures, crashes, or render entire subsystems non-functional.

| # | File | Lines | Issue | Impact |
|---|------|-------|-------|--------|
| C1 | `lib/core/services/perf_monitor.dart` | 2 | `import 'dart:io'` unconditionally — `dart:io` is unavailable on web | **Compilation failure on web targets** |
| C2 | `shaders/globe.frag` | 464 | `uEnableShading` branch gates the entire V1-V7 shading pipeline (ocean, foam, atmosphere, clouds, city lights, tone-mapping) | Entire shading pipeline is dead code |
| C3 | `lib/game/rendering/shader_manager.dart` | 406 | `uEnableShading` is hardcoded to `0.0` — never enabled | Only raw satellite texture ever renders; all visual work in shader is wasted |
| C4 | `lib/data/services/leaderboard_service.dart` | 556-580 | `fetchBestScoresByMode` caches `Map<String,int>` but reads it back as indexed `List` | **Throws `NoSuchMethodError` on every cache hit** |

---

## 2. Data Integrity & Race Conditions

Issues that can cause data loss, corruption, or inconsistent state.

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| R1 | `lib/data/services/challenge_service.dart` | 179-252 | `submitRoundResult` — read-modify-write on JSONB `rounds` with no locking; simultaneous submissions overwrite each other | High |
| R2 | `lib/data/services/challenge_service.dart` | 265-330 | `tryCompleteChallenge` — same read-modify-write race; two players can both determine winner simultaneously | High |
| R3 | `lib/data/services/matchmaking_service.dart` | 208-260 | Challenge created before pool entries marked matched — crash between steps creates orphaned challenge | High |
| R4 | `lib/data/services/auth_service.dart` | 150-161 | Username uniqueness is client-side TOCTOU — no DB unique constraint enforcement | High |
| R5 | `lib/data/services/account_management_service.dart` | 225-247 | `deleteAccountData` — sequential deletes with no transaction; partial failure leaves orphaned data | High |
| R6 | `lib/data/services/account_management_service.dart` | 251-258 | Auth user deletion failure silently swallowed — profile gone but auth row remains | High |
| R7 | `lib/data/services/friends_service.dart` | 670-696 | `sendCoins` — server-side coin transfer and local `spendCoins` are independent operations; failure of either leaves balances diverged | Medium |
| R8 | `lib/features/license/license_screen.dart` | 148-170 | `_reroll()` calls `spendCoins` then `updateLicense` — no rollback if license update fails after coins spent | High |
| R9 | `api/errors/index.js` | 157-174 | `appendToGitHub` — concurrent POSTs cause GitHub 409 (SHA conflict) with no retry; error logs silently dropped | High |
| R10 | `lib/core/services/game_settings.dart` | 119-133 | `hydrateFrom` — if any setter throws, `_hydrating` is never reset to `false`, permanently blocking all syncing | High |
| R11 | `lib/data/services/matchmaking_service.dart` | 193-205 | `String.hashCode` used for round seeds — not stable cross-platform; matched players may get different countries | Medium |
| R12 | `lib/data/models/live_group.dart` | 449-454 | Seed derived from `year*1e8+month*1e6+day*1e4+hour*100+minute` — sessions in same UTC minute get identical questions | High |

---

## 3. Security & Privacy

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| S1 | `lib/core/config/admin_config.dart` | 20 | Hardcoded owner email (`jamiebright1@gmail.com`) in source code — PII exposure | High |
| S2 | `supabase/rebuild.sql` | 88-93 | Same email hardcoded in `handle_new_user()` trigger | High |
| S3 | `supabase/account_recovery_research.sql` | 9 | Hardcoded username `'jamieb01'` in committed diagnostic script | Medium |
| S4 | `api/health/index.js` + `api/admin/stats.js` | various | Supabase publishable key hardcoded in source (violates CLAUDE.md "never hardcode API keys") | Medium |
| S5 | `vercel.json` | 35-39 | `Access-Control-Allow-Origin: *` on all API routes including `/api/admin/stats` | Medium |
| S6 | `api/admin/stats.js` | 108-112 | `topPlayers` query exposes `coins` field — sensitive financial data in admin API | Medium |
| S7 | `lib/main.dart` | 111-160 | `ErrorWidget.builder` replacement runs in ALL builds including release — exposes raw exception text and stack traces to end users | High |
| S8 | `lib/data/services/feature_flag_service.dart` | 43 | Unknown flag keys default to `true` (fail-open) — typos silently enable features | High |
| S9 | `.github/workflows/ci.yml` | 70-76 | Secret scan only checks for AWS/Stripe patterns; misses hardcoded Supabase keys and email addresses | Medium |

---

## 4. Dead Code & Incomplete Features

### 4A. Dead / Unreachable Code

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| D1 | `shaders/globe.frag` | 487-751 | Entire shading pipeline (ocean, foam, atmosphere, clouds, city lights, tone-mapping) — never executes | Critical |
| D2 | `lib/game/rendering/shader_lod.dart` | 1-206 | `ShaderLODManager` — fully implemented but never instantiated; LOD uniforms never consumed by shader | High |
| D3 | `lib/game/rendering/shader_manager.dart` | 345-365 | `shader()` method — never called from anywhere | Low |
| D4 | `lib/core/services/audio_manager.dart` | 313 | `nextTrack()` — public method with no caller; music loops forever on one track | Medium |
| D5 | `lib/data/models/cosmetic.dart` | 3-9 | `CosmeticType` enum values `landingEffect`, `mapSkin`, `title`, `badge` — never appear in catalog | Low |
| D6 | `lib/data/models/daily_challenge.dart` | 315 | `placeholderLeaderboard` — always empty, no purpose | Low |
| D7 | `lib/data/models/live_group.dart` | 562-934 | Three placeholder factories with 370 lines of hardcoded 2025 prototype data | Medium |
| D8 | `lib/game/flit_game.dart` | 162-163 | `_currentClue` — declared but never assigned a non-null value | Low |
| D9 | `lib/game/flit_game.dart` | 120-121 | `motionEnabled` — development scaffolding flag still present | Low |
| D10 | `lib/data/models/ad_config.dart` | 38-44 | `maxInterstitialsPerSession`, `maxRewardedPerDay` — defined but never consumed | Low |
| D11 | `scripts/lint-noflutter.sh` | 73-126 | `check_unused_imports` function — defined but never called | Low |
| D12 | `shaders/globe.frag` | 50 | `const float GLOBE_CENTER = 0.0` — declared but never referenced | Low |
| D13 | `lib/features/play/practice_screen.dart` | 165-171 | `_clueProgress` — hardcoded placeholder data, never updated from real player data | High |

### 4B. Incomplete / Stubbed Features

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| I1 | `lib/features/shop/shop_screen.dart` | 504-521 | All IAP gold package buy buttons show "Coming Soon" — purchase flow entirely stubbed | High |
| I2 | `lib/features/play/region_select_screen.dart` | 209-216 | Non-admin users see "Coming Soon" for all non-world regions — purchase/unlock not implemented | High |
| I3 | `lib/features/admin/admin_screen.dart` | 960-988 | "Gift Cosmetic Item" dialog shows fake success snackbar — no backend call | High |
| I4 | `lib/data/models/iap_receipt.dart` | whole file | IAP receipt model exists with no corresponding service for purchase/validation | High |
| I5 | `lib/data/services/title_service.dart` | 128-151 | Per-type stat tracking documented as "not yet wired up from gameplay" | Medium |
| I6 | `lib/features/auth/update_required_screen.dart` | 19 | App Store URL uses placeholder `idXXXXXXXXXX` | High |
| I7 | `lib/core/core.dart` | 1-9 | Barrel file exports only 5 of many core symbols — abandoned or incomplete | Low |
| I8 | `api/admin/stats.js` | 117-130 | `activePlayers7d` declared but never populated — metric planned but not implemented | Medium |
| I9 | `supabase/functions/delete-auth-user/index.ts` | whole | No admin audit logging after user deletion (most destructive action) | Medium |

---

## 5. Bugs — Logic Errors

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| B1 | `lib/game/session/game_session.dart` | 110-117 | `targetPosition` — no guard against empty `points` list; division by zero produces `NaN` | High |
| B2 | `lib/game/session/game_session.dart` | 129-133 | Same empty-list division-by-zero for `targetCountry.allPoints` | High |
| B3 | `lib/game/map/world_map.dart` | 83 + 357 | `render()` early-exits when `!isHighAltitude`, but city rendering requires `!isHighAltitude` — city labels never drawn | High |
| B4 | `lib/game/components/city_label_overlay.dart` | 64-73 | Label fade-in path (altitude 0.3-0.6) unreachable due to conflicting `isHighAltitude` guard | Medium |
| B5 | `lib/data/models/challenge.dart` | 185 | `currentRound` returns 6 when all 5 rounds complete — off-by-one | Medium |
| B6 | `lib/data/models/daily_challenge.dart` | 366-375 | `DailyMedal` — player with 0 wins gets 1-star bronze medal (`clamp(1,5)` on 0) | Low |
| B7 | `lib/data/models/friend.dart` | 100 | `HeadToHead.draws` can go negative with inconsistent DB data | Medium |
| B8 | `lib/data/services/friends_service.dart` | 198-222 | H2H `lastPlayed` uses `created_at` (creation date), not `completed_at` | Medium |
| B9 | `lib/data/services/leaderboard_service.dart` | 387-420 | `fetchPlayerRank` caps at 1001 silently — true rank above 1000 is wrong | High |
| B10 | `lib/data/services/leaderboard_service.dart` | 630-650 | `fetchStreaks` has no `ORDER BY` — leaderboard order is arbitrary | Medium |
| B11 | `lib/data/services/matchmaking_service.dart` | 74-78 | `calculateEloBand` accepts `elo` parameter but never uses it | Medium |
| B12 | `lib/data/services/account_management_service.dart` | 191-194 | Challenge export always shows `challenger_coins`, even when user was the challenged party | Medium |
| B13 | `lib/data/services/auth_service.dart` | 34-51 | `AuthState.copyWith` always clears `error` when not explicitly passed | Medium |
| B14 | `lib/data/models/subscription.dart` | 44 | `isActive` compares UTC `expiresAt` with local `DateTime.now()` — up to 14h timezone error | Medium |
| B15 | `lib/data/models/player.dart` | 105-153 | `Player.copyWith` cannot clear nullable fields — ban cannot be lifted via copyWith | Medium |
| B16 | `lib/data/models/live_group.dart` | 388-390 | Leaderboard `totalTime` uses last-round time only, not cumulative time | Low |
| B17 | `lib/data/models/player.dart` | 99-100 | `levelProgress` can exceed 1.0 — overflows progress bar widgets | Medium |
| B18 | `lib/core/services/error_service.dart` | 472-487 | Desktop platforms (macOS/Windows/Linux) report as `'web'` in telemetry | Medium |
| B19 | `lib/features/leaderboard/leaderboard_screen.dart` | 49-50 | `_splitEmojis` splits on code points — breaks multi-codepoint emoji (flags, ZWJ sequences) | High |
| B20 | `lib/features/play/play_screen.dart` | 203 | `Random()` used instead of `Random(seed)` — deterministic seeds not actually deterministic | Medium |
| B21 | `lib/features/play/play_screen.dart` | 542 | Timer tick condition `% 100 < 20` can miss 100ms boundaries entirely | Medium |
| B22 | `lib/game/components/country_border_overlay.dart` | 152-187 | Sea label `TextPainter` cache defeated — text rebuilt every frame despite `putIfAbsent` | Medium |
| B23 | `lib/game/rendering/region_camera_presets.dart` | 154-168 | `clampToBounds` doesn't handle date-line wrapping for +-180° longitude | Medium |
| B24 | `lib/game/ui/game_hud.dart` | 1014-1022 | `_ErrorCatcher` try/catch cannot catch child widget build errors | Medium |
| B25 | `lib/game/map/world_map.dart` | 83 | `WorldMap.render()` uses `gameRef.plane.isHighAltitude` while maintaining separate `_isHighAltitude` — can diverge | Medium |
| B26 | `lib/features/shop/shop_screen.dart` | 155 | Mystery plane cost `10000` hardcoded inline, independent of `_mysteryCost` constant | Medium |
| B27 | `lib/data/services/economy_config_service.dart` | 53-68 | Error fallback to defaults is cached for full TTL — network recovery delayed | Medium |
| B28 | `lib/features/matchmaking/find_challenger_screen.dart` | 102 | Generated `seed` string is never used — rounds list is always empty | Medium |
| B29 | `lib/game/components/companion_renderer.dart` | 75-77 | Companion heading subtraction causes visual spinning during sharp turns | Medium |
| B30 | `lib/data/services/app_config_service.dart` | 94-100 | `_versionToNumber` only handles `major.minor` — discards patch version | Medium |
| B31 | `sql/005_clean_flights_update_stats.sql` | 191 | Northern Cyprus and Cyprus both use country code `CY` — score attribution ambiguity | Medium |

---

## 6. Deserialization Safety

Multiple `firstWhere` calls without `orElse` — any unrecognized DB value throws `StateError` and crashes.

| # | File | Lines | Field | Severity |
|---|------|-------|-------|----------|
| DS1 | `lib/data/models/challenge.dart` | 118 | `ClueType` from `clue_type` column | High |
| DS2 | `lib/data/models/cosmetic.dart` | 110 | `CosmeticType` from `type` column | High |
| DS3 | `lib/data/models/social_title.dart` | 63-65 | `TitleCategory` from `category` column | High |
| DS4 | `lib/data/models/live_group.dart` | 526 | `LiveGroupStatus` from `status` column | High |
| DS5 | `lib/data/models/seasonal_theme.dart` | 196-207 | `SeasonalEvent` from `event` column | Medium |
| DS6 | `lib/data/models/subscription.dart` | 135-137 | `DateTime.parse` (not `tryParse`) for dates | Medium |
| DS7 | `lib/data/models/iap_receipt.dart` | 41 | `DateTime.parse` (not `tryParse`) for `created_at` | Medium |
| DS8 | `lib/data/models/pilot_license.dart` | 248-252 | Hard casts (`as int`, `as String`) with no null safety | Medium |
| DS9 | `lib/data/models/challenge.dart` | 113-136 | `start_location` accessed as `List` with no null check | Medium |

---

## 7. Performance

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| P1 | `lib/features/play/play_screen.dart` | 535 | `Timer.periodic` at 16ms calls `setState` every tick unconditionally — forces 60fps rebuilds even when idle | High |
| P2 | `lib/game/components/contrail_renderer.dart` | 58 | `trail.sort()` called every render frame for up to 300 particles per side | Low |
| P3 | `lib/game/components/contrail_renderer.dart` | 83-90 | New `Paint` object created per segment inside inner loop — up to 36,000 allocations/sec | Low |
| P4 | `lib/game/map/world_map.dart` | 380-400 | `TextPainter` created and `layout()` called every frame per city — no caching | Medium |
| P5 | `lib/core/services/audio_manager.dart` | 362-376 | `updateEngineVolume()` is async, called every frame with no concurrent-call guard | Medium |
| P6 | `lib/game/rendering/flat_map_renderer.dart` | 152 | Static `_labelCache` never cleared — leaks across region switches | Medium |
| P7 | `lib/data/services/leaderboard_service.dart` | 700-710 | `fetchDailyPlayerCount` fetches all rows to count client-side instead of using `.count()` | Low |
| P8 | `lib/data/models/social_title.dart` | 615 | `SocialTitleCatalog.all` constructs new list on every call — called multiple times per operation | Low |
| P9 | `lib/data/services/ttl_cache.dart` | 5-41 | No max size limit — unbounded growth with high-cardinality keys | Low |
| P10 | `lib/features/avatar/avatar_widget.dart` | 10 | Module-level `_svgCache` map with no eviction — grows unbounded | Medium |

---

## 8. Redundant / Duplicated Code

| # | Files | Issue | Severity |
|---|-------|-------|----------|
| RD1 | `app_version.dart` + `error_service.dart` | Version string `'v1.251'` hardcoded in two separate files — can silently diverge | Medium |
| RD2 | `error_service.dart` + `report_bug_button.dart` | Platform detection duplicated with **divergent behavior** (`'web'` vs `'desktop'` for macOS/Win/Linux) | Medium |
| RD3 | `leaderboard_screen.dart` + `license_screen.dart` | Rarity colors (`_bronzeColor`, `_silverColor`, `_goldColor`, `_diamondColor`), `_perfectGradientColors`, `_colorForRarity` all duplicated verbatim | Medium |
| RD4 | `license_screen.dart` + `challenge_result_screen.dart` + `profile_screen.dart` | `_rankTitle` / `_aviationRankTitle` logic triplicated | Medium |
| RD5 | `landing_detector.dart` + `globe_hit_test.dart` + `flit_game.dart` | `rad2deg` constant declared 3 times; `greatCircleDistDeg` implemented twice | Low |
| RD6 | `game_hud.dart` + `game_session.dart` | `tierPenalties` duplicated with manual sync comment | Medium |
| RD7 | `lib/game/map/region.dart` | `isRegionalFlatMap` top-level function duplicates `GameRegion.isFlatMap` extension getter | Low |
| RD8 | `lib/features/play/region_select_screen.dart` | 110-205 | PlayScreen navigation setup copy-pasted verbatim for admin vs user path | High |
| RD9 | `lib/game/map/world_map.dart` | 308-325 | `_renderCoastlines` and `_renderCountries` both iterate all country polygons independently | Low |

---

## 9. Stale Code & Maintenance Hazards

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| ST1 | `sql/005_clean_flights_update_stats.sql` + `sql/005_difficulty_config_and_recalibrate.sql` | — | Both files have `005_` prefix — migration ordering collision | High |
| ST2 | `supabase/rebuild.sql` | 35-70 | Two overlapping SELECT policies on `profiles` — one is entirely redundant | Medium |
| ST3 | `supabase/rebuild.sql` | 340 | Policy creation guarded by existence of unrelated policy — INSERT/UPDATE can be silently skipped | Medium |
| ST4 | `lib/data/models/leaderboard_entry.dart` | 97-98 | `LeaderboardPeriod` enum coexists with `TimeframeTab` — no deprecation or migration path | Low |
| ST5 | `lib/data/models/avatar_config.dart` | 513 | DiceBear API version `7.x` hardcoded — breaking bump will break all avatars | Medium |
| ST6 | `lib/features/avatar/avatar_editor_screen.dart` | 223-237 | `'earringsColor'` and `'earringColor'` both present — historical naming workaround | Low |
| ST7 | `pubspec.yaml` | 23-24 | `flag: 7.0.0` pinned for Dart 3.2 compat — restricts security patches | Medium |
| ST8 | `.github/workflows/ci.yml` | 19 | Flutter version pinned to `3.16.0` (late 2023) | Medium |
| ST9 | `supabase/functions/*/index.ts` | 1 | Deno std pinned to `@0.168.0` (2022) — missing security updates | Medium |
| ST10 | `vercel.json` | 29-31 | Rewrite rule for `/confirmed.html` references non-existent file | Low |

---

## 10. Test Coverage Gaps

| # | Area | Description | Severity |
|---|------|-------------|----------|
| T1 | Supabase Edge Functions | `delete-auth-user`, `change-user-email`, `reset-user-password` — zero tests | High |
| T2 | Vercel API Endpoints | `/api/errors`, `/api/health`, `/api/admin/stats` — zero tests | High |
| T3 | Game rendering | Globe renderer, shader manager, shader LOD — no unit tests | Medium |
| T4 | Challenge service | Race condition scenarios untested (concurrent round submissions) | High |
| T5 | Matchmaking service | Pool matching, ELO banding — no unit tests | Medium |
| T6 | `collaborator` admin role | Permissions path untested in `admin_config_test.dart` | Low |
| T7 | SQL migrations | `rebuild.sql`, `verify.sql`, `teardown.sql` — no automated schema verification | Medium |
| T8 | `difficulty_config` table | `recalibrate_scores`/`upsert_difficulty_config` RPCs — untested | Medium |
| T9 | Data generation scripts | `generate_country_data.py`, `generate_region_data.py`, etc. — no tests | Low |
| T10 | Error telemetry test | Tests re-implement server logic in Dart rather than testing actual `scrubUrl()` | Low |
| T11 | Feature flag service | Fail-open default behavior untested | Medium |
| T12 | Daily challenge | Clue type assignment by theme title (`'Duo Mix'`, `'Triple Threat'`) untested | Low |

---

## 11. CI/CD & Infrastructure

| # | File | Lines | Issue | Severity |
|---|------|-------|-------|----------|
| CI1 | `ci.yml` | 37-38 | `flutter create --platform=web .` can silently overwrite tracked files (`web/index.html`) with templates | High |
| CI2 | `ci.yml` | 268-325 | `update-version` pushes directly to `main` — bypasses branch protection | Medium |
| CI3 | `ci.yml` | 273 | Version bumped even when Android build fails (only depends on `smoke-test`) | Medium |
| CI4 | `ci.yml` | 228-239 | Smoke test returns exit 0 even if all 5 retries fail | Low |
| CI5 | `scripts/test.sh` | 92 | `shaders` case arm missing — documented command fails | Medium |
| CI6 | `scripts/test.sh` | 27-31 | `security` subcommand only runs `pub outdated` — not a real security audit | Medium |
| CI7 | `scripts/test.sh` | 33-37 | `integration` subcommand only runs a build — no actual integration tests | Medium |
| CI8 | `scripts/rebuild-supabase.sh` | 97-102 | `psql` without `ON_ERROR_STOP=1` — SQL errors reported as success | Medium |
| CI9 | `hooks/pre-push` | — | Only runs linting — CLAUDE.md says "full build + all tests" | Medium |
| CI10 | `hooks/pre-commit` | 54-57 | Warnings treated as errors — stricter than standalone scanner | Medium |
| CI11 | `.github/workflows/fetch-errors.yml` | 170-193 | Purges `runtime-errors.jsonl` after processing but API also writes to it — data loss | Medium |
| CI12 | `deploy.yml` | 9-10 | Daily scheduled redeploy is redundant with push-triggered deploys | Low |
| CI13 | `api/errors/index.js` | 22-25 | In-memory error store lost on cold start — GET returns incomplete data | High |

---

## 12. Avatar System

83 issues found across 79 avatar part files. Key categories:

### SVG ID Collisions (HIGH — 9 issues)
Multiple avatars rendered in the same document will have gradient/mask ID collisions in:
- `avataaars_accessories.dart` (sunglasses, wayfarers)
- `bottts_eyes.dart` (robocop)
- `bottts_face.dart` (all 6 variants)
- `bottts_mouth.dart` (smile02)
- `bottts_sides.dart` (all 7 variants)
- `bottts_top.dart` (all 10 variants)
- `pixelart_beard.dart` (all 8 variants)

**Fix:** Prefix all SVG IDs with a unique instance identifier at render time.

### Hardcoded Colors (MEDIUM-HIGH — 28 issues)
Colors that bypass the `{{PLACEHOLDER}}` system and cannot be themed:
- Blush/cheek colors across adventurer, bigears
- Mouth interior colors (multiple inconsistent reds: `#FF4F6D`, `#FF4646`, `#D32020`, `#D31E1E`)
- Eye colors in bigears (5+ hardcoded iris colors)
- Bottts accent colors (mint, yellow, blue)
- OpenPeeps face expressions (pink, red, near-black `#231F20`)

### Naming Inconsistencies (MEDIUM — 12 issues)
- Clothing placeholder: `{{CLOTHES_COLOR}}` vs `{{CLOTHING_COLOR}}` vs `{{SHIRT_COLOR}}`
- Earrings placeholder: `{{EARRINGS_COLOR}}` vs `{{EARRING_COLOR}}`
- `bottts_sides.dart`: `squareAssymetric` misspells "asymmetric"
- `micah_nose.dart`: variant `'tound'` should be `'round'`
- `avataaars_top.dart`: `winterHat1` inconsistent with `winterHat02`-`04`

---

## 13. Style & Deprecated API

### `withOpacity` Deprecated (LOW — ~40 occurrences)
Used extensively across 10+ feature screens. Should migrate to `Color.withValues(alpha: ...)`.

**Affected files:** `banned_screen.dart`, `login_screen.dart`, `friends_screen.dart`, `gameplay_guide_screen.dart`, `announcement_banner.dart`, `home_screen.dart`, `leaderboard_screen.dart`, `license_screen.dart`, `find_challenger_screen.dart`, `daily_challenge_screen.dart`, `settings_sheet.dart`

### Missing `mounted` Checks (HIGH — 3 occurrences)
Context used after `await` without `mounted` check:
- `lib/features/friends/friends_screen.dart:364,377,385`
- `lib/features/auth/login_screen.dart` (various)
- `lib/features/challenge/challenge_result_screen.dart:151-155`

### `debugPrint` Instead of `GameLog` (LOW — 3 occurrences)
- `home_screen.dart:269,291`
- `profile_screen.dart:112`

---

## Recommended Priority Order

### Phase 1 — Critical & Data Safety (immediate)
1. Fix `perf_monitor.dart` conditional import for web (C1)
2. Fix `fetchBestScoresByMode` cache type mismatch crash (C4)
3. Add `orElse` to all 4 `firstWhere` deserialization calls (DS1-DS4)
4. Fix `game_session.dart` empty-points division by zero (B1, B2)
5. Add database-side atomic operations for challenge round submission (R1, R2)
6. Fix `ErrorWidget.builder` release-mode information disclosure (S7)

### Phase 2 — High-Impact Bugs & Security
7. Fix feature flag fail-open default (S8)
8. Fix `world_map.dart` city rendering logic contradiction (B3)
9. Fix emoji splitting for multi-codepoint characters (B19)
10. Fix `fetchPlayerRank` silent cap at 1001 (B9)
11. Remove hardcoded PII from source code (S1, S2, S3)
12. Fix placeholder App Store URL (I6)
13. Add missing `mounted` checks after await (3 files)

### Phase 3 — Race Conditions & Data Integrity
14. Add optimistic locking or DB-side RPCs for challenge flow (R1, R2)
15. Transaction-wrap account deletion (R5)
16. Fix matchmaking orphaned-challenge race (R3)
17. Fix coin-spend rollback on license reroll (R8)
18. Fix live group seed collision at minute granularity (R12)

### Phase 4 — Dead Code & Incomplete Features
19. Enable or remove shader shading pipeline (C2, C3, D1, D2)
20. Remove placeholder prototype data from live_group.dart (D7)
21. Remove hardcoded practice screen clue progress data (D13)
22. Implement or remove IAP stubs (I1, I2, I4)

### Phase 5 — Infrastructure & Tests
23. Fix CI `flutter create` overwriting tracked files (CI1)
24. Add `shaders` case to test.sh (CI5)
25. Fix migration numbering collision (ST1)
26. Update pinned dependency versions (ST7, ST8, ST9)
27. Add tests for edge functions and API endpoints (T1, T2)
28. Add race condition tests for challenge service (T4)

### Phase 6 — Code Quality & Cleanup
29. Deduplicate rarity colors, rank titles, platform detection (RD1-RD6)
30. Fix avatar SVG ID collisions (12-avatar prefix strategy)
31. Standardize avatar placeholder naming (78-80)
32. Migrate `withOpacity` to `withValues` (13)
33. Replace `debugPrint` with `GameLog`

---

*Generated by codebase audit — 2026-03-01*
