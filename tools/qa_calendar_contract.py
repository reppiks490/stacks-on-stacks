#!/usr/bin/env python3
"""Independent QA gate for the two original EVERBLOOM festival catalogs.

This validates authored data and prevents accidental calendar collisions; it
does not establish animation, NPC attendance, accessible input, or playability.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEASONS = ("Spring", "Summer", "Autumn", "Winter")


def load_catalogs(root: Path = ROOT) -> tuple[dict, dict]:
    contribution = json.loads((root / "data/festivals.json").read_text(encoding="utf-8"))
    social = json.loads((root / "data/village_life.json").read_text(encoding="utf-8"))
    return contribution, social


def validate_calendar(contribution: dict, social: dict) -> list[str]:
    problems: list[str] = []
    if not isinstance(contribution, dict) or not isinstance(social, dict):
        return ["festival catalogs must be JSON objects"]
    if contribution.get("schema_version") != 1 or social.get("schema_version") != 1:
        problems.append("unsupported calendar schema")
    offerings = contribution.get("festivals")
    gatherings = social.get("festivals")
    if not isinstance(offerings, list) or not isinstance(gatherings, list):
        return problems + ["both catalogs must contain festival arrays"]
    if len(offerings) != 12 or len(gatherings) != 4:
        problems.append("expected 12 contribution and 4 village social events")

    used_slots: set[tuple[int, int]] = set()
    used_ids: set[str] = set()
    counts = {index: [0, 0] for index in range(4)}
    for family, events in (("contribution", offerings), ("social", gatherings)):
        for index, raw in enumerate(events):
            label = f"{family}[{index}]"
            if not isinstance(raw, dict):
                problems.append(f"{label}: event must be an object")
                continue
            identifier = raw.get("id")
            if not isinstance(identifier, str) or not identifier.strip():
                problems.append(f"{label}: missing unique id")
            elif identifier in used_ids:
                problems.append(f"{label}: duplicate cross-catalog id {identifier}")
            else:
                used_ids.add(identifier)
            season = raw.get("season")
            if family == "contribution":
                season = SEASONS.index(season) if season in SEASONS else None
            day = raw.get("day")
            if type(season) is not int or season not in range(4) or (
                type(day) is not int or not 1 <= day <= 14
            ):
                problems.append(f"{label}: invalid 14-day season slot")
                continue
            slot = (season, day)
            if slot in used_slots:
                problems.append(f"{label}: collision on {SEASONS[season]} {day}")
            used_slots.add(slot)
            counts[season][0 if family == "contribution" else 1] += 1
            if family == "social":
                start = raw.get("start_minute")
                end = raw.get("end_minute")
                if (type(start) is not int or type(end) is not int
                        or not 0 <= start < end <= 1320):
                    problems.append(f"{label}: invalid bounded social hours")
                if raw.get("location") != "village_square":
                    problems.append(f"{label}: social venue is not canonical village square")
                if not isinstance(raw.get("narration"), str) or len(raw["narration"].strip()) < 20:
                    problems.append(f"{label}: missing original narrative")
            else:
                if not isinstance(raw.get("title"), str) or len(raw["title"].strip()) < 5:
                    problems.append(f"{label}: missing original event title")
                if not isinstance(raw.get("weather_fallback"), str) or not raw["weather_fallback"].strip():
                    problems.append(f"{label}: missing weather fallback")

    for season, (offering_count, social_count) in counts.items():
        if (offering_count, social_count) != (3, 1):
            problems.append(
                f"{SEASONS[season]}: expected three contributions and one social event")
    return problems


if __name__ == "__main__":
    first, second = load_catalogs()
    errors = validate_calendar(first, second)
    for error in errors:
        print("QA CALENDAR ERROR:", error)
    if errors:
        raise SystemExit(1)
    print("QA CALENDAR PASS: 16 non-overlapping original seasonal occasions (source only)")
