#!/usr/bin/env python3
"""Reproducible first-party EVERBLOOM source-only archive.

No engine binary, third-party game assets, release upload or deployment.
The manifest is content-addressed; repeated packaging of the same Git HEAD
produces byte-identical ZIPs across ordinary Python 3.12 Linux CI runs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
FORBIDDEN_NAMES = {".env", ".env.local", "id_rsa", "id_ed25519"}
FORBIDDEN_SUFFIXES = {".pem", ".p12", ".pfx", ".key", ".sqlite", ".db"}


def tracked_paths(root: Path) -> list[str]:
    output = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"])
    names = [part.decode("utf-8") for part in output.split(b"\0") if part]
    if len(names) != len(set(names)):
        raise ValueError("duplicate tracked source path")
    for name in names:
        relative = PurePosixPath(name)
        if (not name or relative.is_absolute() or ".." in relative.parts
                or "\\" in name or name.startswith("./")):
            raise ValueError(f"unsafe tracked path: {name!r}")
        if (any(segment in {".git", ".godot", "__pycache__"} for segment in relative.parts)
                or relative.name in FORBIDDEN_NAMES
                or relative.suffix.lower() in FORBIDDEN_SUFFIXES):
            raise ValueError(f"unsafe tracked artifact: {name}")
        source = root / name
        if not source.is_file() or source.is_symlink():
            raise ValueError(f"missing or linked source file: {name}")
    return sorted(names)


def validate_provenance(paths: list[str], document: dict) -> None:
    if not isinstance(document, dict) or document.get("schema_version") != 1:
        raise ValueError("asset provenance schema invalid")
    records = document.get("assets")
    if not isinstance(records, list):
        raise ValueError("asset provenance entries missing")
    expected = {name for name in paths
                if name.startswith("assets/") and name != "assets/provenance.json"}
    recorded: set[str] = set()
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("malformed provenance record")
        name = record.get("path")
        if not isinstance(name, str) or name in recorded:
            raise ValueError(f"duplicate/invalid provenance asset: {name!r}")
        recorded.add(name)
        for field in ("creator", "source", "license"):
            if not isinstance(record.get(field), str) or not record[field].strip():
                raise ValueError(f"{name}: missing {field}")
        if record["license"].strip().lower() in {"unknown", "unverified", "tbd"}:
            raise ValueError(f"{name}: unverified redistribution rights")
    if expected != recorded:
        raise ValueError(f"asset provenance mismatch; missing={sorted(expected - recorded)}, "
                         f"extra={sorted(recorded - expected)}")


def make_archive(root: Path, output: Path) -> tuple[int, str]:
    files = tracked_paths(root)
    if "project.godot" not in files or "assets/provenance.json" not in files:
        raise ValueError("not a complete EVERBLOOM source checkout")
    provenance = json.loads((root / "assets/provenance.json").read_text(encoding="utf-8"))
    validate_provenance(files, provenance)
    revision = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    manifest = "".join(
        f"{hashlib.sha256((root / name).read_bytes()).hexdigest()}  {name}\n"
        for name in files
    ).encode("utf-8")
    metadata = json.dumps({
        "project": "EVERBLOOM: The Living Valley",
        "type": "source-only; no native binary or runtime certification",
        "git_revision": revision,
        "file_count": len(files),
        "manifest": "MANIFEST.sha256",
    }, sort_keys=True, separators=(",", ":")).encode("utf-8") + b"\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9, strict_timestamps=True) as archive:
        entries = [(name, (root / name).read_bytes()) for name in files]
        entries.extend([("MANIFEST.sha256", manifest), ("SOURCE_BUILD.json", metadata)])
        for name, data in sorted(entries):
            info = zipfile.ZipInfo(name, date_time=FIXED_TIME)
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED,
                             compresslevel=9)
    return len(files), hashlib.sha256(output.read_bytes()).hexdigest()


def verify_archive(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or names != sorted(names):
            raise ValueError("archive names duplicate or noncanonical")
        lines = archive.read("MANIFEST.sha256").decode("utf-8").splitlines()
        declared: set[str] = set()
        for line in lines:
            if len(line) < 67 or line[64:66] != "  ":
                raise ValueError("invalid checksum manifest line")
            name = line[66:]
            if name in declared or name not in names:
                raise ValueError("missing/duplicate manifest file")
            declared.add(name)
            if hashlib.sha256(archive.read(name)).hexdigest() != line[:64]:
                raise ValueError(f"archive content mismatch: {name}")
        if declared != set(names) - {"MANIFEST.sha256", "SOURCE_BUILD.json"}:
            raise ValueError("manifest does not cover every source entry")
        metadata = json.loads(archive.read("SOURCE_BUILD.json"))
        if metadata.get("file_count") != len(declared):
            raise ValueError("source count metadata mismatch")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        count, digest = make_archive(ROOT, args.output)
        verify_archive(args.output)
    except (ValueError, OSError, subprocess.CalledProcessError,
            json.JSONDecodeError, zipfile.BadZipFile) as exc:
        print(f"QA SOURCE PACKAGE FAIL: {exc}", file=sys.stderr)
        return 1
    print(f"QA SOURCE PACKAGE PASS: {count} tracked files, SHA256 {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
