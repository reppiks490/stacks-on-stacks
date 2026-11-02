#!/usr/bin/env python3
"""Read-only E18 audit: verify 12 pinned Git blobs and compare 100 typed projections.
Design-only evidence. No Godot feature is implemented or authorized by this audit.
"""
import argparse
import copy
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = "reppiks490/stacks-on-stacks"
TYPED_DIR = "docs/innovation/emergence/typed_state/"
CAT_DIR = "docs/innovation/emergence/"
CAT_COMMIT = "63cab5d05c742c61205933482e38fac2a4086764"
EXPECTED_SOURCES = [
    (TYPED_DIR+"causal_011_020.json", "7ef7647b60cf9c264285a43f229b195163d8ccbf", "15551c9b3c77908fae4913152ccf69faa8278dbf"),
    (TYPED_DIR+"biome_021_030.json", "05a5b246737a2ff218d8db68037d6d404075b893", "8915044854ab883b7d3707a452fee0d4a2dea68d"),
    (TYPED_DIR+"social_031_040.json", "bebc3c277d6785f3591ed11614b06fd9661f592f", "9f3c0c42d822abcae78b7352136e99d8fd93aace"),
    (TYPED_DIR+"exchange_041_050.json", "bcd8c7125b970e28896e74bf41163e3597f96930", "a90cbb314ab05ca1e73557ca520da1906fb27ef7"),
    (TYPED_DIR+"navigation_051_060.json", "442415bef69799810e6d897ed035abfed73adae8", "c41f2573fb45b184ca18ee07579ca818476b070a"),
    (TYPED_DIR+"companion_061_070.json", "b8e909f873545025e1f915d22680d69f44fac1b7", "4533e827721e07af292451a4e23b64cb51728ffb"),
    (TYPED_DIR+"ritual_071_080.json", "a96fe9d4a6946448e8c6e3f3053f7edb8086a023", "08915f5fe7f13068cfb2067aee9e8a7d50bd2577"),
    (TYPED_DIR+"creative_081_090.json", "534d8c9e2ab21c20eec65e250c767bcf3832c41d", "bb30e8f705a1e43d652eb003c35265006dbdd316"),
    (TYPED_DIR+"sky_091_100.json", "babf6ad96eca680db9edd2d61ff7c4686783c7e8", "714d63bb6d0bafb96cd32cfcaac8212e04249aa2"),
    (TYPED_DIR+"cooperation_101_110.json", "215dfe72ca96380b54f8724ceb743dcdb1dc2eb3", "ca52226d63bf1b20dbb7893dac671edaaa6bfafd"),
    (CAT_DIR+"phaseB_011_050.json", CAT_COMMIT, "a5def76918e77e0ded7e3e8085444698b4e0b549"),
    (CAT_DIR+"phaseB_051_110.json", CAT_COMMIT, "eb7c590f43c92ded0e328ecfdf7003fa7c06ceac"),
]
EXPECTED_META = [{"path": p, "commit": c, "blob_sha": s} for p, c, s in EXPECTED_SOURCES]
EXPECTED_IDS = ["EB-E-%03d" % n for n in range(11, 111)]
FLAG_NAMES = {
    "missing_verbs", "missing_dependencies", "missing_assets", "missing_budget",
    "missing_explicit_receipt_contract", "missing_embedded_fixtures",
    "unpadded_legacy_namespace", "source_contamination",
}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def fetch_pinned(path, commit, expected_sha, source_dir):
    if source_dir:
        data = (source_dir / path).read_bytes()
    else:
        url = "https://raw.githubusercontent.com/%s/%s/%s" % (REPO, commit, path)
        request = urllib.request.Request(url, headers={"User-Agent": "Everbloom-E18-SourceAudit/1"})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read()
    require(len(data) < 4_000_000, "oversized pinned source: " + path)
    blob = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()
    require(blob == expected_sha, "Git blob SHA mismatch: " + path)
    return json.loads(data.decode("utf-8"))

