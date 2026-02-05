# SPRINTS.md - Flit Development Roadmap

## Testing Strategy (iOS + Open Source)

### Primary: Flutter Web → PWA on iOS
- Deploy web build to **GitHub Pages** (free)
- Install as PWA on iOS home screen (Add to Home Screen)
- Near-native experience, instant updates, no App Store

### Secondary: Native iOS via TestFlight
- Requires Apple Developer account ($99/year) - only when ready for beta
- Use **Codemagic** free tier (500 build mins/month) for iOS builds

### Local Development
```bash
# Web (test in any browser, including iOS Safari)
flutter run -d chrome

# iOS Simulator (Mac only)
flutter run -d ios

# Android Emulator
flutter run -d android
```

### CI/CD Pipeline (GitHub Actions - Free)
```
Push → Build (Web/Android) → Test → Deploy Web to GitHub Pages
                                  → Deploy Android to Firebase App Distribution (free)
```

---

## Sprint Overview

| Sprint | Focus | Duration | Parallel Agents |
|--------|-------|----------|-----------------|
| 0 | Infrastructure | 1 day | 4 |
| 1 | Core Flight | 2 days | 3 |
| 2 | Map & Geography | 2 days | 4 |
| 3 | Clues & Landing | 2 days | 3 |
| 4 | Solo Mode | 1 day | 3 |
| 5 | Backend & Auth | 2 days | 4 |
| 6 | Leaderboards | 1 day | 2 |
| 7 | Friends & H2H | 2 days | 3 |
| 8 | Challenges | 2 days | 3 |
| 9 | Progression & Shop | 2 days | 3 |
| 10 | Regional Maps | 2 days | 4 |
| 11 | Audio & Polish | 2 days | 4 |
| 12 | Launch Prep | 2 days | 3 |

---

## Sprint 0: Infrastructure & Scaffold

**Goal:** Project builds and deploys on all platforms. CI/CD operational.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 0.1 | Flutter project scaffold with Flame | build-validator | None |
| 0.2 | Folder structure per architecture | explore + implement | None |
| 0.3 | GitHub Actions CI (lint, test, build) | build-validator | None |
| 0.4 | GitHub Pages deployment workflow | build-validator | 0.1 |

### Sequential Tasks
| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 0.5 | Verify web build on iOS Safari | platform-validator | 0.1, 0.4 |
| 0.6 | Verify Android build | platform-validator | 0.1 |

### Definition of Done
- [ ] `flutter build web` succeeds
- [ ] `flutter build apk` succeeds
- [ ] GitHub Actions green on push
- [ ] Web deployed to GitHub Pages
- [ ] PWA installable on iOS

### Ship Checklist
```bash
npm run lint && npm run test:unit && npm run build
git push origin main
# Verify: https://<username>.github.io/flit loads on iOS Safari
```

---

## Sprint 1: Core Flight Mechanics

**Goal:** Plane flies, steers, wraps around screen edges. Two altitudes work.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 1.1 | Plane sprite component (bi-plane, tilt animation) | implement | 0.1 |
| 1.2 | Input handling (swipe L/R, arrow keys) | implement | 0.1 |
| 1.3 | Contrail particle system | implement | 0.1 |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 1.4 | Flight physics (constant speed, steering) | implement | 1.1, 1.2 |
| 1.5 | Altitude toggle (high/low) with speed change | implement | 1.4 |
| 1.6 | Screen wrap-around (Mercator style) | implement | 1.4 |
| 1.7 | Camera follow | implement | 1.4 |

### Definition of Done
- [ ] Plane renders and animates tilt on turn
- [ ] Contrails emit from wingtips
- [ ] Swipe/arrow input steers plane
- [ ] Altitude toggle changes speed
- [ ] Plane wraps at screen edges
- [ ] 60fps on web, iOS Safari, Android

### Ship Checklist
```bash
npm run test:unit -- --coverage
npm run test:integration:web
npm run test:integration:ios
npm run lint
git push origin main
# Manual: Test flight controls on iOS PWA
```

---

## Sprint 2: Map & Geography

