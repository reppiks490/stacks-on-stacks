#!/usr/bin/env python3
"""Offline strict design-contract checks for B021–B030; NOT native gameplay proof."""
import argparse
import copy
import json
import math
import re
from pathlib import Path

DATA = Path(__file__).with_name("interior_021_030.json")
MAX_EPOCH = 9007199254740991


class ContractError(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise ContractError(reason)


def load_data(path=DATA):
    def reject_constant(value):
        raise ContractError("nonfinite JSON constant " + value)
    return json.loads(Path(path).read_text(encoding="utf-8"), parse_constant=reject_constant)


def check_value(spec, value, path):
    kind = spec["type"]
    if kind == "integer":
        require(type(value) is int and spec["min"] <= value <= spec["max"], path + ": integer type/bounds")
    elif kind == "boolean":
        require(type(value) is bool, path + ": expected bool")
    elif kind == "string":
        require(type(value) is str and spec["min_length"] <= len(value) <= spec["max_length"], path + ": string bounds")
        require(not any(ord(c) < 32 for c in value), path + ": control character")
    elif kind == "enum":
        require(type(value) is str and value in spec["values"], path + ": enum")
    elif kind == "object":
        require(type(value) is dict and set(value) == set(spec["fields"]), path + ": object shape")
        for key, child in spec["fields"].items():
            check_value(child, value[key], path + "." + key)
    elif kind == "list":
        require(type(value) is list and len(value) <= spec["max_items"], path + ": list size/type")
        for j, item in enumerate(value):
            check_value(spec["items"], item, path + "[" + str(j) + "]")
        if "unique_by" in spec:
            vals = [item[spec["unique_by"]] for item in value]
            require(len(vals) == len(set(vals)), path + ": duplicate key")
    else:
        raise ContractError(path + ": unsupported schema kind " + str(kind))


def orientation(a, b, c):
    return (b["x_cm"]-a["x_cm"])*(c["z_cm"]-a["z_cm"])-(b["z_cm"]-a["z_cm"])*(c["x_cm"]-a["x_cm"])


def on_segment(a, b, c):
    return (min(a["x_cm"], b["x_cm"]) <= c["x_cm"] <= max(a["x_cm"], b["x_cm"])
            and min(a["z_cm"], b["z_cm"]) <= c["z_cm"] <= max(a["z_cm"], b["z_cm"]))


def intersect(a, b, c, d):
    x, y, z, w = orientation(a,b,c), orientation(a,b,d), orientation(c,d,a), orientation(c,d,b)
    if ((x > 0 > y or x < 0 < y) and (z > 0 > w or z < 0 < w)):
        return True
    return ((x == 0 and on_segment(a,b,c)) or (y == 0 and on_segment(a,b,d))
            or (z == 0 and on_segment(c,d,a)) or (w == 0 and on_segment(c,d,b)))


def manhattan(a,b):
    return abs(a["x_cm"]-b["x_cm"])+abs(a["z_cm"]-b["z_cm"])


def check_rule(rule, s):
    if rule == "acoustic_room_link":
        require({x["room_id"] for x in s["absorption_map"]} == {x["room_id"] for x in s["noise_map"]}, "acoustic room mismatch")
    elif rule == "acoustic_spill_formula":
        m = {x["room_id"]:x for x in s["absorption_map"]}
        for n in s["noise_map"]:
            a=m[n["room_id"]]
            expected=min(n["source_db10"], (n["source_db10"]*(1000-a["absorption_permille"])+500)//1000
                         + (n["source_db10"]//5 if a["door_open"] else 0))
            require(n["spill_db10"] == expected, "acoustic spill must match model")
    elif rule == "shaft_polygon_simple":
        p=s["shaft_polygon"]
        if p:
            require(len(p)>=3, "shaft polygon too short")
            area2=abs(sum(a["x_cm"]*p[(i+1)%len(p)]["z_cm"]-p[(i+1)%len(p)]["x_cm"]*a["z_cm"] for i,a in enumerate(p)))
            require(area2>=20000, "shaft polygon area too small")
            for i in range(len(p)):
                for j in range(i+1,len(p)):
                    if j==i+1 or (i==0 and j==len(p)-1):
                        continue
                    require(not intersect(p[i],p[(i+1)%len(p)],p[j],p[(j+1)%len(p)]), "self crossing shaft")
    elif rule == "light_requires_shaft":
        require(bool(s["shaft_polygon"]) or not s["light_map"], "light without shaft")
    elif rule == "daylight_formula":
        for x in s["light_map"]:
            require(x["lux10"] == x["sun_deg"]*10*(1000-x["occlusion_permille"])//1000, "incorrect daylight")
    elif rule == "track_room_distinct":
        require(all(x["from_room"]!=x["to_room"] for x in s["divider_tracks"]), "divider self room")
    elif rule == "divider_position":
        require(all(x["position_cm"]<=x["length_cm"] for x in s["divider_tracks"]), "divider outside track")
    elif rule == "exit_clear":
        require(all(x["exit_clear"] for x in s["divider_tracks"]), "blocked egress")
    elif rule == "room_revision_match":
        require(not s["divider_tracks"] or s["room_revision"]==s["revision"], "stale room revision")
    elif rule == "shelf_exact_ledger":
        for cell in s["shelf_cells"]:
            entries=[x for x in s["stored_ids"] if x["cell_id"]==cell["cell_id"]]
            require(sum(x["mass_g"] for x in entries)==cell["used_g"], "shelf mass discrepancy")
            require(sum(x["volume_cm3"] for x in entries)==cell["used_cm3"], "shelf volume discrepancy")
    elif rule == "shelf_capacity":
        require(all(x["used_g"]<=x["capacity_g"] and x["used_cm3"]<=x["capacity_cm3"] for x in s["shelf_cells"]), "shelf overload")
    elif rule == "shelf_refs":
        ids={x["cell_id"] for x in s["shelf_cells"]}
        require(all(x["cell_id"] in ids for x in s["stored_ids"]), "orphan stored item")
    elif rule == "food_epoch_bound":
        require(all(x["last_checked_epoch"]<=s["day_epoch"] for x in s["food_lots"]), "future food observation")
    elif rule == "food_spoilage_floor":
        v=s["vent_state"]
        floor=max(0,v["humidity_permille"]-800)//2 + max(0,v["temp_c_x10"]-250)//5
        require(all(x["spoilage_permille"]>=floor for x in s["food_lots"]), "spoilage below environmental floor")
    elif rule == "kitchen_fixture_set":
        f=s["fixture_positions"]
        require(not f or {x["kind"] for x in f}=={"sink","prep","stove"}, "incomplete fixture triangle")
        require(len({(x["x_cm"],x["z_cm"]) for x in f})==len(f), "overlapping fixtures")
    elif rule == "kitchen_route_exact":
        f={x["kind"]:x for x in s["fixture_positions"]}
        distance=(manhattan(f["sink"],f["prep"])+manhattan(f["prep"],f["stove"])+manhattan(f["stove"],f["sink"])) if len(f)==3 else 0
        require(s["route_cost"]=={"distance_cm":distance,"seconds":(distance+79)//80}, "route cost mismatch")
    elif rule == "wash_mass_balance":
        t=s["wash_tank"]
        require(t["input_ml"]==t["untreated_ml"]+t["treated_ml"]+t["used_ml"], "wash water creation/loss")
    elif rule == "filter_capacity_balance":
        t,f=s["wash_tank"],s["filter_state"]
        require(f["processed_ml"]==t["treated_ml"]+t["used_ml"], "filter throughput mismatch")
        require(f["processed_ml"]<=f["capacity_ml"] and f["remaining_ml"]==f["capacity_ml"]-f["processed_ml"], "filter capacity mismatch")
    elif rule == "pigment_recipe_ref":
        ids={x["pigment_id"] for x in s["pigment_recipe"]}
        require(all(x["pigment_id"] in ids for x in s["wall_finish"]), "orphan pigment")
    elif rule == "pigment_mass_budget":
        for p in s["pigment_recipe"]:
            coats=sum(x["coats"] for x in s["wall_finish"] if x["pigment_id"]==p["pigment_id"])
            require(coats*10<=p["quantity_g"], "pigment overspent")
    elif rule == "finish_epoch":
        require(all(x["applied_epoch"]<=s["day_epoch"] for x in s["wall_finish"]), "future finish")
    elif rule == "pigment_hex":
        require(all(re.fullmatch(r"[0-9A-Fa-f]{6}",x["rgb_hex"]) for x in s["pigment_recipe"]), "invalid pigment RGB")
    elif rule == "firebreak_cell_refs":
        ids={x["cell_id"] for x in s["clearance_mask"]}
        require(all(x["cell_id"] in ids for x in s["firebreak_tiles"]), "orphan firebreak")
    elif rule == "firebreak_coverage":
        tiles={x["cell_id"]:x for x in s["firebreak_tiles"]}
        require(all(x["cell_id"] in tiles and tiles[x["cell_id"]]["heat_rating"]>=200
                    for x in s["clearance_mask"] if x["combustible"] and x["distance_cm"]<120), "unprotected hearth")
    elif rule == "ramp_slope_width_landing":
        require(all(x["run_cm"]>=x["rise_cm"]*12 and x["width_cm"]>=90 and x["landing_cm"]>=120
                    for x in s["ramp_sections"]), "inaccessible ramp")
    elif rule == "ramp_route_refs":
        ids={x["section_id"] for x in s["ramp_sections"]}
        require(all(all(ref in ids for ref in r["section_ids"]) for r in s["access_routes"]), "orphan ramp section")
    elif rule == "ramp_route_nonempty":
        require(not s["ramp_sections"] or bool(s["access_routes"]), "no access route")
        require(all(r["section_ids"] and r["passable"] and len(set(r["section_ids"]))==len(r["section_ids"])
                    for r in s["access_routes"]), "unpassable/repeated route")
    else:
        raise ContractError("unimplemented rule " + rule)


def check_state(contract, s):
    fields=contract["fields"]
    require(type(s) is dict and set(s)==set(fields), "state missing/extra fields")
    for name,spec in fields.items():
        check_value(spec,s[name],contract["id"]+"."+name)
    require(len(s["receipts"])==len(set(s["receipts"])), "duplicate receipt")
    active=any(s[name]!=spec["default"] for name,spec in fields.items()
               if name not in ("site_id","revision","day_epoch","receipts"))
    require(not active or (s["site_id"] and s["revision"]>=1 and s["day_epoch"]>=1), "orphan active state")
    for rule in contract["rules"]:
        check_rule(rule,s)


def expect_rejected(contract,s,reason):
    try:
        check_state(contract,s)
    except ContractError:
        return
    raise AssertionError(contract["id"]+": accepted invalid "+reason)


def self_test(data):
    contracts=data["state_contracts"]
    require(len(contracts)==10 and [c["id"] for c in contracts]==["EB-B-%03d"%i for i in range(21,31)], "wrong tranche")
    require(len({c["save_namespace"] for c in contracts})==10, "duplicate namespaces")
    total_valid=total_invalid=0
    for c in contracts:
        require(set(c["source_fields"])==set(c["fields"]), "source fields drift")
        require(c["native_gate"].startswith("Not tested in native Godot"), "false native claim")
        require(len(c["rules"])>=2 and len(c["invalid_examples"])>=2, "missing domain tests")
        example=c["valid_example"]
        check_state(c,example)
        require(json.loads(json.dumps(example,allow_nan=False))==example, "state roundtrip drift")
        inactive={name:copy.deepcopy(spec["default"]) for name,spec in c["fields"].items()}
        check_state(c,inactive)
        total_valid+=2
        for item in c["invalid_examples"]:
            expect_rejected(c,item["state"],item["reason"])
            total_invalid+=1
        custom=next(name for name in c["fields"] if name not in ("site_id","revision","day_epoch","receipts"))
        bad=[]
        x=copy.deepcopy(example);del x[custom];bad.append(("missing field",x))
        x=copy.deepcopy(example);x["unknown"]="x";bad.append(("unknown field",x))
        x=copy.deepcopy(example);x["revision"]=True;bad.append(("bool as int",x))
        x=copy.deepcopy(example);x["receipts"]=["cmdA","cmdA"];bad.append(("replayed receipt",x))
        x=copy.deepcopy(example);x["receipts"]=[""];bad.append(("empty receipt",x))
        x=copy.deepcopy(example);x["day_epoch"]=0;bad.append(("orphan epoch",x))
        x=copy.deepcopy(example);x[custom]=True;bad.append(("wrong nested type",x))
        x=copy.deepcopy(example);x["receipts"]=["r%03d"%j for j in range(129)];bad.append(("receipt overflow",x))
        x=copy.deepcopy(example);x["site_id"]="site\n";bad.append(("control char",x))
        for reason,x in bad:
            expect_rejected(c,x,reason)
            total_invalid+=1
    require(total_valid==20 and total_invalid==110, "unexpected fixture counts")
    print("INTERIOR DESIGN CONTRACT PASS: 10 contracts; %d valid; %d rejected; %d bounded fields; %d rules" %
          (total_valid,total_invalid,sum(len(c["fields"]) for c in contracts),sum(len(c["rules"]) for c in contracts)))
    return True


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    data=load_data()
    if args.self_test:
        self_test(data)
    else:
        print("B021-B030 strict schema loaded; use --self-test for fixtures")


if __name__=="__main__":
    main()
