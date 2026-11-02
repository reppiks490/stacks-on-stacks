"""EVERBLOOM B02/B03/B13 detached reference oracle; NOT a live game subsystem.

No real inventory authority, game save migration, or Phase-C implementation.
Run: python3 docs/innovation/construction/command_journal/reference.py
"""
from __future__ import annotations

import copy
import hashlib
import json
import re
import unittest

START = {"timber": 24, "stone": 12}
PARTS = {
    "foundation": {"cost": {"stone": 4}, "parent": None, "sockets": ()},
    "post": {"cost": {"timber": 2}, "parent": "foundation", "sockets": ("nw", "ne", "sw", "se")},
    "wall": {"cost": {"timber": 3}, "parent": "post", "sockets": ("side_a", "side_b")},
    "roof": {"cost": {"timber": 4}, "parent": "wall", "sockets": ("top",)},
}
DEVICES = ("keyboard", "mouse", "gamepad", "touch")
ID = re.compile(r"^[a-z][a-z0-9_-]{0,47}$")
MAX_COMMANDS = 1024
MAX_PIECES = 128


class Rejected(ValueError):
    """Invalid command, state, or unauthorized replay; never partially applied."""


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def fresh():
    return {
        "version": 1, "day_epoch": 0, "materials": copy.deepcopy(START),
        "pieces": {}, "placed": [], "redo": [], "receipts": [], "commands": [],
    }


def require(condition, message):
    if not condition:
        raise Rejected(message)


def identifier(value):
    return isinstance(value, str) and ID.fullmatch(value) is not None


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def part_cost(kind):
    return PARTS[kind]["cost"]


def check_placement(state, part):
    kind = part["kind"]
    require(kind in PARTS, "unknown part kind")
    parent = part["parent"]
    socket = part["socket"]
    if kind == "foundation":
        require(parent is None and socket is None, "foundation cannot attach")
        require(not any(p["kind"] == "foundation" for p in state["pieces"].values()), "one foundation per reference dwelling")
    else:
        require(identifier(parent) and parent in state["pieces"], "missing parent")
        require(state["pieces"][parent]["kind"] == PARTS[kind]["parent"], "incompatible parent type")
        require(socket in PARTS[kind]["sockets"], "incompatible typed socket")
        require(not any(p["parent"] == parent and p["socket"] == socket for p in state["pieces"].values()), "occupied socket")
    require(not any(p["position"] == part["position"] for p in state["pieces"].values()), "overlapping footprint")
    require(len(state["pieces"]) < MAX_PIECES, "piece budget exceeded")


def _step(state, command):
    require(type(command) is dict, "command must be object")
    common = {"receipt", "epoch", "verb", "device"}
    require(common <= set(command), "missing command fields")
    verb = command["verb"]
    require(verb in ("place", "undo", "redo", "tick"), "unknown verb")
    expected = common | ({"piece_id", "kind", "parent", "socket", "position"} if verb == "place" else set())
    require(set(command) == expected, "unknown or missing command keys")
    receipt, epoch = command["receipt"], command["epoch"]
    require(identifier(receipt) and receipt not in state["receipts"], "duplicate or invalid receipt")
    require(integer(epoch, 1, 10_000_000) and epoch >= state["day_epoch"], "nonmonotonic or invalid epoch")
    require(command["device"] in DEVICES, "unknown device")
    require(len(state["commands"]) < MAX_COMMANDS, "journal budget exceeded")

    if verb == "place":
        part = {key: copy.deepcopy(command[key]) for key in ("piece_id", "kind", "parent", "socket", "position")}
        pid = part.pop("piece_id")
        require(identifier(pid), "invalid piece id")
        require(pid not in state["pieces"], "duplicate piece id")
        require(not any(row["piece_id"] == pid for row in state["placed"] + state["redo"]), "reused journal piece id")
        pos = part["position"]
        require(type(pos) is list and len(pos) == 2 and all(integer(n, -32, 32) for n in pos), "invalid integer grid coordinate")
        check_placement(state, part)
        cost = part_cost(part["kind"])
        require(all(state["materials"][key] >= amount for key, amount in cost.items()), "insufficient material escrow")
        for key, amount in cost.items():
            state["materials"][key] -= amount
        state["pieces"][pid] = part
        state["placed"].append({"piece_id": pid, **copy.deepcopy(part)})
        state["redo"].clear()

    elif verb == "undo":
        require(state["placed"], "empty undo stack")
        last = state["placed"][-1]
        pid = last["piece_id"]
        require(pid in state["pieces"], "missing undo target")
        require(not any(p["parent"] == pid for p in state["pieces"].values()), "cannot undo load-bearing parent")
        state["placed"].pop()
        del state["pieces"][pid]
        for key, amount in part_cost(last["kind"]).items():
            state["materials"][key] += amount
        state["redo"].append(last)

    elif verb == "redo":
        require(state["redo"], "empty redo stack")
        last = state["redo"][-1]
        pid = last["piece_id"]
        require(pid not in state["pieces"], "redo target exists")
        part = {key: copy.deepcopy(last[key]) for key in ("kind", "parent", "socket", "position")}
        check_placement(state, part)
        cost = part_cost(part["kind"])
        require(all(state["materials"][key] >= amount for key, amount in cost.items()), "redo lacks escrow")
        for key, amount in cost.items():
            state["materials"][key] -= amount
        state["redo"].pop()
        state["pieces"][pid] = part
        state["placed"].append(last)

    state["day_epoch"] = epoch
    state["receipts"].append(receipt)
    state["commands"].append(copy.deepcopy(command))
    return state


