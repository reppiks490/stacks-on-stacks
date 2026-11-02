# EVERBLOOM Principal P12/P11 — accessible Save Health text scaling

**Owner:** Principal Systems Architect. **Engine:** Godot 4.x only. **Status:** implementation candidate pending exact-HEAD native CI and integration. **Authority:** Save Health presentation; no domain, currency, inventory, calendar, save, recovery or lock mutations.

## Player interaction, UI feedback and state

While the read-only Save Health report is open, players can increase/decrease text using the two 44-logical-pixel-minimum on-screen buttons, **F10/F9**, or controller **D-pad Up/Down**. Both controls are focusable. Five deterministic size levels are available: 85%, 100% (default), 120%, 140%, 160%. Changes immediately resize title, report, and action text; boundary buttons disable at the minimum/maximum. English and Spanish instructions and control labels are shown in the report. Existing PageUp/PageDown, LB/RB and touch-drag report navigation remain active. The original modal pause, refresh, close and read-only diagnostic rules remain intact.

**State semantics:** `text_scale_index` is an ephemeral presentation-only session preference. It is intentionally **not** written to the game save or to disk. Reopening the modal in the same running session preserves the selected size; restarting the game resets to 100%. Changing text size must not affect the authoritative `SaveService.inspect_save_health()` dictionary, game RNG, `day_epoch`, inventory, currency, relationships, or any primary/backup/temp bytes. This avoids introducing an unreviewed save-schema migration.

**Modal safety:** the Principal Save Health panel now explicitly checks the newer Village gift chooser in addition to the existing topic/journal and paused-session gates. The gift chooser is Village-owned; this change does not alter its implementation or authority. If a gift modal is visible, Save Health refuses to open even if a synthetic test has not yet paused the scene.

## Acceptance and native regression

`scripts/principal_save_health_panel_acceptance.gd` instantiates the actual assembled `game.gd`, checks default fonts and minimum touch targets, simulates F9/F10 and controller D-pad inputs, emits button presses, verifies real Godot theme font sizes and clamped limits, and tests gift-modal exclusion. Existing acceptance exercises genuine 80-line scroll overflow, bilingual diagnostics, primary/backup corruption, lock reports, save-byte conservation, calendar and inventory. The push-only `.github/workflows/everbloom-principal-save-health-ui.yml` runs checksum-pinned Godot 4.7.2 editor import and assembled native acceptance; general validation is a separate exact-head gate. No PR is required or authorized.

## Original asset, dependency, performance and port boundary

Uses existing original Godot `CanvasLayer`, `PanelContainer`, `Button`, `Label`, `ScrollContainer` and system-font rendering. No external artwork, font files, music, proprietary assets, new packages or spending. Scale changes update a constant number of text controls; no per-frame reformat loop was added. This is an algorithmic estimate, **not measured mobile/desktop frame time**. Real hardware gamepad focus, phone safe-area layouts, touch scrolling, screen readers, and narrow-screen/large-text overflow still need hands-on testing. Engine-neutral save and domain contracts remain untouched; Unreal/Unity port gate remains closed.

## Cross-loop handoff

Only Principal-owned panel, acceptance and this document are changed. Farming, Village, Construction and Emergence source/assets/catalogs are untouched. Innovation Phase C stays closed until the entire 220-record ledger passes the independent semantic and authority gate. No Codex in any form, no PR, force push, branch deletion, publication, spending, or premature engine port.
