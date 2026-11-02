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

if __name__ == "__main__":
    unittest.main()
