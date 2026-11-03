# EVERBLOOM B13/B19 — native construction save-extension preflight

**Status: test-only characterization. Phase C CLOSED. Not a construction feature, approved schema migration, or playable cottage.**

## Scope and source
- Pinned charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Canonical main at claim: `f37cf0f214cab00f75ba62dba9c3a1339e6c40a8`.
- Isolated branch: `game/everbloom-construction-b13-save-preflight-20261102`.
- New Construction-owned paths only: this document, `native_acceptance.gd`, and a dedicated push-only native CI workflow. Production `scripts/game.gd`, `scripts/save_service.gd`, domain scripts, assets, catalogs and player saves are untouched.
- Existing cross-branch 220 ledger is documented, but semantic and authority gates remain open.

## Native, assembled-game risk characterization
The test instantiates the real `scenes/main.tscn`, uses actual `Game.save_game()`, `Game.load_game()`, `SaveService.validate_payload()`, `write_payload()`, and `read_payload()`. It checks the 56→57 and 112→113 epoch boundaries and conserves pre-existing inventory, currency, Farm, Animals, Village and Festival state through a prospective extension save/load/re-save.

The probe uses a **synthetic, never-authorized** top-level `construction` dictionary with nested structures, mock escrow, unique receipts, and unknown nested data. A separate in-memory hostile probe has duplicate receipts and a future epoch. No live construction gameplay, resource spending, or migration is performed.

Possible findings:
1. **SAFE REJECTION:** `SaveService.validate_payload` rejects unknown construction state; no prospective state reaches game load.
2. **SAFE PRESERVATION:** the extension is admitted and the assembled game preserves its full nested state through load/re-save.
3. **BLOCKER — SILENT LOSS:** the extension is admitted and stored but `Game.load_game` / `save_game` drop it. This is a prospective integration defect, not a defect affecting current schema-1 construction data (none exists).
4. **BLOCKER — RECEIPT ADMISSION:** duplicate or future construction receipts are accepted because the existing schema does not yet authorize construction fields.

The runner prints exact classification lines. **Its exit code 0 means the characterization ran correctly, not that Phase C is safe.** A `BLOCKER` line must not be described as a passing feature gate. CI fails on assertion errors, malformed native scripts, missing or corrupt snapshots, or unexpected loss of existing domain data.

## Reproduce safely
Use **only an isolated disposable Godot user-data directory** (CI uses a fresh `XDG_DATA_HOME`). The script refuses to run if a primary, temp, backup, quarantine or writer lock already exists. Never run it against a real player's `user://`.

```bash
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script res://docs/innovation/construction/save_preflight/native_acceptance.gd
```

The CI job downloads the checksum-pinned official Godot 4.7.2 binary, checks the exact GitHub checkout SHA, imports scripts, runs the actual game-scene preflight, and preserves raw logs. General source/native validation also runs on push. No PR is created because existing general validation has a pull-request trigger and automated reviews are not authorized.

## Authority and next integration gates
- **Principal P03/P04:** define explicit versioned construction save namespace, reject unknown active state or preserve it without loss, bound nested structures, authorize global receipt uniqueness, future-epoch and migration rules, and test crash-safe full-game roundtrip.
- **Farming:** approve finite real wood/stone supply, single-debit escrow and compensating refunds. This preflight's escrow is inert data.
- **Village/Emergence:** own NPC consent, privacy and cross-feature receipt domains.
- **Construction B02/B03/B13/B20:** only after the complete 220 catalog receives independent semantic and authority approval, implement Godot placement/undo/save/load with native acceptance and measured mobile/desktop performance.

No Codex, force push, merge, publication, unapproved spending, proprietary assets, or engine port.
