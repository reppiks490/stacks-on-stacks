#!/usr/bin/env python3
"""E03/E05/E18: bounded biome design-state validator. NOT Godot gameplay."""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

PATH = Path(__file__).with_name("biome_021_030.json")
SAFE_MAX = 9007199254740991
SOURCE = {
    "EB-E-021": ["network_nodes", "log_receipts", "connectivity", "regrowth_epoch"],
    "EB-E-022": ["tagged_seeds", "carrier_routes", "dispersal_epoch", "germinations"],
    "EB-E-023": ["plot_ids", "shade_state", "moisture_observations", "score"],
    "EB-E-024": ["tree_id", "beetle_mix", "intervention_receipts", "season_epoch"],
    "EB-E-025": ["species_signals", "heard_cells", "diversity_index", "signal_provenance", "accessibility_mode"],
    "EB-E-026": ["crossing_id", "window_epoch", "escort_state", "detour"],
    "EB-E-027": ["patch_id", "succession_stage", "last_epoch", "observations"],
    "EB-E-028": ["garden_id", "dark_hours", "moth_visits", "credits"],
    "EB-E-029": ["sample_sites", "substrate_class", "confidence", "advice"],
    "EB-E-030": ["refuge_ids", "occupants", "season_lock", "detour_path"],
}
RULES = {
    "EB-E-021": ["node_references", "distinct_log_edges", "connectivity_count", "epoch_covers_receipts"],
    "EB-E-022": ["seed_route_refs", "seed_germination_refs", "route_epoch_covers", "germination_route_match"],
    "EB-E-023": ["shade_plot_refs", "observation_plot_refs", "comparison_requires_two_plots"],
    "EB-E-024": ["tree_required", "intervention_species_refs", "season_epoch_covers"],
    "EB-E-025": ["signal_provenance_refs", "heard_cell_refs", "diversity_unique_species"],
    "EB-E-026": ["crossing_active_requirements", "reachable_detour"],
    "EB-E-027": ["patch_history", "stage_monotonic", "stage_matches_last", "epoch_matches_last"],
    "EB-E-028": ["garden_required", "credit_visit_refs", "darkness_gate", "credit_epoch_match"],
    "EB-E-029": ["advice_site_refs", "confidence_requires_samples", "advice_requires_substrate"],
    "EB-E-030": ["occupant_refuge_refs", "protected_requires_detour", "lock_epoch_bounds"],
}
STAGES = ["dormant", "pioneer", "meadow", "shrub", "woodland"]


def typed(value, spec):
    if value is None:
        return spec.get("nullable") is True
    kind = spec.get("type")
    if kind == "string":
        return (type(value) is str and spec.get("min_length", 0) <= len(value)
                <= spec.get("max_length", -1))
    if kind == "boolean":
        return type(value) is bool
    if kind == "integer":
        return (type(value) is int and spec.get("min", 1) <= value
                <= min(spec.get("max", -1), SAFE_MAX))
    if kind == "number":
        return (type(value) in (int, float) and math.isfinite(value)
                and spec.get("min", 1) <= value <= spec.get("max", -1))
    if kind == "enum":
        return type(value) is str and value in spec.get("values", [])
    if kind == "object":
        fields = spec.get("fields", {})
        return (type(value) is dict and set(value) == set(fields)
                and all(typed(value[k], fields[k]) for k in fields))
    if kind == "list":
        if type(value) is not list or len(value) > spec.get("max_items", -1):
            return False
        item_spec = spec.get("items", {})
        if not all(typed(item, item_spec) for item in value):
            return False
        unique = spec.get("unique_by")
        if unique:
            keys = [item if unique == "$value" else item[unique] for item in value]
            return len(keys) == len(set(keys))
        return True
    return False


