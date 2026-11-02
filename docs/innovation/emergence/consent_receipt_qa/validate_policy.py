#!/usr/bin/env python3
"""E18 QA-only deterministic adversarial oracle. NOT a Godot game feature or authority."""
import argparse
import copy
import hashlib
import json
import random
import unittest
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
POLICY = json.loads((ROOT / "POLICY.json").read_text(encoding="utf-8"))
REPO = "reppiks490/stacks-on-stacks"


def check(ok, reason):
    if not ok:
        raise ValueError(reason)


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def validate_policy(policy):
    check(policy.get("schema_version") == 1, "policy version")
    check(policy.get("phase_c") == "CLOSED", "phase C gate")
    check(policy.get("status") == "QA_REFERENCE_ORACLE_NOT_LIVE_AUTHORITY", "status")
    check(policy.get("approval") == {"village": False, "principal": False, "phase_c": False}, "unapproved authority")
    expected = {"EB-B-084": "memorial", "EB-E-036": "kindness",
                "EB-E-077": "archive", "EB-E-040": "story", "EB-E-075": "welcome"}
    check(policy.get("feature_purposes") == expected, "feature/purpose mapping")
    pairs = {tuple(sorted(p)) for p in policy.get("unresolved_pairs", [])}
    check(len(policy["unresolved_pairs"]) == 3 and pairs == {
        ("EB-B-084", "EB-E-036"), ("EB-E-036", "EB-E-077"),
        ("EB-E-040", "EB-E-075")}, "source conflict pairs")
    check(len(policy.get("adversarial_gates", [])) == 17
          and len(set(policy["adversarial_gates"])) == 17, "threat coverage")
    check(set(policy.get("authorities", {})) == {"consent", "receipts", "calendar"}, "authority map")
    source = policy.get("source", {})
    check(source == {"path": "docs/innovation/emergence/joint220_audit/PAIR_TRIAGE.json",
                     "commit": "1204ed50cb84572fad77450f836863901e0635ca",
                     "blob_sha": "2320aa61189fed9aeadaf90bfe47a6aa6501c3e6"}, "source pin")


def verify_pinned_source(policy, source_file=None):
    source = policy["source"]
    if source_file:
        raw = Path(source_file).read_bytes()
    else:
        url = "https://raw.githubusercontent.com/%s/%s/%s" % (
            REPO, source["commit"], source["path"])
        request = urllib.request.Request(url, headers={"User-Agent": "Everbloom-E18-ConsentQA/1"})
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    check(len(raw) < 250000, "oversized source")
    sha = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    check(sha == source["blob_sha"], "pinned source bytes changed")
    data = json.loads(raw.decode("utf-8"))
    check(data["phase_c"] == "CLOSED" and data["counts"]["pairs"] == 21, "triage status")
    flagged = [p for p in data["pairs"] if p["decision"] == "requires_authority_contract"]
    check(len(flagged) == 3, "source conflict count")
    check({tuple(sorted(p["ids"])) for p in flagged} ==
          {tuple(sorted(p)) for p in policy["unresolved_pairs"]}, "source conflicts drift")
    check(all(p["integration_status"] == "NOT_APPROVED"
              and p["native_gameplay_proof"] is False for p in flagged),
          "source claims unauthorized approval")
    return len(flagged)


