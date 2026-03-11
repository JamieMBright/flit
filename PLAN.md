# Tutorial Difficulty Progression — Implementation Plan

## Summary

Address beta tester feedback: game is too hard for newcomers. Implement a tutorial campaign mode with progressive difficulty, overhaul fuel mechanics to reduce pressure, and gate competitive modes behind player level.

---

## Phase 1: Fuel Mechanic Overhaul

### 1A. Remove Emergency Landing
**Files:** `lib/game/flit_game.dart`, `lib/features/play/play_screen.dart`

- Remove `onFuelEmpty` callback and emergency landing logic
- When fuel hits 0, stop consuming but **don't end the round**
- Player can continue flying with 0 fuel (they just get no fuel bonus)

### 1B. Change Fuel Scoring to Bonus (not Penalty)
**File:** `lib/game/session/game_session.dart`

Current: `resourcePenalty = (1.0 - fuelFraction) * 5000` (penalty up to -5000)

New approach:
- Base score = 5000 (not 10000)
- Fuel bonus = `fuelFraction * 5000` (bonus up to +5000)
- So: `rawScore = 5000 + fuelBonus - hintPenalty`
- Same 0–10000 range, but framed as **earning** fuel bonus, not losing points
- Perfect fuel = 10000 base. No fuel = 5000 base. Hints still subtract.

### 1C. License fuelBoost → Fuel Efficiency
**Files:** `lib/data/models/pilot_license.dart`, `lib/game/flit_game.dart`, `lib/features/play/play_screen.dart`

- Rename `fuelBoost` stat to `fuelEfficiency` in display (keep field name for DB compat)
- Change behavior: instead of increasing tank size (maxFuel), reduce burn rate
- Formula: `effectiveEfficiency = planeFuelEfficiency * (1.0 + fuelBoost / 100.0)`
- This means license fuelBoost of 15 = 15% slower fuel burn = more fuel remaining = higher score
- Remove the speed multiplication side-effect from fuelBoostMultiplier on plane

### 1D. Update Guide & UI
**File:** `lib/features/guide/gameplay_guide_screen.dart`

- Update scoring explanations to reflect bonus model
- Update fuel description: "Fuel remaining at landing earns bonus points"
- Remove "emergency landing" references

---

## Phase 2: Tutorial Campaign Mode

### 2A. Coach/Aviator Data Model (NEW)
**File:** `lib/game/tutorial/coach.dart` (NEW)

```dart
class Coach {
  final String name;           // e.g. "Captain Nadia Al-Masri"
  final String nationality;    // e.g. "Palestinian"
  final String countryCode;    // e.g. "PS" for flag emoji
  final String title;          // e.g. "Navigation Instructor"
  final String bio;            // Short 1-line bio
  final String avatarAsset;    // Path to avatar (or emoji placeholder initially)
}
```

~8-10 coaches from diverse countries:
- Palestinian, Ethiopian, Brazilian, Indonesian, Mongolian, Irish, Colombian, Filipino, Jordanian, Icelandic
- Each specializes in teaching a concept (flags, capitals, outlines, fuel, hints, etc.)
- NOT US/UK-centric. Celebrate obscure nations.

### 2B. Campaign Mission Data Model (NEW)
**File:** `lib/game/tutorial/campaign_mission.dart` (NEW)

```dart
class CampaignMission {
  final String id;
  final int order;              // Sequential mission number
  final String title;           // e.g. "First Flight"
  final String description;     // Mission briefing text
  final Coach coach;            // Who introduces this mission
  final List<ClueType> allowedClues;  // Which clue types enabled
  final int rounds;             // Number of rounds (1-3 for tutorial)
  final double maxDifficulty;   // Country difficulty cap (easy countries only at first)
  final bool fuelEnabled;       // Fuel off for first few missions
  final List<String>? targetCountries;  // Optional: specific countries for scripted missions
  final int xpReward;           // XP earned on completion
  final int coinReward;         // Coins earned
  final String? unlockMessage;  // "You unlocked Free Flight!" etc.
  final List<CoachTip> midGameTips;  // Tips shown during gameplay
}
```

### 2C. Campaign Mission Definitions (NEW)
**File:** `lib/game/tutorial/campaign_missions.dart` (NEW)

~12 missions, progressive:

| # | Title | Coach | Clues | Fuel | Difficulty | Teaches |
|---|-------|-------|-------|------|------------|---------|
| 1 | First Flight | Nadia (PS) | borders | OFF | 0.15 | Basic flying, answering |
| 2 | Flag Spotter | Amara (ET) | flag | OFF | 0.20 | Flag clues |
| 3 | Capital Knowledge | Mateo (CO) | capital | OFF | 0.25 | Capital clues |
| 4 | Mixed Signals | Bayarmaa (MN) | borders+flag | OFF | 0.30 | Multiple clue types |
| 5 | Fuel Management | Rizal (PH) | borders+flag+capital | ON | 0.25 | Fuel basics, altitude |
| 6 | Hint System | Siobhán (IE) | flag+capital | ON | 0.35 | Using hints wisely |
| 7 | Stats & Facts | Lina (JO) | stats | ON | 0.30 | Stats clues |
| 8 | Shape Shifter | Diego (BR) | outline | ON | 0.25 | Outline clues (hardest type) |
| 9 | World Tour | Ayu (ID) | all | ON | 0.45 | All clue types together |
| 10 | License to Fly | Harpa (IS) | all | ON | 0.50 | Licenses, planes, economy |
| 11 | Daily Prep | Nadia (PS) | all | ON | 0.55 | Prepares for daily modes |
| 12 | Ready for Takeoff | All coaches | all | ON | 0.60 | Graduation mission |