def valid_invariants(rid, s):
    """Domain-local projections only; no mutation of authoritative owner state."""
    if rid == "EB-E-021":
        nodes = {x["node_id"]: x for x in s["network_nodes"]}
        edges = set()
        for log in s["log_receipts"]:
            a, b = log["node_a"], log["node_b"]
            if a == b or a not in nodes or b not in nodes:
                return False
            edge = tuple(sorted((a, b)))
            if edge in edges:
                return False
            edges.add(edge)
            if log["kind"] != "removed" and (not nodes[a]["active"] or not nodes[b]["active"]):
                return False
        return (s["connectivity"] == sum(x["kind"] != "removed" for x in s["log_receipts"])
                and s["regrowth_epoch"] == (-1 if not s["log_receipts"] else
                    max(x["epoch"] for x in s["log_receipts"])))
    if rid == "EB-E-022":
        seeds = {x["seed_id"]: x for x in s["tagged_seeds"]}
        routes = {x["seed_id"]: x for x in s["carrier_routes"]}
        if any(x["seed_id"] not in seeds or x["from_cell"] != seeds[x["seed_id"]]["origin_cell"]
               for x in s["carrier_routes"]):
            return False
        if s["dispersal_epoch"] != (-1 if not routes else max(x["epoch"] for x in routes.values())):
            return False
        return all(x["seed_id"] in routes
                   and x["cell_id"] == routes[x["seed_id"]]["to_cell"]
                   and x["epoch"] >= routes[x["seed_id"]]["epoch"]
                   for x in s["germinations"])
    if rid == "EB-E-023":
        plots = set(s["plot_ids"])
        if any(x["plot_id"] not in plots for x in s["shade_state"] + s["moisture_observations"]):
            return False
        if s["score"] == 0:
            return True
        observations = s["moisture_observations"]
        return (len({x["plot_id"] for x in observations}) >= 2
                and len({x["shade_snapshot"] for x in observations}) >= 2)
    if rid == "EB-E-024":
        if (s["beetle_mix"] or s["intervention_receipts"]) and not s["tree_id"]:
            return False
        species = {x["species_id"] for x in s["beetle_mix"]}
        if any(x["species_id"] not in species for x in s["intervention_receipts"]):
            return False
        return s["season_epoch"] == (-1 if not s["intervention_receipts"] else
                                     max(x["epoch"] for x in s["intervention_receipts"]))
    if rid == "EB-E-025":
        signals = {x["signal_id"]: x for x in s["species_signals"]}
        provenance = {x["signal_id"] for x in s["signal_provenance"]}
        if any(k not in signals for k in provenance):
            return False
        if any(x["verified"] and x["signal_id"] not in provenance for x in signals.values()):
            return False
        cells = {x["cell_id"] for x in signals.values() if x["verified"]}
        if any(cell not in cells for cell in s["heard_cells"]):
            return False
        species = {x["species_id"] for x in signals.values() if x["verified"]}
        return s["diversity_index"] <= min(1.0, len(species) / 20.0) + 1e-9
    if rid == "EB-E-026":
        state = s["escort_state"]
        if state == "idle":
            return s["crossing_id"] is None and s["window_epoch"] == -1 and not s["detour"]
        if not s["crossing_id"] or s["window_epoch"] < 1:
            return False
        if state in ("scheduled", "active", "completed"):
            return any(x["reachable"] and x["owner_confirmed"] for x in s["detour"])
        return True
    if rid == "EB-E-027":
        obs = s["observations"]
        if not obs:
            return s["succession_stage"] == "dormant" and s["last_epoch"] == -1
        if not s["patch_id"]:
            return False
        prev_epoch = -1
        prev_stage = 0
        for x in obs:
            stage = STAGES.index(x["stage"])
            if x["epoch"] <= prev_epoch or stage != prev_stage + 1:
                return False
            prev_epoch, prev_stage = x["epoch"], stage
        return s["last_epoch"] == prev_epoch and s["succession_stage"] == STAGES[prev_stage]
    if rid == "EB-E-028":
        visits = {x["id"]: x for x in s["moth_visits"]}
        if (visits or s["credits"]) and not s["garden_id"]:
            return False
        if any(x["garden_id"] != s["garden_id"] for x in visits.values()):
            return False
        if s["credits"] and s["dark_hours"] < 4:
            return False
        if len({x["owner_effect_id"] for x in s["credits"]}) != len(s["credits"]):
            return False
        return all(x["visit_id"] in visits and x["epoch"] >= visits[x["visit_id"]]["epoch"]
                   for x in s["credits"])
    if rid == "EB-E-029":
        sites = {x["site_id"] for x in s["sample_sites"]}
        if any(x["site_id"] not in sites for x in s["advice"]):
            return False
        if s["advice"] and s["substrate_class"] == "unknown":
            return False
        return s["confidence"] <= min(1.0, len(sites) / 5.0) + 1e-9
    if rid == "EB-E-030":
        refuges = set(s["refuge_ids"])
        if any(x["refuge_id"] not in refuges for x in s["occupants"]):
            return False
        start, end = s["lock_start_epoch"], s["lock_end_epoch"]
        if s["season_lock"] == "open":
            return start == -1 and end == -1 and not s["occupants"]
        if start < 1 or end < start:
            return False
        if any(not start <= x["arrival_epoch"] <= end for x in s["occupants"]):
            return False
        return any(x["reachable"] and x["owner_confirmed"] for x in s["detour_path"])
    raise ValueError("unknown contract " + rid)