**Goal:** Stylized world map renders. Countries visible at high altitude. Cities at low.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 2.1 | Download & process Natural Earth countries | geo-data-validator | None |
| 2.2 | Download & process major cities (GeoNames) | geo-data-validator | None |
| 2.3 | Color palette system (2-3 color low-fi) | implement | None |
| 2.4 | Map renderer component (vector polygons) | implement | 1.6 |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 2.5 | High altitude layer (country outlines only) | implement | 2.1, 2.4 |
| 2.6 | Low altitude layer (cities, landmarks) | implement | 2.2, 2.4 |
| 2.7 | Altitude-based layer switching | implement | 2.5, 2.6, 1.5 |
| 2.8 | Map culling for performance | performance-profiler | 2.7 |

### Definition of Done
- [ ] World map renders with low-fi aesthetic
- [ ] Country boundaries visible at high altitude
- [ ] Cities/labels visible at low altitude
- [ ] Smooth transition between altitude layers
- [ ] No frame drops when panning
- [ ] Bundle size < 5MB (compressed geo data)

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:performance
npm run lint
git push origin main
# Manual: Fly around world on iOS, verify both altitudes
```

---

## Sprint 3: Clues & Landing Detection

**Goal:** Clues display. Player can land at target. Detection works.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 3.1 | Clue UI component (top corner overlay) | implement | None |
| 3.2 | Flag assets (SVG, all countries) | geo-data-validator | None |
| 3.3 | Country outline silhouette generator | implement | 2.1 |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 3.4 | Clue types: flag, outline, borders, capital | implement | 3.1, 3.2, 3.3 |
| 3.5 | Clue type: stats (population, religion, etc.) | implement | 3.1 |
| 3.6 | Target zone definition | implement | 2.1 |
| 3.7 | Landing detection (low altitude + proximity) | implement | 3.6, 1.5 |
| 3.8 | Success/failure feedback | implement | 3.7 |

### Definition of Done
- [ ] All 5 clue types render correctly
- [ ] Clue appears after reaching altitude
- [ ] Target zone defined per challenge
- [ ] Landing detection triggers at low altitude over target
- [ ] Visual/audio feedback on land
- [ ] Works identically on all platforms

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:integration:android
npm run lint
git push origin main
# Manual: Complete a full clue→fly→land loop on iOS
```

---

## Sprint 4: Solo Mode

**Goal:** Playable solo mode with local scoring. Random challenges.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 4.1 | Random spawn location generator | implement | 2.1 |
| 4.2 | Random target selection | implement | 2.1 |
| 4.3 | Timer UI component | implement | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 4.4 | Solo game flow (spawn → clue → fly → land) | implement | 4.1, 4.2, 3.7 |
| 4.5 | Scoring (time-based) | implement | 4.4, 4.3 |
| 4.6 | Local high score storage (Isar) | implement | 4.5 |
| 4.7 | Results screen | implement | 4.5 |

### Definition of Done
- [ ] Can play complete solo round
- [ ] Random start/target each game
- [ ] Timer tracks flight time
- [ ] Score saved locally
- [ ] Results screen shows time
- [ ] Can play offline

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run lint
git push origin main
# Manual: Play 5 solo rounds on iOS PWA (airplane mode)
```

---

## Sprint 5: Backend & Auth

**Goal:** Supabase integrated. Users can sign up, log in, sync data.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 5.1 | Supabase project setup | implement | None |
| 5.2 | Auth UI (sign up, log in, guest mode) | implement | None |
| 5.3 | Player profile schema (Supabase) | implement | 5.1 |
| 5.4 | Offline sync queue (Isar) | implement | 4.6 |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 5.5 | Auth flow integration | implement | 5.1, 5.2 |
| 5.6 | Profile CRUD operations | implement | 5.3, 5.5 |
| 5.7 | Sync service (offline → online) | implement | 5.4, 5.6 |
| 5.8 | Security audit | security-auditor | 5.5, 5.6, 5.7 |

### Definition of Done
- [ ] User can sign up / log in / play as guest
- [ ] Profile stored in Supabase
- [ ] Solo scores sync when online
- [ ] Offline play queues for sync
- [ ] No security vulnerabilities
- [ ] Auth works on all platforms

### Ship Checklist
```bash
npm run test:unit
npm run test:security
npm run test:integration:web
npm run test:integration:ios
npm run lint
git push origin main
# Manual: Sign up on web, log in on iOS, verify profile syncs
```

---

## Sprint 6: Leaderboards

**Goal:** Global leaderboards. Daily/weekly/monthly/yearly/all-time.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 6.1 | Leaderboard schema (Supabase) | implement | 5.1 |
| 6.2 | Leaderboard UI component | implement | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 6.3 | Score submission to leaderboard | implement | 6.1, 4.5 |
| 6.4 | Time-windowed queries (day/week/month/year/all) | implement | 6.1 |
| 6.5 | Leaderboard screen with filters | implement | 6.2, 6.4 |
| 6.6 | Daily challenge (fixed seed per day) | implement | 4.4 |

### Definition of Done
- [ ] Scores appear on global leaderboard
- [ ] Can filter by time window
- [ ] Daily challenge uses same seed for everyone
- [ ] Player rank visible
- [ ] Leaderboard loads fast (<500ms)

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:performance
npm run lint
git push origin main
# Manual: Complete daily challenge, verify on leaderboard
```

