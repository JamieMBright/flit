---
name: flit-canvas-art
description: >-
  Design and verify the game's hand-drawn Canvas art — planes, seasonal
  vehicles, HUD, contrails, and globe/map overlays drawn with Flutter
  CustomPainter / Path (e.g. lib/game/rendering/plane_renderer.dart). Use when
  adding or refining any vehicle silhouette or other CustomPainter visual, so
  the result is recognizable, on-aesthetic, and visually verified before it
  ships. Adapts Anthropic's frontend-design + canvas-design craftsmanship to
  Flutter, and bakes in a render-and-look verification loop.
---

# Flit Canvas Art

Hand-drawn Canvas art (the lo-fi plane/vehicle overlay, HUD, map markers) is
the game's signature contrast against the realistic globe. Treat every shape as
a small piece of craft, not a quick `Path`. Reference aesthetic: lo-fi atlas
warmth, hand-drawn pencil-and-wash, readable at a glance.

## Non-negotiable: verify visually before shipping

You cannot judge Canvas art by reading code — you must look at it. Flutter golden
tests render real pixels offline, and you can open the PNG.

1. Add/extend a golden under `test/golden/` that renders the art on a neutral
   **mid-grey** ground (`0xFF808890` — shows both light and near-black parts),
   centered, no animation/banking (`bankCos: 1.0, bankSin: 0.0`). Grid multiple
   subjects so you see them together.
2. Regenerate: `flutter test --update-goldens test/golden/<file>_test.dart`
3. **Read the PNG** and critique it honestly. Apply the **squint test**: from the
   silhouette alone, is it unmistakably the thing? If a stranger wouldn't name
   it, it isn't done.
4. Refine the `Path`/draw code and repeat until it reads. Then run
   `flutter analyze` on the file.
5. Keep scratch goldens local-only (`echo 'test/golden/' >> .git/info/exclude`)
   to avoid cross-environment golden flakiness, OR commit one as a deliberate
   regression gate — but never let it block CI on AA/font differences.

> This loop is how the seasonal "Santa's Sleigh" bug was caught: it had rendered
> as a winged bug (runners drawn as wide wings + reins drawn as antennae). The
> code looked fine; the picture did not. A picture is worth 1000 tokens.

## Design principles

- **Silhouette first.** Recognition lives in the outline at small size. Nail the
  2–3 iconic cues of the subject before any interior detail (sleigh = curled
  runner scrolls + gift sack; broom = bristle fan + handle; hang-glider = delta
  sail + slung pilot). Cut anything that fights the silhouette.
- **Respect the coordinate system.** Vehicles draw nose-up (`-Y`), span on `±X`.
  Don't force a side-profile subject (sleigh, broom) into the wide L/R "wing"
  slots — that's what made the sleigh read as an insect. Draw the subject's true
  silhouette in the available frame instead of stretching it into wings.
- **Spend boldness in one place.** One signature element per subject; keep
  everything else quiet and disciplined. Delete decoration that doesn't earn its
  place (the sleigh's reins read as antennae — removing them helped more than
  any addition).
- **Refine, don't add.** When something feels off, the instinct to draw another
  shape is usually wrong. Ask "how do I make what's already here read better?"
  Make existing forms crisper and more cohesive before adding marks.
- **Use the shared language.** Build from the existing helpers
  (`_wash` / `_pencilOutline` / `_crossHatch`) and the passed `colorScheme`
  (`primary` / `secondary` / `detail`) so new art matches the lo-fi pencil-wash
  look and picks up seasonal palettes. Follow `bankCos`/`bankSin` and
  `dynamicWingSpan` conventions so it banks correctly in flight.
- **Recognizable, not cartoony or amateur.** Aim for crafted and intentional —
  the result of care, not a rough sketch.

## Apply universally (per CLAUDE.md)

A rendering improvement (border smoothing, silhouette fix, banding fix) belongs
at the shared layer and to every relevant subject/mode — not one vehicle in
isolation. When you fix one, ask which others need the same.

## Provenance / further skills

Principles adapted from Anthropic's official **frontend-design** (installed
alongside this skill at `.claude/skills/frontend-design/`) and **canvas-design**
skills (`github.com/anthropics/skills`). For standalone marketing/poster art
(PNG/PDF) rather than in-game Canvas, the official `canvas-design` skill (ships a
large web-font set) is the better tool and can be installed via
`npx skills add anthropics/skills`.
