#!/usr/bin/env python3
"""E03/E07/E18: strict offline social-design state contracts, NOT playable Godot."""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

PATH = Path(__file__).with_name("social_031_040.json")
SAFE_MAX = 9007199254740991
SOURCE = {
    "EB-E-031": ["draft_id", "recipient_consent", "revision", "delivery_receipt"],
    "EB-E-032": ["claim_id", "witness_links", "confidence", "privacy_flags"],
    "EB-E-033": ["heirloom_id", "owner_id", "consent", "display_receipt"],
    "EB-E-034": ["recipe_id", "contributors", "consents", "recipe_revision"],
    "EB-E-035": ["npc_id", "preferred_gestures", "last_contact_epoch", "consent"],
    "EB-E-036": ["favor_id", "visibility_consent", "map_pin", "reciprocity_receipt"],
    "EB-E-037": ["reunion_id", "invitees", "slot_reservations", "travel_eta"],
    "EB-E-038": ["dispute_id", "statements", "proposal", "party_consents"],
    "EB-E-039": ["mentor_id", "learner_id", "lesson_steps", "skill_receipts"],
    "EB-E-040": ["circle_id", "participants", "story_versions", "visibility"],
}
RULE_COUNTS = {rid: 4 for rid in SOURCE}


def typed(value, spec):
    if value is None:
        return spec.get("nullable") is True
    kind = spec.get("type")
    if kind == "string":
        return type(value) is str and spec.get("min_length", 0) <= len(value) <= spec.get("max_length", -1)
    if kind == "boolean":
        return type(value) is bool
    if kind == "integer":
        return type(value) is int and spec.get("min", 1) <= value <= min(spec.get("max", -1), SAFE_MAX)
    if kind == "number":
        return type(value) in (int, float) and math.isfinite(value) and spec.get("min", 1) <= value <= spec.get("max", -1)
    if kind == "enum":
        return type(value) is str and value in spec.get("values", [])
    if kind == "object":
        fields = spec.get("fields", {})
        return type(value) is dict and set(value) == set(fields) and all(typed(value[k], v) for k, v in fields.items())
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