---

## Sprint 7: Friends & Head-to-Head

**Goal:** Friends list. Lifetime H2H records tracked.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 7.1 | Friends schema (Supabase) | implement | 5.1 |
| 7.2 | H2H records schema (Supabase) | implement | 5.1 |
| 7.3 | Friends list UI | implement | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 7.4 | Add friend (by username/code) | implement | 7.1, 7.3 |
| 7.5 | Friend request flow (send/accept/decline) | implement | 7.4 |
| 7.6 | Friend profile view with H2H stats | implement | 7.2, 7.3 |
| 7.7 | Realtime friend status (Supabase realtime) | implement | 7.1 |

### Definition of Done
- [ ] Can add friends by username
- [ ] Friend requests work
- [ ] H2H lifetime record displays
- [ ] Friend list shows online status
- [ ] Works across platforms

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run lint
git push origin main
# Manual: Add friend on iOS, verify on web
```

---

## Sprint 8: Challenge Mode

**Goal:** Async 1v1 challenges. Best of 5. Route replay.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 8.1 | Challenge schema (Supabase) | implement | 5.1 |
| 8.2 | Round schema with seed | implement | 5.1 |
| 8.3 | Route recording (path data) | implement | 1.4 |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 8.4 | Create challenge flow | implement | 8.1, 7.1 |
| 8.5 | Seeded random (identical start/target) | implement | 8.2, 4.1, 4.2 |
| 8.6 | Play challenge round | implement | 8.5, 4.4 |
| 8.7 | Round completion + notification | implement | 8.6 |
| 8.8 | Route replay on 2D map | implement | 8.3 |
| 8.9 | Results screen with both routes | implement | 8.8 |
| 8.10 | Coin rewards (winner/loser) | implement | 8.6 |
| 8.11 | H2H record update | implement | 8.6, 7.2 |

### Definition of Done
- [ ] Can create and send challenge to friend
- [ ] Both players get identical start/target
- [ ] Best of 5 flow works
- [ ] Routes recorded and replayed
- [ ] Winner gets more coins than loser
- [ ] H2H record updates
- [ ] Push notifications work

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:security
npm run lint
git push origin main
# Manual: Complete full challenge with friend across devices
```

---

## Sprint 9: Progression & Shop

**Goal:** XP, levels, currency, cosmetics shop.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 9.1 | XP/Level system design | implement | None |
| 9.2 | Currency schema (Supabase) | implement | 5.1 |
| 9.3 | Cosmetics catalog (planes, contrails) | implement | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 9.4 | XP gain on game completion | implement | 9.1, 4.5 |
| 9.5 | Level up flow + rewards | implement | 9.4 |
| 9.6 | Currency earn (solo, challenge, daily) | implement | 9.2, 4.5, 8.10 |
| 9.7 | Shop UI | implement | 9.3 |
| 9.8 | Purchase flow (currency → cosmetic) | implement | 9.7, 9.6 |
| 9.9 | Cosmetic equip + display in game | implement | 9.8, 1.1 |
| 9.10 | IAP integration (optional currency purchase) | implement | 9.6 |

