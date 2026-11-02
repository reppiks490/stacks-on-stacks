"""Pure Python deterministic numerical reference model; not the Godot engine."""
from __future__ import annotations
import json
import unittest
from pathlib import Path
DATA=json.loads((Path(__file__).resolve().parents[1]/'data/game_rules.json').read_text())

class ResourceAdmissionModel:
    def __init__(self):
        self.stamina=DATA['combat']['stamina_max']
        self.strike_ready=0.0
        self.pulse_ready=0.0
        self.dodge_until=0.0
    def strike(self,now):
        if now < self.strike_ready or self.stamina < DATA['combat']['strike_cost']:
            return False
        self.stamina-=DATA['combat']['strike_cost']
        self.strike_ready=now+DATA['combat']['strike_cooldown_seconds']
        return True
    def pulse(self,now):
        if now < self.pulse_ready or self.stamina < DATA['combat']['pulse_cost']:
            return False
        self.stamina-=DATA['combat']['pulse_cost']
        self.pulse_ready=now+DATA['combat']['pulse_cooldown_seconds']
        return True
    def dodge(self,now):
        if now < self.dodge_until or self.stamina < DATA['combat']['dodge_cost']:
            return False
        self.stamina-=DATA['combat']['dodge_cost']
        self.dodge_until=now+DATA['combat']['dodge_duration_seconds']
        return True

class ResourceModelTests(unittest.TestCase):
    def test_cooldown_denies_spam_without_resource_loss(self):
        c=ResourceAdmissionModel()
        self.assertTrue(c.strike(1.0))
        after=c.stamina
        self.assertFalse(c.strike(1.1))
        self.assertEqual(c.stamina,after)
        self.assertTrue(c.strike(1.49))
    def test_expensive_attack_fails_when_exhausted(self):
        c=ResourceAdmissionModel()
        c.stamina=15.0
        self.assertFalse(c.pulse(1.0))
        self.assertEqual(c.stamina,15.0)
    def test_dodge_cannot_stack_inside_window(self):
        c=ResourceAdmissionModel()
        self.assertTrue(c.dodge(1.0))
        after=c.stamina
        self.assertFalse(c.dodge(1.1))
        self.assertEqual(c.stamina,after)
    def test_combined_spend_bounds(self):
        c=ResourceAdmissionModel()
        self.assertTrue(c.strike(1.0))
        self.assertTrue(c.pulse(1.0))
        self.assertTrue(c.dodge(1.0))
        self.assertGreaterEqual(c.stamina,0.0)
        self.assertFalse(c.dodge(1.01))
    def test_declared_objectives_terminate(self):
        goal=DATA['objectives']
        self.assertEqual([x['id'] for x in goal],['OBJ-001','OBJ-002','OBJ-003'])
        self.assertEqual(len(set(x['id'] for x in goal)),3)

if __name__=='__main__':unittest.main()