class Gate:
    """Intentionally detached reference model: rejection semantics, not a live save service."""
    def __init__(self):
        self.state = {"day_epoch": 56, "paper": 12, "consents": {},
                      "records": [], "receipts": {}, "daily": []}

    def snapshot(self):
        return copy.deepcopy(self.state)

    def digest(self):
        return hashlib.sha256(canonical(self.state).encode()).hexdigest()

    def grant(self, resident, feature, revision, public=False, allowed=True):
        check(isinstance(resident, str) and resident.strip(), "resident")
        check(feature in POLICY["feature_purposes"], "feature")
        check(type(revision) is int and revision > 0, "revision")
        check(type(public) is bool and type(allowed) is bool, "consent flags")
        key = resident + "|" + feature
        prior = self.state["consents"].get(key)
        check(prior is None or revision > prior["revision"], "stale consent revision")
        self.state["consents"][key] = {
            "revision": revision, "allowed": allowed, "public": public,
            "purpose": POLICY["feature_purposes"][feature]}

    def advance(self, epoch):
        check(type(epoch) is int and epoch >= self.state["day_epoch"], "nonmonotonic epoch")
        self.state["day_epoch"] = epoch

    def apply(self, cmd):
        required = {"receipt", "feature", "resident", "purpose", "actor",
                    "revision", "epoch", "cost", "audience", "note"}
        check(type(cmd) is dict and set(cmd) == required, "command envelope")
        receipt = cmd["receipt"]
        check(isinstance(receipt, str) and 1 <= len(receipt) <= 64, "receipt id")
        signature = canonical(cmd)
        old = self.state["receipts"].get(receipt)
        if old is not None:
            check(old == signature, "global receipt collision or changed replay")
            return "replay"
        feature = cmd["feature"]
        check(feature in POLICY["feature_purposes"], "unknown feature")
        check(cmd["purpose"] == POLICY["feature_purposes"][feature], "wrong purpose")
        check(cmd["actor"] == "player", "forged actor")
        check(isinstance(cmd["resident"], str) and cmd["resident"].strip(), "resident")
        check(type(cmd["epoch"]) is int and cmd["epoch"] >= 1
              and cmd["epoch"] == self.state["day_epoch"], "epoch admission")
        check(type(cmd["revision"]) is int and cmd["revision"] >= 1, "consent revision")
        check(type(cmd["cost"]) is int and 0 <= cmd["cost"] <= 3, "material quote")
        check(cmd["audience"] in ("private", "public"), "audience")
        check(isinstance(cmd["note"], str) and len(cmd["note"]) <= 100, "note")
        key = cmd["resident"] + "|" + feature
        consent = self.state["consents"].get(key)
        check(consent is not None and consent["allowed"], "missing/revoked consent")
        check(consent["revision"] == cmd["revision"], "stale consent")
        check(consent["purpose"] == cmd["purpose"], "consent purpose")
        check(cmd["audience"] != "public" or consent["public"], "public consent")
        daily_key = "%s|%s|%s" % (cmd["epoch"], cmd["resident"], feature)
        check(daily_key not in self.state["daily"], "duplicate daily award")
        check(sum(r["epoch"] == cmd["epoch"] for r in self.state["records"]) < 8,
              "bounded daily event cap")
        check(self.state["paper"] >= cmd["cost"], "material underflow")
        # No state mutation above this point. Commit the entire accepted reference transition.
        self.state["paper"] -= cmd["cost"]
        self.state["receipts"][receipt] = signature
        self.state["daily"].append(daily_key)
        self.state["records"].append({k: cmd[k] for k in
                                     ("receipt", "feature", "resident", "purpose",
                                      "revision", "epoch", "cost", "audience", "note")})
        return "applied"

    def visible(self, resident):
        result = []
        for row in self.state["records"]:
            if row["resident"] != resident:
                continue
            consent = self.state["consents"].get(resident + "|" + row["feature"])
            if consent and consent["allowed"] and consent["purpose"] == row["purpose"]:
                if row["audience"] == "private" or consent["public"]:
                    result.append(copy.deepcopy(row))
        return result

    def restore(self, candidate):
        check(type(candidate) is dict and set(candidate) == set(self.state), "snapshot shape")
        check(type(candidate["day_epoch"]) is int and candidate["day_epoch"] >= 1, "snapshot epoch")
        check(type(candidate["paper"]) is int and candidate["paper"] >= 0, "snapshot stock")
        check(type(candidate["consents"]) is dict, "consent shape")
        check(type(candidate["receipts"]) is dict and type(candidate["records"]) is list
              and type(candidate["daily"]) is list, "ledger shape")
        for key, value in candidate["consents"].items():
            check(type(key) is str and "|" in key and type(value) is dict, "consent key")
            feature = key.split("|", 1)[1]
            check(feature in POLICY["feature_purposes"], "consent feature")
            check(set(value) == {"revision", "allowed", "public", "purpose"}, "consent fields")
            check(type(value["revision"]) is int and value["revision"] > 0
                  and type(value["allowed"]) is bool and type(value["public"]) is bool
                  and value["purpose"] == POLICY["feature_purposes"][feature], "consent integrity")
        check(len(candidate["records"]) == len(candidate["receipts"])
              == len(candidate["daily"]), "ledger cardinality")
        expected_daily = []
        seen_receipts = set()
        counts = {}
        for row in candidate["records"]:
            check(type(row) is dict and set(row) ==
                  {"receipt", "feature", "resident", "purpose", "revision",
                   "epoch", "cost", "audience", "note"}, "record shape")
            check(row["feature"] in POLICY["feature_purposes"]
                  and row["purpose"] == POLICY["feature_purposes"][row["feature"]], "record purpose")
            check(type(row["epoch"]) is int and 1 <= row["epoch"] <= candidate["day_epoch"],
                  "record epoch")
            check(type(row["cost"]) is int and 0 <= row["cost"] <= 3, "record cost")
            check(type(row["revision"]) is int and row["revision"] > 0, "record revision")
            check(type(row["resident"]) is str and row["resident"].strip(), "record resident")
            check(type(row["note"]) is str and len(row["note"]) <= 100, "record note")
            check(row["audience"] in ("public", "private"), "record audience")
            receipt = row["receipt"]
            check(type(receipt) is str and receipt and receipt not in seen_receipts,
                  "duplicate receipt")
            seen_receipts.add(receipt)
            signature = candidate["receipts"].get(receipt)
            check(type(signature) is str, "missing receipt signature")
            original = json.loads(signature)
            check(original == dict(row, actor="player"), "torn or forged receipt")
            check(canonical(original) == signature, "noncanonical receipt")
            daily_key = "%s|%s|%s" % (row["epoch"], row["resident"], row["feature"])
            expected_daily.append(daily_key)
            counts[row["epoch"]] = counts.get(row["epoch"], 0) + 1
        check(candidate["daily"] == expected_daily
              and len(set(expected_daily)) == len(expected_daily), "duplicate daily ledger")
        check(all(n <= 8 for n in counts.values()), "event storm in snapshot")
        self.state = copy.deepcopy(candidate)

    @staticmethod
    def year_day(epoch):
        check(type(epoch) is int and epoch >= 1, "invalid epoch")
        return ((epoch - 1) // 56 + 1, (epoch - 1) % 56 + 1)


def command(feature="EB-E-036", resident="npc1", receipt="r1", epoch=56, revision=1,
            cost=1, audience="private"):
    return {"receipt": receipt, "feature": feature, "resident": resident,
            "purpose": POLICY["feature_purposes"][feature], "actor": "player",
            "revision": revision, "epoch": epoch, "cost": cost, "audience": audience, "note": "QA"}


class Tests(unittest.TestCase):
    def setUp(self):
        self.g = Gate()
        self.g.grant("npc1", "EB-E-036", 1)

    def denied(self, cmd):
        before = self.g.digest()
        with self.assertRaises(ValueError):
            self.g.apply(cmd)
        self.assertEqual(self.g.digest(), before)

    def test_policy(self):
        validate_policy(POLICY)

    def test_all_five_purposes(self):
        for f in POLICY["feature_purposes"]:
            self.assertTrue(POLICY["feature_purposes"][f])

    def test_missing_and_cross_feature_consent(self):
        self.denied(command(feature="EB-E-077"))
        self.denied(command(resident="npc2"))

    def test_wrong_purpose(self):
        c = command(); c["purpose"] = "archive"; self.denied(c)

    def test_stale_revision(self):
        self.denied(command(revision=2))

    def test_revocation(self):
        self.g.grant("npc1", "EB-E-036", 2, allowed=False)
        self.denied(command(revision=2))

    def test_forged_actor(self):
        c = command(); c["actor"] = "npc"; self.denied(c)

    def test_public_without_permission(self):
        self.denied(command(audience="public"))

    def test_valid_public_permission(self):
        self.g.grant("npc1", "EB-E-036", 2, public=True)
        self.assertEqual(self.g.apply(command(revision=2, audience="public")), "applied")

    def test_authorized_conserves_paper(self):
        self.assertEqual(self.g.apply(command()), "applied")
        self.assertEqual(self.g.state["paper"], 11)

    def test_replay_no_double_spend(self):
        c = command()
        self.g.apply(c); before = self.g.digest()
        self.assertEqual(self.g.apply(c), "replay")
        self.assertEqual(self.g.digest(), before)

    def test_global_collision(self):
        self.g.apply(command())
        self.g.grant("npc1", "EB-E-077", 1)
        self.denied(command(feature="EB-E-077", receipt="r1"))

    def test_changed_replay(self):
        self.g.apply(command())
        self.denied(command(cost=2))

    def test_negative_zero_future_stale_epochs(self):
        for epoch in (-1, 0, 55, 57, True):
            self.denied(command(epoch=epoch))

    def test_cost_type_and_range(self):
        for cost in (-1, 4, True, 2.5):
            self.denied(command(cost=cost))

    def test_daily_duplicate(self):
        self.g.apply(command())
        self.denied(command(receipt="r2"))

    def test_year_rollover(self):
        self.assertEqual(Gate.year_day(56), (1, 56))
        self.assertEqual(Gate.year_day(57), (2, 1))
        self.assertEqual(Gate.year_day(113), (3, 1))
        self.g.apply(command())
        self.g.advance(57)
        self.assertEqual(self.g.apply(command(receipt="r2", epoch=57)), "applied")

    def test_nonmonotonic_clock(self):
        with self.assertRaises(ValueError): self.g.advance(55)

    def test_storm_cap(self):
        for i in range(8):
            resident = "npc%d" % i
            self.g.grant(resident, "EB-E-036", 1)
            self.g.apply(command(resident=resident, receipt="r%d" % i, cost=0))
        self.g.grant("npc9", "EB-E-036", 1)
        self.denied(command(resident="npc9", receipt="r9", cost=0))

    def test_stock_underflow(self):
        self.g.state["paper"] = 0
        self.denied(command(cost=1))

    def test_revocation_hides_prior_record(self):
        self.g.apply(command())
        self.assertEqual(len(self.g.visible("npc1")), 1)
        self.g.grant("npc1", "EB-E-036", 2, allowed=False)
        self.assertEqual(self.g.visible("npc1"), [])
        self.assertEqual(len(self.g.state["records"]), 1)

    def test_roundtrip_nested(self):
        self.g.apply(command())
        serialized = canonical(self.g.snapshot())
        other = Gate(); other.restore(json.loads(serialized))
        self.assertEqual(other.digest(), self.g.digest())

    def test_restore_rejects_duplicate_daily(self):
        self.g.apply(command())
        bad = self.g.snapshot()
        bad["daily"].append(bad["daily"][0])
        before = self.g.digest()
        with self.assertRaises(ValueError): self.g.restore(bad)
        self.assertEqual(self.g.digest(), before)

    def test_restore_rejects_torn_receipt(self):
        self.g.apply(command())
        bad = self.g.snapshot(); bad["receipts"]["r1"] = "{}"
        with self.assertRaises(ValueError): self.g.restore(bad)

    def test_restore_rejects_negative_balance(self):
        bad = self.g.snapshot(); bad["paper"] = -1
        with self.assertRaises(ValueError): self.g.restore(bad)

    def test_restore_rejects_forged_feature(self):
        self.g.apply(command())
        bad = self.g.snapshot(); bad["records"][0]["feature"] = "EB-E-999"
        with self.assertRaises(ValueError): self.g.restore(bad)

    def test_restore_rejects_future_epoch(self):
        self.g.apply(command())
        bad = self.g.snapshot(); bad["day_epoch"] = 1
        with self.assertRaises(ValueError): self.g.restore(bad)

    def test_restore_rejects_noncanonical_receipt(self):
        self.g.apply(command())
        bad = self.g.snapshot()
        bad["receipts"]["r1"] = json.dumps(json.loads(bad["receipts"]["r1"]))
        with self.assertRaises(ValueError): self.g.restore(bad)

    def test_policy_mutations(self):
        mutations = []
        for key, value in [("phase_c", "OPEN"), ("status", "PLAYABLE")]:
            x = copy.deepcopy(POLICY); x[key] = value; mutations.append(x)
        for key in ("village", "principal", "phase_c"):
            x = copy.deepcopy(POLICY); x["approval"][key] = True; mutations.append(x)
        x = copy.deepcopy(POLICY); x["unresolved_pairs"].pop(); mutations.append(x)
        x = copy.deepcopy(POLICY); x["feature_purposes"]["EB-E-036"] = "story"; mutations.append(x)
        x = copy.deepcopy(POLICY); x["source"]["blob_sha"] = "0"*40; mutations.append(x)
        x = copy.deepcopy(POLICY); x["adversarial_gates"].pop(); mutations.append(x)
        x = copy.deepcopy(POLICY); x["authorities"].pop("consent"); mutations.append(x)
        for mutation in mutations:
            with self.assertRaises(ValueError): validate_policy(mutation)
        self.assertEqual(len(mutations), 10)

    def test_seeded_two_year_determinism(self):
        def run():
            g = Gate()
            for i in range(12):
                for f in POLICY["feature_purposes"]:
                    g.grant("npc%d" % i, f, 1, public=(i % 2 == 0))
            rng = random.Random(20261102)
            outcomes = []
            for epoch in range(56, 169):
                g.advance(epoch)
                for k in range(12):
                    f = rng.choice(sorted(POLICY["feature_purposes"]))
                    resident = "npc%d" % rng.randrange(12)
                    c = command(f, resident, "seed-%d-%d" % (epoch, k), epoch,
                                cost=rng.randrange(4))
                    try: outcomes.append(g.apply(c))
                    except ValueError: outcomes.append("denied")
            restored = Gate(); restored.restore(json.loads(canonical(g.snapshot())))
            self.assertEqual(restored.digest(), g.digest())
            return g.digest(), outcomes
        self.assertEqual(run(), run())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--source-file")
    args = parser.parse_args()
    validate_policy(POLICY)
    if not args.offline:
        count = verify_pinned_source(POLICY, args.source_file)
        print("PINNED SOURCE VERIFIED: %d unresolved authority pairs" % count)
    if args.self_test:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(Tests)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        print("QA ORACLE: %d tests, %d failures, %d errors" %
              (result.testsRun, len(result.failures), len(result.errors)))
        if not result.wasSuccessful():
            raise SystemExit(1)
    print("PHASE C CLOSED: QA-only reference model, no playable feature or live authority")


if __name__ == "__main__":
    main()
