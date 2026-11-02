"""Deterministic first-party source packaging and provenance mutation tests."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from tools.package_source import (
    ROOT, make_archive, tracked_paths, validate_provenance, verify_archive,
)


class QASourcePackagingTests(unittest.TestCase):
    def test_two_archives_of_same_commit_are_byte_identical(self):
        with tempfile.TemporaryDirectory(prefix="everbloom-qa-") as directory:
            first = Path(directory) / "first.zip"
            second = Path(directory) / "second.zip"
            count_a, digest_a = make_archive(ROOT, first)
            count_b, digest_b = make_archive(ROOT, second)
            self.assertGreater(count_a, 15)
            self.assertEqual(count_a, count_b)
            self.assertEqual(digest_a, digest_b)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            verify_archive(first)
            with zipfile.ZipFile(first) as archive:
                self.assertIn("project.godot", archive.namelist())
                self.assertIn("assets/provenance.json", archive.namelist())
                self.assertNotIn(".git/config", archive.namelist())
                metadata = json.loads(archive.read("SOURCE_BUILD.json"))
                self.assertIn("source-only", metadata["type"])

    def test_tracked_files_have_no_symlink_or_credential_artifacts(self):
        paths = tracked_paths(ROOT)
        self.assertIn("project.godot", paths)
        self.assertTrue(all(".git/" not in name and ".godot/" not in name for name in paths))

    def test_missing_asset_provenance_is_rejected(self):
        paths = ["assets/provenance.json", "assets/vector/everbloom_emblem.svg",
                 "assets/vector/undocumented.svg"]
        provenance = json.loads((ROOT / "assets/provenance.json").read_text(encoding="utf-8"))
        with self.assertRaisesRegex(ValueError, "provenance mismatch"):
            validate_provenance(paths, provenance)

    def test_unverified_asset_license_is_rejected(self):
        paths = ["assets/provenance.json", "assets/vector/everbloom_emblem.svg"]
        provenance = json.loads((ROOT / "assets/provenance.json").read_text(encoding="utf-8"))
        modified = copy.deepcopy(provenance)
        modified["assets"][0]["license"] = "unverified"
        with self.assertRaisesRegex(ValueError, "unverified redistribution rights"):
            validate_provenance(paths, modified)

    def test_manifest_detects_tampered_source(self):
        with tempfile.TemporaryDirectory(prefix="everbloom-qa-") as directory:
            clean = Path(directory) / "clean.zip"
            tampered = Path(directory) / "tampered.zip"
            make_archive(ROOT, clean)
            with zipfile.ZipFile(clean) as original, zipfile.ZipFile(
                tampered, "w", compression=zipfile.ZIP_DEFLATED
            ) as modified:
                for item in original.infolist():
                    data = original.read(item.filename)
                    if item.filename == "project.godot":
                        data += b"\n; unexpected mutation\n"
                    modified.writestr(item, data)
            with self.assertRaisesRegex(ValueError, "archive content mismatch"):
                verify_archive(tampered)


if __name__ == "__main__":
    unittest.main()
