# EVERBLOOM B02/B03/B13 — detached construction command-journal oracle

**Status: isolated reference-model QA, NOT playable Godot construction. Phase C CLOSED.**

## Source, branch and ownership

- Charter read at explicit pinned commit `b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Source canonical main at claim: `211049b412b7e246dea12afd30f497fdb0decd70`.
- Isolated branch: `game/everbloom-construction-b13-command-journal-oracle-20261102`.
- New Construction-owned paths only: `docs/innovation/construction/command_journal/reference.py`, this document, and dedicated push-only CI workflow. No existing game source, saves, asset files, original innovation catalogs, or other lanes are changed.
- Existing B011–B110 typed contracts and namespace dry-run policy remain separately versioned; this oracle does not silently approve or replace them.

## Deterministic test-only contract

`reference.py` models a small four-part **test cottage** (foundation → post → wall → roof) with typed parent/socket checks, bounded integer-grid footprint, strict receipts, monotonic `day_epoch`, fixed mock timber/stone escrow, and a replay-derived canonical JSON snapshot. It is a bounded **negative-test oracle** for interface review, not B20's cottage implementation.

A `place` command requires unique `receipt`, `piece_id`, `epoch`, `device`, `kind`, `parent`, `socket`, and integer `position`. `undo` and `redo` have their own unique receipts and reverse/reapply fixed mock costs. `tick` advances a monotonic epoch. All commands reject unknown fields, duplicate receipts, impossible parent types, socket reuse, footprint overlap, invalid coordinates, exhausted escrow and backward calendar time. Rejecting a command leaves the original snapshot unchanged. Snapshot loading recomputes the full journal and rejects tampering of materials, pieces, epoch, receipt history and nested structure. Deterministic hashes permit replay comparison.

**Limits:** 128 active parts, 1,024 commands, coordinates -32..32, epoch 1..10,000,000; exactly one foundation in this reference dwelling. Mock starting escrow is 24 timber and 12 stone. These values are fixtures, not approved gameplay balancing. Only four exemplar part kinds are covered. No procedural mesh generation, real collision/terrain physics, nav graph, original art assets, live money/material ledger, NPC consent, UI, animation, or Godot scene is implemented.

## Player-facing design and engine contracts (not implemented)

- Keyboard/mouse: hover ghost, grid/snap selection, click confirm, keyboard undo/redo.
- Gamepad: left stick cursor, D-pad precision nudge, shoulder socket cycle, A confirm, B cancel; explicit undo/redo actions.
- Touch: drag ghost, tap socket, two-step confirmation and visible undo affordance; no gesture-only critical command.
- One input-normalization adapter should emit the same domain command regardless of device. Reference test checks keyboard, mouse, gamepad and touch **semantic state parity** only; it does not simulate physical devices.
- UI feedback: typed socket mismatch, collision, insufficient resources and duplicate receipt must have distinct non-destructive rejection messages; ghost preview should remain reversible. Original stylized-realistic modular beam/stone/roof kit needs independent provenance and mobile/desktop LOD review.
- Proposed performance budget for later design review: <=0.5 ms validation per preview on desktop and <=1 ms on mobile, <=128 active pieces, no per-frame full journal replay. **No device benchmarks measured.** Replay-all is deliberately a test oracle and unsuitable for per-frame production use.

## Reproduction and acceptance

```bash
python3 docs/innovation/construction/command_journal/reference.py
```

The standalone Python unittest suite covers four-part assembly, cost conservation across undo/redo, duplicate receipts, typed sockets, overlapping footprint, no second foundation, malformed coordinates, immutable failures, corrupted saves, cross-device semantic equivalence, 56→57 and 112→113 annual boundaries, and 113-day replay/checkpoints. Dedicated CI runs this exact file; the existing general push workflow separately checks native Godot import/smoke/save recovery at the same SHA. Native baseline PASS does **not** prove these reference commands run in Godot.

## Required authority approvals before integration

- **Principal P02/P03/P04/P07:** approve global receipt scope, authoritative command envelopes, epoch and save migration, undo/replay transaction ordering, and input adapter.
- **Farming F19:** approve real inventory reservation/debit/refund and compensating transactions; mock escrow cannot mint or consume real materials.
- **Village/Emergence:** approve consent and privacy semantics for community structures, cross-feature event receipts and NPC occupancy.
- **Construction B01/B02/B03/B13/B20:** replace mock part catalog with real structural and terrain rules only after 220-ledger gate; add native Godot scene/input/atomic persistence tests and measured mobile performance.

No Codex, PR, force push, merge, publication, paid service, proprietary assets or premature engine port.
