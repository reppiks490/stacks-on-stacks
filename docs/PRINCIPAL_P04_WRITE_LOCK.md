# P04/P05 — Exclusive local save-writer contract (2026-11-02)

**Scope:** Original EVERBLOOM Godot 4.x baseline, Principal-owned `scripts/save_service.gd`. This is a bounded concurrency improvement, **not** proof of crash durability, power-loss atomicity, Windows file locking, schema migration or multiplayer safety.

## Player-visible scenario

Two local game processes or two save callers may attempt to write the same `user://everbloom_save_v1.json`. Previously both could overwrite the shared `.tmp`, rotate `.bak`, and replace the primary concurrently, causing lost progress or mismatched backup. The writer now acquires an exclusive filesystem directory `user://everbloom_save_v1.json.writer.lock` before touching temporary, primary, backup or quarantine paths. The second writer fails closed; Game.save_game() displays its existing save-failure feedback. No currency, inventory, crops, livestock, Village memories or festival awards are minted or changed by the rejected writer.

## Authority and interfaces

- `SaveService.write_payload(Dictionary) -> bool`: validates first, then acquires the lock with `DirAccess.make_dir_absolute`; only the owner calls `_write_payload_under_lock`; it releases the lock after success **or** ordinary failure.
- Existing `SaveService.read_payload()`, `validate_payload()`, schema-1 JSON, the 56-day monotonic `day_epoch`, and domain `save_state/load_state` interfaces are unchanged.
- A preexisting lock is treated as held or stale; **never auto-delete** it. After an abnormal crash, a knowledgeable owner must ensure all game processes are closed, preserve the save/backup/quarantine evidence, and only then remove the empty lock directory. A stale lock deliberately blocks automatic saving until resolved.
- Lock cleanup failure reports failure, even if the snapshot was already committed. The caller must inspect the saved state before retrying. This cannot guarantee no ambiguity after a filesystem failure.
- Existing temp/backup/quarantine semantics are unchanged. A crash between primary removal and temp promotion may still leave a missing primary recoverable from backup. No filesystem `fsync` of file and parent directory is claimed.
- Single-host local filesystem only. Network-mounted filesystems with non-atomic directory creation are unsupported; no lock-stealing, PID/time heuristics, or automatic stale lock recovery.

## Native acceptance

`scripts/principal_recovery_acceptance.gd` runs on an isolated CI `XDG_DATA_HOME`. It creates a simulated lock before the first write and after valid primary/backup creation, proves rejected writers leave all primary/backup/temp bytes unchanged, removes the simulated lock, and verifies ordinary saving and recovery still work. `tests/test_save_contract.py` guards the contract. Require exact-commit Godot native CI, two-year assembled QA, festival QA and general import/Python checks. CI proof does not substitute for simultaneous-process or Windows desktop testing.

## Device, visuals and dependency budget

This is a save-boundary service, not a new interactive invention. Existing keyboard save key and HUD failure text remain; controller/touch parity is pending Principal P11. No new art assets; existing original HUD is reused. The uncontended path adds one directory creation and removal per save (O(1) filesystem operations), with no per-frame overhead. Measure actual Windows/mobile storage latency before setting a device budget. Depends on Godot `DirAccess`, `FileAccess`, local `user://` storage, and all domain snapshots. No innovation Phase-C implementation or engine migration is authorized.

**Mission status:** P04 implementing / native-tested only when exact SHA native receipts exist; P05 adversarial acceptance expanded; P18 coordinated through issue #2. Windows lock semantics, power-loss recovery, true simultaneous-process stress, migration and native physical input remain open.
