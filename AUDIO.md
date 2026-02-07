# Audio Asset Guide

Flit uses CC0 / Public Domain audio assets. This document lists every required
file, where to download it, and how to prepare it for the project.

---

## Directory Structure

```
assets/audio/
  engines/          # Looping engine sounds (per plane type)
  music/            # Lo-fi background tracks
  sfx/              # One-shot sound effects
```

---

## Engine Sounds (`assets/audio/engines/`)

Each plane type has a distinct engine character. Sounds should loop seamlessly
and be **mono, OGG Vorbis, 44.1 kHz**.

| File | Description | Plane IDs | Suggested Source |
|------|-------------|-----------|-----------------|
| `biplane_engine.ogg` | Chuttering propeller, rhythmic | `plane_default`, `plane_red_baron` | Freesound: search "biplane propeller loop" CC0 |
| `prop_engine.ogg` | Smooth propeller drone | `plane_prop`, `plane_spitfire`, `plane_seaplane` | Freesound: search "propeller aircraft loop" CC0 |
| `bomber_engine.ogg` | Low, heavy drone | `plane_lancaster`, `plane_stealth` | Freesound: search "heavy aircraft engine" CC0 |
| `jet_engine.ogg` | Smooth jet engine hum | `plane_jet`, `plane_bryanair`, `plane_concorde_classic`, `plane_air_force_one`, `plane_golden_jet`, `plane_diamond_concorde`, `plane_platinum_eagle` | Freesound: search "jet engine cabin loop" CC0 |
| `rocket_engine.ogg` | Rocket roar / rumble | `plane_rocket` | Freesound: search "rocket engine loop" CC0 |
| `wind.ogg` | Just wind / air rush | `plane_paper` | Freesound: search "wind loop outdoor" CC0 |

### Volume Behaviour

- Base volume: **12%** (quiet background presence)
- On turn: volume increases to **20%** (proportional to turn intensity)
- This creates subtle audio feedback for banking

### Recommended Freesound Sources (CC0)

