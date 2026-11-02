"""Contract and adversarial validation, not Godot runtime tests."""
from __future__ import annotations
import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('sablestar_guard',ROOT/'tools/validate_project.py')
assert SPEC and SPEC.loader
import sys
mod=importlib.util.module_from_spec(SPEC)
sys.modules['sablestar_guard']=mod
SPEC.loader.exec_module(mod)

class GameProjectContract(unittest.TestCase):
    def setUp(self):
        self.data=json.loads((ROOT/'data/game_rules.json').read_text(encoding='utf-8'))
    def test_project_sources_complete(self):
        self.assertEqual(mod.validate(),[])
    def test_unique_stable_identity(self):
        self.assertEqual(self.data['project_id'],'SABLESTAR-ORIGINAL-001')
        ids=[x['id'] for k in ['factions','enemy_archetypes'] for x in self.data[k]]
        ids += [x['id'] for x in self.data['world']['region_definitions']]
        self.assertEqual(len(ids),len(set(ids)))
    def test_data_limits(self):
        combat=self.data['combat']
        self.assertLessEqual(combat['pulse_damage'],combat['health_max'])
        self.assertGreater(combat['dodge_cost'],0)
        self.assertGreater(combat['pulse_cooldown_seconds'],0)
        self.assertGreater(combat['strike_cooldown_seconds'],0)
        self.assertGreater(combat['stamina_max'],combat['pulse_cost'])
    def test_no_shipping_evidence_invented(self):
        self.assertEqual(self.data['evidence']['godot_engine_run'],'not_run')
        self.assertFalse(self.data['evidence']['third_party_assets_copied'])
    def test_no_automatic_codex_workflows(self):
        import re
        workflows=ROOT/'.github/workflows'
        for workflow in workflows.glob('*.yml'):
            source=workflow.read_text(encoding='utf-8')
            # Do not permit Codex actions, agent invocations, PR review bots,
            # or automatically triggered comment/review workflows.
            self.assertFalse(re.search(r'(?im)^\s*(?:-\s*)?(?:uses|run):[^\n]*(?:codex|chatgpt-codex|openai/codex)',source),workflow)
            self.assertFalse(re.search(r'(?im)^\s*(?:pull_request_review|issue_comment|workflow_run):',source),workflow)
            self.assertFalse(re.search(r'(?i)@codex|chatgpt-codex-connector',source),workflow)
    def test_save_uses_allowlisted_local_state(self):
        session=(ROOT/'scripts/session_state.gd').read_text(encoding='utf-8')
        self.assertIn('chosen_faction',session)
        self.assertIn('return false',session)
        self.assertIn('MAX_FRAGMENTS',session)
        self.assertNotIn('HTTPClient',session)
    def test_damage_scope_restricted_to_damageable(self):
        player=(ROOT/'scripts/player_actor.gd').read_text(encoding='utf-8')
        self.assertEqual(player.count('get_nodes_in_group("damageable")'),2)
        self.assertIn('if not entity.has_method("take_damage"):',player)
    def test_local_crystal_cannot_reward_twice(self):
        source=(ROOT/'scripts/resonance_crystal.gd').read_text(encoding='utf-8')
        self.assertIn('if _broken or amount <= 0.0:',source)
        self.assertIn('_broken = true',source)
    def test_beacon_choice_requires_player_interaction(self):
        source=(ROOT/'scripts/game_root.gd').read_text(encoding='utf-8')
        self.assertIn('beacon.connect("interaction_requested", Callable(self, "_on_beacon_requested"))',source)
        self.assertIn('if player.global_position.distance_to(_pending_beacon.global_position) > 3.8:',source)
    def test_faction_choice_is_once_only(self):
        source=(ROOT/'scripts/session_state.gd').read_text(encoding='utf-8')
        self.assertIn('if chosen_faction != "" or not id in ["FAC-01", "FAC-02"]:',source)
    def test_enemy_windup_and_dead_gate(self):
        source=(ROOT/'scripts/enemy_actor.gd').read_text(encoding='utf-8')
        self.assertIn('Mode.WINDUP',source)
        self.assertIn('if _dead or amount <= 0.0:',source)
        self.assertIn('remove_from_group("damageable")',source)

if __name__=='__main__':unittest.main()
