# Flit - Future Feature Plan

Scaffolded models and UI components that are not yet wired into the app but represent planned features. Each has a data model or widget already written and ready for integration.

---

## Monetisation

### Subscription Tiers
**File:** `lib/data/models/subscription.dart`

Four-tier freemium model (free, monthly, annual, lifetime) with premium perks including ad removal and Live Group hosting access. Includes pricing, active status tracking, and optional gifting.

### Ad System
**File:** `lib/data/models/ad_config.dart`

Ad placement strategy covering banner, interstitial, and rewarded ad types. Defines frequency limits per session and placement rules. Ad eligibility is gated by subscription tier (premium users see no ads).

---

## Social & Multiplayer

### Live Groups
**File:** `lib/data/models/live_group.dart`

Real-time multiplayer sessions where a premium subscriber hosts up to 8 players in live challenges with seeded questions and a streaming leaderboard. Supports two scoring modes: standard and first-to-answer.

### Leaderboards
**File:** `lib/data/models/leaderboard.dart`

Comprehensive leaderboard system supporting licensed/unlicensed play across multiple board types: daily, all-time, seasonal, regional, and friends. Includes placeholder data generation for UI development and annual cosmetic rewards for top performers.

### Social Titles
**File:** `lib/data/models/social_title.dart`

Achievement title system with 8 categories (flags, capitals, outlines, borders, stats, general, speed, streak) unlocked through gameplay milestones. Titles have rarity tiers with corresponding visual presentation.

---

## Gameplay UI

### Challenge Result Screen
**File:** `lib/features/challenge/challenge_result_screen.dart`

End-of-challenge summary screen showing victory/defeat, best-of-5 score, per-round time comparisons, coins earned, and rematch/home navigation. Consumes the `Challenge` model from `lib/data/models/challenge.dart`.

### Altitude Slider
**File:** `lib/game/ui/altitude_slider.dart`

Vertical slider widget for controlling camera altitude with smooth transitions, drag-to-adjust, and color/icon feedback representing zoom levels from low to high.

### Region Camera Presets
**File:** `lib/game/rendering/region_camera_presets.dart`

Per-region camera positions, altitudes, FOV overrides, and bounds-checking for the globe camera. Covers world, US, UK, Caribbean, Ireland, and Canada regions. Has a full test suite in `test/unit/game/rendering/camera_state_test.dart`.

---

## Core Infrastructure

### Core Barrel Export
**File:** `lib/core/core.dart`

Barrel file exporting core module services (dev overlay, error sender, error service) and theming utilities (colours and theme) for convenient access.
