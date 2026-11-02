#!/usr/bin/env python3
"""E081-E090 DESIGN-ONLY typed-state and adversarial contract verification."""
import argparse
import copy
import json
import pathlib
import random

PATH = pathlib.Path(__file__).with_name("creative_081_090.json")


def typed(value, spec):
    kind = spec["kind"]
    if value is None:
        return bool(spec.get("nullable"))
    if kind == "boolean":
        return type(value) is bool
    if kind == "integer":
        return type(value) is int and spec["minimum"] <= value <= spec["maximum"]
    if kind == "string":
        return type(value) is str and len(value) <= spec["max_length"]
    if kind == "array":
        return (type(value) is list and len(value) <= spec["max_items"]
                and all(typed(item, spec["items"]) for item in value))
    if kind == "object":
        return (type(value) is dict and set(value) == set(spec["properties"])
                and all(typed(value[k], v) for k, v in spec["properties"].items()))
    return False


def distinct(items):
    return len(items) == len(set(items))


def nonempty(x):
    return type(x) is str and bool(x.strip())


def domain(n, s):
    if n == 81:
        batch = s["ink_batch"]
        pages = s["journal_pages"]
        ingredients = s["ingredient_receipts"]
        author = s["authorship"]
        if batch is None:
            return not pages and not ingredients and author == {
                "owner_id": "", "public": False, "consent": False}
        if not (nonempty(batch["batch_id"]) and nonempty(batch["owner_id"])
                and batch["units"] > 0 and 0 <= batch["spent"] <= batch["units"]
                and author["owner_id"] == batch["owner_id"]
                and (not author["public"] or author["consent"])):
            return False
        return (distinct([x["receipt_id"] for x in ingredients])
                and distinct([x["page_id"] for x in pages])
                and all(nonempty(x["receipt_id"]) and x["batch_id"] == batch["batch_id"]
                        and x["units"] > 0 for x in ingredients)
                and sum(x["units"] for x in ingredients) == batch["units"]
                and all(nonempty(x["page_id"]) and nonempty(x["content_digest"])
                        and x["batch_id"] == batch["batch_id"]
                        and x["owner_id"] == author["owner_id"]
                        and x["ink_units"] > 0 for x in pages)
                and sum(x["ink_units"] for x in pages) == batch["spent"])
    if n == 82:
        u = s["pigment_units"]
        p = s["gesture_path"]
        if not s["edition_id"]:
            return s["pattern_seed"] == 0 and not p and u == {
                "reserved": 0, "consumed": 0, "refunded": 0}
        return (s["pattern_seed"] > 0 and len(p) >= 2
                and all(0 <= x["x"] <= 1000 and 0 <= x["y"] <= 1000
                        and x["tick"] >= 0 for x in p)
                and all(a["tick"] < b["tick"] for a, b in zip(p, p[1:]))
                and u["reserved"] > 0 and u["consumed"] > 0
                and u["refunded"] == 0 and u["reserved"] == u["consumed"])
    if n == 83:
        recipe, receipt, color = s["glaze_recipe"], s["firing_receipt"], s["color_result"]
        if not s["vessel_id"]:
            return recipe == {"recipe_id": "", "pigment_units": 0} and receipt is None and color == {
                "color_id": "", "edition_id": ""}
        return (nonempty(recipe["recipe_id"]) and recipe["pigment_units"] > 0
                and receipt is not None and nonempty(receipt["receipt_id"])
                and receipt["vessel_id"] == s["vessel_id"]
                and receipt["recipe_id"] == recipe["recipe_id"]
                and receipt["consumed_units"] == recipe["pigment_units"]
                and nonempty(color["color_id"]) and nonempty(color["edition_id"]))
    if n == 84:
        notes = s["note_sequence"]
        return (40 <= s["tempo"] <= 200
                and (bool(s["chime_id"]) == bool(notes))
                and len(notes) <= 16
                and all(0 <= x["pitch"] <= 12 and 0 <= x["beat"] <= 64 for x in notes)
                and all(a["beat"] < b["beat"] for a, b in zip(notes, notes[1:])))
    if n == 85:
        p, h = s["book_page"], s["habitat_rule"]
        if not s["specimen_id"]:
            return s["collection_epoch"] == -1 and p == {
                "page_id": "", "specimen_id": "", "collection_receipt": ""} and not h["protected"]
        return (s["collection_epoch"] >= 1 and s["collection_epoch"] <= s["day_epoch"]
                and not h["protected"] and nonempty(p["page_id"])
                and p["specimen_id"] == s["specimen_id"]
                and nonempty(p["collection_receipt"]))
    if n == 86:
        ing, f, c = s["ingredient_units"], s["formula"], s["consent"]
        if not s["blend_id"]:
            return not ing and f == {"recipe_id": "", "total_units": 0} and c == {
                "owner_id": "", "public": False, "npc_id": "", "npc_allowed": False}
        return (nonempty(c["owner_id"]) and nonempty(f["recipe_id"])
                and f["total_units"] > 0
                and distinct([x["receipt_id"] for x in ing])
                and all(nonempty(x["receipt_id"]) and nonempty(x["item_id"])
                        and x["units"] > 0 for x in ing)
                and sum(x["units"] for x in ing) == f["total_units"]
                and (not c["npc_id"] or c["npc_allowed"])
                and (not c["npc_allowed"] or bool(c["npc_id"])))
    if n == 87:
        ids, frames, stage, receipt = (s["puppet_ids"], s["keyframes"],
                                       s["stage_slot"], s["performance_receipt"])
        if not ids:
            return not frames and stage == {
                "slot_id": "", "cleared": False, "performer_consents": []} and receipt is None
        return (distinct(ids) and all(nonempty(x) for x in ids)
                and bool(frames) and all(x["puppet_id"] in ids and
                0 <= x["tick"] <= 10000 and 0 <= x["pose"] <= 64 for x in frames)
                and distinct([(x["puppet_id"], x["tick"]) for x in frames])
                and (receipt is None or (nonempty(receipt["receipt_id"])
                     and receipt["reward_units"] >= 0 and receipt["charged_viewers"] == 0
                     and stage["cleared"] and nonempty(stage["slot_id"])
                     and bool(stage["performer_consents"])
                     and all(nonempty(x) for x in stage["performer_consents"]))))
    if n == 88:
        ing, layout = s["ingredient_receipts"], s["layout"]
        if not s["dish_id"]:
            return not ing and not layout and s["judging_score"] == 0
        return (bool(ing) and bool(layout) and 0 <= s["judging_score"] <= 100
                and distinct([x["receipt_id"] for x in ing])
                and all(nonempty(x["receipt_id"]) and nonempty(x["item_id"])
                        and x["units"] > 0 for x in ing)
                and all(x["item_id"] in {i["item_id"] for i in ing}
                        and 0 <= x["x"] <= 100 and 0 <= x["y"] <= 100 for x in layout)
                and len(layout) <= sum(x["units"] for x in ing))
    if n == 89:
        ing, notes, layout = s["material_receipts"], s["biome_notes"], s["layout"]
        if not s["diorama_id"]:
            return not ing and not layout and notes == {
                "observation_ids": [], "content_digest": ""}
        return (bool(ing) and bool(layout) and nonempty(notes["content_digest"])
                and distinct(notes["observation_ids"])
                and all(nonempty(x) for x in notes["observation_ids"])
                and distinct([x["receipt_id"] for x in ing])
                and all(nonempty(x["receipt_id"]) and nonempty(x["item_id"])
                        and x["units"] > 0 for x in ing)
                and all(x["part_id"] in {i["item_id"] for i in ing}
                        and 0 <= x["x"] <= 100 and 0 <= x["y"] <= 100 for x in layout)
                and len(layout) <= sum(x["units"] for x in ing))
    if n == 90:
        receipt = s["repair_receipt"]
        if not s["instrument_id"]:
            return s["durability"] == 0 and receipt is None and not s["session_id"]
        return (0 <= s["durability"] <= 100
                and (receipt is None or (nonempty(receipt["receipt_id"])
                     and receipt["spent_units"] > 0
                     and 0 < receipt["restored_points"] <= 100
                     and s["durability"] >= receipt["restored_points"])))
    return False


