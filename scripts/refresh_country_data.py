#!/usr/bin/env python3
"""Weekly refresh of volatile country stats from Wikidata (CC0).

Fetches the current head of government (P6, preferred) else head of state (P35),
and the population (P1082), keyed by ISO alpha-2 (P297), for sovereign states
(P31 = Q3624078). Updates ONLY the two volatile fields (``headOfState`` /
``population``) in ``assets/data/country_stats.json``, and only for ISO codes
that already exist in that file (never introduces new countries).

Guardrails (all fail *safe* — keep the existing value, never blank the game):
  * Abort with exit 1 and NO write if fewer than MIN_ROWS rows are returned
    (protects against a partial/broken Wikidata response wiping data).
  * Missing leader for a country  -> keep the existing value.
  * Population accepted only within [POP_MIN, POP_MAX]; otherwise keep existing.
  * Population reformatted to the game's "331M" / "38K" convention.

The file is written only if something actually changed. Keys are sorted for
stable diffs and ``_meta`` is refreshed.

Stdlib only (urllib, json) — no pip install needed in CI.

Usage:
    python3 scripts/refresh_country_data.py            # live fetch + write
    python3 scripts/refresh_country_data.py --self-test  # offline logic check
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
import urllib.parse
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(REPO_ROOT, "assets", "data", "country_stats.json")

WDQS_ENDPOINT = "https://query.wikidata.org/sparql"
DEFAULT_USER_AGENT = (
    "FlitCountryDataBot/1.0 (https://github.com/JamieMBright/flit; "
    "geography game country-stats refresh) Python-urllib"
)

# Guardrail thresholds.
MIN_ROWS = 180          # abort if fewer distinct countries than this
POP_MIN = 1_000         # reject implausibly small populations
POP_MAX = 1_600_000_000  # reject implausibly large populations (> ~India/China)

SPARQL_QUERY = """
SELECT ?iso ?hogLabel ?hosLabel ?population WHERE {
  ?country wdt:P31 wd:Q3624078 .
  ?country wdt:P297 ?iso .
  OPTIONAL {
    ?country p:P6 ?hogSt .
    ?hogSt ps:P6 ?hog .
    FILTER NOT EXISTS { ?hogSt pq:P582 ?hogEnd }
    ?hog rdfs:label ?hogLabel . FILTER(LANG(?hogLabel) = "en")
  }
  OPTIONAL {
    ?country p:P35 ?hosSt .
    ?hosSt ps:P35 ?hos .
    FILTER NOT EXISTS { ?hosSt pq:P582 ?hosEnd }
    ?hos rdfs:label ?hosLabel . FILTER(LANG(?hosLabel) = "en")
  }
  OPTIONAL { ?country wdt:P1082 ?population }
}
"""


# ---------------------------------------------------------------------------
# Pure helpers (unit-tested by --self-test)
# ---------------------------------------------------------------------------

def format_population(value: int | float | str) -> str | None:
    """Reformat a raw population count to the game's "331M"/"38K" convention.

    Returns None if the value is non-numeric or outside [POP_MIN, POP_MAX].
    """
    try:
        n = int(float(value))
    except (TypeError, ValueError):
        return None
    if n < POP_MIN or n > POP_MAX:
        return None
    if n >= 1_000_000:
        return f"{round(n / 1_000_000)}M"
    if n >= 1_000:
        return f"{round(n / 1_000)}K"
    return str(n)


def parse_sparql_results(data: dict) -> dict[str, dict]:
    """Collapse SPARQL bindings into {ISO: {"leader": str?, "population": int?}}.

    Multiple rows per country are merged: head-of-government (P6) is preferred
    over head-of-state (P35); the largest population value seen wins (P1082
    preferred-rank truthy values, most-recent tends to be the largest).
    """
    out: dict[str, dict] = {}
    bindings = data.get("results", {}).get("bindings", [])
    for row in bindings:
        iso = _binding(row, "iso")
        if not iso:
            continue
        iso = iso.strip().upper()
        if len(iso) != 2 or not iso.isalpha():
            continue
        entry = out.setdefault(iso, {"leader": None, "population": None})

        hog = _binding(row, "hogLabel")
        hos = _binding(row, "hosLabel")
        # Prefer head of government; only fall back to head of state.
        if hog:
            entry["leader"] = hog
        elif hos and not entry["leader"]:
            entry["leader"] = hos

        pop_raw = _binding(row, "population")
        if pop_raw is not None:
            try:
                pop = int(float(pop_raw))
            except (TypeError, ValueError):
                pop = None
            if pop is not None and (
                entry["population"] is None or pop > entry["population"]
            ):
                entry["population"] = pop
    return out


def _binding(row: dict, key: str) -> str | None:
    cell = row.get(key)
    if not isinstance(cell, dict):
        return None
    val = cell.get("value")
    if val is None:
        return None
    val = str(val).strip()
    return val or None


def apply_updates(
    existing: dict[str, dict], fetched: dict[str, dict]
) -> tuple[dict[str, dict], list[str]]:
    """Merge fetched values onto existing countries only. Returns (new, changes).

    Only ISO codes already present in ``existing`` are touched. Missing or
    out-of-range values keep the existing entry.
    """
    updated = {code: dict(fields) for code, fields in existing.items()}
    changes: list[str] = []

    for code, fields in updated.items():
        f = fetched.get(code)
        if not f:
            continue

        leader = f.get("leader")
        if leader and leader != fields.get("headOfState"):
            changes.append(
                f"{code} headOfState: {fields.get('headOfState')!r} -> {leader!r}"
            )
            fields["headOfState"] = leader

        pop_fmt = format_population(f["population"]) if f.get("population") else None
        if pop_fmt and pop_fmt != fields.get("population"):
            changes.append(
                f"{code} population: {fields.get('population')!r} -> {pop_fmt!r}"
            )
            fields["population"] = pop_fmt

    return updated, changes


# ---------------------------------------------------------------------------
# I/O
# ---------------------------------------------------------------------------

def fetch_wikidata(user_agent: str) -> dict:
    """Query WDQS and return the parsed sparql-results JSON."""
    params = urllib.parse.urlencode({"query": SPARQL_QUERY, "format": "json"})
    url = f"{WDQS_ENDPOINT}?{params}"
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/sparql-results+json",
            "User-Agent": user_agent,
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:  # noqa: S310
        return json.load(resp)


def load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: str, payload: dict) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2, sort_keys=True)
        fh.write("\n")


# ---------------------------------------------------------------------------
# Self-test (offline validation of parse/format/guardrail logic)
# ---------------------------------------------------------------------------

def run_self_test() -> int:
    ok = True

    def check(cond: bool, msg: str) -> None:
        nonlocal ok
        status = "PASS" if cond else "FAIL"
        if not cond:
            ok = False
        print(f"  [{status}] {msg}")

    print("format_population:")
    check(format_population(331_000_000) == "331M", "331,000,000 -> 331M")
    check(format_population(38_000_000) == "38M", "38,000,000 -> 38M")
    check(format_population(38_250) == "38K", "38,250 -> 38K")
    check(format_population(500) is None, "500 rejected (< POP_MIN)")
    check(format_population(2_000_000_000) is None, "2e9 rejected (> POP_MAX)")
    check(format_population("not-a-number") is None, "non-numeric rejected")
    check(format_population(1_500) == "2K", "1,500 -> 2K (rounds)")

    print("parse_sparql_results:")
    fixture = {
        "results": {
            "bindings": [
                # US: head of government present, two population rows (max wins)
                {
                    "iso": {"value": "US"},
                    "hogLabel": {"value": "Jane Doe"},
                    "population": {"value": "331000000"},
                },
                {
                    "iso": {"value": "US"},
                    "population": {"value": "334000000"},
                },
                # FR: only head of state present (no P6)
                {
                    "iso": {"value": "FR"},
                    "hosLabel": {"value": "Jean Dupont"},
                    "population": {"value": "68000000"},
                },
                # XX: bogus population out of range -> should be dropped later
                {
                    "iso": {"value": "XX"},
                    "hogLabel": {"value": "Nobody"},
                    "population": {"value": "9999999999"},
                },
                # bad ISO length -> skipped entirely
                {"iso": {"value": "USA"}, "hogLabel": {"value": "Ignore Me"}},
            ]
        }
    }
    parsed = parse_sparql_results(fixture)
    check(parsed["US"]["leader"] == "Jane Doe", "US leader = head of government")
    check(parsed["US"]["population"] == 334_000_000, "US population = max row")
    check(parsed["FR"]["leader"] == "Jean Dupont", "FR leader falls back to P35")
    check("USA" not in parsed, "3-letter ISO skipped")

    print("apply_updates:")
    existing = {
        "US": {"headOfState": "Old Prez", "population": "300M"},
        "FR": {"headOfState": "Old Pres", "population": "60M"},
        "XX": {"headOfState": "Keep Me", "population": "5M"},
        "ZZ": {"headOfState": "Untouched", "population": "1M"},  # not in fetch
    }
    updated, changes = apply_updates(existing, parsed)
    check(updated["US"]["headOfState"] == "Jane Doe", "US leader updated")
    check(updated["US"]["population"] == "334M", "US population reformatted")
    check(updated["FR"]["headOfState"] == "Jean Dupont", "FR leader updated")
    check(
        updated["XX"]["population"] == "5M",
        "XX out-of-range population kept (not blanked)",
    )
    check(updated["ZZ"] == existing["ZZ"], "ZZ (absent from fetch) untouched")
    check("XX" not in {c.split()[0] for c in changes if "population" in c},
          "XX population NOT recorded as a change")

    print("guardrail (MIN_ROWS):")
    small = {f"C{i:02d}": {"leader": "x", "population": 1_000_000} for i in range(5)}
    check(len(small) < MIN_ROWS, "small fetch would trip MIN_ROWS abort")

    print()
    print("SELF-TEST:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test",
        "--dry-run",
        dest="self_test",
        action="store_true",
        help="Validate parse/format/guardrail logic offline; no network, no write.",
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    user_agent = os.environ.get("WDQS_USER_AGENT", DEFAULT_USER_AGENT)

    existing_doc = load_json(JSON_PATH)
    existing = existing_doc.get("countries", {})
    if not existing:
        print("ERROR: existing country_stats.json has no countries", file=sys.stderr)
        return 1

    print(f"Querying Wikidata as: {user_agent}")
    data = fetch_wikidata(user_agent)
    fetched = parse_sparql_results(data)
    print(f"Wikidata returned {len(fetched)} distinct countries")

    # GUARDRAIL: refuse to proceed on a suspiciously small result set.
    if len(fetched) < MIN_ROWS:
        print(
            f"ERROR: only {len(fetched)} rows (< MIN_ROWS={MIN_ROWS}); "
            "aborting without writing.",
            file=sys.stderr,
        )
        return 1

    updated, changes = apply_updates(existing, fetched)

    if not changes:
        print("No changes — leaving country_stats.json untouched.")
        return 0

    print(f"{len(changes)} field change(s):")
    for c in changes:
        print(f"  {c}")

    payload = {
        "_meta": {
            "generated": datetime.datetime.now(datetime.timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "source": "wikidata",
            "rowCount": len(updated),
        },
        "countries": {code: updated[code] for code in sorted(updated)},
    }
    write_json(JSON_PATH, payload)
    print(f"Wrote {JSON_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