def project(source_documents):
    catalog = {}
    for path, _, _ in EXPECTED_SOURCES[10:]:
        doc = source_documents[path]
        for concept in doc["concepts"]:
            require(concept["id"] not in catalog, "duplicate catalog ID")
            catalog[concept["id"]] = concept
    require(len(catalog) == 100, "expected 100 original Phase-B concepts")
    require(sorted(catalog) == EXPECTED_IDS, "original catalog ID gap")

    records = []
    for path, _, _ in EXPECTED_SOURCES[:10]:
        doc = source_documents[path]
        contracts = doc.get("state_contracts", doc.get("contracts"))
        require(isinstance(contracts, list) and len(contracts) == 10, "tranche not 10: " + path)
        for item in contracts:
            feature_id = item["id"]
            require(feature_id in catalog, "typed ID not in source: " + feature_id)
            source = catalog[feature_id]
            require(item["title"] == source["title"], "typed title drift: " + feature_id)
            require(item["source_fields"] == source["state_schema"]["fields"], "source-field drift: " + feature_id)
            fields = item["fields"]
            keys = sorted(fields)
            mapping = {key: item.get("source_field_mapping", {}).get(key, key)
                       for key in item["source_fields"]}
            require(all(key in fields for key in mapping.values()), "unmapped source field: " + feature_id)
            controls = item.get("controls", item.get("input_contract", {}))
            for mode in ("keyboard_mouse", "controller", "touch"):
                require(isinstance(controls.get(mode), str) and controls[mode].strip(),
                        "missing platform control: " + feature_id + "/" + mode)
            flags = []
            if not item.get("player_verbs"):
                flags.append("missing_verbs")
            if not item.get("dependencies"):
                flags.append("missing_dependencies")
            if not (item.get("original_asset_plan") or item.get("asset_plan")):
                flags.append("missing_assets")
            if not (item.get("performance_budget") or item.get("performance")):
                flags.append("missing_budget")
            if not item.get("receipt_contract"):
                flags.append("missing_explicit_receipt_contract")
            if not (item.get("fixtures") or item.get("positive_fixtures") or item.get("valid_state")):
                flags.append("missing_embedded_fixtures")
            if re.fullmatch(r"emergence\.eb_e_\d{2}", item["save_namespace"]):
                flags.append("unpadded_legacy_namespace")
            typed_negative = str(item.get("negative_case") or item.get("negative")
                                 or item.get("acceptance", {}).get("adversarial") or "")
            if feature_id == "EB-E-102" and "eclipse" in typed_negative.lower():
                flags.append("source_contamination")
            no_unique = sorted(
                name for name, spec in fields.items()
                if re.search(r"receipt|ledger|claim", name, re.I)
                and (spec.get("type") or spec.get("kind")) in ("list", "array")
                and not spec.get("unique_by")
            )
            sentinels = sorted(
                name for name, spec in fields.items()
                if (spec.get("type") or spec.get("kind")) == "integer"
                and spec.get("min", spec.get("minimum")) == -1
            )
            records.append({
                "id": feature_id,
                "title": item["title"],
                "source_fields": item["source_fields"],
                "source_field_mapping": mapping,
                "field_keys": keys,
                "save_namespace": item["save_namespace"],
                "flags": sorted(flags),
                "receipt_arrays_without_declarative_unique_by": no_unique,
                "top_level_negative_epoch_sentinels": sentinels,
                "source_negative_acceptance": source.get("acceptance", {}).get("adversarial", ""),
                "typed_negative_acceptance": typed_negative,
            })
    records.sort(key=lambda row: row["id"])
    require([r["id"] for r in records] == EXPECTED_IDS, "typed ID missing, duplicate or out of range")
    require(len({r["title"].casefold().strip() for r in records}) == 100, "typed title collision")
    counts = {}
    for record in records:
        for flag in record["flags"]:
            require(flag in FLAG_NAMES, "unknown flag")
            counts[flag] = counts.get(flag, 0) + 1
    return records, counts

def validate(evidence, records, counts):
    require(evidence["schema_version"] == 1, "schema version drift")
    require(evidence["project"] == "EVERBLOOM: The Living Valley", "project drift")
    require(evidence["owner"] == "Emergence E03/E18", "owner drift")
    require(evidence["phase_c"] == "CLOSED", "phase gate unauthorized")
    require(evidence["status"] == "SOURCE_DERIVED_DESIGN_AUDIT_NOT_GAMEPLAY_PROOF", "playability claim drift")
    require(evidence["canonical_main_at_claim"] == "e90fe68d070fdc141129ebbe1da6bbcd72cd2bc8", "base main drift")
    require(evidence["source_files"] == EXPECTED_META, "pinned source metadata drift")
    require(evidence["record_count"] == 100, "record count drift")
    require(evidence["flag_counts"] == counts, "flag counts drift")
    require(evidence["records"] == records, "source-derived record projection drift")
    e102 = next(r for r in records if r["id"] == "EB-E-102")
    require("eclipse" in e102["source_negative_acceptance"].lower()
            and "eclipse" in e102["typed_negative_acceptance"].lower(),
            "E102 contamination not tracked; review source correction and regenerate audit")
    return True

