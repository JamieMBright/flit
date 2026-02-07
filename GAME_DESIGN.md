# Flit - Game Design Document

## Core Concept

Flit is a geography flight game. Players pilot a biplane around a 3D globe,
navigating to countries based on clues. The game is fast, comical, and
knowledge-rewarding. A full lap of the world takes 15-20 seconds at high
altitude.

---

## Game Rules

### Objective
You receive a clue (flag, outline, borders, capital, or stats) identifying a
target country or region. Steer your plane to that location and land on it.
Faster = higher score.

### Controls
| Input            | Action                           |
|------------------|----------------------------------|
| Swipe left/right | Steer the plane (banking turn)   |
| Arrow keys       | Steer the plane (keyboard)       |
| Tap altitude btn | Toggle high/low altitude         |

### Altitude
| Mode | Speed | Visibility |
|------|-------|------------|
| High | Fast  | Country outlines, continental shapes, ocean boundaries |
| Low  | Slow  | City names, landmarks, detailed coastlines, street-level hints |

**High altitude** covers ground quickly (~15-20s per world lap) but gives less
detail. **Low altitude** slows the plane down but reveals city labels and fine
geographic detail, making identification easier.

### Scoring
```
score = 10,000 - (elapsed_seconds * 10)
```
Minimum score is 0. Bonus multipliers may apply for streaks, altitude changes,
and fuel efficiency (see Fuel Mechanics).

### Landing
Landing is detected by Haversine great-circle distance. When the plane is
within a threshold radius of the target *and* at low altitude, the landing
triggers. The player must be flying low to land - you can't score from
cruising altitude.

---

## Game Modes

### 1. Free Flight (Solo)
- Pick a region (World, US States, UK Counties, Caribbean, Ireland)
- Single round per session
- Score recorded to personal best
- Coins earned based on score tier

### 2. Training Sortie
- 10 consecutive rounds, no pressure
- Practice-only, no rank impact
- Varied clue types each round
- Learn countries/regions without consequences

### 3. Daily Scramble
- **Same puzzle for all players** (date-seeded RNG)
- Everyone gets the same start position, target, and clue
- Complete it for coin reward
- Global leaderboard (daily/weekly/monthly/yearly/all-time)
- Seasonal events with themed vehicles (Christmas sleigh, etc.)
- Medal progression: Bronze -> Silver -> Gold -> Platinum (20 steps)
- Hall of Fame shows yesterday's winner
- Licensed vs Unlicensed leaderboard toggle

### 4. Dogfight (Challenge)
- **Best of 5 rounds** head-to-head
- Challenger starts round 1 and plays at their convenience
- Challenge is sent to a "friend" in-game
- **Identical start point and quiz questions** for both players
- Challenged plays the same mission, then round results compare
- After challenged completes, challenger is notified
- Results shown on **2D map overlay** comparing both flight routes
- Fastest on each round wins that round
- Winner = first to 3 round wins
- Coins awarded to winner, smaller consolation to loser
- Rematch option after result

---

## Clue Types

Clues appear in the **top corner** of the screen during gameplay.

| Clue Type  | What's Shown | Difficulty |
|-----------|--------------|------------|
| **Flag**  | The national/regional flag | Medium |
| **Outline** | Country/region silhouette shape | Hard |
| **Borders** | List of all bordering countries | Medium |
| **Capital** | The capital city name | Easy |
| **Stats** | Collection of facts about the country | Varied |

### Stats Clue Details
When a stats clue is shown, it includes a subset of:
- Population
- Dominant religion
- Most popular sport
- Notable celebrity
- President / King / Head of State
- Continent
- Official language
- Currency

The daily challenge chooses which clue types are active each day (shown as
chips in the challenge header).

---

## Fuel Mechanics

### Standard Modes (Free Flight, Daily, Challenge)
No fuel limit. The timer is the constraint - slower = lower score.

### Unlimited Mode (Endless Flight)
An extended game mode where fuel becomes the core resource:

**Starting Fuel:** Full tank (100 units)

**Fuel Consumption:**
| Altitude | Rate       | Rationale |
|----------|-----------|-----------|
| High     | 1 unit/s  | Efficient cruising |
| Low      | 2.5 unit/s | More thrust to stay low |
| Boosting | 5 unit/s  | Sprint burns fuel fast |

**Refueling Methods:**
1. **Correct Answer Refill:** Landing on the correct target refills
   fuel by a percentage:
   - Perfect (<5s): +40% tank
   - Good (<15s): +25% tank
   - OK (<30s): +15% tank
   - Slow (30s+): +10% tank

2. **Fuel Pickups:** Floating fuel canister icons appear on the globe at
   random locations. Flying through one grants +5-10% fuel. Pickups
   spawn every 20-30 seconds and disappear after 15 seconds.

3. **Fuel Efficiency Bonus:** Completing 3 targets in a row without
   going below 20% fuel grants a "Fuel Efficient" bonus (+10% flat).

**Running Out of Fuel:**
- When fuel reaches 0, the plane begins a 5-second glide descent
- If you land on the correct target during the glide, you survive with
  +20% fuel (emergency landing bonus)
- If you don't land in time, game over
- Your score is the number of targets found before running out

**Leaderboard:** Unlimited mode has its own leaderboard ranked by
targets-found count, then by total time.

---

## Plane Animations

### Banking (Turning)
When swiping left or right, the plane tilts visibly in the turn direction.
The bank angle is proportional to turn rate, with smooth easing in/out.
Max bank angle capped to prevent the plane looking unnatural.

