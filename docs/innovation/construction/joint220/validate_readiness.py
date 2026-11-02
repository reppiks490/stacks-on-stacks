#!/usr/bin/env python3
"""Offline, non-Codex design-readiness ledger validation. No engine claims."""
import argparse
import copy
import json
import pathlib
import re
from collections import Counter

HERE = pathlib.Path(__file__).resolve().parent
EXPECTED = {"B_A": 10, "E_A": 10, "B_B": 100, "E_B1": 40, "E_B2": 60}
ID = re.compile(r"^EB-[BE]-(\d{3})$")

def validate(data):
    assert data["schema_version"] == 1
    assert data["engine"] == "Godot 4.x"
    assert data["phaseC_gate"] == "CLOSED_UNTIL_PRINCIPAL_EXPLICIT_220_ACCEPTANCE"
    sources = data["source_blobs"]
    assert len(sources) == 5
    assert {s["key"]: s["count"] for s in sources} == EXPECTED
    assert all(len(s["commit"]) == 40 and len(s["blob_sha"]) == 40 for s in sources)
    rows = data["features"]
    assert len(rows) == 220
    ids = [r["id"] for r in rows]
    assert len(set(ids)) == 220
    assert len({r["title"].strip().casefold() for r in rows}) == 220
    assert Counter(r["source_key"] for r in rows) == Counter(EXPECTED)
    assert len([r for r in rows if r["phase"] == "A"]) == 20
    assert len([r for r in rows if r["phase"] == "B"]) == 200
    source_by_key = {s["key"]: s for s in sources}
    for r in rows:
        match = ID.fullmatch(r["id"])
        assert match, r.get("id")
        assert r["source_key"] in source_by_key
        s = source_by_key[r["source_key"]]
        assert r["source_commit"] == s["commit"]
        assert r["source_path"] == s["path"]
        assert r["source_blob_sha"] == s["blob_sha"]
        assert r["owner"] == s["owner"]
        assert r["phase"] == s["phase"]
        assert r["status"] == "design_only_requires_owner_review"
        assert "principal_cross_domain_approval_pending" in r["risk_flags"]
        assert "native_gameplay_proof_missing" in r["risk_flags"]
        assert isinstance(r["state_fields"], list)
        assert isinstance(r["player_verbs"], list) and r["player_verbs"]
        assert isinstance(r["control_keys"], list)
        assert r["positive_acceptance"] and r["negative_acceptance"]
    for prefix in ("B", "E"):
        assert sorted(int(r["id"][-3:]) for r in rows if r["owner"] == ("construction" if prefix == "B" else "emergence")) == list(range(1, 111))
    assert data["metrics"]["total"] == len(rows)
    assert data["metrics"]["unique_ids"] == len(set(ids))
    assert data["metrics"]["unique_casefold_titles"] == len({r["title"].strip().casefold() for r in rows})
    return True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    payload = json.loads((HERE / "READINESS_LEDGER.json").read_text(encoding="utf-8"))
    validate(payload)
    print("PASS: 220 design-only records, source provenance, IDs, phase gate and risk flags")
    if args.self_test:
        cases = [
            lambda x: x["features"].pop(),
            lambda x: x["features"][0].update(id=x["features"][1]["id"]),
            lambda x: x["features"][0].update(title=x["features"][1]["title"].upper()),
            lambda x: x.update(phaseC_gate="OPEN"),
            lambda x: x["source_blobs"][0].update(blob_sha="0"*40),
            lambda x: x["features"][0].update(source_commit="0"*40),
            lambda x: x["features"][0].update(status="implemented"),
            lambda x: x["features"][0]["risk_flags"].remove("native_gameplay_proof_missing"),
            lambda x: x["features"][0].update(player_verbs=[]),
            lambda x: x["features"][0].update(positive_acceptance=False),
            lambda x: x["features"][0].update(source_key="B_B"),
        ]
        for i, mutation in enumerate(cases, 1):
            altered = copy.deepcopy(payload)
            mutation(altered)
            try:
                validate(altered)
            except (AssertionError, KeyError, TypeError):
                continue
            raise AssertionError(f"mutation {i} escaped validator")
        print(f"PASS: {len(cases)} deliberately invalid ledgers rejected")

if __name__ == "__main__":
    main()