def mutation_test(evidence, records, counts):
    cases = [
        "schema", "project", "owner", "phase", "status", "base", "source_path",
        "source_commit", "source_blob", "source_drop", "source_duplicate",
        "count", "flag_count", "record_drop", "record_duplicate", "record_reverse",
        "id", "title", "source_fields", "mapping", "field_keys", "namespace",
        "flags", "receipt_array", "sentinel", "source_negative", "typed_negative",
    ]
    passed = 0
    for case in cases:
        m = copy.deepcopy(evidence)
        row = m["records"][0]
        if case == "schema": m["schema_version"] = 2
        elif case == "project": m["project"] = "OTHER"
        elif case == "owner": m["owner"] = "Construction"
        elif case == "phase": m["phase_c"] = "OPEN"
        elif case == "status": m["status"] = "PLAYABLE"
        elif case == "base": m["canonical_main_at_claim"] = "0"*40
        elif case == "source_path": m["source_files"][0]["path"] += ".bak"
        elif case == "source_commit": m["source_files"][0]["commit"] = "0"*40
        elif case == "source_blob": m["source_files"][0]["blob_sha"] = "0"*40
        elif case == "source_drop": m["source_files"].pop()
        elif case == "source_duplicate": m["source_files"].append(copy.deepcopy(m["source_files"][0]))
        elif case == "count": m["record_count"] = 99
        elif case == "flag_count": m["flag_counts"]["missing_assets"] = 999
        elif case == "record_drop": m["records"].pop()
        elif case == "record_duplicate": m["records"].append(copy.deepcopy(row))
        elif case == "record_reverse": m["records"].reverse()
        elif case == "id": row["id"] = "EB-E-999"
        elif case == "title": row["title"] += " forged"
        elif case == "source_fields": row["source_fields"].append("invented")
        elif case == "mapping": row["source_field_mapping"]["forecast_id"] = "invented"
        elif case == "field_keys": row["field_keys"].append("phantom")
        elif case == "namespace": row["save_namespace"] = "principal.money"
        elif case == "flags": row["flags"].append("source_contamination")
        elif case == "receipt_array": row["receipt_arrays_without_declarative_unique_by"].append("fake")
        elif case == "sentinel": row["top_level_negative_epoch_sentinels"].append("fake")
        elif case == "source_negative": row["source_negative_acceptance"] += " changed"
        elif case == "typed_negative": row["typed_negative_acceptance"] += " changed"
        try:
            validate(m, records, counts)
        except (ValueError, KeyError, TypeError):
            passed += 1
        else:
            raise AssertionError("hostile mutation accepted: " + case)
    return passed, len(cases)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, help="optional local root containing all 12 pinned source files")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    evidence = json.loads((HERE / "SOURCE_EVIDENCE.json").read_text(encoding="utf-8"))
    sources = {path: fetch_pinned(path, commit, sha, args.source_dir)
               for path, commit, sha in EXPECTED_SOURCES}
    records, counts = project(sources)
    validate(evidence, records, counts)
    print("PINNED_GIT_BLOBS_VERIFIED=%d" % len(sources))
    print("EMERGENCE_TYPED_CONTRACTS=%d" % len(records))
    print("SOURCE_FIELD_MAPPINGS=100/100")
    print("DECLARATIVE_RECEIPT_ARRAYS_WITHOUT_UNIQUE_BY=%d" %
          sum(len(r["receipt_arrays_without_declarative_unique_by"]) for r in records))
    print("CONTRACTS_WITH_TOP_LEVEL_NEGATIVE_EPOCH_SENTINEL=%d" %
          sum(bool(r["top_level_negative_epoch_sentinels"]) for r in records))
    print("SPECIFICATION_FLAGS=%s" % json.dumps(counts, sort_keys=True))
    print("E102_SOURCE_AND_TYPED_ECLIPSE_CONTAMINATION=CONFIRMED_OPEN")
    print("PHASE_C=CLOSED; GAMEPLAY_IMPLEMENTATION_PROOF=NONE")
    if args.self_test:
        passed, total = mutation_test(evidence, records, counts)
        print("ADVERSARIAL_PROJECTION_MUTATIONS_REJECTED=%d/%d" % (passed, total))

if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as error:
        print("E18_AUDIT_FAIL: %s" % error, file=sys.stderr)
        sys.exit(1)
