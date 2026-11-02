#!/usr/bin/env python3
"""Independent, offline E18 QA of frozen EVERBLOOM innovation specifications.

Source catalogs are not modified or represented as playable game features.
The projection records source blob identifiers; it does NOT contain complete
source bytes, so a separate full-source re-fetch is required before Phase C.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECTION = HERE / "FROZEN_PROJECTION.json"
ERRATA = HERE / "SEMANTIC_ERRATA.json"
EXPECTED_SOURCES = {
    "builder_A": ("1fbcafa552dfab5f03e0c22fbb929174dbaa5e87", 10),
    "emergence_A": ("883f73fdf8dd31177865107eef82a7125b2703b2", 10),
    "builder_B": ("d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b", 100),
    "emergence_B_011_050": ("a5def76918e77e0ded7e3e8085444698b4e0b549", 40),
    "emergence_B_051_110": ("eb7c590f43c92ded0e328ecfdf7003fa7c06ceac", 60),
}
SKY_TERMS = re.compile(r"\b(eclipse|aurora|meteor|constellation)\b", re.I)
EXPECTED_IDS = {f"EB-{lane}-{number:03d}" for lane in "BE" for number in range(1, 111)}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def audit(projection: dict, errata: dict) -> dict:
    require(projection.get("schema_version") == 1, "projection schema")
    sources = projection.get("source_blobs")
    require(isinstance(sources, list) and len(sources) == 5, "source count")
    source_map = {}
    for source in sources:
        require(isinstance(source, dict), "source shape")
        key = source.get("key")
        require(key in EXPECTED_SOURCES and key not in source_map, "source key")
        sha, count = EXPECTED_SOURCES[key]
        require(source.get("blob_sha") == sha, "source blob provenance")
        require(source.get("expected") == count, "source expected count")
        require(isinstance(source.get("path"), str) and source["path"].endswith(".json"), "source path")
        require(isinstance(source.get("ref"), str) and source["ref"].startswith("game/"), "source branch")
        source_map[key] = source
    require(set(source_map) == set(EXPECTED_SOURCES), "source coverage")

    records = projection.get("records")
    require(isinstance(records, list) and len(records) == 220, "record count")
    ids, titles, counts, sky_leaks = set(), set(), Counter(), []
    by_id = {}
    for row in records:
        require(isinstance(row, dict), "record shape")
        feature_id = row.get("id")
        require(isinstance(feature_id, str) and feature_id in EXPECTED_IDS, "feature ID range")
        require(feature_id not in ids, "duplicate feature ID")
        ids.add(feature_id)
        title = row.get("title")
        require(isinstance(title, str) and len(title.strip()) >= 8, "title")
        title_key = " ".join(title.casefold().split())
        require(title_key not in titles, "duplicate normalized title")
        titles.add(title_key)
        source_key = row.get("source_key")
        require(source_key in source_map, "unknown source")
        counts[source_key] += 1
        n = int(feature_id[-3:])
        lane = feature_id[3]
        expected_key = ("builder_" if lane == "B" else "emergence_") + ("A" if n <= 10 else "B")
        if expected_key == "emergence_B":
            expected_key = "emergence_B_011_050" if n <= 50 else "emergence_B_051_110"
        require(source_key == expected_key, "source to feature ID mismatch")
        require(isinstance(row.get("domain"), str) and row["domain"].strip(), "domain")
        require(isinstance(row.get("player_scenario"), str) and len(row["player_scenario"].strip()) >= 20, "scenario")
        require(isinstance(row.get("player_verbs"), list) and len(row["player_verbs"]) >= 2, "player verbs")
        require(all(isinstance(x, str) and x.strip() for x in row["player_verbs"]), "empty player verb")
        require(isinstance(row.get("state_fields"), list) and len(row["state_fields"]) >= 2, "state fields")
        require(all(isinstance(x, str) and x.strip() for x in row["state_fields"]), "empty state field")
        controls = row.get("controls")
        require(isinstance(controls, dict), "control map")
        require(all(isinstance(controls.get(k), str) and controls[k].strip()
                    for k in ("keyboard_mouse", "controller", "touch")), "control parity specification")
        for k in ("acceptance_positive", "acceptance_negative"):
            require(isinstance(row.get(k), str) and len(row[k].strip()) >= 20, k)
        require(isinstance(row.get("dependencies"), list), "dependencies")
        require(row.get("status") in ("specified_pending_review", "specified_not_implemented"), "design status")
        negative = row["acceptance_negative"]
        identity = " ".join([row["title"], row["domain"], row["player_scenario"]])
        if SKY_TERMS.search(negative) and not SKY_TERMS.search(identity):
            sky_leaks.append(feature_id)
        by_id[feature_id] = row
    require(ids == EXPECTED_IDS, "incomplete 220 ID sequence")
    require(all(counts[k] == expected_count for k, (_, expected_count) in EXPECTED_SOURCES.items()),
            "per-source record count")
    # A genuine frozen-source defect is expected. Never hide it by silently
    # editing the original catalog or by declaring a clean source audit.
    require(sky_leaks == ["EB-E-102"], f"unreviewed cross-domain sky leakage: {sky_leaks}")

    require(errata.get("schema_version") == 1, "errata schema")
    require(errata.get("phase_c") == "CLOSED", "phase C gate")
    entries = errata.get("entries")
    require(isinstance(entries, list) and len(entries) == 1, "errata count")
    fix = entries[0]
    require(fix.get("id") == "EB-E-102", "errata target")
    require(fix.get("source_key") == "emergence_B_051_110", "errata source key")
    require(fix.get("source_blob_sha") == EXPECTED_SOURCES["emergence_B_051_110"][0],
            "errata source blob")
    require(fix.get("source_negative_acceptance") == by_id["EB-E-102"]["acceptance_negative"],
            "errata original must match frozen source")
    replacement = fix.get("proposed_negative_acceptance")
    require(isinstance(replacement, str) and len(replacement) >= 100, "replacement depth")
    require(not SKY_TERMS.search(replacement), "replacement still crosses into sky mystery")
    require("consent" in replacement and "schedule" in replacement and "overlap" in replacement,
            "replacement missing core negative guards")
    require(fix.get("status") == "PROPOSED_NOT_APPLIED", "errata not source-approved")
    return {
        "records": len(records),
        "unique_ids": len(ids),
        "unique_titles": len(titles),
        "source_counts": dict(sorted(counts.items())),
        "frozen_source_semantic_findings": sky_leaks,
        "proposed_errata": [fix["id"]],
        "phase_c": "CLOSED",
    }


def adversarial_self_test(projection: dict, errata: dict) -> int:
    def reject(name, change):
        p, e = copy.deepcopy(projection), copy.deepcopy(errata)
        change(p, e)
        try:
            audit(p, e)
        except (ValueError, TypeError, KeyError):
            return 1
        raise AssertionError(f"invalid mutation incorrectly accepted: {name}")

    def row(p, feature_id):
        return next(x for x in p["records"] if x["id"] == feature_id)

    tests = [
        ("lost record", lambda p, e: p["records"].pop()),
        ("duplicate ID", lambda p, e: p["records"].__setitem__(0, {**p["records"][0], "id": p["records"][1]["id"]})),
        ("duplicate title", lambda p, e: p["records"][0].__setitem__("title", p["records"][1]["title"])),
        ("unknown source", lambda p, e: p["records"][0].__setitem__("source_key", "other")),
        ("wrong source ownership", lambda p, e: row(p, "EB-E-102").__setitem__("source_key", "builder_B")),
        ("tampered source blob", lambda p, e: p["source_blobs"][0].__setitem__("blob_sha", "0" * 40)),
        ("tampered source count", lambda p, e: p["source_blobs"][0].__setitem__("expected", 11)),
        ("invalid feature ID", lambda p, e: p["records"][0].__setitem__("id", "EB-X-001")),
        ("empty title", lambda p, e: p["records"][0].__setitem__("title", "")),
        ("empty scenario", lambda p, e: p["records"][0].__setitem__("player_scenario", "")),
        ("no verbs", lambda p, e: p["records"][0].__setitem__("player_verbs", [])),
        ("no state", lambda p, e: p["records"][0].__setitem__("state_fields", [])),
        ("no touch", lambda p, e: p["records"][0]["controls"].__setitem__("touch", "")),
        ("no positive test", lambda p, e: p["records"][0].__setitem__("acceptance_positive", "")),
        ("no negative test", lambda p, e: p["records"][0].__setitem__("acceptance_negative", "")),
        ("extra cross-domain contamination", lambda p, e: row(p, "EB-E-103").__setitem__("acceptance_negative", "A meteor eclipse must teleport this resident without consent")),
        ("original E102 evidence erased", lambda p, e: row(p, "EB-E-102").__setitem__("acceptance_negative", "The search succeeds safely with consent and schedule validation")),
        ("wrong errata target", lambda p, e: e["entries"][0].__setitem__("id", "EB-E-103")),
        ("false errata source", lambda p, e: e["entries"][0].__setitem__("source_blob_sha", "0" * 40)),
        ("unsafe errata", lambda p, e: e["entries"][0].__setitem__("proposed_negative_acceptance", "An eclipse puzzle must be solvable")),
        ("errata gate bypass", lambda p, e: e.__setitem__("phase_c", "OPEN")),
        ("errata falsely applied", lambda p, e: e["entries"][0].__setitem__("status", "APPROVED")),
        ("extra unreviewed errata", lambda p, e: e["entries"].append(copy.deepcopy(e["entries"][0]))),
    ]
    return sum(reject(name, change) for name, change in tests)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    projection = json.loads(PROJECTION.read_text(encoding="utf-8"))
    errata = json.loads(ERRATA.read_text(encoding="utf-8"))
    result = audit(projection, errata)
    rejected = adversarial_self_test(projection, errata) if args.self_test else 0
    print("JOINT220_AUDIT=" + json.dumps(result, sort_keys=True))
    print(f"ADVERSARIAL_MUTATIONS_REJECTED={rejected}")
    print("FROZEN_SOURCE_DEFECT_E102=OPEN; ERRATUM=PROPOSED_NOT_APPLIED")
    print("DESIGN_ONLY=TRUE; NATIVE_NEW_FEATURE_GAMEPLAY_PROOF=FALSE; PHASE_C=CLOSED")
    print("JOINT220_AUDIT_RESULT=PASS")


if __name__ == "__main__":
    main()
