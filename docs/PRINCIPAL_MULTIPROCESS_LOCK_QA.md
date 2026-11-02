# Principal P04/P05/P16 — actual-process save writer lock regression

**Scope:** Isolated, non-Codex, Linux/Godot 4.7.2 native acceptance. This is a regression gate, not a claim of cross-platform transactional durability or a new gameplay feature.

## Why this test exists

The existing `principal_recovery_acceptance.gd` simulates a held lock inside one Godot process. That proves lock rejection but not exclusion between two independently scheduled processes. This additional test launches an actual holder and contender as separate Godot processes against one newly created `XDG_DATA_HOME`, then deliberately kills the holder to reproduce a crash-stranded lock. No player save directory is touched.

## Deterministic sequence and required observations

1. **Seed** a valid schema-1 primary (150 petals, 50 turnips) and prior backup (125 petals, 25 turnips), with stable calendar, Village relationship and paddock fixtures.
2. **Hold** the exclusive writer-lock directory in an independent Godot process. The process flushes a readiness marker before contention begins. CI confirms that the holder remains alive.
3. **Contend** from another Godot process. A proposed 999-petal write must fail. Primary and backup bytes must remain exactly unchanged, no temp file may be created, and money/items must not duplicate.
4. **Crash** the holder with SIGKILL, reap it and verify that a second write still fails closed because the abandoned lock remains. No heuristic stale-lock deletion is permitted in game code.
5. **Recover** only within the disposable CI directory, after proving the holder exited. Remove exactly the known isolated lock directory with `rmdir`, then commit a 175-petal save. Primary must have 75 turnips, backup must remain the previous 150-petal/50-turnip state, and temp/lock must be absent.

Each worker emits a `PRINCIPAL MULTIPROCESS <mode>: N assertions, 0 failures` receipt. The holder's readiness marker and process liveness are verified by the shell coordinator. The workflow archives separate seed, holder, live-contention, crash-stale and recovered-commit logs, named by exact `github.sha`.

## Ownership and reproducibility

- Isolated branch: `game/everbloom-principal-p05-multiprocess-20261102`.
- Principal-only new files: `scripts/principal_multiprocess_probe.gd`, `.github/workflows/everbloom-principal-multiprocess-lock.yml`, this document.
- CI uses official Godot 4.7.2 Linux executable with a pinned SHA-256, native headless import, and isolated process tests. It is push-triggered only; no PR or Codex workflow.
- Local reproduction requires Linux, Bash, coreutils, Godot 4.7.2, a fresh isolated `XDG_DATA_HOME`, and the workflow's exact shell commands. **Never** run this destructive fault fixture against an existing user-data directory.
- No SaveService or other runtime code is changed by this QA increment. Farming, Village, Valley, Construction and Emergence paths are untouched.

## Boundaries and outstanding engineering work

A passing result demonstrates **Linux filesystem process exclusion under this specific runner**, not Windows/NTFS or Android/iOS behavior. SIGKILL models process termination, not abrupt power removal or filesystem cache loss; it cannot establish fsync durability. Manual lock removal is safe here only because the runner owns the disposable directory and reaps the holder. Actual player stale-lock recovery requires a separately designed owner-confirmed protocol with process-liveness checks and backups. Physical input devices, device performance, cross-machine storage and full schema migrations remain unverified.

Mission states: P04 **implementing**; P05 **native-tested partial** only after exact-head workflow success; P16 **native-tested partial** only after exact-head workflow success. P18 remains an integration handoff until coordinated reconciliation. The 220-feature innovation implementation gate remains closed.