def invariants(rid, s):
    if rid == "EB-E-031":
        receipt = s["delivery_receipt"]
        return (bool(s["draft_id"]) or (s["revision"] == 0 and receipt is None)
                ) and ((receipt is None and s["delivery_epoch"] == -1)
                       or (receipt is not None and s["recipient_consent"] == "granted"
                           and s["revision"] > 0 and s["delivery_epoch"] >= 1))
    if rid == "EB-E-032":
        links = s["witness_links"]
        ids = {x["witness_id"] for x in links}
        verified = [x for x in links if x["verified"]]
        return (set(s["privacy_flags"]) <= ids
                and all(x["consent"] and x["evidence"] == "firsthand" for x in verified)
                and 0 <= s["confidence"] <= min(100, 40 * len(verified))
                and (bool(s["claim_id"]) or (not links and not s["privacy_flags"] and s["confidence"] == 0)))
    if rid == "EB-E-033":
        receipt = s["display_receipt"]
        return (bool(s["heirloom_id"]) == bool(s["owner_id"])
                and ((receipt is None and s["display_epoch"] == -1)
                     or (receipt is not None and s["consent"] == "public"
                         and bool(s["owner_id"]) and s["display_epoch"] >= 1)))
    if rid == "EB-E-034":
        contributors = s["contributors"]
        approvals = s["consents"]
        rev = s["recipe_revision"]
        if not s["recipe_id"]:
            return not contributors and not approvals and rev == 0 and s["publication_receipt"] is None
        if len(contributors) != 2 or rev < 1 or any(x["contributor_id"] not in contributors for x in approvals):
            return False
        return s["publication_receipt"] is None or (len(approvals) == 2 and
            {x["contributor_id"] for x in approvals} == set(contributors)
            and all(x["approved"] and x["revision"] == rev for x in approvals))
    if rid == "EB-E-035":
        receipts = s["contact_receipts"]
        if not s["npc_id"]:
            return not receipts and not s["preferred_gestures"] and s["last_contact_epoch"] == -1
        epochs = [x["epoch"] for x in receipts]
        return ((not receipts or (s["consent"] and s["last_contact_epoch"] >= max(epochs)))
                and len(epochs) == len(set(epochs))
                and all(x["gesture"] in s["preferred_gestures"] for x in receipts))
    if rid == "EB-E-036":
        pin = s["map_pin"]
        return ((pin is None or bool(s["favor_id"]))
                and (pin is None or not pin["visible"] or s["visibility_consent"] == "public")
                and (s["reciprocity_receipt"] is None or (s["source_receipt"] is not None and bool(s["favor_id"])))
                and (s["source_receipt"] is None or bool(s["favor_id"])))
    if rid == "EB-E-037":
        invitees = {x["npc_id"]: x for x in s["invitees"]}
        slots = s["slot_reservations"]
        return ((bool(s["reunion_id"]) or (not invitees and not slots and s["travel_eta"] == 0))
                and all(x["npc_id"] in invitees and invitees[x["npc_id"]]["consent"]
                        and x["minute"] >= max(s["travel_eta"], invitees[x["npc_id"]]["travel_minutes"])
                        for x in slots)
                and len({(x["npc_id"], x["epoch"]) for x in slots}) == len(slots))
    if rid == "EB-E-038":
        statements = s["statements"]
        consents = s["party_consents"]
        if not s["dispute_id"]:
            return not statements and not consents and s["proposal"] == "none" and s["settlement_receipt"] is None
        if {x["npc_id"] for x in statements} != {x["npc_id"] for x in consents}:
            return False
        return s["settlement_receipt"] is None or (s["proposal"] == "compromise"
            and len(statements) == 2 and len(consents) == 2
            and all(x["approved"] for x in consents))
    if rid == "EB-E-039":
        steps = s["lesson_steps"]
        receipts = s["skill_receipts"]
        if not s["mentor_id"] or not s["learner_id"]:
            return not steps and not receipts and not s["mentor_id"] and not s["learner_id"]
        if s["mentor_id"] == s["learner_id"]:
            return False
        by_id = {x["step_id"]: x for x in steps}
        seen_incomplete = False
        for step in steps:
            if step["completed"] and (seen_incomplete or step["completed_epoch"] < 1):
                return False
            if not step["completed"] and step["completed_epoch"] != -1:
                return False
            seen_incomplete = seen_incomplete or not step["completed"]
        return (len({x["step_id"] for x in receipts}) == len(receipts)
                and all(x["step_id"] in by_id and by_id[x["step_id"]]["completed"]
                        and x["epoch"] >= by_id[x["step_id"]]["completed_epoch"] for x in receipts))
    if rid == "EB-E-040":
        people = {x["npc_id"]: x for x in s["participants"]}
        stories = s["story_versions"]
        if not s["circle_id"]:
            return not people and not stories and not s["published_story_ids"] and s["visibility"] == "private"
        groups = {}
        for entry in stories:
            if entry["author_id"] not in people:
                return False
            groups.setdefault(entry["story_id"], []).append(entry)
        latest = {}
        for story_id, versions in groups.items():
            if len({x["author_id"] for x in versions}) != 1:
                return False
            nums = sorted(x["version"] for x in versions)
            if nums != list(range(1, len(nums) + 1)):
                return False
            latest[story_id] = max(versions, key=lambda x: x["version"])
        return (s["visibility"] == "public" or not s["published_story_ids"]) and all(
            sid in latest and latest[sid]["visibility"] == "public"
            and people[latest[sid]["author_id"]]["consent"]
            for sid in s["published_story_ids"])
    return False


def valid_state(contract, state):
    try:
        fields = contract["fields"]
        return (type(state) is dict and set(state) == set(fields)
                and all(typed(state[k], v) for k, v in fields.items())
                and invariants(contract["id"], state))
    except (KeyError, TypeError, ValueError, OverflowError):
        return False


