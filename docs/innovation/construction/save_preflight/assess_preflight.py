#!/usr/bin/env python3
"""Classify native Construction B13 probe logs without confusing probe PASS with feature readiness."""
import json
import pathlib
import sys

def classify(log):
    lines = log.splitlines()
    def has(prefix):
        return any(line.startswith(prefix) for line in lines)
    if not has("CONSTRUCTION PREFLIGHT CHARACTERIZATION PASS:"):
        raise ValueError("missing completed native probe")
    if any(("ASSERTION FAIL:" in line or "SCRIPT ERROR:" in line or "Parse Error:" in line) for line in lines):
        raise ValueError("native probe contains errors")
    loss = has("CONSTRUCTION PREFLIGHT BLOCKER: assembled-game load/re-save DROPS construction extension")
    safe = has("CONSTRUCTION PREFLIGHT SAFE: assembled-game load/re-save preserves extension")
    rejected = has("CONSTRUCTION PREFLIGHT SAFE: unrecognized extension rejected before game load")
    receipt = has("CONSTRUCTION PREFLIGHT BLOCKER: production schema lacks construction receipt/epoch admission rules")
    receipt_safe = has("CONSTRUCTION PREFLIGHT SAFE: duplicate/future construction payload rejected")
    if sum((loss, safe, rejected)) != 1 or sum((receipt, receipt_safe)) != 1:
        raise ValueError("incomplete or contradictory native outcomes")
    return {"native_probe_completed": True, "extension_roundtrip_loss": loss,
            "receipt_epoch_admission_missing": receipt, "phase_c_ready": False,
            "reason": "catalog and authoritative transaction integration gates are not approved"}

def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: assess_preflight.py <native-log>")
    try:
        result = classify(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(json.dumps({"classification": "invalid_evidence", "reason": str(error)}, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
