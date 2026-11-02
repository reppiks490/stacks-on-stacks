#!/usr/bin/env python3
"""Offline deterministic audit of frozen Construction B011-B110 evidence.

This validates a source-derived evidence snapshot, NOT the original GitHub
blobs or Godot gameplay. Inspect pinned blob SHAs before approving migrations.
"""
from __future__ import annotations
import argparse
import copy
import json
import re
from collections import Counter
from pathlib import Path

EVIDENCE = Path(__file__).with_name("SOURCE_EVIDENCE.json")
EXPECTED = {
    "receipt_uniqueness_not_declarative": 60,
    "negative_epoch_sentinel_requires_policy": 60,
    "typed_quote_not_self_contained": 10,
    "typed_player_verbs_not_self_contained": 10,
    "typed_dependencies_not_self_contained": 50,
    "typed_asset_plan_not_self_contained": 10,
    "typed_budget_not_self_contained": 10,
    "noncanonical_save_namespace": 10,
}
SHA = re.compile(r"^[a-f0-9]{40}$")
ID = re.compile(r"^EB-B-(\\d{3})$")


class AuditFailure(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def evaluate(doc: dict) -> dict:
    require(doc.get("schema_version") == 1, "schema version")
    require(doc.get("phase_c") == "CLOSED", "Phase C must remain closed")
    require(SHA.fullmatch(doc.get("canonical_main_sha", "")) is not None, "main SHA")
    ledger = doc.get("readiness_ledger", {})
    require(SHA.fullmatch(ledger.get("blob_sha", "")) is not None, "readiness blob")
    require(ledger.get("feature_count") == 220, "readiness catalog count")
    tranches = doc.get("tranches", [])
    require(len(tranches) == 10, "exactly ten pinned source tranches")
    require(len({t.get("filename") for t in tranches}) == 10, "duplicate tranche")
    for t in tranches:
        require(SHA.fullmatch(t.get("blob_sha", "")) is not None, "tranche blob SHA")
        require(t.get("records") == 10, "tranche record count")
        require(t.get("ref", "").startswith("game/everbloom-construction-"), "source ref")
    tranche_names = {t["filename"] for t in tranches}
    records = doc.get("records", [])
    require(len(records) == 100, "100 typed contracts required")
    seen, expected_findings = set(), []
    def mark(row, kind):
        expected_findings.append((row["id"], kind))
    for row in records:
        ident = row.get("id", "")
        match = ID.fullmatch(ident)
        require(match is not None and 11 <= int(match.group(1)) <= 110, "invalid ID")
        require(ident not in seen, "duplicate ID")
        seen.add(ident)
        require(row.get("title") == row.get("source_title") and bool(row.get("title")), "title drift")
        require(row.get("tranche") in tranche_names, "unproven tranche")
        mapped = row.get("source_fields", [])
        require(len(mapped) >= 5, "source fields missing")
        require(len({f.get("source") for f in mapped}) == len(mapped), "duplicate source field")
        for f in mapped:
            require(f.get("root") == re.split(r"[.\\[]", f.get("target", ""))[0], "nested field root")
            require(f.get("exists") is True, "source field not mapped to typed state")
        require(row.get("receipt_field_present") is True, "receipt field missing")
        require(row.get("save_version") == 1, "unexpected migration version")
        require(row.get("valid_fixture_count", 0) >= 1, "positive fixture missing")
        require(row.get("negative_fixture_count", 0) >= 1, "negative fixture missing")
        controls = dict(row.get("controls_present", []))
        require(set(controls) == {"keyboard_mouse", "gamepad", "touch"}, "input keys")
        require(all(controls.values()), "input parity incomplete")
        canonical = "construction." + ident.lower().replace("-", "_")
        require(row.get("canonical_namespace") == canonical, "canonical namespace mismatch")
        require(row.get("day_epoch_min") in (-1, 0), "unexpected epoch lower bound")
        src_cost = row.get("source_materials")
        require(isinstance(src_cost, dict) and bool(src_cost), "source cost missing")
        require(all(isinstance(v, int) and v >= 0 for v in src_cost.values()), "bad source quote")
        typed_cost = row.get("typed_materials")
        if typed_cost is None:
            mark(row, "typed_quote_not_self_contained")
        else:
            require(typed_cost == src_cost, "typed/source cost drift")
        if row.get("namespace") != canonical:
            mark(row, "noncanonical_save_namespace")
        if row.get("receipt_uniqueness_declarative") is not True:
            mark(row, "receipt_uniqueness_not_declarative")
        if row.get("day_epoch_min") == -1:
            mark(row, "negative_epoch_sentinel_requires_policy")
        for field, kind in [
            ("typed_player_verbs_present", "typed_player_verbs_not_self_contained"),
            ("typed_dependencies_present", "typed_dependencies_not_self_contained"),
            ("typed_asset_plan_present", "typed_asset_plan_not_self_contained"),
            ("typed_performance_budget_present", "typed_budget_not_self_contained"),
        ]:
            if row.get(field) is not True:
                mark(row, kind)
    require(seen == {f"EB-B-{n:03d}" for n in range(11, 111)}, "missing expected feature ID")
    actual = doc.get("findings", [])
    actual_pairs = [(f.get("id"), f.get("kind")) for f in actual]
    require(len(actual_pairs) == len(set(actual_pairs)), "duplicate finding")
    require(set(actual_pairs) == set(expected_findings), "findings do not match evidence")
    require(all(f.get("disposition") == "REVIEW_REQUIRED_DESIGN_ONLY" for f in actual), "unsafe disposition")
    counts = dict(Counter(kind for _, kind in expected_findings))
    require(counts == EXPECTED, f"unexpected source-derived finding distribution: {counts}")
    metrics = doc.get("metrics", {})
    require(metrics.get("contracts") == 100 and metrics.get("unique_ids") == 100, "metric counts")
    require(metrics.get("findings") == len(expected_findings), "finding count metric")
    require(metrics.get("by_kind") == counts, "finding summary mismatch")
    require(json.loads(json.dumps(doc, sort_keys=True)) == doc, "JSON roundtrip")
    return counts


def self_test(original: dict) -> int:
    def tamper(mutator):
        altered = copy.deepcopy(original)
        mutator(altered)
        try:
            evaluate(altered)
        except AuditFailure:
            return
        raise AuditFailure("adversarial mutation was accepted")
    attacks = [
        lambda d: d["records"].pop(),
        lambda d: d["records"][1].update(id=d["records"][0]["id"]),
        lambda d: d["records"][0].update(title="unreviewed duplicate"),
        lambda d: d["records"][0]["source_fields"][0].update(exists=False),
        lambda d: d["records"][0]["source_fields"][0].update(root="wrong"),
        lambda d: d["records"][10].update(typed_materials={"wood": 999}),
        lambda d: d["records"][0].update(controls_present=[["touch", False]]),
        lambda d: d["records"][0].update(valid_fixture_count=0),
        lambda d: d["records"][0].update(receipt_field_present=False),
        lambda d: d["records"][0].update(canonical_namespace="collision"),
        lambda d: d["findings"].pop(),
        lambda d: d["metrics"].update(findings=0),
        lambda d: d["tranches"][0].update(blob_sha="unverified"),
        lambda d: d.update(phase_c="OPEN"),
        lambda d: d["records"][0].update(day_epoch_min=-999),
        lambda d: d["records"][0].update(typed_dependencies_present=True),
    ]
    for attack in attacks:
        tamper(attack)
    return len(attacks)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    data = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    counts = evaluate(data)
    print("PASS: 100 distinct B011-B110 design contracts, ten pinned source blobs, all field mappings and source quotes checked")
    print("DESIGN FINDINGS (not runtime defects):", json.dumps(counts, sort_keys=True))
    if args.self_test:
        n = self_test(data)
        print(f"PASS: {n}/{n} adversarial manifest mutations rejected")
    print("Phase C CLOSED. Snapshot audit only; no native gameplay, device performance, or authoritative save/settlement proof.")


if __name__ == "__main__":
    main()