def validate(feature, state):
    if type(state) is not dict or set(state) != set(feature["fields"]):
        return False
    if not all(typed(state[k], spec) for k, spec in feature["fields"].items()):
        return False
    if state["revision"] < 0:
        return False
    if state["day_epoch"] == -1:
        if state["revision"] != 0 or state["command_receipts"]:
            return False
    elif state["day_epoch"] < 1:
        return False
    receipts = state["command_receipts"]
    if not distinct([r["command_id"] for r in receipts]):
        return False
    if not all(nonempty(r["command_id"]) and nonempty(r["effect_digest"])
               and r["expected_revision"] < state["revision"]
               and 1 <= r["day_epoch"] <= state["day_epoch"] for r in receipts):
        return False
    if len(receipts) > state["revision"]:
        return False
    return domain(int(feature["id"][-3:]), state)


def mutate(feature, state):
    """Deterministic hostile corpus: structural, type, receipt and semantic faults."""
    out = []
    for k, spec in feature["fields"].items():
        x = copy.deepcopy(state)
        x.pop(k)
        out.append(x)
        x = copy.deepcopy(state)
        x[k] = {"injected": "unexpected"}
        out.append(x)
    x = copy.deepcopy(state)
    x["unauthorized"] = 1
    out.append(x)
    x = copy.deepcopy(state)
    x["day_epoch"] = 0
    out.append(x)
    x = copy.deepcopy(state)
    x["command_receipts"] *= 2
    out.append(x)
    x = copy.deepcopy(state)
    x["revision"] = 0
    out.append(x)
    for k, v in state.items():
        if type(v) is dict and v:
            first = next(iter(v))
            x = copy.deepcopy(state)
            x[k].pop(first)
            out.append(x)
        if type(v) is list and v and type(v[0]) is dict and v[0]:
            first = next(iter(v[0]))
            x = copy.deepcopy(state)
            x[k][0].pop(first)
            out.append(x)
    n = int(feature["id"][-3:])
    x = copy.deepcopy(state)
    if n == 81:
        x["ink_batch"]["spent"] = 9
    elif n == 82:
        x["pigment_units"]["refunded"] = 2
    elif n == 83:
        x["firing_receipt"]["vessel_id"] = "wrong"
    elif n == 84:
        x["note_sequence"][1]["beat"] = 0
    elif n == 85:
        x["habitat_rule"]["protected"] = True
    elif n == 86:
        x["formula"]["total_units"] = 999
    elif n == 87:
        x["performance_receipt"]["charged_viewers"] = 3
    elif n == 88:
        x["layout"][0]["item_id"] = "unowned"
    elif n == 89:
        x["layout"][0]["part_id"] = "unowned"
    elif n == 90:
        x["repair_receipt"]["restored_points"] = 101
    out.append(x)
    return out


