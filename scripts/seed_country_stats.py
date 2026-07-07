#!/usr/bin/env python3
"""Seed assets/data/country_stats.json from the const allStats map.

One-off (and re-runnable) extractor that parses the ``allStats`` block out of
``lib/game/clues/clue_types.dart`` and emits an override asset containing ONLY
the two volatile fields (``headOfState`` + ``population``) for every country.

The emitted JSON is the baseline override; the weekly refresh script mutates it
in place. Keys are sorted for stable diffs.

Usage:
    python3 scripts/seed_country_stats.py

Stdlib only.
"""

from __future__ import annotations

import datetime
import json
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DART_PATH = os.path.join(REPO_ROOT, "lib", "game", "clues", "clue_types.dart")
OUT_PATH = os.path.join(REPO_ROOT, "assets", "data", "country_stats.json")

# Fields we extract into the override asset.
FIELDS = ("headOfState", "population")


def extract_allstats_block(source: str) -> str:
    """Return the text between ``const allStats ... {`` and its closing ``};``."""
    start_marker = "const allStats = <String, Map<String, String>>{"
    start = source.find(start_marker)
    if start == -1:
        raise SystemExit("Could not locate 'const allStats' block in clue_types.dart")
    body_start = start + len(start_marker)
    # The block closes at the first 4-space-indented '};' after the start.
    end = source.find("\n    };", body_start)
    if end == -1:
        raise SystemExit("Could not locate end of allStats block")
    return source[body_start:end]


def field_value(body: str, field: str) -> str | None:
    """Extract a single/double-quoted string value for ``field`` from an entry."""
    m = re.search(
        r"'" + re.escape(field) + r"':\s*(?:'([^']*)'|\"([^\"]*)\")",
        body,
    )
    if not m:
        return None
    return m.group(1) if m.group(1) is not None else m.group(2)


def parse_countries(block: str) -> dict[str, dict[str, str]]:
    """Parse each ``'XX': { ... }`` country entry from the allStats block."""
    countries: dict[str, dict[str, str]] = {}
    # Each country map is flat (no nested braces), so a non-greedy body match
    # stops at the country's own closing brace.
    for m in re.finditer(r"'([A-Z]{2})':\s*\{(.*?)\}", block, re.DOTALL):
        code = m.group(1)
        body = m.group(2)
        entry: dict[str, str] = {}
        for field in FIELDS:
            val = field_value(body, field)
            if val is None or val == "":
                raise SystemExit(f"Country {code}: empty/missing field '{field}'")
            entry[field] = val
        countries[code] = entry
    return countries


def main() -> int:
    with open(DART_PATH, "r", encoding="utf-8") as fh:
        source = fh.read()

    block = extract_allstats_block(source)
    countries = parse_countries(block)

    # Sanity: count of '<CODE>': { headers inside the block should match.
    header_count = len(re.findall(r"'[A-Z]{2}':\s*\{", block))
    if header_count != len(countries):
        raise SystemExit(
            f"Parsed {len(countries)} entries but found {header_count} headers"
        )

    payload = {
        "_meta": {
            "generated": datetime.datetime.now(datetime.timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "source": "seed",
            "rowCount": len(countries),
        },
        "countries": {
            code: countries[code] for code in sorted(countries)
        },
    }

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2, sort_keys=True)
        fh.write("\n")

    print(f"Wrote {OUT_PATH}")
    print(f"rowCount = {len(countries)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