def load_catalog():
    def reject_constant(value):
        raise ValueError("non-finite JSON token: " + value)
    with PATH.open(encoding="utf-8") as f:
        return json.load(f, parse_constant=reject_constant)


def validate_catalog(doc):
    assert doc["status"] == "design_only_non_authorizing"
    assert doc["phaseC"].startswith("closed_")
    assert doc["source"]["blob_sha"] == "a5def76918e77e0ded7e3e8085444698b4e0b549"
    contracts = doc["state_contracts"]
    assert len(contracts) == len(SOURCE) == 10
    assert {x["id"] for x in contracts} == set(SOURCE)
    assert len({x["title"] for x in contracts}) == 10
    assert len({x["save_namespace"] for x in contracts}) == 10
    for c in contracts:
        assert c["phase"] == "design_only_no_runtime_implementation"
        assert c["source_fields"] == SOURCE[c["id"]]
        assert set(c["source_fields"] + c["additions"]) == set(c["fields"])
        assert len(c["rule_codes"]) == RULE_COUNTS[c["id"]]
        assert len(set(c["rule_codes"])) == RULE_COUNTS[c["id"]]
        assert c["state_version"] == 1
        assert all(c.get(k) for k in ("authority", "migration", "negative", "controls",
                                    "performance_budget", "native_gate", "player_verbs", "dependencies"))
        assert all(typed(copy.deepcopy(spec["default"]), spec) for spec in c["fields"].values())


def inactive(c):
    return {k: copy.deepcopy(v["default"]) for k, v in c["fields"].items()}


def active(c):
    s = inactive(c)
    n = int(c["id"][-3:])
    if n == 31:
        s.update(draft_id="draft1", recipient_consent="granted", revision=1, delivery_receipt="r1", delivery_epoch=57)
    elif n == 32:
        s.update(claim_id="claim1", witness_links=[dict(witness_id="w1", evidence="firsthand", consent=True, verified=True)], confidence=40)
    elif n == 33:
        s.update(heirloom_id="h1", owner_id="n1", consent="public", display_receipt="r1", display_epoch=57)
    elif n == 34:
        s.update(recipe_id="recipe1", contributors=["a", "b"], consents=[
            dict(contributor_id="a", revision=1, approved=True),
            dict(contributor_id="b", revision=1, approved=True)], recipe_revision=1, publication_receipt="r1")
    elif n == 35:
        s.update(npc_id="n1", preferred_gestures=["nod"], last_contact_epoch=57, consent=True,
                 contact_receipts=[dict(receipt_id="r1", epoch=57, gesture="nod")])
    elif n == 36:
        s.update(favor_id="f1", visibility_consent="public", map_pin=dict(cell_id="cell1", visible=True),
                 reciprocity_receipt="r1", source_receipt="s1")
    elif n == 37:
        s.update(reunion_id="reunion1", invitees=[dict(npc_id="n1", consent=True, travel_minutes=10)],
                 slot_reservations=[dict(npc_id="n1", epoch=57, minute=100)], travel_eta=20)
    elif n == 38:
        s.update(dispute_id="d1", statements=[dict(npc_id="a", text="I disagree"), dict(npc_id="b", text="Let's talk")],
                 proposal="compromise", party_consents=[dict(npc_id="a", approved=True),
                 dict(npc_id="b", approved=True)], settlement_receipt="r1")
    elif n == 39:
        s.update(mentor_id="m1", learner_id="l1", lesson_steps=[
            dict(step_id="s1", completed=True, completed_epoch=56),
            dict(step_id="s2", completed=False, completed_epoch=-1)],
                 skill_receipts=[dict(step_id="s1", receipt_id="r1", epoch=57)])
    elif n == 40:
        s.update(circle_id="c1", participants=[dict(npc_id="n1", consent=True)],
                 story_versions=[dict(story_id="story1", author_id="n1", version=1, visibility="public")],
                 visibility="public", published_story_ids=["story1"])
    return s