def validate_state(rec, state):
    """Optional missing namespace is valid; malformed present state is atomic reject."""
    if state is None:
        return True
    if type(state) is not dict or set(state) != set(rec["fields"]):
        return False
    return (all(typed(state[k], spec) for k, spec in rec["fields"].items())
            and valid_invariants(rec["id"], state))


def default_state(rec):
    return {k: copy.deepcopy(v["default"]) for k, v in rec["fields"].items()}


def validate_catalog(data):
    if data.get("schema_version") != 1 or data.get("phaseC") != "closed_pending_Principal_joint_220_approval":
        raise ValueError("phase gate or schema drift")
    if data.get("source", {}).get("blob_sha") != "a5def76918e77e0ded7e3e8085444698b4e0b549":
        raise ValueError("source provenance drift")
    records = data.get("state_contracts")
    if type(records) is not list or len(records) != 10 or [r.get("id") for r in records] != list(SOURCE):
        raise ValueError("missing, duplicate or unsorted records")
    if len({r.get("save_namespace") for r in records}) != 10:
        raise ValueError("duplicate namespace")
    field_count = rule_count = 0
    for rec in records:
        rid = rec["id"]
        additions = ["lock_start_epoch", "lock_end_epoch"] if rid == "EB-E-030" else []
        if rec.get("source_fields") != SOURCE[rid] or rec.get("additions") != additions:
            raise ValueError("source fields or additions drift " + rid)
        if list(rec.get("fields", {})) != SOURCE[rid] + additions:
            raise ValueError("missing or reordered typed fields " + rid)
        if rec.get("state_version") != (2 if additions else 1):
            raise ValueError("migration version " + rid)
        if rec.get("rule_codes") != RULES[rid] or rec.get("owner") != "Emergence":
            raise ValueError("invariant or owner drift " + rid)
        if rec.get("phase") != "design_only_no_runtime_implementation":
            raise ValueError("premature runtime status")
        if not all(rec.get(k) for k in ("migration", "negative", "authority", "receipt_contract", "controls", "native_gate")):
            raise ValueError("incomplete design contract")
        if not validate_state(rec, default_state(rec)):
            raise ValueError("invalid default state " + rid)
        field_count += len(rec["fields"])
        rule_count += len(rec["rule_codes"])
    return field_count, rule_count


