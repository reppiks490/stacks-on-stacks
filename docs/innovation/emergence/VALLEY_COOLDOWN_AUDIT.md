# EVERBLOOM — E18 Native Valley Cooldown Diagnostic (2026-11-02)

**Owner:** Emergence Architect, E18 independent adversarial QA. **State:** diagnostic branch; no gameplay fix. **Godot:** 4.x only. **Source baseline:** canonical main `bbc38294952c2f76c1898747968d2ce2d220890c`. **Branch:** `qa/everbloom-emergence-valley-repro-20261102`. **Owned files:** new `tests/native_emergence_valley_audit.gd`, new `.github/workflows/everbloom-emergence-valley-audit.yml`, this document. No edits to `game.gd`, `valley.gd`, `save_service.gd`, or any other lane's source.

## Reproducible defects and exact mechanics

The current `scripts/valley.gd` keeps `fishing_day` and `forage_day` initialized to -1 in volatile node state. Its `act()` compares those values to `game.day` (1..14), not the already available monotonic `game.day_epoch()`. The assembled `scripts/game.gd` save payload serializes Farm, Village, Animals and Festivals but not Valley state. Two separate classes of defect follow:

1. **Reload duplication:** catch one fish (+1 fish, -8 energy) and gather once (+2 wild_herb, -3 energy) on Spring 1, save, dispose of the original scene, instantiate a fresh actual main scene, load the valid save, and interact at the same lake and grove. Without persisted cooldowns, the new Valley node resets to -1 and allows another fish and two herbs on the same epoch. This is an unintended once-per-day gate bypass, not a legitimate second-day harvest.
2. **Cross-season day aliasing:** in the reloaded session fish and forage on Spring 1, advance exactly 14 real `Game.next_day()` transitions to Summer 1 (epoch 15), then attempt the same actions. Since the stored day-of-season is still 1, both actions can be incorrectly denied even though a new monotonic day has begun. The same alias pattern can recur across years.

The native diagnostic executes the **real** `scenes/main.tscn`, real `valley.act`, actual inventory/energy accounting, `SaveService.write_payload/read_payload`, a fresh scene restart, and 14 real calendar transitions. It does not mock the game coordinator or simulate results using source-text matches. It uses an isolated `XDG_DATA_HOME` and refuses to overwrite existing save files.

The output contains a JSON object of five independent observations:
- `save_omits_valley_cooldowns`
- `same_day_reload_fish_duplicate`
- `same_day_reload_forage_duplicate`
- `season_day_alias_blocks_fishing`
- `season_day_alias_blocks_foraging`

**Important test semantics:** A green diagnostic means the harness executed successfully with no harness errors; it does **not** mean the cooldown defects were fixed. The observations may be true or false as the implementation evolves. The final source SHA and native log must be inspected to establish which issues remain. The workflow never intentionally fails merely because an existing defect is reproduced; when Principal and Valley owners fix the bug, convert this into an enforcing regression acceptance test and require all five findings false.

## Proposed owner-coordinated remediation — NOT implemented here

- **Valley source owner:** replace day-of-season fields with monotonic `fishing_epoch` and `forage_epoch`; expose bounded `save_state()/load_state()` for the two cooldown epochs. Failed interactions must never consume energy, grant items or change restoration.
- **Principal calendar/save owner:** add a backward-compatible optional Valley snapshot to the assembled save (no second hidden save); validate type, nonnegative/bounded integer epochs, no future epoch relative to the saved 56-day calendar, and reject corrupt payloads without mutating active session. Existing schema-1 saves without Valley state require an explicit conservative default/migration policy.
- **Shared QA:** after owner-approved changes, run this native reproducer in enforcing mode, 112-day assembled QA, native save corruption and backup-recovery tests, and seasonal/year rollovers. Check no duplicate fish/herbs/restoration, no energy minting, no denied legitimate new-day catch, no save corruption or accidental farm/village/animal state changes.
- **Accessibility and game feel:** show a readable cooldown message for both fishing and foraging, with keyboard, gamepad and touch parity. Those physical-device tests are not established by this diagnostic.

## Policy, boundaries and current phase gate

All seven existing GitHub workflow bodies were inspected on `main` before writing: no Codex or privileged review step was found. This new workflow uses read-only checkout, checksum-pinned official Godot, headless import, native diagnostic and short-retention log artifacts. No PR, force push, paid service, proprietary assets, game implementation, external release or engine migration.

Construction's Phase-A joint review at `game/everbloom-construction-crossaudit-20261102@04948bb8492fdeca4ab6e46c0050ce5e0d6670dc` mechanically audits the 20 original concepts and eight interface contracts. **Principal acceptance is still pending.** Do not start the additional 200 ideas or new Emergence gameplay implementation until the Phase-A gate is explicitly accepted; existing baseline QA and defect correction may proceed.

**Evidence ledger:** Record this branch's final exact SHA and the corresponding successful native workflow run after it completes. Never describe the diagnostic as a verified gameplay fix or a physical mobile/controller test.