### Definition of Done
- [ ] XP earned on every game
- [ ] Levels increase with XP
- [ ] Currency earned and displayed
- [ ] Shop shows available cosmetics
- [ ] Can purchase and equip plane skins
- [ ] Equipped cosmetics show in game
- [ ] IAP works (iOS + Android)

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:integration:android
npm run test:security
npm run lint
git push origin main
# Manual: Earn coins, buy cosmetic, verify equipped
```

---

## Sprint 10: Regional Maps

**Goal:** Alternative maps: US states, UK counties, Caribbean, Ireland.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 10.1 | US states geo data | geo-data-validator | None |
| 10.2 | UK counties geo data | geo-data-validator | None |
| 10.3 | Caribbean islands geo data | geo-data-validator | None |
| 10.4 | Ireland counties geo data | geo-data-validator | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 10.5 | Map selection UI | implement | None |
| 10.6 | Map-specific clue data (capitals, stats) | implement | 10.1-10.4 |
| 10.7 | Map loader (swap active map) | implement | 2.4, 10.1-10.4 |
| 10.8 | Regional leaderboards | implement | 6.1, 10.5 |
| 10.9 | Regional challenges | implement | 8.1, 10.5 |

### Definition of Done
- [ ] Can select map from menu
- [ ] All 4 regional maps playable
- [ ] Clues appropriate per region
- [ ] Separate leaderboards per map
- [ ] Challenges can specify map
- [ ] Performance maintained

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:performance
npm run lint
git push origin main
# Manual: Play each regional map on iOS
```

---

## Sprint 11: Audio & Polish

**Goal:** Lo-fi music, sound effects, animations polished.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 11.1 | Lo-fi background music (royalty-free) | implement | None |
| 11.2 | Sound effects (turn, altitude, land) | implement | None |
| 11.3 | Menu transitions/animations | implement | None |
| 11.4 | Loading states & skeletons | implement | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 11.5 | Audio manager (play, pause, volume) | implement | 11.1, 11.2 |
| 11.6 | Audio settings UI | implement | 11.5 |
| 11.7 | Haptic feedback (iOS/Android) | implement | None |
| 11.8 | Animation polish pass | implement | 11.3 |
| 11.9 | Performance profiling | performance-profiler | All |
| 11.10 | Bug bash | test-runner | All |

### Definition of Done
- [ ] Music plays, can mute
- [ ] Sound effects on all actions
- [ ] Smooth menu transitions
- [ ] Haptics on mobile
- [ ] 60fps sustained
- [ ] No P0/P1 bugs

### Ship Checklist
```bash
npm run test:unit
npm run test:integration:web
npm run test:integration:ios
npm run test:integration:android
npm run test:performance
npm run test:security
npm run lint
git push origin main
# Manual: Full playthrough with audio on iOS
```

---

## Sprint 12: Launch Prep

**Goal:** Production ready. App Store + Play Store + Web live.

### Parallel Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 12.1 | App Store assets (screenshots, description) | implement | None |
| 12.2 | Play Store assets | implement | None |
| 12.3 | Privacy policy + ToS | implement | None |
| 12.4 | Analytics integration (privacy-respecting) | implement | None |

### Sequential Tasks

| Task ID | Task | Agent Type | Dependencies |
|---------|------|------------|--------------|
| 12.5 | Production Supabase environment | implement | 5.1 |
| 12.6 | App Store submission | build-validator | 12.1, 12.3 |
| 12.7 | Play Store submission | build-validator | 12.2, 12.3 |
| 12.8 | Production web deployment | build-validator | None |
| 12.9 | Smoke test all platforms | platform-validator | 12.6, 12.7, 12.8 |
| 12.10 | Launch! | - | 12.9 |

### Definition of Done
- [ ] App Store approved
- [ ] Play Store approved
- [ ] Web production live
- [ ] Analytics working
- [ ] No critical bugs
- [ ] Monitoring in place

### Ship Checklist
```bash
npm run test
npm run test:security
npm run test:deploy
npm run lint
# Submit to stores
# Deploy web to production
# Monitor for 24h
```

---

## Parallel Execution Map

```
Sprint 0: [0.1]──┬──[0.4]──[0.5]
          [0.2]──┤         [0.6]
          [0.3]──┘

Sprint 1: [1.1]──┬──[1.4]──[1.5]──[1.6]──[1.7]
          [1.2]──┤
          [1.3]──┘

Sprint 2: [2.1]──┬──[2.5]──┬──[2.7]──[2.8]
          [2.2]──┼──[2.6]──┘
          [2.3]──┤
          [2.4]──┘

(Continue pattern for all sprints...)
```

---

## Quick Commands

```bash
# Start sprint
git checkout -b sprint-X-description

# Run all pre-commit checks
npm run lint && npm run test:unit && npm run test:security

# Build all platforms
flutter build web && flutter build apk

# Deploy web to GitHub Pages
git push origin main  # triggers GitHub Action

# Test on iOS
# Open https://<user>.github.io/flit in Safari
# Tap Share → Add to Home Screen
```
