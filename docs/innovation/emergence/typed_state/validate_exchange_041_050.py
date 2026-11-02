#!/usr/bin/env python3
"""E03/E08/E18: executable design-state audit, NOT a Godot gameplay implementation."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

PATH = Path(__file__).with_name("exchange_041_050.json")
SAFE_MAX = 9007199254740991
SOURCE = {
    "EB-E-041": ["offer_id", "item_quotes", "valuation_epoch", "trade_receipt"],
    "EB-E-042": ["tool_id", "borrower_id", "due_epoch", "deposit_receipt"],
    "EB-E-043": ["delivery_id", "route_stops", "quality_clock", "settlement"],
    "EB-E-044": ["seed_lot_id", "donor", "recipient", "exchange_receipt"],
    "EB-E-045": ["commission_id", "escrow", "quality_gate", "stage_receipts"],
    "EB-E-046": ["pool_id", "contributions", "loss_receipts", "payouts"],
    "EB-E-047": ["lesson_id", "teacher", "student", "slot", "skill_receipt"],
    "EB-E-048": ["contract_id", "due_epoch", "quantity", "escrow", "settlement"],
    "EB-E-049": ["item_instance", "condition", "repair_receipt", "salvage_choice"],
    "EB-E-050": ["price_series", "market_epoch", "read_cursor", "confidence"],
}


def typed(value, spec):
    if value is None:
        return spec.get("nullable") is True
    kind = spec.get("type")
    if kind == "string":
        return type(value) is str and spec["min_length"] <= len(value) <= spec["max_length"]
    if kind == "integer":
        return type(value) is int and spec["min"] <= value <= min(spec["max"], SAFE_MAX)
    if kind == "boolean":
        return type(value) is bool
    if kind == "enum":
        return type(value) is str and value in spec["values"]
    if kind == "object":
        fields = spec["fields"]
        return type(value) is dict and set(value) == set(fields) and all(
            typed(value[k], sub) for k, sub in fields.items())
    if kind == "list":
        if type(value) is not list or len(value) > spec["max_items"]:
            return False
        if not all(typed(x, spec["items"]) for x in value):
            return False
        unique = spec.get("unique_by")
        if unique:
            keys = [x if unique == "$value" else x[unique] for x in value]
            return len(keys) == len(set(keys))
        return True
    return False


def invariants(feature, s):
    n = int(feature[-3:])
    if n == 41:
        if not s["offer_id"]:
            return (not s["item_quotes"] and s["valuation_epoch"] == -1
                    and s["trade_receipt"] is None and s["settlement_epoch"] == -1)
        return (len(s["item_quotes"]) == 2 and s["valuation_epoch"] >= 1
                and all(q["source_epoch"] <= s["valuation_epoch"] for q in s["item_quotes"])
                and ((s["trade_receipt"] is None and s["settlement_epoch"] == -1)
                     or (s["trade_receipt"] is not None
                         and s["settlement_epoch"] >= s["valuation_epoch"])))
    if n == 42:
        if not s["tool_id"]:
            return (s["borrower_id"] == "" and s["due_epoch"] == -1
                    and s["checkout_epoch"] == -1 and s["deposit_receipt"] is None
                    and s["return_receipt"] is None)
        return (bool(s["borrower_id"]) and s["deposit_receipt"] is not None
                and s["checkout_epoch"] >= 1 and s["due_epoch"] >= s["checkout_epoch"]
                and s["return_receipt"] != s["deposit_receipt"])
    if n == 43:
        if not s["delivery_id"]:
            return (not s["route_stops"] and s["quality_clock"] == -1
                    and s["settlement"] is None and s["reserved_units"] == 0
                    and s["delivered_units"] == 0
                    and s["current_quality"] == s["initial_quality"])
        stops = s["route_stops"]
        return (bool(stops) and s["quality_clock"] >= 1
                and all(x["arrival_epoch"] <= s["quality_clock"] for x in stops)
                and sum(x["quantity"] for x in stops) == s["reserved_units"]
                and sum(x["quantity"] for x in stops if x["delivered"]) == s["delivered_units"]
                and s["delivered_units"] <= s["reserved_units"]
                and s["current_quality"] <= s["initial_quality"]
                and (s["settlement"] is None or
                     (all(x["delivered"] for x in stops)
                      and s["delivered_units"] == s["reserved_units"])))
    if n == 44:
        if not s["seed_lot_id"]:
            return (not s["donor"] and not s["recipient"] and s["transferred_units"] == 0
                    and s["exchange_receipt"] is None and s["debit_receipt"] is None)
        return (bool(s["donor"]) and bool(s["recipient"]) and s["donor"] != s["recipient"]
                and s["transferred_units"] > 0 and s["exchange_receipt"] is not None
                and s["debit_receipt"] is not None
                and s["exchange_receipt"] != s["debit_receipt"])
    if n == 45:
        e = s["escrow"]
        if not s["commission_id"]:
            return (not s["stage_receipts"] and all(v == 0 for v in e.values())
                    and s["quality_gate"] == "pending" and s["cancellation_receipt"] is None)
        return (e["deposited"] == e["released"] + e["refunded"] + e["reserved"]
                and e["released"] == sum(x["amount"] for x in s["stage_receipts"])
                and len({x["receipt_id"] for x in s["stage_receipts"]}) == len(s["stage_receipts"])
                and (e["released"] == 0 or s["quality_gate"] == "pass")
                and (s["cancellation_receipt"] is None
                     or (e["reserved"] == 0 and e["refunded"] > 0)))
    if n == 46:
        if not s["pool_id"]:
            return (not s["contributions"] and not s["loss_receipts"] and not s["payouts"]
                    and s["opening_balance"] == 0 and s["closing_balance"] == 0)
        losses = {x["loss_id"]: x for x in s["loss_receipts"]}
        payouts = s["payouts"]
        return (s["closing_balance"] == s["opening_balance"]
                + sum(x["units"] for x in s["contributions"])
                - sum(x["amount"] for x in payouts)
                and all(x["loss_id"] in losses and losses[x["loss_id"]]["approved"]
                        for x in payouts)
                and len({x["receipt_id"] for x in payouts}) == len(payouts))
    if n == 47:
        if not s["lesson_id"]:
            return (not s["teacher"] and not s["student"]
                    and s["slot"] is None and s["skill_receipt"] is None)
        slot = s["slot"]
        if not s["teacher"] or not s["student"] or s["teacher"] == s["student"] or slot is None:
            return False
        return (slot["start_minute"] + slot["duration"] <= 1440
                and (not slot["completed"]
                     or (slot["teacher_reserved"] and slot["student_reserved"]))
                and (s["skill_receipt"] is None
                     or (slot["completed"] and slot["teacher_reserved"]
                         and slot["student_reserved"])))
    if n == 48:
        if not s["contract_id"]:
            return (s["due_epoch"] == -1 and s["quantity"] == 0 and s["escrow"] == 0
                    and s["settlement"] == "pending" and s["reserved_units"] == 0
                    and s["delivered_units"] == 0 and s["settlement_receipt"] is None)
        return (s["due_epoch"] >= 1 and s["quantity"] > 0
                and s["delivered_units"] <= s["reserved_units"] <= s["quantity"]
                and ((s["settlement"] == "fulfilled" and
                      s["delivered_units"] == s["quantity"]
                      and s["settlement_receipt"] is not None)
                     or (s["settlement"] != "fulfilled"
                         and s["settlement_receipt"] is None
                         and (s["settlement"] != "cancelled" or s["delivered_units"] == 0))))
    if n == 49:
        if not s["item_instance"]:
            return (s["condition"] == 0 and s["repair_receipt"] is None
                    and s["salvage_receipt"] is None
                    and s["salvage_choice"] == "undecided" and not s["disposed"])
        repaired = s["repair_receipt"] is not None
        salvaged = s["salvage_receipt"] is not None
        return (not (repaired and salvaged)
                and (not repaired or (s["salvage_choice"] == "repair"
                                     and s["condition"] > 0 and not s["disposed"]))
                and (not salvaged or (s["salvage_choice"] == "salvage"
                                     and s["condition"] == 0 and s["disposed"]))
                and (not s["disposed"] or salvaged))
    if n == 50:
        entries = s["price_series"]
        if not entries:
            return (s["market_epoch"] == -1 and s["read_cursor"] == 0
                    and s["confidence"] == "unknown")
        keys = [(x["item_id"], x["epoch"]) for x in entries]
        if (len(keys) != len(set(keys)) or s["read_cursor"] > len(entries)
                or s["market_epoch"] < max(x["epoch"] for x in entries)):
            return False
        if any((x["price"] is not None and x["source_receipt"] is not None) != x["observed"]
               or ((x["price"] is None) != (x["source_receipt"] is None))
               for x in entries):
            return False
        observed = sum(x["observed"] for x in entries)
        expected = ("unknown" if observed == 0 else
                    "observed" if observed == len(entries) else "partial")
        return s["confidence"] == expected
    return False


def valid_state(contract, state):
    try:
        fields = contract["fields"]
        return (type(state) is dict and set(state) == set(fields)
                and all(typed(state[k], v) for k, v in fields.items())
                and invariants(contract["id"], state))
    except (KeyError, ValueError, TypeError, OverflowError):
        return False


def reject_constant(value):
    raise ValueError("Nonfinite JSON constant: " + value)


def load_catalog():
    with PATH.open(encoding="utf-8") as stream:
        return json.load(stream, parse_constant=reject_constant)


def validate_catalog(doc):
    assert doc["status"] == "design_only_non_authorizing"
    assert doc["phaseC"].startswith("closed_")
    assert doc["source"]["blob_sha"] == "a5def76918e77e0ded7e3e8085444698b4e0b549"
    contracts = doc["state_contracts"]
    assert len(contracts) == 10 and {x["id"] for x in contracts} == set(SOURCE)
    assert len({x["title"] for x in contracts}) == 10
    assert len({x["save_namespace"] for x in contracts}) == 10
    for c in contracts:
        assert c["phase"] == "design_only_no_runtime_implementation"
        assert c["source_fields"] == SOURCE[c["id"]]
        assert set(c["source_fields"] + c["additions"]) == set(c["fields"])
        assert len(c["rule_codes"]) == len(set(c["rule_codes"])) == 4
        assert c["state_version"] == 1
        assert len(c["positive_fixtures"]) >= 2 and len(c["negative_cases"]) >= 4
        assert all(c.get(k) for k in ("authority", "migration", "controls", "native_gate",
                                     "performance_budget", "player_verbs", "dependencies"))
        assert all(typed(copy.deepcopy(spec["default"]), spec) for spec in c["fields"].values())


def run_self_test():
    doc = load_catalog()
    validate_catalog(doc)
    positive = negative = roundtrips = 0
    for c in doc["state_contracts"]:
        for fixture in c["positive_fixtures"]:
            state = fixture["state"]
            assert valid_state(c, state), (c["id"], fixture["name"], "valid fixture rejected")
            positive += 1
            encoded = json.dumps(state, sort_keys=True, allow_nan=False)
            restored = json.loads(encoded, parse_constant=reject_constant)
            assert restored == state and valid_state(c, restored)
            roundtrips += 1
        active = next(x["state"] for x in c["positive_fixtures"] if x["name"] == "active")
        for case in c["negative_cases"]:
            hostile = copy.deepcopy(active)
            hostile.update(copy.deepcopy(case["patch"]))
            assert not valid_state(c, hostile), (c["id"], case["name"], "hostile accepted")
            negative += 1
        for key, spec in c["fields"].items():
            hostile = copy.deepcopy(active)
            hostile[key] = {"forged": True}
            assert not valid_state(c, hostile), (c["id"], key, "wrong type accepted")
            negative += 1
            if spec["type"] == "integer":
                hostile = copy.deepcopy(active)
                hostile[key] = True
                assert not valid_state(c, hostile), (c["id"], key, "boolean as integer")
                negative += 1
                hostile[key] = SAFE_MAX + 1
                assert not valid_state(c, hostile), (c["id"], key, "unsafe integer")
                negative += 1
        hostile = copy.deepcopy(active)
        hostile["forged_authority_field"] = "extra"
        assert not valid_state(c, hostile), (c["id"], "extra key")
        negative += 1
        hostile = copy.deepcopy(active)
        del hostile[next(iter(c["fields"]))]
        assert not valid_state(c, hostile), (c["id"], "missing key")
        negative += 1
    try:
        json.loads('{"counter": NaN}', parse_constant=reject_constant)
    except ValueError:
        negative += 1
    else:
        raise AssertionError("Nonfinite JSON accepted")
    print("PASS: 10 E041-E050 design contracts, %d valid fixtures, %d hostile cases rejected, "
          "%d deterministic JSON roundtrips, source blob pinned, Phase C closed."
          % (positive, negative, roundtrips))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
    else:
        doc = load_catalog()
        validate_catalog(doc)
        print("PASS: 10 design schemas structurally valid; use --self-test for hostile fixtures")


if __name__ == "__main__":
    main()
