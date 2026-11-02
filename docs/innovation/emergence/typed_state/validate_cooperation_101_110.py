#!/usr/bin/env python3
"""Strict Phase-B E101–E110 cooperation state contracts; NOT playable Godot features.

Run: python docs/innovation/emergence/typed_state/validate_cooperation_101_110.py --self-test
Only design fixtures, schema checks, and seeded hostile-state tests are proven here.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import random

PATH = Path(__file__).with_name("cooperation_101_110.json")


def named(value):
    return type(value) is str and bool(value.strip())


def unique(values):
    return len(values) == len(set(values))


def typed(value, spec):
    if value is None:
        return spec.get("nullable", False) is True
    kind = spec["kind"]
    if kind == "string":
        return type(value) is str and len(value) <= spec["max_length"]
    if kind == "integer":
        return type(value) is int and spec["minimum"] <= value <= spec["maximum"]
    if kind == "boolean":
        return type(value) is bool
    if kind == "enum":
        return type(value) is str and value in spec["values"]
    if kind == "array":
        return (type(value) is list and len(value) <= spec["max_items"]
                and all(typed(item, spec["items"]) for item in value))
    if kind == "object":
        return (type(value) is dict and set(value) == set(spec["properties"])
                and all(typed(value[k], child)
                        for k, child in spec["properties"].items()))
    raise ValueError("unknown schema kind")


def domain(number, s):
    day = s["day_epoch"]
    if number == 101:
        q, releases = s["queue"], s["release_receipts"]
        if not s["tool_id"]:
            return not q and not releases and s["slot_epoch"] == -1
        if not (1 <= s["slot_epoch"] <= day
                and unique([b["booking_id"] for b in q])
                and all(named(b["booking_id"]) and named(b["actor_id"])
                        and b["start_epoch"] <= b["end_epoch"] for b in q)
                and unique([r["receipt_id"] for r in releases])
                and unique([r["booking_id"] for r in releases])):
            return False
        for i, a in enumerate(q):
            if a["status"] == "cancelled":
                continue
            for b in q[i + 1:]:
                if b["status"] != "cancelled" and max(
                        a["start_epoch"], b["start_epoch"]) <= min(
                        a["end_epoch"], b["end_epoch"]):
                    return False
        bookings = {b["booking_id"]: b for b in q}
        return all(named(r["receipt_id"]) and r["day_epoch"] <= day
                   and r["booking_id"] in bookings
                   and bookings[r["booking_id"]]["status"] == "cancelled"
                   for r in releases)
    if number == 102:
        volunteers, cells, found = s["volunteers"], s["cells"], s["find_receipt"]
        if not s["search_id"]:
            return not volunteers and not cells and found is None
        people = {v["npc_id"]: v for v in volunteers}
        if not (unique([v["npc_id"] for v in volunteers])
                and unique([c["cell_id"] for c in cells])
                and unique([c["assigned_npc_id"] for c in cells])
                and all(named(v["npc_id"]) for v in volunteers)
                and all(named(c["cell_id"]) and c["assigned_npc_id"] in people
                        and people[c["assigned_npc_id"]]["consent"]
                        and people[c["assigned_npc_id"]]["available"] for c in cells)):
            return False
        return found is None or (
            named(found["receipt_id"]) and found["verified"]
            and found["day_epoch"] <= day
            and any(c["cell_id"] == found["cell_id"]
                    and c["status"] == "found" for c in cells))
    if number == 103:
        requests, slots, receipts = (s["requests"], s["volunteer_slots"],
                                    s["care_receipts"])
        if not s["resident_id"]:
            return not requests and not slots and not receipts
        rmap = {r["request_id"]: r for r in requests}
        smap = {v["slot_id"]: v for v in slots}
        if not (unique([r["request_id"] for r in requests])
                and unique([v["slot_id"] for v in slots])
                and unique([(v["npc_id"], v["epoch"]) for v in slots])
                and unique([r["receipt_id"] for r in receipts])
                and unique([r["request_id"] for r in receipts])
                and all(named(r["request_id"]) and
                        (r["consent"] or r["status"] == "declined")
                        for r in requests)
                and all(named(v["slot_id"]) and named(v["npc_id"])
                        and v["consent"] and v["epoch"] <= day
                        and v["request_id"] in rmap
                        and rmap[v["request_id"]]["consent"] for v in slots)):
            return False
        return all(named(r["receipt_id"]) and r["slot_id"] in smap
                   and r["request_id"] in rmap
                   and smap[r["slot_id"]]["request_id"] == r["request_id"]
                   and rmap[r["request_id"]]["status"] == "completed"
                   and smap[r["slot_id"]]["epoch"] <= r["day_epoch"] <= day
                   for r in receipts)
    if number == 104:
        completion = s["completion"]
        if not s["puzzle_id"]:
            return (not s["partner_id"] and s["hint_level"] == 0
                    and completion == {"receipt_id": "", "completed": False,
                                       "day_epoch": -1, "method": "none"})
        if completion["completed"]:
            return (named(completion["receipt_id"])
                    and 1 <= completion["day_epoch"] <= day
                    and completion["method"] != "none")
        return (completion["receipt_id"] == ""
                and completion["day_epoch"] == -1
                and completion["method"] == "none")
    if number == 105:
        bids, jobs, wages = s["bids"], s["assignments"], s["compensation"]
        if not s["job_id"]:
            return not bids and not jobs and not wages
        bmap = {b["bid_id"]: b for b in bids}
        if not (unique([b["bid_id"] for b in bids])
                and unique([j["assignment_id"] for j in jobs])
                and unique([w["assignment_id"] for w in wages])
                and all(named(b["bid_id"]) and named(b["npc_id"])
                        and named(b["skill_id"]) for b in bids)
                and all(named(j["assignment_id"]) and j["bid_id"] in bmap
                        and bmap[j["bid_id"]]["consent"]
                        and bmap[j["bid_id"]]["npc_id"] == j["npc_id"]
                        and j["start_epoch"] <= j["end_epoch"] for j in jobs)):
            return False
        for i, a in enumerate(jobs):
            for b in jobs[i + 1:]:
                if a["npc_id"] == b["npc_id"] and max(
                        a["start_epoch"], b["start_epoch"]) <= min(
                        a["end_epoch"], b["end_epoch"]):
                    return False
        assignments = {j["assignment_id"] for j in jobs}
        return (unique([w["receipt_id"] for w in wages if w["paid"]])
                and all(w["assignment_id"] in assignments and
                        ((w["paid"] and w["units"] > 0 and named(w["receipt_id"]))
                         or (not w["paid"] and w["units"] == 0
                             and not w["receipt_id"])) for w in wages))
    if number == 106:
        slots, consents, completed = (s["slots"], s["volunteer_consents"],
                                      s["completion"])
        if not s["rota_id"]:
            return not slots and not consents and not completed
        cmap = {c["npc_id"]: c for c in consents}
        smap = {v["slot_id"]: v for v in slots}
        if not (unique([v["slot_id"] for v in slots])
                and unique([(v["npc_id"], v["epoch"]) for v in slots])
                and unique([c["npc_id"] for c in consents])
                and unique([r["slot_id"] for r in completed])
                and unique([r["receipt_id"] for r in completed])
                and all(named(v["slot_id"]) and named(v["npc_id"])
                        and v["npc_id"] in cmap and cmap[v["npc_id"]]["consent"]
                        and v["epoch"] <= cmap[v["npc_id"]]["valid_until_epoch"]
                        for v in slots)):
            return False
        completed_slots = {r["slot_id"] for r in completed}
        return (all((v["status"] == "completed") ==
                    (v["slot_id"] in completed_slots) for v in slots)
                and all(named(r["receipt_id"]) and r["slot_id"] in smap
                        and smap[r["slot_id"]]["epoch"] <= r["day_epoch"] <= day
                        for r in completed))
    if number == 107:
        edges, acks, exp = s["relay_graph"], s["acknowledgments"], s["expiry"]
        if not s["alert_id"]:
            return not edges and not acks and exp == {
                "created_epoch": -1, "expires_epoch": -1, "delivered_ids": []}
        if not (1 <= exp["created_epoch"] <= day
                and exp["created_epoch"] <= exp["expires_epoch"]
                <= exp["created_epoch"] + 3
                and unique([(e["source_id"], e["target_id"]) for e in edges])
                and unique(exp["delivered_ids"])
                and unique([a["npc_id"] for a in acks])
                and unique([a["receipt_id"] for a in acks])
                and all(named(e["source_id"]) and named(e["target_id"])
                        and e["source_id"] != e["target_id"] for e in edges)
                and all(named(i) for i in exp["delivered_ids"])):
            return False
        return all(named(a["npc_id"]) and named(a["receipt_id"])
                   and a["npc_id"] in exp["delivered_ids"] for a in acks)
    if number == 108:
        people, places, rests = (s["participants"], s["waypoints"],
                                 s["rest_ledger"])
        if not s["trip_id"]:
            return not people and not places and not rests
        pmap = {p["npc_id"]: p for p in people}
        wmap = {w["waypoint_id"]: w for w in places}
        if not (bool(people) and bool(places)
                and unique([p["npc_id"] for p in people])
                and unique([w["waypoint_id"] for w in places])
                and unique([r["receipt_id"] for r in rests])
                and unique([(r["npc_id"], r["waypoint_id"], r["day_epoch"])
                            for r in rests])
                and all(named(p["npc_id"]) and p["consent"]
                        and p["position_id"] in wmap
                        and wmap[p["position_id"]]["reachable"] for p in people)
                and all(named(w["waypoint_id"]) for w in places)):
            return False
        return all(named(r["receipt_id"]) and r["npc_id"] in pmap
                   and r["waypoint_id"] in wmap
                   and wmap[r["waypoint_id"]]["reachable"]
                   and wmap[r["waypoint_id"]]["rest_available"]
                   and r["day_epoch"] <= day for r in rests)
    if number == 109:
        pair, lessons, consent, progress = (s["mentor_pair"], s["lesson_plan"],
                                            s["consent"], s["progress"])
        if not pair["mentor_id"] and not pair["learner_id"]:
            return not lessons and not progress and consent == {
                "mentor": False, "learner": False, "epoch": -1}
        if not (named(pair["mentor_id"]) and named(pair["learner_id"])
                and pair["mentor_id"] != pair["learner_id"]
                and consent["mentor"] and consent["learner"]
                and 1 <= consent["epoch"] <= day
                and unique([l["lesson_id"] for l in lessons])
                and unique([p["lesson_id"] for p in progress])
                and unique([p["receipt_id"] for p in progress])
                and all(named(l["lesson_id"]) and named(l["skill_id"])
                        and consent["epoch"] <= l["epoch"] for l in lessons)):
            return False
        lmap = {l["lesson_id"]: l for l in lessons}
        return (sum(p["units"] for p in progress) <= 10
                and all(named(p["receipt_id"]) and p["lesson_id"] in lmap
                        and lmap[p["lesson_id"]]["epoch"] <= p["day_epoch"] <= day
                        for p in progress))
    if number == 110:
        votes, decision = s["votes"], s["decision_receipt"]
        if not s["proposal_id"]:
            return s["revision"] == 0 and not votes and decision is None
        if not (s["revision"] >= 1
                and unique([v["npc_id"] for v in votes])
                and unique([v["receipt_id"] for v in votes])
                and all(named(v["npc_id"]) and named(v["receipt_id"])
                        and v["consent"]
                        and v["proposal_revision"] == s["revision"]
                        for v in votes)):
            return False
        return decision is None or (
            len(votes) >= 2 and named(decision["receipt_id"])
            and decision["receipt_id"] not in {v["receipt_id"] for v in votes}
            and decision["proposal_revision"] == s["revision"]
            and decision["day_epoch"] <= day)
    raise ValueError("unknown cooperative feature")


def valid(contract, state):
    if not typed(state, {"kind": "object", "properties": contract["fields"]}):
        return False
    receipts = state["command_receipts"]
    if state["revision"] < len(receipts):
        return False
    if not unique([r["command_id"] for r in receipts]):
        return False
    if any(not named(r["command_id"]) or not named(r["effect_digest"])
           or r["day_epoch"] > state["day_epoch"]
           or r["expected_revision"] >= state["revision"] for r in receipts):
        return False
    if any(a["expected_revision"] >= b["expected_revision"]
           for a, b in zip(receipts, receipts[1:])):
        return False
    return domain(int(contract["id"][-3:]), state)


def bad_type(spec):
    kind = spec["kind"]
    return {"string": 7, "integer": "invalid", "boolean": 1,
            "enum": 7, "array": {}, "object": []}[kind]


def change(state, path, value):
    candidate = copy.deepcopy(state)
    node = candidate
    for key in path[:-1]:
        node = node[key]
    node[path[-1]] = value
    return candidate


def leaf_paths(value, spec, prefix=()):
    kind = spec["kind"]
    if kind == "object":
        for key, child in spec["properties"].items():
            yield from leaf_paths(value[key], child, prefix + (key,))
    elif kind == "array":
        for i, item in enumerate(value):
            yield from leaf_paths(item, spec["items"], prefix + (i,))
        yield prefix, spec
    else:
        yield prefix, spec


def domain_mutations(number, s):
    c = lambda path, value: change(s, path, value)
    if number == 101:
        return [c(("queue", 1, "status"), "reserved"),
                c(("queue", 1, "booking_id"), "booking-a"),
                c(("release_receipts", 0, "booking_id"), "unknown"),
                c(("slot_epoch",), 58)]
    if number == 102:
        return [c(("volunteers", 0, "consent"), False),
                c(("cells", 1, "cell_id"), "cell-a"),
                c(("cells", 1, "assigned_npc_id"), "npc-a"),
                c(("find_receipt", "cell_id"), "cell-b"),
                c(("volunteers", 1, "available"), False)]
    if number == 103:
        return [c(("requests", 0, "consent"), False),
                c(("requests", 1, "request_id"), "request-a"),
                c(("care_receipts", 0, "slot_id"), "unknown"),
                c(("volunteer_slots", 0, "epoch"), 58),
                c(("care_receipts", 0, "day_epoch"), 56)]
    if number == 104:
        return [c(("completion", "completed"), False),
                c(("completion", "method"), "none"),
                c(("completion", "day_epoch"), 58),
                c(("puzzle_id",), "")]
    if number == 105:
        return [c(("assignments", 1, "npc_id"), "npc-a"),
                c(("bids", 1, "bid_id"), "bid-a"),
                c(("compensation", 0, "receipt_id"), ""),
                c(("compensation", 0, "paid"), False),
                c(("assignments", 0, "end_epoch"), 56)]
    if number == 106:
        return [c(("slots", 1), {**s["slots"][1], "npc_id": "npc-a", "epoch": 57}),
                c(("slots", 1, "slot_id"), "slot-a"),
                c(("completion", 0, "slot_id"), "slot-b"),
                c(("volunteer_consents", 0, "consent"), False),
                c(("completion", 0, "day_epoch"), 56)]
    if number == 107:
        return [c(("relay_graph", 0, "target_id"), "tower"),
                c(("relay_graph", 1, "source_id"), "npc-b"),
                c(("acknowledgments", 0, "npc_id"), "stranger"),
                c(("expiry", "expires_epoch"), 56),
                c(("expiry", "delivered_ids"), ["npc-a", "npc-a"])]
    if number == 108:
        return [c(("participants", 0, "position_id"), "void"),
                c(("waypoints", 0, "reachable"), False),
                c(("rest_ledger", 0, "waypoint_id"), "ridge"),
                c(("rest_ledger", 0, "npc_id"), "stranger"),
                c(("participants", 0, "consent"), False)]
    if number == 109:
        return [c(("mentor_pair", "learner_id"), "npc-a"),
                c(("consent", "mentor"), False),
                c(("lesson_plan", 0, "epoch"), 56),
                c(("progress", 0, "day_epoch"), 56),
                c(("progress", 0, "receipt_id"), "")]
    if number == 110:
        return [c(("votes", 1, "npc_id"), "npc-a"),
                c(("votes", 1, "consent"), False),
                c(("votes", 1, "proposal_revision"), 2),
                c(("decision_receipt", "proposal_revision"), 2),
                c(("decision_receipt", "receipt_id"), "vote-a")]
    raise ValueError("unknown mutation target")


def self_test():
    document = json.loads(PATH.read_text(encoding="utf-8"))
    contracts = document["contracts"]
    expected = [f"EB-E-{i:03d}" for i in range(101, 111)]
    assert document["count"] == len(contracts) == 10
    assert [c["id"] for c in contracts] == expected
    assert document["phase"].endswith("CLOSED")
    assert all(c["status"] == "design_only_not_playable"
               and c["source_blob_sha"] == document["source_blob_sha"]
               and set(c["source_fields"]) <= set(c["fields"])
               and c["save_namespace"] == "emergence.cooperation." + c["id"][-3:]
               and c["controls"]["touch"] and c["controls"]["controller"]
               and c["original_asset_plan"] and c["performance_budget"]
               and c["acceptance"]["adversarial"] for c in contracts)
    assert (2 - 1) * 56 + 0 * 14 + 1 == 57
    assert (3 - 1) * 56 + 0 * 14 + 1 == 113

    accepted = rejected = roundtrips = rollover = 0
    domain_negative = typed_negative = fuzz_negative = 0
    rng = random.Random(20261102)
    for contract in contracts:
        number = int(contract["id"][-3:])
        for label in ("empty", "active"):
            state = contract["fixtures"][label]
            assert valid(contract, state), (number, label)
            accepted += 1
            encoded = json.dumps(state, sort_keys=True, separators=(",", ":"))
            assert json.loads(encoded) == state
            assert hashlib.sha256(encoded.encode()).hexdigest() == hashlib.sha256(
                json.dumps(json.loads(encoded), sort_keys=True,
                           separators=(",", ":")).encode()).hexdigest()
            roundtrips += 1
        state = contract["fixtures"]["active"]
        future = copy.deepcopy(state)
        future["day_epoch"] = 113
        assert valid(contract, future), ("year-three persistence", number)
        rollover += 1

        candidates = []
        candidates += domain_mutations(number, state)
        domain_negative += len(candidates)
        for key, spec in contract["fields"].items():
            candidates.append(change(state, (key,), bad_type(spec)))
            typed_negative += 1
        for path, spec in leaf_paths(state, {"kind": "object",
                                             "properties": contract["fields"]}):
            if path:
                candidates.append(change(state, path, bad_type(spec)))
                typed_negative += 1
        candidates.append({**state, "unrecognized_authority": 1})
        missing = copy.deepcopy(state)
        del missing["revision"]
        candidates.append(missing)
        candidates.append(change(state, ("day_epoch",), 0))
        candidates.append(change(state, ("command_receipts", 0, "day_epoch"), 114))
        candidates.append(change(state, ("command_receipts", 0, "expected_revision"), 1))
        duplicate = copy.deepcopy(state)
        duplicate["command_receipts"].append(copy.deepcopy(
            duplicate["command_receipts"][0]))
        candidates.append(duplicate)
        for candidate in candidates:
            assert not valid(contract, candidate), (
                "accepted invalid mutation", number, candidate)
            rejected += 1

        paths = list(leaf_paths(state, {"kind": "object",
                                        "properties": contract["fields"]}))
        for _ in range(32):
            path, spec = rng.choice(paths)
            mutation = change(state, path, bad_type(spec))
            assert not valid(contract, mutation), ("fuzz mutation accepted", number, path)
            fuzz_negative += 1

    print("COOPERATION_PHASE_B_ONLY=TRUE")
    print("COOPERATION_CONTRACTS=10")
    print(f"COOPERATION_VALID_FIXTURES={accepted}")
    print(f"COOPERATION_JSON_ROUNDTRIPS={roundtrips}")
    print(f"COOPERATION_YEAR_ROLLOVERS={rollover}")
    print(f"COOPERATION_DOMAIN_NEGATIVE={domain_negative}")
    print(f"COOPERATION_TYPED_NEGATIVE={typed_negative}")
    print(f"COOPERATION_ADVERSARIAL_REJECTED={rejected}")
    print(f"COOPERATION_SEEDED_FUZZ_REJECTED={fuzz_negative}")
    print("COOPERATION_RESULT=PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true", required=True)
    parser.parse_args()
    self_test()
