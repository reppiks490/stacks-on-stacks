"""Original art and geometry integrity; not Godot native imports."""
from pathlib import Path
import importlib.util
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('original_assets',ROOT/'tools/generate_original_assets.py')
assert SPEC and SPEC.loader
assets=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)

class TestOriginalAssets(unittest.TestCase):
    def test_reproducible_source_mesh(self):
        self.assertEqual(assets.mesh_source(),assets.mesh_source())
        self.assertGreater(assets.mesh_source().count('\nf '),60)
    def test_original_mesh_and_audio_are_wired_into_runtime(self):
        player=(ROOT/'scripts/player_actor.gd').read_text()
        hud=(ROOT/'scripts/hud.gd').read_text()
        game=(ROOT/'scripts/game_root.gd').read_text()
        self.assertIn('preload("res://assets/models/sableblade.obj")',player)
        self.assertIn('_sword.mesh = SABLEBLADE_MESH',player)
        self.assertIn('preload("res://assets/vector/sablestar_sigillum.svg")',hud)
        self.assertIn('preload("res://assets/audio/resonance_pulse.wav")',game)
        self.assertIn('preload("res://assets/audio/covenant_seal.wav")',game)
    def test_full_asset_provenance(self):
        valid,errors=assets.verify(ROOT)
        self.assertTrue(valid,errors)
    def test_no_claimed_native_import(self):
        import json
        record=json.loads((ROOT/'assets/provenance.json').read_text())
        self.assertEqual(record['native_engine_import'],'not_run')
        self.assertEqual(record['external_proprietary_assets'],0)
        self.assertGreaterEqual(len(record['asset_entries']),10)

if __name__=='__main__':
    unittest.main()