def replay(commands):
    require(type(commands) is list and len(commands) <= MAX_COMMANDS, "invalid command journal")
    state = fresh()
    for command in commands:
        _step(state, command)
    return state


def validate(snapshot):
    require(type(snapshot) is dict and set(snapshot) == set(fresh()), "invalid snapshot shape")
    require(snapshot["version"] == 1, "unsupported snapshot version")
    expected = replay(snapshot["commands"])
    require(canonical(snapshot) == canonical(expected), "snapshot diverges from authoritative command replay")
    return True


def apply(snapshot, command):
    validate(snapshot)
    result = copy.deepcopy(snapshot)
    _step(result, copy.deepcopy(command))
    validate(result)
    return result


def save(snapshot):
    validate(snapshot)
    return canonical(snapshot)


def load(raw):
    try:
        state = json.loads(raw)
    except (TypeError, ValueError) as exc:
        raise Rejected("corrupt JSON") from exc
    validate(state)
    return state


def gameplay_projection(snapshot):
    validate(snapshot)
    return canonical({"materials": snapshot["materials"], "pieces": snapshot["pieces"], "placed": snapshot["placed"], "redo": snapshot["redo"], "day_epoch": snapshot["day_epoch"]})


def digest(snapshot):
    return hashlib.sha256(save(snapshot).encode("utf-8")).hexdigest()


def command(receipt, epoch, verb, device="keyboard", **fields):
    return {"receipt": receipt, "epoch": epoch, "verb": verb, "device": device, **fields}


def place(receipt, epoch, piece_id, kind, position, parent=None, socket=None, device="keyboard"):
    return command(receipt, epoch, "place", device, piece_id=piece_id, kind=kind, parent=parent, socket=socket, position=position)


