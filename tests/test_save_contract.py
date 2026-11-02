"""Principal-owned save integration invariants; real Godot save tests still required."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class SaveIntegrationContract(unittest.TestCase):
    def test_save_service_uses_temp_backup_and_recovery(self):
        code = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        for token in ("TEMP_PATH", "BACKUP_PATH", "validate_payload",
                      "DirAccess.copy_absolute", "DirAccess.rename_absolute",
                      "_read_one(BACKUP_PATH)", "FileAccess.open(TEMP_PATH"):
            self.assertIn(token, code)

    def test_game_uses_save_service_for_both_directions(self):
        code = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
        self.assertIn('preload("res://scripts/save_service.gd")', code)
        self.assertIn("SaveService.write_payload(payload)", code)
        self.assertIn("SaveService.read_payload()", code)

    def test_year_and_epoch_survive_save(self):
        code = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
        for token in ("var year: int = 1", "year += 1", "func day_epoch() -> int:",
                      '"year":year', 'content.get("year", 1)'):
            self.assertIn(token, code)


    def test_native_adversarial_save_contract_is_tracked(self):
        runner = (ROOT / "scripts/principal_save_acceptance.gd").read_text(encoding="utf-8")
        for case in ("fractional schema", "fractional day", "infinite minute",
                     "NaN energy", "negative inventory", "malformed farm",
                     "malformed animal", "integer precision overflow"):
            self.assertIn(case, runner)
        workflow = (ROOT / ".github/workflows/everbloom-principal-save-integrity.yml").read_text(
            encoding="utf-8")
        self.assertIn("principal_save_acceptance.gd", workflow)
        self.assertIn("sha256sum --check", workflow)
        self.assertNotIn("codex", workflow.lower())

    def test_save_service_rejects_nonfinite_and_nonintegral_state(self):
        code = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        for invariant in ("_finite_number", "is_nan(number)", "is_inf(number)",
                          "_whole_in_range", "MAX_SAFE_INTEGER", "_safe_json_tree",
                          "coordinates.size() != 3", "inventory[id]"):
            self.assertIn(invariant, code)

    def test_assembled_ecology_and_village_roundtrip_is_native(self):
        native = (ROOT / "scripts/principal_save_acceptance.gd").read_text(encoding="utf-8")
        for token in ('"__paddocks__"', '"compost_counter"', '"worked"', '"memories"',
                      'load("res://scripts/game.gd").new()', "session.save_game(false)",
                      "session.load_game()", "session.animals.paddocks",
                      "session.village.memories"):
            self.assertIn(token, native)
        boundary = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        for token in ('if id == "__paddocks__":', 'paddock.get("forage", null)',
                      '"compost_counter"', '"worked"', '"memories"'):
            self.assertIn(token, boundary)

    def test_village_recollection_fields_are_validated_by_principal_boundary(self):
        service = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        native = (ROOT / "scripts/principal_save_acceptance.gd").read_text(
            encoding="utf-8")
        for field in ("last_gift_favorite", "recalled_gift_epoch",
                      "gift_recollections"):
            self.assertIn(field, service)
            self.assertIn(field, native)
        for case in ("numeric favorite flag accepted",
                     "future recall epoch accepted",
                     "recollection without gift accepted",
                     "recollection before gift accepted",
                     "unbounded recollection count accepted",
                     "invalid assembled gift memory written",
                     "assembled gift recollection failed to roundtrip exactly"):
            self.assertIn(case, native)

    def test_earned_village_dialogue_is_strictly_validated_and_native_roundtripped(self):
        boundary = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        native = (ROOT / "scripts/principal_save_acceptance.gd").read_text(encoding="utf-8")
        for invariant in ('memory.has("dialogue_log")', 'history.size() > 12',
                          'line.size() != 3', 'line["epoch"]',
                          'line["locale"]', 'line["text"]',
                          'line_epoch <= previous_epoch', 'spoken.length() > 256'):
            self.assertIn(invariant, boundary)
        for case in ("valid two-year bilingual dialogue history rejected",
                     "legacy village memory without dialogue log rejected",
                     "future dialogue epoch accepted", "duplicate dialogue epoch accepted",
                     "unknown dialogue locale accepted", "oversized dialogue text accepted",
                     "overlong dialogue history accepted",
                     "future assembled dialogue history written",
                     "invalid dialogue history modified authoritative save bytes",
                     "assembled earned bilingual dialogue failed to roundtrip exactly"):
            self.assertIn(case, native)

    def test_nested_festival_awards_are_validated_and_native_roundtripped(self):
        service = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        native = (ROOT / "scripts/principal_save_acceptance.gd").read_text(
            encoding="utf-8")
        for token in ('payload.has("festivals")', 'festival_state.get("schema", null)',
                      'awarded.size() > 5000', 'award_keys.has(key)',
                      'award_year > saved_year'):
            self.assertIn(token, service)
        for case in ("valid multi-year festival awards rejected",
                     "duplicate festival award accepted",
                     "future-year festival award accepted",
                     "future-year assembled festival award written",
                     "assembled festival award failed to roundtrip without duplication"):
            self.assertIn(case, native)

    def test_festival_award_registry_matches_original_catalog(self):
        import json
        catalog = json.loads((ROOT / "data/festivals.json").read_text(encoding="utf-8"))
        service = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        registry = service.split("const FESTIVAL_EVENT_IDS := [", 1)[1].split("]", 1)[0]
        import re
        registered = re.findall(r'"([a-z0-9_]+)"', registry)
        expected = [entry["id"] for entry in catalog["festivals"]]
        self.assertEqual(len(registered), len(set(registered)))
        self.assertEqual(set(registered), set(expected))

    def test_original_village_job_has_player_input_dispatch(self):
        game = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
        hud = (ROOT / "scripts/hud.gd").read_text(encoding="utf-8")
        self.assertIn('"job":[KEY_K]', game)
        self.assertIn('event.is_action_pressed("job")', game)
        self.assertIn('village.act("job", hero.global_position)', game)
        self.assertIn("K Job", hud)

    def test_recovered_saves_quarantine_invalid_primary_without_losing_backup(self):
        service = (ROOT / "scripts/save_service.gd").read_text(encoding="utf-8")
        for invariant in ("QUARANTINE_PREFIX", "MAX_QUARANTINE_SLOTS",
                          "_available_quarantine_path", "damaged_primary",
                          "_read_one(BACKUP_PATH).is_empty()",
                          "DirAccess.rename_absolute(target, ProjectSettings.globalize_path(quarantine_path))"):
            self.assertIn(invariant, service)
        native = (ROOT / "scripts/principal_recovery_acceptance.gd").read_text(
            encoding="utf-8")
        for scenario in ("resume write after corrupt-primary recovery",
                         "resumed inventory persists exactly, no duplicate",
                         "second recovery resumes saving",
                         "fail closed without valid backup",
                         "fail closed when quarantine full"):
            self.assertIn(scenario, native)
        workflow = (ROOT / ".github/workflows/everbloom-principal-save-integrity.yml").read_text(
            encoding="utf-8")
        self.assertIn("principal_recovery_acceptance.gd", workflow)
        self.assertIn("XDG_DATA_HOME: /tmp/everbloom-principal-recovery-resume", workflow)
        self.assertNotIn("codex", workflow.lower())

if __name__ == "__main__":
    unittest.main()