### 2D. Campaign Progress Tracking
**Files:** `lib/data/providers/account_provider.dart`, `lib/data/models/player.dart`

- Add `campaignProgress` to player state: `Map<String, CampaignMissionResult>`
- Track: completed, bestScore, stars (1-3 based on score thresholds)
- Persist to Supabase `campaign_progress` table (or local prefs as fallback)

### 2E. Campaign Screen UI (NEW)
**File:** `lib/features/campaign/campaign_screen.dart` (NEW)

- Vertical scrollable list of missions (like a flight path/route map)
- Each mission shows: number, title, coach avatar, clue icons, stars earned, lock state
- Locked missions grayed out, unlocked when previous completed
- Tapping unlocked mission → mission briefing dialog (coach intro) → start game

### 2F. Coach Dialogue Overlay (NEW)
**File:** `lib/features/campaign/coach_overlay.dart` (NEW)

- Semi-transparent overlay at bottom of screen during gameplay
- Shows coach avatar + speech bubble with tip text
- Auto-appears at key moments (first clue revealed, first hint used, fuel getting low, etc.)
- "Got it" button to dismiss (skippable)
- Only appears during campaign missions (and only for relevant mission)
- Does NOT appear in regular game modes

### 2G. Mission Briefing & Completion Dialogs (NEW)
**File:** `lib/features/campaign/mission_dialog.dart` (NEW)

- **Briefing**: Coach introduces the mission. "Welcome, pilot! Today we'll learn about flags..."
- **Completion**: Coach congratulates. Shows score, stars, XP earned, any unlocks
- Aviation-themed language throughout

---

## Phase 3: Mode Gating

### 3A. Game Mode Requirements
**File:** `lib/game/tutorial/mode_requirements.dart` (NEW)

| Mode | Unlock Requirement | Mission Gate |
|------|-------------------|--------------|
| Campaign | Always available | — |
| Free Flight | Always available | — |
| Training Sortie | Always available | — |
| Uncharted | Always available | — |
| Flight School | Level 1+ (existing) | — |
| Daily Briefing | Level 3 OR Mission 6 complete | Mission 6 |
| Daily Challenge | Level 5 OR Mission 9 complete | Mission 9 |
| Dogfight | Level 5 OR Mission 11 complete | Mission 11 |
| Matchmaking | Level 7 OR Mission 12 complete | Mission 12 |

Dual unlock: either reach the level naturally (existing players) OR complete the campaign mission (new players). This avoids punishing existing players.

### 3B. Home Screen Lock States
**File:** `lib/features/home/home_screen.dart`

- Modify `_GameModeCard` to accept `isLocked` + `unlockRequirement` string
- Locked cards: grayed out, lock icon overlay, tap shows unlock requirement
- Check `accountProvider.player.level` and `campaignProgress` against requirements
- Show "Complete Mission X or reach Level Y to unlock" message

### 3C. First-Time Player Flow
**File:** `lib/features/home/home_screen.dart`

- For brand new players (level 1, no games played): auto-show campaign as primary CTA
- "Start your pilot training!" prominent button
- Other unlocked modes (Free Flight, Training, Uncharted) shown but secondary

---

## Phase 4: Integration & Polish

### 4A. XP Rewards from Campaign
- Campaign missions award XP (50-150 per mission)
- Completing the full campaign (~12 missions) should bring player to ~level 5-7
- This naturally unlocks most gated modes through progression

### 4B. Existing Player Handling
- Players who are already level 5+ see everything unlocked (no regression)
- Campaign still available as optional content even if modes are unlocked
- "Pilot Training" shown as a game mode, not forced

### 4C. Update Gameplay Guide
- Add Campaign tab to gameplay guide
- Update fuel/scoring sections
- Add coach bios page

### 4D. Tests
- Unit tests for new campaign models
- Unit tests for fuel scoring changes
- Unit tests for mode gating logic
- Integration test: complete campaign mission flow

---

## File Impact Summary

**New files (~7):**
- `lib/game/tutorial/coach.dart`
- `lib/game/tutorial/campaign_mission.dart`
- `lib/game/tutorial/campaign_missions.dart` (data)
- `lib/game/tutorial/mode_requirements.dart`
- `lib/features/campaign/campaign_screen.dart`
- `lib/features/campaign/coach_overlay.dart`
- `lib/features/campaign/mission_dialog.dart`

**Modified files (~8):**
- `lib/game/flit_game.dart` (fuel: remove emergency landing)
- `lib/game/session/game_session.dart` (scoring: bonus model)
- `lib/data/models/pilot_license.dart` (fuelBoost display rename)
- `lib/features/play/play_screen.dart` (fuel efficiency, remove emergency)
- `lib/features/home/home_screen.dart` (mode gating, campaign CTA)
- `lib/data/providers/account_provider.dart` (campaign progress)
- `lib/data/models/player.dart` (campaign progress field)
- `lib/features/guide/gameplay_guide_screen.dart` (updated docs)

**Test files (~4):**
- `test/game/tutorial/campaign_mission_test.dart`
- `test/game/session/game_session_test.dart` (updated scoring)
- `test/game/tutorial/mode_requirements_test.dart`
- `test/features/campaign/campaign_screen_test.dart`

---

## Implementation Order

1. **Phase 1** (Fuel) — smallest, most impactful, unblocks everything
2. **Phase 2A-2C** (Data models) — foundation for campaign
3. **Phase 3** (Mode gating) — can ship independently of campaign UI
4. **Phase 2D-2G** (Campaign UI) — the big feature
5. **Phase 4** (Polish) — integration, tests, guide updates