def hostile(c, state):
    n = int(c["id"][-3:])
    def mutate(key, value):
        s = copy.deepcopy(state)
        s[key] = value
        return s
    if n == 31:
        return [mutate("recipient_consent", "denied"), mutate("delivery_epoch", -1)]
    if n == 32:
        x = copy.deepcopy(state); x["witness_links"][0]["evidence"] = "hearsay"
        return [x, mutate("privacy_flags", ["ghost"]), mutate("confidence", 100)]
    if n == 33:
        return [mutate("consent", "withdrawn"), mutate("owner_id", "")]
    if n == 34:
        x = copy.deepcopy(state); x["consents"][0]["approved"] = False
        y = copy.deepcopy(state); y["consents"][0]["revision"] = 0
        return [x, y]
    if n == 35:
        x = copy.deepcopy(state); x["contact_receipts"].append(dict(receipt_id="r2", epoch=57, gesture="nod"))
        return [x, mutate("consent", False)]
    if n == 36:
        return [mutate("visibility_consent", "withdrawn"), mutate("source_receipt", None)]
    if n == 37:
        x = copy.deepcopy(state); x["invitees"][0]["consent"] = False
        return [x, mutate("travel_eta", 101)]
    if n == 38:
        x = copy.deepcopy(state); x["party_consents"][0]["approved"] = False
        y = copy.deepcopy(state); y["party_consents"][0]["npc_id"] = "ghost"
        return [x, y]
    if n == 39:
        x = copy.deepcopy(state); x["lesson_steps"][1].update(completed=True, completed_epoch=57)
        x["lesson_steps"][0].update(completed=False, completed_epoch=-1)
        y = copy.deepcopy(state); y["skill_receipts"].append(dict(step_id="s1", receipt_id="r2", epoch=57))
        return [x, y]
    if n == 40:
        x = copy.deepcopy(state); x["story_versions"][0]["visibility"] = "retracted"
        y = copy.deepcopy(state); y["participants"][0]["consent"] = False
        return [x, y]
    raise AssertionError("unknown feature")


def self_test(doc):
    validate_catalog(doc)
    positives = 0
    rejected = 0
    for c in doc["state_contracts"]:
        for state in (inactive(c), active(c)):
            assert valid_state(c, state), ("valid fixture rejected", c["id"], state)
            positives += 1
        for state in hostile(c, active(c)):
            assert not valid_state(c, state), ("hostile fixture admitted", c["id"], state)
            rejected += 1
        state = active(c)
        for bad in (
            dict(state, unexpected="ghost"),
            {k: v for k, v in state.items() if k != next(iter(state))},
        ):
            assert not valid_state(c, bad), ("unknown/missing field admitted", c["id"])
            rejected += 1
        for key, spec in c["fields"].items():
            bad = copy.deepcopy(state)
            kind = spec["type"]
            bad[key] = {"string": 42, "boolean": "yes", "integer": True,
                        "number": float("nan"), "enum": "INVALID", "list": {},
                        "object": []}[kind]
            assert not valid_state(c, bad), ("invalid type admitted", c["id"], key)
            rejected += 1
            if kind == "list":
                bad = copy.deepcopy(state)
                bad[key] = [copy.deepcopy(spec["items"]["default"])] * (spec["max_items"] + 1) if "default" in spec["items"] else [None] * (spec["max_items"] + 1)
                assert not valid_state(c, bad), ("unbounded list admitted", c["id"], key)
                rejected += 1
    print("SOCIAL DESIGN CONTRACT PASS: %d contracts; %d valid; %d rejected; %d bounded fields; %d rules" %
          (len(doc["state_contracts"]), positives, rejected,
           sum(len(c["fields"]) for c in doc["state_contracts"]),
           sum(len(c["rule_codes"]) for c in doc["state_contracts"])))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    doc = load_catalog()
    validate_catalog(doc)
    if args.self_test:
        self_test(doc)
    else:
        print("SOCIAL DESIGN CONTRACT SCHEMA PASS: 10 design-only specifications")


if __name__ == "__main__":
    main()