def positive_fixtures(records):
    """Valid nonempty states demonstrate rules are not vacuous."""
    tests = {}
    def put(rid, **changes):
        r = records[rid]
        state = default_state(r)
        state.update(changes)
        assert validate_state(r, state), rid
        tests[rid] = state
    put("EB-E-021", network_nodes=[
        {"node_id":"n1","habitat_id":"h1","active":True},
        {"node_id":"n2","habitat_id":"h1","active":True}],
        log_receipts=[{"id":"r1","epoch":2,"log_id":"l1","node_a":"n1","node_b":"n2","kind":"restored"}],
        connectivity=1, regrowth_epoch=2)
    put("EB-E-022", tagged_seeds=[{"seed_id":"s1","species_id":"wildflower","origin_cell":"c1"}],
        carrier_routes=[{"seed_id":"s1","carrier_id":"bird1","from_cell":"c1","to_cell":"c2","epoch":55}],
        dispersal_epoch=55, germinations=[{"seed_id":"s1","cell_id":"c2","epoch":57}])
    put("EB-E-023", plot_ids=["p1","p2"],
        shade_state=[{"plot_id":"p1","shade_level":4},{"plot_id":"p2","shade_level":0}],
        moisture_observations=[
            {"observation_id":"o1","plot_id":"p1","epoch":3,"moisture_pct":60,"shade_snapshot":4},
            {"observation_id":"o2","plot_id":"p2","epoch":3,"moisture_pct":25,"shade_snapshot":0}],
        score=0.4)
    put("EB-E-024", tree_id="tree1",
        beetle_mix=[{"species_id":"b1","role":"beneficial","population":5}],
        intervention_receipts=[{"id":"t1","epoch":4,"species_id":"b1","delta":-2,"owner_effect_id":"world1"}],
        season_epoch=4)
    put("EB-E-025", species_signals=[{"signal_id":"sig1","species_id":"bird1","cell_id":"c1","verified":True}],
        heard_cells=["c1"], diversity_index=0.05,
        signal_provenance=[{"signal_id":"sig1","source":"caption","observed_epoch":10}],
        accessibility_mode="captions")
    put("EB-E-026", crossing_id="cross1", window_epoch=57, escort_state="active",
        detour=[{"path_id":"path1","reachable":True,"owner_confirmed":True}])
    put("EB-E-027", patch_id="patch1", succession_stage="meadow", last_epoch=60,
        observations=[{"receipt_id":"a1","epoch":1,"stage":"pioneer"},
                      {"receipt_id":"a2","epoch":60,"stage":"meadow"}])
    put("EB-E-028", garden_id="garden1", dark_hours=5,
        moth_visits=[{"id":"v1","epoch":11,"garden_id":"garden1","moth_id":"m1"}],
        credits=[{"id":"credit1","epoch":11,"visit_id":"v1","owner_effect_id":"farm1"}])
    put("EB-E-029", sample_sites=[{"site_id":"s1","cell_id":"river1","epoch":12}],
        substrate_class="pebble", confidence=0.2,
        advice=[{"site_id":"s1","nursery_prediction":"high","epoch":12}])
    put("EB-E-030", refuge_ids=["r1"], season_lock="winter",
        occupants=[{"animal_id":"fox1","refuge_id":"r1","arrival_epoch":101}],
        detour_path=[{"path_id":"p1","reachable":True,"owner_confirmed":True}],
        lock_start_epoch=100,lock_end_epoch=113)
    return tests


