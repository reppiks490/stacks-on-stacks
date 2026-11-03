# V19 / V05 — Conversation modal focus traversal (2026-11-02)

## Status and ownership
- Mission IDs: **V19**, **V05**, **V20**; bounded existing Godot baseline accessibility defect correction, **not** a completed mission or Phase-C innovation implementation.
- Isolated branch: `game/everbloom-village-v19-topic-focus-20261102`, based on `main@319e32da90a42dc235f9c509a8111992ad4bb3ac`.
- Exclusive Village paths: `scripts/village_topic_panel.gd`, `scripts/village_topic_panel_acceptance.gd`, this document. Principal owns `game.gd`, shared input/save and coordination doc.
- **No new save keys or domain mutations.** Existing Village `act("talk")` remains the sole rewarded talk authority.

## Defect and actual player interaction
Before this patch, the topic menu's D-pad Up/Down and keyboard arrows clamped between topic choices, never reaching the visible **Language** and **Cancel** controls. Players without pointer/Tab access could not reach those actions through the menu's advertised navigation. Also, confirming while no modal control held focus fell back to a previously selected rewarded topic.

Now, focus traversal follows all visible enabled topics, then **Language**, then **Cancel**, clamped at either end. Hidden locked topics and disabled controls are skipped. Controller A/keyboard Enter activates the **actual** focused control; a missing/foreign focus does nothing instead of initiating a talk. Direct 1–4 topic shortcuts, C/X language shortcut, B/Escape cancellation, mouse/touch buttons and journal coexistence remain unchanged.

## State, dependency and persistence contract
- Player feedback: visibly focused native Godot Button, bilingual updated navigation hint and immediate English/Spanish labels.
- State semantics: language is transient presentation state; selecting Language changes only locale, Cancel restores prior pause state; only selecting a legitimate topic can call `Village.act("talk")`.
- Economic invariants: navigating, translating, cancelling and confirming with no focused modal control cannot change affection, money, energy, inventory, restoration or conversation log.
- Clock: unchanged monotonic `day_epoch()` and 56-day year. Existing social save/load and one-talk-per-day checks remain authoritative.
- Input: keyboard arrows, Enter, 1–4, C, Escape; controller D-pad, A, X, B; mouse/touch native Godot buttons. Synthetic events are native-tested; **physical devices not verified**.
- Assets: first-party Godot controls and original bilingual text only; no external textures/fonts/audio or copyrighted material.
- Dependencies: Principal input/modal authority; V05 topic predicates; V06 gift modal separate; Emergence may independently audit denial/replay. Builder and Farming unchanged.
- Performance: O(number of visible topic buttons) bounded by four, on key/controller events only; no per-frame work added. Target no more than six focus candidates per navigation. **No measured FPS, touch latency, device memory or mobile profiling.**

## Native acceptance and limits
The existing `.github/workflows/everbloom-v05-topics.yml` executes `scripts/village_topic_panel_acceptance.gd` on a real assembled Godot game and pins official Godot 4.7.2 by SHA-256. New assertions cover topic→language→cancel traversal, reverse navigation, clamped first action, disabled topic skipping, controller confirmation, locale roundtrip, pause restoration, and no-focus rejection without resource or friendship gains. Existing suite covers year-spanning save/load, earned chapter gates and bilingual replies. Exact SHA and workflow/job receipts must be attached after CI; this document alone does **not** establish a native PASS.

Remaining V19/V05/V20 work: full localization and screen-reader semantics, actual controller and touch hardware validation, short-viewport clipping, measured desktop/mobile performance, and persistent consequential social choices coordinated with Principal's save schema. The separate 220-feature innovation implementation gate remains closed.