- **Prop plane loop**: [OpenGameArt "Airplane Prop Loop"](https://opengameart.org/content/airplane-prop-loop) (CC-BY 3.0 - credit required)
- **Jet cabin**: Freesound [#451741 richwise](https://freesound.org/people/richwise/sounds/451741/) (CC0)
- **Wind loop**: Freesound [#683096 florianreichelt](https://freesound.org/people/florianreichelt/sounds/683096/) (CC0)

---

## Sound Effects (`assets/audio/sfx/`)

One-shot effects. **Mono or stereo, OGG Vorbis, 44.1 kHz**. Keep files short
(< 2 seconds) for responsiveness.

| File | Description | When Played | Suggested Source |
|------|-------------|-------------|-----------------|
| `clue_pop.ogg` | Simple, modern click/pop | New clue appears | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) (CC0) |
| `landing_success.ogg` | Satisfying confetti pop / celebration | Successful landing | Freesound: [#446111 JustInvoke](https://freesound.org/people/JustInvoke/sounds/446111/) (CC0) |
| `coin_collect.ogg` | Coin jingle | Coins awarded | Freesound: [#350872 cabled_mess](https://freesound.org/people/cabled_mess/sounds/350872/) (CC0) |
| `ui_click.ogg` | Subtle UI tap | Button presses | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) (CC0) |
| `altitude_change.ogg` | Whoosh / altitude shift | Toggle altitude | Freesound: [#683096 florianreichelt](https://freesound.org/people/florianreichelt/sounds/683096/) (CC0) |
| `boost_start.ogg` | Speed boost activation | Boost activated | Freesound: search "speed boost" CC0 |

---

## Background Music (`assets/audio/music/`)

Lo-fi hip hop beats. **Stereo, OGG Vorbis, 44.1 kHz, normalized to -14 LUFS**.
Music plays at 25% volume so it sits behind gameplay.

| File | Description | Suggested Source |
|------|-------------|-----------------|
| `lofi_track_01.ogg` | Chill lo-fi beat | [HoliznaCC0 "Tokyo Sunset"](https://freemusicarchive.org/music/holiznacc0/) (CC0) |
| `lofi_track_02.ogg` | Mellow lo-fi beat | [TAD "Cat Caffe"](https://opengameart.org/content/lofi-ambient-music-pack) (CC0) |
| `lofi_track_03.ogg` | Atmospheric lo-fi | [TAD "Oceanside"](https://opengameart.org/content/lofi-ambient-music-pack) (CC0) |

### Adding More Tracks

To add more tracks, place OGG files in `assets/audio/music/` and add them to
`AudioManager._musicTracks`. Tracks are shuffled and loop automatically.

---

## Download Instructions

Audio files cannot be auto-fetched in CI due to network restrictions. Download
manually:

### Quick Setup (All Platforms)

1. **Kenney Interface Sounds** (for `clue_pop.ogg` and `ui_click.ogg`):
   - Visit https://kenney.nl/assets/interface-sounds
   - Download ZIP, extract, pick two suitable `.ogg` files
   - Rename and place in `assets/audio/sfx/`

2. **Freesound CC0 sounds** (for engine loops, landing, coin, altitude):
   - Create a free account at https://freesound.org
   - Search for each sound using the IDs listed above
   - Filter by "Creative Commons 0" license
   - Download, convert to OGG if needed, place in appropriate directory

3. **Free Music Archive / OpenGameArt** (for lo-fi tracks):
   - Visit the links above for HoliznaCC0 and TAD
   - Download tracks, convert to OGG if needed
   - Normalize to -14 LUFS using Audacity or ffmpeg:
     ```bash
     ffmpeg -i input.mp3 -filter:a loudnorm=I=-14 -codec:a libvorbis output.ogg
     ```

### Converting to OGG

```bash
# Single file
ffmpeg -i input.wav -codec:a libvorbis -q:a 6 output.ogg

# Batch convert
for f in *.wav; do ffmpeg -i "$f" -codec:a libvorbis -q:a 6 "${f%.wav}.ogg"; done
```

### Verifying Assets

All required files:
```
assets/audio/engines/biplane_engine.ogg
assets/audio/engines/prop_engine.ogg
assets/audio/engines/bomber_engine.ogg
assets/audio/engines/jet_engine.ogg
assets/audio/engines/rocket_engine.ogg
assets/audio/engines/wind.ogg
assets/audio/sfx/clue_pop.ogg
assets/audio/sfx/landing_success.ogg
assets/audio/sfx/coin_collect.ogg
assets/audio/sfx/ui_click.ogg
assets/audio/sfx/altitude_change.ogg
assets/audio/sfx/boost_start.ogg
assets/audio/music/lofi_track_01.ogg
assets/audio/music/lofi_track_02.ogg
assets/audio/music/lofi_track_03.ogg
```

---

## Licensing Summary

| Source | License | Attribution Required |
|--------|---------|---------------------|
| Kenney.nl | CC0 1.0 | No |
| Freesound (CC0 tagged) | CC0 1.0 | No |
| HoliznaCC0 | CC0 1.0 | No |
| TAD (OpenGameArt) | CC0 1.0 | No |
| OpenGameArt Prop Loop | CC-BY 3.0 | Yes - credit in app |

All CC0 assets require no attribution. The CC-BY 3.0 prop loop requires credit
in the app's about/credits screen.

---

## AudioManager API

```dart
// Initialize (call once in main.dart)
AudioManager.instance.initialize();

// Toggle sound on/off
AudioManager.instance.enabled = true; // or false

// Start engine for equipped plane (auto-selects sound)
AudioManager.instance.startEngine('plane_jet');

// Update engine volume with turn intensity (call each frame)
AudioManager.instance.updateEngineVolume(turnDirection.abs());

// Play one-shot SFX
AudioManager.instance.playSfx(SfxType.cluePop);
AudioManager.instance.playSfx(SfxType.landingSuccess);

// Background music
AudioManager.instance.startMusic();
AudioManager.instance.stopMusic();
```