def negative_tests(data):
    cases = 0
    def reject_state(rec, state):
        nonlocal cases
        if validate_state(rec, state):
            raise AssertionError("invalid state accepted: " + rec["id"])
        cases += 1
    def reject_catalog(bad):
        nonlocal cases
        try:
            validate_catalog(bad)
        except (ValueError, TypeError, KeyError):
            cases += 1
            return
        raise AssertionError("invalid catalog accepted")
    by_id = {r["id"]: r for r in data["state_contracts"]}
    for kind in ("phase", "source", "id", "version", "fields", "rules", "owner"):
        bad = copy.deepcopy(data)
        first = bad["state_contracts"][0]
        if kind == "phase": bad["phaseC"] = "open"
        if kind == "source": bad["source"]["blob_sha"] = "forged"
        if kind == "id": first["id"] = "EB-E-999"
        if kind == "version": first["state_version"] = 4
        if kind == "fields": first["fields"].pop("connectivity")
        if kind == "rules": first["rule_codes"] = ["accept_anything"]
        if kind == "owner": first["owner"] = "Principal"
        reject_catalog(bad)
    fixtures = positive_fixtures(by_id)
    for rec in data["state_contracts"]:
        valid = default_state(rec)
        assert validate_state(rec, valid)
        assert validate_state(rec, None)
        reject_state(rec, [])
        reject_state(rec, {})
        reject_state(rec, {**valid, "unapproved": 1})
        for field, spec in rec["fields"].items():
            bad = copy.deepcopy(valid)
            bad[field] = {"bad": "nested object"}
            reject_state(rec, bad)
            bad = copy.deepcopy(valid)
            bad.pop(field)
            reject_state(rec, bad)
            if spec["type"] == "integer":
                bad = copy.deepcopy(valid)
                bad[field] = True
                reject_state(rec, bad)
            if spec["type"] == "number":
                bad = copy.deepcopy(valid)
                bad[field] = float("nan")
                reject_state(rec, bad)
            if spec["type"] == "list":
                bad = copy.deepcopy(valid)
                bad[field] = [None]
                reject_state(rec, bad)
                bad = copy.deepcopy(valid)
                bad[field] = [copy.deepcopy(spec["items"].get("default", {}))] * (spec["max_items"] + 1)
                reject_state(rec, bad)
    for rid, fixture in fixtures.items():
        rec = by_id[rid]
        bad = copy.deepcopy(fixture)
        if rid == "EB-E-021": bad["connectivity"] = 2
        elif rid == "EB-E-022": bad["germinations"][0]["cell_id"] = "wrong"
        elif rid == "EB-E-023": bad["moisture_observations"][1]["plot_id"] = "p1"
        elif rid == "EB-E-024": bad["intervention_receipts"][0]["species_id"] = "missing"
        elif rid == "EB-E-025": bad["diversity_index"] = 1.0
        elif rid == "EB-E-026": bad["detour"][0]["owner_confirmed"] = False
        elif rid == "EB-E-027": bad["observations"][1]["stage"] = "woodland"
        elif rid == "EB-E-028": bad["credits"].append({**bad["credits"][0], "id":"credit2","owner_effect_id":"farm2"})
        elif rid == "EB-E-029": bad["advice"][0]["site_id"] = "missing"
        elif rid == "EB-E-030": bad["lock_end_epoch"] = 100
        reject_state(rec, bad)
    # More domain-specific conservation, replay and rollover adversarial checks.
    def change(rid, field, value):
        rec = by_id[rid]
        state = copy.deepcopy(fixtures[rid])
        state[field] = value
        reject_state(rec, state)
    change("EB-E-021", "regrowth_epoch", 1)
    change("EB-E-022", "dispersal_epoch", 54)
    change("EB-E-024", "tree_id", None)
    change("EB-E-025", "heard_cells", ["unknown"])
    change("EB-E-026", "window_epoch", -1)
    change("EB-E-027", "last_epoch", 59)
    change("EB-E-028", "dark_hours", 0)
    change("EB-E-029", "substrate_class", "unknown")
    change("EB-E-030", "season_lock", "open")
    return cases, len(fixtures)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()
    data = json.loads(PATH.read_text(encoding="utf-8"))
    fields, rules = validate_catalog(data)
    print("BIOME DESIGN AUDIT: %d contracts, %d bounded top-level fields, %d cross-field invariants"
          % (len(data["state_contracts"]), fields, rules))
    if args.self_test:
        invalid, valid = negative_tests(data)
        print("BIOME DESIGN AUDIT: %d invalid cases rejected, %d nonempty positive fixtures, 0 harness failures"
              % (invalid, valid))
    print("DESIGN ONLY PASS; no native Godot gameplay, real-device measurements or Phase-C authorization")


if __name__ == "__main__":
    main()
