"""QA-owned cross-domain calendar mutation tests and workflow safety checks.

These are source-level tests. Native Godot, controller, touch, hardware and
long-form player-session gates remain separate.
"""
from __future__ import annotations

import copy
import re
import unittest
from pathlib import Path

from tools.qa_calendar_contract import load_catalogs, validate_calendar

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"


def workflow_risks(source: str) -> list[str]:
    """Conservative fail-closed review of GitHub Actions workflow source."""
    risks = []
    if re.search(r"codex", source, flags=re.IGNORECASE):
        risks.append("Codex invocation/reference is forbidden")
    if re.search(
        r"^\s*(pull_request_target|workflow_run|issue_comment|repository_dispatch)\s*:",
        source, flags=re.MULTILINE,
    ):
        risks.append("privileged or indirect trigger requires explicit manual audit")
    if re.search(r"^\s*(contents|actions|pull-requests|issues)\s*:\s*write\s*$",
                 source, flags=re.MULTILINE):
        risks.append("write permission not allowed in source verification workflow")
    return risks


class QACalendarMutationTests(unittest.TestCase):
    def setUp(self):
        self.offerings, self.social = load_catalogs()

    def test_current_calendar_has_sixteen_distinct_days(self):
        self.assertEqual(validate_calendar(self.offerings, self.social), [])

    def test_cross_catalog_day_collision_is_rejected(self):
        modified = copy.deepcopy(self.social)
        modified["festivals"][0]["day"] = self.offerings["festivals"][0]["day"]
        self.assertTrue(validate_calendar(self.offerings, modified))

    def test_cross_catalog_duplicate_id_is_rejected(self):
        modified = copy.deepcopy(self.social)
        modified["festivals"][0]["id"] = self.offerings["festivals"][0]["id"]
        self.assertTrue(validate_calendar(self.offerings, modified))

    def test_out_of_calendar_range_is_rejected(self):
        modified = copy.deepcopy(self.social)
        modified["festivals"][0]["day"] = 15
        self.assertTrue(validate_calendar(self.offerings, modified))

    def test_fractional_day_is_rejected(self):
        modified = copy.deepcopy(self.offerings)
        modified["festivals"][0]["day"] = 3.5
        self.assertTrue(validate_calendar(modified, self.social))

    def test_invalid_social_hours_are_rejected(self):
        modified = copy.deepcopy(self.social)
        modified["festivals"][0]["end_minute"] = 900
        self.assertTrue(validate_calendar(self.offerings, modified))

    def test_missing_weather_fallback_is_rejected(self):
        modified = copy.deepcopy(self.offerings)
        modified["festivals"][0]["weather_fallback"] = ""
        self.assertTrue(validate_calendar(modified, self.social))

    def test_annual_distribution_is_rejected_if_event_removed(self):
        modified = copy.deepcopy(self.social)
        modified["festivals"].pop()
        self.assertTrue(validate_calendar(self.offerings, modified))


class QAWorkflowSafetyTests(unittest.TestCase):
    def test_all_workflows_are_free_of_codex_and_privileged_triggers(self):
        workflows = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
        self.assertGreaterEqual(len(workflows), 6)
        for workflow in workflows:
            with self.subTest(workflow=workflow.name):
                self.assertEqual(workflow_risks(workflow.read_text(encoding="utf-8")), [])

    def test_codex_action_mutation_detected(self):
        self.assertTrue(workflow_risks("steps:\n  - uses: vendor/codex-action@v1\n"))

    def test_privileged_trigger_mutation_detected(self):
        self.assertTrue(workflow_risks("on:\n  pull_request_target:\n"))

    def test_write_permission_mutation_detected(self):
        self.assertTrue(workflow_risks("permissions:\n  contents: write\n"))

    def test_native_qa_workflow_uses_real_godot_and_isolated_user_data(self):
        workflow = (WORKFLOWS / "everbloom-qa-multiyear.yml").read_text(encoding="utf-8")
        self.assertIn("sha256sum --check", workflow)
        self.assertIn("native_qa_multiyear.gd", workflow)
        self.assertIn("XDG_DATA_HOME", workflow)
        self.assertIn("EVERBLOOM QA MULTIYEAR NATIVE:", workflow)
        self.assertEqual(workflow_risks(workflow), [])


if __name__ == "__main__":
    unittest.main()
