# EVERBLOOM Principal P11/P12 — Save Health report navigation

**Ownership:** Principal Systems Architect. **Engine:** Godot 4.x only. **Status:** candidate; do not claim integrated or device-verified before exact-HEAD native CI and reconciliation. **Authority:** presentation-only; `SaveService.inspect_save_health()` remains the single read-only diagnostic source.

## Player verbs, feedback and controls

Open Save Health with **Y**, **controller Start**, or the existing on-screen touch button while no other modal is active. The report explicitly displays English/Spanish scrolling guidance. With the modal open, **PageDown / PageUp** and **controller RB / LB** scroll the report by 65% of its visible height (minimum 48 logical pixels). The native Godot ScrollContainer continues to support touch dragging and mouse-wheel scrolling; its report area is focusable for keyboard/gamepad navigation. **B / Escape / Return** closes the modal. The existing Refresh action resets the report to its authoritative diagnostic content and the scroll position to zero.

Scrolling clamps to the visible report range and never changes gameplay time, RNG, money, inventory, relationships, farm state, writer locks, or primary/backup/temp bytes. Input is consumed only while this modal is open; it is not a new global input map. Modal exclusion remains owned by the existing Principal panel and Village read-only visibility signals.

## Acceptance and deterministic regression

The native `scripts/principal_save_health_panel_acceptance.gd` test instantiates the **assembled Game**, forces 80 lines of report overflow, waits for layout, verifies actual scroll range, and injects physical PageDown/PageUp and gamepad shoulder-button events. It checks forward/backward scrolling, reset on refresh, bilingual guidance, modal gating, and economy/calendar/save-byte conservation. This tests simulated Godot input events, **not** a physical gamepad or a mobile device. The existing push-only `.github/workflows/everbloom-principal-save-health-ui.yml` runs the exact-commit Godot 4.7.2 editor import and native acceptance; general source/scene/save CI is an independent gate.

## Dependencies, original assets and performance

Depends only on existing Godot `ScrollContainer`, `VScrollBar`, `Label`, `Button`, `InputEventKey`, and `InputEventJoypadButton` APIs; no new resources or proprietary assets. Existing UI uses original procedural controls and system fonts. Scroll handling is O(1) per discrete input and allocates no persistent state; this is an **algorithmic estimate**, not a measured frame-time, battery, touch, or controller result. Desktop/mobile profiling, actual hardware input, screen readers, dynamic text scaling, and narrow-device safe-area tests remain open.

**Cross-loop contract:** no Farming/Village/Construction/Emergence source changes; no save-schema or innovation-catalog modifications. Phase C remains closed until the audited 220-record ledger passes the independent implementation gate. No Codex, PR auto-review, force push, spend, publication, or engine port.