def run():
    doc = json.loads(PATH.read_text(encoding="utf-8"))
    assert doc["schema_version"] == 2 and doc["count"] == 10
    assert doc["phase"].startswith("Phase B")
    assert doc["source_blob_sha"] == "eb7c590f43c92ded0e328ecfdf7003fa7c06ceac"
    ids = [x["id"] for x in doc["contracts"]]
    assert ids == ["EB-E-%03d" % i for i in range(81, 91)]
    assert len({x["title"].casefold() for x in doc["contracts"]}) == 10
    accepted = rejected = roundtrips = 0
    for f in doc["contracts"]:
        assert f["status"] == "design_only_not_playable"
        assert len(f["source_fields"]) == 4
        assert set(f["source_fields"]).issubset(f["fields"])
        assert set(f["fields"]) == set(f["default_state"]) == set(f["valid_state"])
        assert f["save_namespace"] == "emergence.creative." + f["id"][-3:]
        assert f["controls"]["keyboard_mouse"] and f["controls"]["touch"]
        assert f["controls"]["controller"] and f["assets"] and f["acceptance"]
        for state in [f["default_state"], f["valid_state"]]:
            assert validate(f, state), "valid fixture rejected: " + f["id"]
            accepted += 1
            encoded = json.dumps(state, sort_keys=True, separators=(",", ":"))
            assert validate(f, json.loads(encoded))
            assert encoded == json.dumps(json.loads(encoded), sort_keys=True, separators=(",", ":"))
            roundtrips += 1
        for bad in mutate(f, f["valid_state"]):
            assert not validate(f, bad), "hostile fixture accepted: " + f["id"] + " " + repr(bad)
            rejected += 1
        # Exact default and active state may not be cross-accepted with stale receipts.
        bad = copy.deepcopy(f["default_state"])
        bad["command_receipts"] = copy.deepcopy(f["valid_state"]["command_receipts"])
        assert not validate(f, bad)
        rejected += 1
    print("CREATIVE_CONTRACTS=10 VALID=%d HOSTILE_REJECTED=%d ROUNDTRIPS=%d"
          % (accepted, rejected, roundtrips))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.parse_args()
    run()