```
bankAngle = lerp(currentBank, targetBank, 0.1)  // per frame
clamp(bankAngle, -maxBankAngle, maxBankAngle)
```

### Contrails
Animated particle trails emanate from both wingtips. Each frame spawns
particles that fade over ~1 second, creating twin white trails. Contrails
use the equipped contrail color scheme.

### Propeller
The biplane's propeller spins continuously (drawn as rotating lines).
Speed is proportional to current velocity.

### Altitude Transitions
When toggling altitude, the plane animates a smooth climb or descent
over ~0.5 seconds. The globe zoom level adjusts correspondingly.

---

## Progression System

### Experience & Levels
| Action              | XP Earned |
|---------------------|-----------|
| Complete a round    | 50 XP     |
| Win a challenge     | 100 XP    |
| Complete daily      | 75 XP     |
| Perfect time (<5s)  | 25 XP bonus |
| First play of day   | 50 XP bonus |

Level thresholds follow a curve: `xpRequired = level * 100`.
Max level: 50 (title: "Admiral of the Skies").

### Coin Economy
| Action              | Coins Earned |
|---------------------|-------------|
| Complete daily      | 50-100      |
| Daily leader bonus  | 500         |
| Challenge win       | 75          |
| Challenge loss      | 15          |
| Level up            | level * 20  |

### Unlockable Content

**Regions (unlock by level OR purchase):**
| Region     | Required Level | Coin Cost |
|------------|---------------|-----------|
| World      | 1 (default)   | Free      |
| US States  | 3             | 500       |
| UK Counties| 5             | 1,000     |
| Caribbean  | 7             | 2,000     |
| Ireland    | 10            | 5,000     |

**Planes (purchase from shop):**
| Plane             | Rarity    | Price  |
|-------------------|-----------|--------|
| Classic Biplane   | -         | Free   |
| Prop Plane        | Common    | 500    |
| Paper Plane       | Common    | 750    |
| Sleek Jet         | Rare      | 2,000  |
| Rocket Ship       | Rare      | 3,000  |
| Stealth Bomber    | Epic      | 7,500  |
| Golden Jet        | Epic      | 12,000 |
| Diamond Concorde  | Legendary | 25,000 |
| Platinum Eagle    | Legendary | 50,000 |

**Mystery Plane:** 10,000 coins for a random unowned plane. Weighted by
rarity (common 50%, rare 30%, epic 15%, legendary 5%).

**Contrails:** 5 color schemes (default free, 4 purchasable).

---

## Leaderboard System

### Global Leaderboards (Daily Scramble)
Points are determined by **speed** (faster = higher score).

| Period      | Reset Cycle |
|------------|-------------|
| Daily      | Midnight UTC |
| Weekly     | Monday 00:00 UTC |
| Monthly    | 1st of month |
| Yearly     | January 1st |
| All-Time   | Never |

### Licensed vs Unlicensed
Players can optionally verify their "Pilot License" (identity
verification). Two separate leaderboards:
- **Unlicensed:** Open to all, may include casual/alt accounts
- **Licensed:** Verified accounts only, competitive integrity

### Hall of Fame
Previous daily winners are preserved in a historical record showing date,
winner name, and medal tier achieved.

---

## Challenge (Dogfight) Flow

```
Round 1:
  Challenger plays → time recorded → challenge sent to friend
  Challenged is notified → plays same mission → time recorded
  Round winner determined (fastest)

Round 2:
  Challenged plays first this time (alternating)
  Same flow

...continues best-of-5...

After final round:
  Both players see ChallengeResultScreen:
  - Victory/Defeat header
  - Win count (e.g., 3-1)
  - 2D route map showing both flight paths overlaid
  - Per-round time breakdown
  - Coins earned
  - Rematch button
```

---

## Regional Maps

Each region has its own area database with named targets:

| Region      | # of Areas | Example Targets |
|-------------|-----------|-----------------|
| World       | ~196      | France, Japan, Brazil, etc. |
| US States   | 50        | California, Texas, etc. |
| UK Counties | 100       | Kent, Lancashire, Highland, etc. |
| Caribbean   | 16        | Jamaica, Barbados, etc. |
| Ireland     | 32        | Dublin, Cork, Galway, etc. |

Each area includes: code, name, polygon points, capital, population,
and a fun fact. The camera auto-zooms to the appropriate view for each
region using `RegionCameraPresets`.

---

## Seasonal Events

The daily challenge supports seasonal themes that modify the vehicle
appearance and add festive flair:

| Event       | Dates           | Vehicle          |
|-------------|-----------------|------------------|
| Christmas   | Dec 20 - Jan 2  | Santa's Sleigh   |
| Halloween   | Oct 25 - Nov 2  | Witch's Broom    |
| Easter      | Mar 28 - Apr 5  | Easter Bunny Hop |
| Summer      | Jun 20 - Sep 1  | Surfboard Glider |
| Valentine's | Feb 10 - Feb 18 | Cupid's Arrow    |
| St Patrick's| Mar 14 - Mar 20 | Shamrock Shuttle |

---

## Random Start Position

Each round starts from a **random location** on the globe (not necessarily
a real airport - just a random lat/lng). The plane ascends to altitude
and only then does the player discover where they are. This creates the
"where am I?" moment that drives the gameplay.

The target location is generated via `GameSession.random(region)` which
uses `Random()` to pick a random area from the region's database.

For daily challenges, `GameSession.seeded(seed)` uses the date as seed
to ensure all players get the same puzzle.
