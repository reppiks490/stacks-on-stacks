#!/usr/bin/env python3
"""Independent scenario-level audit of 21 cross-catalog similarity candidates."""
from __future__ import annotations

import copy
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXPECTED_BLOCKED = {
    ("EB-B-084", "EB-E-036"),
    ("EB-E-036", "EB-E-077"),
    ("EB-E-040", "EB-E-075"),
}
EXPECTED_LEDGER_BLOB = "783b7bca5af5d52e23f4af439d2aa6e36111afa4"


def check(projection: dict, triage: dict) -> dict:
    if triage.get("schema_version") != 1 or triage.get("phase_c") != "CLOSED":
        raise ValueError("phase gate")
    if triage.get("source_readiness_ledger_blob") != EXPECTED_LEDGER_BLOB:
        raise ValueError("readiness ledger provenance")
    rows = triage.get("pairs")
    if not isinstance(rows, list) or len(rows) != 21:
        raise ValueError("pair count")
    catalog = {r["id"]: r for r in projection["records"]}
    seen, blocked = set(), set()
    for row in rows:
        ids = row.get("ids")
        if not isinstance(ids, list) or len(ids) != 2 or ids[0] == ids[1]:
            raise ValueError("pair identity")
        pair = tuple(ids)
        if pair in seen or any(i not in catalog for i in pair):
            raise ValueError("duplicate/unknown pair")
        seen.add(pair)
        if row.get("titles") != [catalog[i]["title"] for i in pair]:
            raise ValueError("title provenance")
        if row.get("player_scenarios") != [catalog[i]["player_scenario"] for i in pair]:
            raise ValueError("scenario provenance")
        if not isinstance(row.get("review_reason"), str) or len(row["review_reason"]) < 60:
            raise ValueError("insufficient semantic explanation")
        if row.get("integration_status") != "NOT_APPROVED" or row.get("native_gameplay_proof") is not False:
            raise ValueError("unverified integration claim")
        decision = row.get("decision")
        if decision == "requires_authority_contract":
            blocked.add(pair)
        elif decision != "mechanically_distinct_on_scenario_review":
            raise ValueError("unknown review disposition")
    if blocked != EXPECTED_BLOCKED:
        raise ValueError("unresolved authority boundaries altered")
    if triage.get("counts") != {
        "pairs": 21, "authority_contract_required": 3,
        "mechanically_distinct_on_scenario_review": 18,
    }:
        raise ValueError("summary counts")
    return {"pairs": len(rows), "authority_contract_required": len(blocked),
            "scenario_distinct_pending_integration": len(rows) - len(blocked)}


def self_test(projection: dict, triage: dict) -> int:
    mutations = [
        ("drop pair", lambda x: x["pairs"].pop()),
        ("duplicate pair", lambda x: x["pairs"].__setitem__(0, copy.deepcopy(x["pairs"][1]))),
        ("wrong title", lambda x: x["pairs"][0]["titles"].__setitem__(0, "Not the source title")),
        ("wrong scenario", lambda x: x["pairs"][0]["player_scenarios"].__setitem__(1, "A substituted scenario")),
        ("false authority clearance", lambda x: next(r for r in x["pairs"] if r["ids"] == ["EB-B-084", "EB-E-036"]).__setitem__("decision", "mechanically_distinct_on_scenario_review")),
        ("false gameplay proof", lambda x: x["pairs"][0].__setitem__("native_gameplay_proof", True)),
        ("phase C bypass", lambda x: x.__setitem__("phase_c", "OPEN")),
        ("tampered ledger provenance", lambda x: x.__setitem__("source_readiness_ledger_blob", "0" * 40)),
        ("missing explanation", lambda x: x["pairs"][0].__setitem__("review_reason", "")),
    ]
    rejected = 0
    for name, mutation in mutations:
        altered = copy.deepcopy(triage)
        mutation(altered)
        try:
            check(projection, altered)
        except (ValueError, KeyError, TypeError):
            rejected += 1
        else:
            raise AssertionError(f"accepted hostile pair mutation: {name}")
    return rejected


if __name__ == "__main__":
    p = json.loads((HERE / "FROZEN_PROJECTION.json").read_text(encoding="utf-8"))
    t = json.loads((HERE / "PAIR_TRIAGE.json").read_text(encoding="utf-8"))
    result = check(p, t)
    rejected = self_test(p, t)
    print("SIMILARITY_TRIAGE=" + json.dumps(result, sort_keys=True))
    print(f"PAIR_ADVERSARIAL_MUTATIONS_REJECTED={rejected}")
    print("SCENARIO_REVIEW_NOT_FULL_SEMANTIC_CERTIFICATION=TRUE; PHASE_C=CLOSED")
    print("SIMILARITY_TRIAGE_RESULT=PASS")
