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


if __name__ == "__main__":
    unittest.main()
