# Principal P05/P11/P12 — Save-health player readability and scrolling

**Owner:** Principal Systems Architect. **Status:** implementing; native verification required at exact candidate SHA before integration. **Engine:** Godot 4.x only. **Scope:** read-only player-facing diagnostics in `scripts/principal_save_health_panel.gd`, plus assembled-game acceptance. No save schema, save writer, farm, Village, Construction, Emergence or innovation-ledger changes.

## Player behavior and interaction

Opening the Save Health panel via keyboard **Y**, controller **Start** or the existing 48-pixel touch button pauses the simulation. The player sees a localized title, readable English/Spanish statuses for primary, backup, interrupted temp, load source and writer lock. Damaged JSON, invalid payload, inaccessible file, absent file and healthy file are distinct. Unknown future machine codes display a generic warning instead of raw internal tokens. A `ScrollContainer` allows long reports to scroll without displacing the Refresh and Return buttons. The diagnostic dictionary is unchanged for support tools.

Refresh and Return remain focusable, touch-sized buttons. Controller **B** and keyboard **Escape** close the modal, restoring the prior pause state. All inspection is read-only: the panel cannot write, load, quarantine, unlock or delete player files. Active locks are never assumed stale.

## Authority, save and replay

`SaveService.inspect_save_health()` remains the sole status authority; `_human_status()` translates presentation only. The game retains sole ownership of save/load operations, and the panel blocks both while open. No new persistent fields, currency/item changes or RNG use. Two-year `day_epoch` and nested domain roundtrips remain unchanged.

## Assets, accessibility, and performance

Only original procedural UI styling and system fonts; no third-party assets or extracted game materials. The text report uses wrapping and vertical scrolling, with 44–48px minimum action targets. The existing modal title was English-only; now it follows the Village EN/ES setting. Expected inspection cost remains bounded by local file size, but **no measured mobile frame/memory results** are claimed. Screen-reader output, contrast audit, actual physical gamepad navigation and real-device touch scrolling remain **unverified**. A production mobile build must measure viewport fit and touch hit targets on device.

## Deterministic regression and dependency map

`scripts/principal_save_health_panel_acceptance.gd` exercises the real assembled `Game`, creates only an isolated CI `user://` profile, checks readable English/Spanish corruption and lock states, scroll configuration, input events, and byte-for-byte preservation of primary/backup. Dedicated non-Codex push workflow `.github/workflows/everbloom-principal-save-health-ui.yml` runs official checksum-pinned Godot native import and assertions. General Godot/Python validation is a separate gate. Never run the destructive test in a player profile.

**Handoff:** Farming/Village continue their own gameplay files. Construction/Emergence innovation Phase C remains closed until the entire 220-ledger audit is complete. Principal owns the panel and tests; cross-loop integration requires exact-HEAD CI and non-force fast-forward. No PR due to possible auto-review triggers. No Codex or paid services.
