# Plan: "Uncharted" Game Mode

## Concept
A new game mode where blank country/region outlines are shown on a map. The player types names into a persistent text field to "discover" them. As each name is correctly entered, the country fills in with color and its name appears on the map. Two sub-modes: **Name Countries** and **Name Capitals**. Common misspellings accepted.

## Regions Available
- World (all countries — requires zoom for small ones)
- Europe, Africa, Asia, Latin America, Oceania, Caribbean
- US States, UK Counties, Ireland, Canada

---

## Implementation Plan

### Phase 1: Fuzzy Matching Engine
**New file:** `lib/game/quiz/fuzzy_match.dart`

- Normalized comparison: lowercase, strip diacritics/accents, trim whitespace
- Levenshtein distance threshold: <=2 chars for names <=8 chars, <=3 for longer
- Alias map for common alternatives (see Phase 6)
- `FuzzyMatcher.bestMatch(input, Map<String, String> candidates) -> String?` returns area code of best match, or null if nothing close enough
- Only matches against unrevealed areas (no double-counting)

### Phase 2: Uncharted Session Logic
**New file:** `lib/game/quiz/uncharted_session.dart`

- `UnchartedMode` enum: `countries`, `capitals`
- `UnchartedSession` class:
  - Constructor takes `GameRegion` + `UnchartedMode`
  - Loads all `RegionalArea` entries, builds name->code lookup
  - For capitals mode, builds capital->code lookup instead
  - `Set<String> revealedCodes` — correctly named areas
  - `submitGuess(String input) -> UnchartedGuessResult` (matched code + name, or null)
  - Tracks: elapsed time, total guesses, correct guesses, wrong guesses
  - `isComplete` when all areas revealed
  - Scoring: base per correct + time bonus + accuracy multiplier

### Phase 3: Country Aliases Data
**New file:** `lib/game/data/country_aliases.dart`

Comprehensive map of alternative names/spellings:
- English alternatives: Myanmar/Burma, Eswatini/Swaziland, Czechia/Czech Republic
- Common abbreviations: DRC, UAE, UK, US/USA
- Without diacritics: Cote d'Ivoire = Ivory Coast
- Short forms: Bosnia = Bosnia and Herzegovina
- Common typos: Kazakstan, Phillipines, Columba, etc.

### Phase 4: Blank Atlas Map Widget
**New file:** `lib/game/quiz/uncharted_map_widget.dart`

- Reuses polygon data from `RegionalData.getAreas(region)`
- Dark background with light outline strokes for all areas
- Revealed areas: filled with themed color + name label at polygon centroid
- Unrevealed areas: outline only, slightly translucent
- `InteractiveViewer` for pinch-to-zoom + pan
- Labels scale appropriately with zoom level
- For flat-map regions (US, UK, Ireland, Canada): Canvas polygon rendering
- For globe regions (world, continents): flat equirectangular projection (simpler than globe for this mode)

### Phase 5: Uncharted Game Screen
**New file:** `lib/features/quiz/uncharted_game_screen.dart`

Layout:
- **Top bar**: Timer (counting up), progress counter "X / Y discovered"
- **Center**: Zoomable map widget
- **Bottom**: Persistent TextField
  - Always focused, auto-clears on correct match
  - Green flash + name reveal animation on correct
  - Subtle shake on wrong guess
  - Last correct answer shown briefly as feedback
- **Give Up button**: Reveals all remaining, ends game
- On completion: navigate to results screen

### Phase 6: Uncharted Setup Screen
**New file:** `lib/features/quiz/uncharted_setup_screen.dart`

- Region grid (same regions as Flight School)
- Mode toggle chips: "Countries" / "Capitals"
- Area count shown per region
- Start button
- Matches existing Flit dark theme + card style

### Phase 7: Home Screen Integration
**Modified:** `lib/features/home/home_screen.dart`

- Add "Uncharted" tile/button alongside existing Flight School entry
- Icon: `explore` or `travel_explore`

### Phase 8: Tests
- `test/unit/game/quiz/fuzzy_match_test.dart` — exact, close, alias, reject
- `test/unit/game/quiz/uncharted_session_test.dart` — reveal flow, scoring, completion
- Widget test for screen rendering (optional if time permits)

---

## Files Created (8)
1. `lib/game/quiz/fuzzy_match.dart`
2. `lib/game/quiz/uncharted_session.dart`
3. `lib/game/data/country_aliases.dart`
4. `lib/game/quiz/uncharted_map_widget.dart`
5. `lib/features/quiz/uncharted_game_screen.dart`
6. `lib/features/quiz/uncharted_setup_screen.dart`
7. `test/unit/game/quiz/fuzzy_match_test.dart`
8. `test/unit/game/quiz/uncharted_session_test.dart`

## Files Modified (1)
1. `lib/features/home/home_screen.dart` — Add Uncharted navigation entry
