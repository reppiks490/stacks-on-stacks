#!/usr/bin/env python3
"""Non-authoritative, deterministic Construction namespace migration dry-run.

This tool NEVER reads or writes Godot saves, inventory, currency, or gameplay.
It validates an isolated namespace->JSON-state map and rejects unsafe aliases,
epochs, and duplicate receipts. Principal must approve policy before integration.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
MAX_EPOCH = 9007199254740991
SHA = re.compile(r"^[0-9a-f]{40}$")
FEATURE = re.compile(r"^EB-B-([0-9]{3})$")


class PolicyError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise PolicyError(message)


def exact_int(value: object) -> bool:
    return type(value) is int


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\\0" + data).hexdigest()


def verify_policy(doc: dict, source_bytes: bytes | None = None) -> list[dict]:
    require(isinstance(doc, dict), "policy must be object")
    require(doc.get("schema_version") == 1, "schema version")
    require(doc.get("status") == "PROPOSED_NOT_APPROVED_NOT_GAMEPLAY", "unsafe authority status")
    require(doc.get("phase_c") == "CLOSED", "Phase C gate")
    source = doc.get("source", {})
    require(source.get("commit") == "d73fc5641552ab192e57ed7327e815c3370d0181", "source commit")
    require(SHA.fullmatch(source.get("blob_sha", "")) is not None, "source blob SHA")
    require(source.get("path") == "docs/innovation/construction/typed100_crossaudit/SOURCE_EVIDENCE.json", "source path")
    rows = doc.get("entries", [])
    require(isinstance(rows, list) and len(rows) == 100, "exactly 100 entries")
    seen_ids, seen_ns, seen_aliases = set(), set(), set()
    aliases = sentinels = 0
    for row in rows:
        require(isinstance(row, dict), "entry object")
        ident = row.get("id", "")
        m = FEATURE.fullmatch(ident)
        require(m is not None and 11 <= int(m.group(1)) <= 110, "invalid feature ID")
        require(ident not in seen_ids, "duplicate feature ID")
        seen_ids.add(ident)
        canonical = "construction." + ident.lower().replace("-", "_")
        require(row.get("namespace") == canonical, "canonical namespace drift")
        require(canonical not in seen_ns, "duplicate namespace")
        seen_ns.add(canonical)
        alias = row.get("legacy_alias")
        if alias is not None:
            require(isinstance(alias, str) and alias.startswith("construction.eb_b_"), "invalid alias")
            require(alias not in seen_aliases and alias != canonical, "alias collision")
            require(31 <= int(m.group(1)) <= 40, "unexpected alias outside civic tranche")
            seen_aliases.add(alias)
            aliases += 1
        require(row.get("epoch_min") in (-1, 0), "epoch lower bound")
        if row["epoch_min"] == -1:
            sentinels += 1
        require(row.get("sentinel_policy") == ("inert_only_no_receipts" if row["epoch_min"] == -1 else "not_allowed"), "sentinel rule")
        require(row.get("receipt_policy") == "global_unique_nonempty", "receipt authority")
    require(seen_ids == {f"EB-B-{i:03d}" for i in range(11, 111)}, "missing feature")
    require(not (seen_ns & seen_aliases), "alias shadows canonical")
    require(aliases == 10 and sentinels == 60, "unexpected source distribution")
    require(doc.get("policy", {}).get("legacy_aliases") == 10, "alias count")
    require(doc.get("policy", {}).get("negative_epoch_sentinels") == 60, "sentinel count")
    if source_bytes is not None:
        require(git_blob_sha(source_bytes) == source["blob_sha"], "pinned source bytes differ")
        evidence = json.loads(source_bytes)
        require(evidence.get("phase_c") == "CLOSED", "source phase gate")
        records = evidence.get("records", [])
        require(len(records) == 100, "source record count")
        by_id = {r["id"]: r for r in records}
        require(len(by_id) == 100, "source duplicate IDs")
        for row in rows:
            old = by_id.get(row["id"])
            require(old is not None, "missing source ID")
            require(row["namespace"] == old["canonical_namespace"], "source canonical drift")
            require((row["legacy_alias"] or row["namespace"]) == old["namespace"], "source alias drift")
            require(row["epoch_min"] == old["day_epoch_min"], "source epoch drift")
            require(old["receipt_field_present"] is True, "source receipt missing")
    return rows


def year_of(epoch: int) -> int:
    require(exact_int(epoch) and 1 <= epoch <= MAX_EPOCH, "active day_epoch required")
    return (epoch - 1) // 56 + 1


def dry_run(rows: list[dict], namespace_states: dict, current_epoch: int) -> dict:
    """Return a detached, lossless proposal; reject all malformed known states.

    Unknown namespaces are preserved, not interpreted. This is NOT a full typed
    schema validator, and cannot authorize actual resource settlements.
    """
    require(exact_int(current_epoch) and 1 <= current_epoch <= MAX_EPOCH, "current epoch")
    require(isinstance(namespace_states, dict), "namespace state map")
    require(all(isinstance(k, str) for k in namespace_states), "namespace keys")
    try:
        result = json.loads(json.dumps(namespace_states, allow_nan=False, sort_keys=True))
    except (TypeError, ValueError, OverflowError) as exc:
        raise PolicyError("non-JSON state") from exc
    global_receipts: set[str] = set()
    for row in rows:
        canonical, alias = row["namespace"], row["legacy_alias"]
        has_canonical = canonical in result
        has_alias = alias is not None and alias in result
        require(not (has_canonical and has_alias), "ambiguous legacy and canonical state")
        if not (has_canonical or has_alias):
            continue
        key = alias if has_alias else canonical
        state = result[key]
        require(isinstance(state, dict), "known feature state must be object")
        revision = state.get("revision")
        epoch = state.get("day_epoch")
        receipts = state.get("receipts")
        require(exact_int(revision) and 0 <= revision <= 100000000, "revision invalid")
        require(exact_int(epoch) and row["epoch_min"] <= epoch <= current_epoch, "epoch invalid/future")
        require(isinstance(receipts, list) and len(receipts) <= 128, "receipts invalid")
        for receipt in receipts:
            require(isinstance(receipt, str) and 1 <= len(receipt) <= 96, "receipt format")
            require(receipt not in global_receipts, "duplicate global receipt")
            global_receipts.add(receipt)
        if epoch < 1:
            require(revision == 0 and not receipts, "uninitialized epoch cannot have actions")
        else:
            require(year_of(epoch) <= year_of(current_epoch), "future year")
        if has_alias:
            result[canonical] = result.pop(alias)
    return result


def self_test(rows: list[dict]) -> int:
    passed = 0
    def good(value: dict, epoch: int = 113) -> dict:
        nonlocal passed
        original = copy.deepcopy(value)
        migrated = dry_run(rows, value, epoch)
        require(value == original, "input mutated")
        require(dry_run(rows, migrated, epoch) == migrated, "non-idempotent")
        require(json.loads(json.dumps(migrated, sort_keys=True)) == migrated, "roundtrip")
        passed += 1
        return migrated

    def bad(value: dict, epoch: int = 113) -> None:
        nonlocal passed
        original = copy.deepcopy(value)
        try:
            dry_run(rows, value, epoch)
        except PolicyError:
            require(value == original, "rejected input mutated")
            passed += 1
            return
        raise PolicyError("unsafe mutation accepted")

    for i, row in enumerate(rows):
        ns = row["namespace"]
        state = {"revision": 1, "day_epoch": 57, "receipts": [f"r-{i}"], "nested": {"keep": [1, {"x": True}]}}
        result = good({ns: state})
        require(result[ns]["nested"] == state["nested"], "nested state lost")
        bad({ns: {**state, "receipts": ["dup", "dup"]}})
        bad({ns: {**state, "day_epoch": 114}})
        bad({ns: {**state, "day_epoch": True}})
        bad({ns: {**state, "receipts": [5]}})
        bad({ns: {**state, "revision": -1}})
        if row["epoch_min"] == -1:
            good({ns: {"revision": 0, "day_epoch": -1, "receipts": []}})
            bad({ns: {"revision": 1, "day_epoch": -1, "receipts": ["used"]}})
        else:
            bad({ns: {"revision": 0, "day_epoch": -1, "receipts": []}})
        if row["legacy_alias"]:
            alias = row["legacy_alias"]
            converted = good({alias: state})
            require(ns in converted and alias not in converted, "alias not canonicalized")
            bad({alias: state, ns: state})
    a, b = rows[0]["namespace"], rows[1]["namespace"]
    bad({a: {"revision": 1, "day_epoch": 56, "receipts": ["same"]},
         b: {"revision": 1, "day_epoch": 57, "receipts": ["same"]}})
    good({"unrecognized.future_namespace": {"untouched": [3, 2, 1]}})
    for epoch, expected in ((1, 1), (56, 1), (57, 2), (112, 2), (113, 3)):
        require(year_of(epoch) == expected, "56-day year boundary")
        passed += 1
    for invalid in (0, -1, True, 1.2):
        try:
            year_of(invalid)
        except PolicyError:
            passed += 1
        else:
            raise PolicyError("invalid active epoch accepted")
    return passed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, help="pinned SOURCE_EVIDENCE.json; required for source-backed CI")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    doc = json.loads((HERE / "POLICY.json").read_text(encoding="utf-8"))
    source = args.source.read_bytes() if args.source else None
    rows = verify_policy(doc, source)
    print(f"PASS: 100 Construction policies; 10 aliases; 60 negative epoch sentinels; source bytes verified={source is not None}")
    if args.self_test:
        count = self_test(rows)
        print(f"PASS: {count}/{count} deterministic positive/negative dry-run checks")
    print("Phase C CLOSED; no Godot gameplay, actual save migration, inventory authority, or physical device verification.")


if __name__ == "__main__":
    main()
