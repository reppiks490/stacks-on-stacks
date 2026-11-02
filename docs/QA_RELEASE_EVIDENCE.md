# EVERBLOOM QA release evidence and outstanding gates

**Scope:** Independent QA lane only. This is an original Godot source project,
not a claim of a finished game, shipping binary, certified controller support,
or tested mobile performance. Do not use proprietary Harvest Moon assets.

## Reproducible candidate

- Branch: `qa/everbloom-multiyear-recovery-20261102`; baseline
  `main@3d5bbab736627b2f662c12550765648ecac519b9`.
- `tests/native_qa_multiyear.gd` instantiates the actual main scene,
  calls 112 successive `Game.next_day()` operations (two complete years),
  verifies the 30-bed farm, three paddocks, village memory, full save validation,
  annual festival rewards, reload and corrupted-primary/unfinished-temp fallback.
  It deliberately does **not** simulate real user input or a rendered playthrough.
- `tools/qa_calendar_contract.py` validates the 12 contribution festivals and
  four separate village social gatherings as **16 non-overlapping original
  occasions**, three contribution plus one social event per season.
- `tests/test_qa_calendar_contract.py` introduces adversarial data mutations
  (cross-catalog ID/day collisions, fractional/out-of-range dates, malformed
  hours, missing rain plan) and conservative workflow-source checks for Codex,
  privileged triggers and write permissions.
- `.github/workflows/everbloom-qa-multiyear.yml` runs those Python tests,
  downloads the checksum-verified official Godot 4.7.2 Linux binary,
  performs a native import and executes the real 112-day scene harness.
  The `XDG_DATA_HOME` directory is job-local; the harness refuses to erase
  a pre-existing save. The CI runner is Linux, not Windows/mobile hardware.

**Evidence status:** Native QA at source commit `a37b6dd13d39d25707bb870e743b16aa0ac8781b`
passed **927 assertions, zero failures**, plus 13 Python QA tests:
[dedicated native run 41402341282](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41402341282).
General Python/native import/120-frame smoke/save also passed at that exact
source SHA: [run 41402341374](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41402341374).
Earlier QA trial [41402276932](https://github.com/reppiks490/stacks-on-stacks/actions/runs/41402276932)
failed one whole-array pasture comparison; the fixed test compares numeric forage
per paddock. The deliberately corrupted JSON triggers expected Godot parse-error
diagnostics during fallback, while the assertions verify valid backup recovery.
**Any later branch tip still requires its own exact-head CI confirmation.**

## Release blockers and integration handoffs

1. **Save recovery is read-only after primary corruption.** The principal-owned
   `SaveService.read_payload()` can load a valid backup when the primary JSON
   is corrupt, but `write_payload()` explicitly refuses to overwrite an
   existing invalid primary. Thus gameplay may resume from backup yet cannot
   save again until the damaged primary is safely quarantined/recovered.
   Principal should implement a tested, no-data-loss recovery promotion and
   cover disk-full, interrupted rename, Windows file locking, stale temp,
   and backup corruption. QA must rerun native assembled-game tests afterward.
2. **Controller/touch is not implemented in the shared game input contract.**
   `scripts/game.gd` currently registers keyboard `InputEventKey` mappings
   for actions. No native joypad/touch mappings or accessibility focus-flow
   proof is present. No claims of controller/mobile support until native input
   dispatch, screen reader/captions, scaling and real-device tests pass.
3. **Long-term save schema and gameplay:** schema-1 roundtrip does not establish
   schema migration, multiple slots, durable sync/fsync, crash consistency,
   anti-tamper, or multi-hour interactive progression. The 112-day test calls
   `next_day()` directly; it does not prove 112 days of manual play.
4. **Performance/art:** no device-level CPU/GPU memory, frame-time,
   controller latency, battery, thermal or touch data has been measured by QA.
   Original authored music, models, animations and provenance need independent
   review; primitive geometry is not production-complete.
5. **Calendar presentation:** the two catalogs contain distinct 16 event days,
   but the current UI does not prove a unified 16-entry calendar or meaningful
   NPC attendance. Village/Principal should coordinate a single player-facing
   calendar without double-granting awards.

## Merge gate

No PR creation or auto-review. Check all workflow triggers first, require
**exact-commit** green general CI and dedicated QA native CI, then obtain
Principal integration coordination and non-destructive reconciliation.
No force push, branch deletion, publication, unapproved spend or Codex.