class ReferenceAcceptance(unittest.TestCase):
    def build(self, device="keyboard"):
        state = fresh()
        for c in (
            place("r_found", 1, "f", "foundation", [0, 0], device=device),
            place("r_post", 1, "p", "post", [1, 0], "f", "nw", device=device),
            place("r_wall", 2, "w", "wall", [2, 0], "p", "side_a", device=device),
            place("r_roof", 2, "r", "roof", [3, 0], "w", "top", device=device),
        ):
            state = apply(state, c)
        return state

    def assert_rejected_atomic(self, state, candidate):
        before = save(state)
        with self.assertRaises(Rejected):
            apply(state, candidate)
        self.assertEqual(save(state), before)

    def test_complete_four_part_chain(self):
        s = self.build()
        self.assertEqual(set(s["pieces"]), {"f", "p", "w", "r"})
        self.assertEqual(s["materials"], {"timber": 15, "stone": 8})

    def test_undo_redo_conserves_materials(self):
        s = self.build()
        s = apply(s, command("u1", 3, "undo"))
        self.assertEqual(s["materials"]["timber"], 19)
        s = apply(s, command("redo1", 3, "redo"))
        self.assertEqual(s["materials"]["timber"], 15)
        self.assertEqual(set(s["pieces"]), {"f", "p", "w", "r"})

    def test_undo_all_and_redo_all(self):
        s = self.build()
        for n in range(4):
            s = apply(s, command("undo" + str(n), 3, "undo"))
        self.assertEqual(s["materials"], START)
        self.assertFalse(s["pieces"])
        for n in range(4):
            s = apply(s, command("redo" + str(n), 4, "redo"))
        self.assertEqual(s["materials"], self.build()["materials"])

    def test_redo_invalidated_by_new_placement(self):
        s = apply(self.build(), command("u1", 3, "undo"))
        s = apply(s, place("new_roof", 3, "r2", "roof", [4, 0], "w", "top"))
        self.assert_rejected_atomic(s, command("r_again", 3, "redo"))

    def test_duplicate_receipt_no_double_refund(self):
        s = apply(self.build(), command("u1", 3, "undo"))
        self.assert_rejected_atomic(s, command("u1", 3, "undo"))

    def test_duplicate_receipt_across_verbs(self):
        self.assert_rejected_atomic(self.build(), command("r_found", 4, "tick"))

    def test_wrong_parent_type(self):
        self.assert_rejected_atomic(self.build(), place("bad", 3, "bad", "roof", [5, 0], "f", "top"))

    def test_missing_parent(self):
        self.assert_rejected_atomic(fresh(), place("bad", 1, "p", "post", [1, 0], "ghost", "nw"))

    def test_invalid_socket(self):
        self.assert_rejected_atomic(self.build(), place("bad", 3, "p2", "post", [5, 0], "f", "top"))

    def test_occupied_socket(self):
        self.assert_rejected_atomic(self.build(), place("bad", 3, "p2", "post", [5, 0], "f", "nw"))

    def test_overlapping_footprint(self):
        self.assert_rejected_atomic(self.build(), place("bad", 3, "p2", "post", [1, 0], "f", "ne"))

    def test_no_second_foundation(self):
        self.assert_rejected_atomic(self.build(), place("bad", 3, "f2", "foundation", [6, 0]))

    def test_insufficient_material(self):
        s = self.build()
        for n, socket in enumerate(("ne", "sw", "se")):
            s = apply(s, place("post_" + str(n), 3, "p" + str(n), "post", [n + 5, 0], "f", socket))
        self.assertEqual(s["materials"]["timber"], 9)
        for n in range(3):
            s = apply(s, place("wall_" + str(n), 3, "wall" + str(n), "wall", [10 + n, 0], "p" + str(n), "side_a"))
        self.assertEqual(s["materials"]["timber"], 0)
        self.assert_rejected_atomic(s, place("bad", 3, "wall4", "wall", [14, 0], "p", "side_b"))

    def test_negative_and_boolean_epoch(self):
        s = self.build()
        for epoch in (-1, 0, True, 1, 10_000_001):
            self.assert_rejected_atomic(s, command("bad_" + str(epoch).lower(), epoch, "tick"))

    def test_56_day_year_boundary(self):
        s = self.build()
        for epoch in (56, 57, 112, 113):
            s = apply(s, command("day" + str(epoch), epoch, "tick"))
        self.assertEqual(s["day_epoch"], 113)
        self.assert_rejected_atomic(s, command("rollback", 56, "tick"))

    def test_save_load_nested_exact(self):
        s = self.build()
        self.assertEqual(load(save(s)), s)
        self.assertEqual(digest(load(save(s))), digest(s))

    def test_corrupt_snapshot_rejected(self):
        s = self.build()
        for field, value in (("materials", {"timber": 999, "stone": 8}), ("day_epoch", 900), ("receipts", []), ("pieces", {})):
            altered = copy.deepcopy(s)
            altered[field] = value
            with self.assertRaises(Rejected):
                load(canonical(altered))

    def test_corrupt_json_rejected(self):
        with self.assertRaises(Rejected):
            load('{"version":')

    def test_invalid_types_and_nonfinite_coordinates(self):
        s = self.build()
        for pos in ([True, 0], [1.5, 0], [float("nan"), 0], [33, 0], [1]):
            self.assert_rejected_atomic(s, place("bad", 3, "p2", "post", pos, "f", "ne"))

    def test_input_semantic_parity(self):
        results = [gameplay_projection(self.build(device)) for device in DEVICES]
        self.assertEqual(len(set(results)), 1)

    def test_deterministic_replay_and_checkpoint(self):
        s = self.build()
        for epoch in range(3, 114):
            s = apply(s, command("tick" + str(epoch), epoch, "tick"))
            if epoch % 14 == 0:
                s = load(save(s))
        self.assertEqual(s, replay(s["commands"]))
        self.assertEqual(digest(s), digest(load(save(s))))

    def test_hostile_command_fields(self):
        s = self.build()
        bad = command("bad", 3, "tick", amount=1000)
        self.assert_rejected_atomic(s, bad)

    def test_empty_undo_redo(self):
        self.assert_rejected_atomic(fresh(), command("bad", 1, "undo"))
        self.assert_rejected_atomic(fresh(), command("bad", 1, "redo"))

    def test_immutable_input_on_success(self):
        s = self.build()
        before = save(s)
        apply(s, command("next", 3, "tick"))
        self.assertEqual(save(s), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
