# Village V06/V19 — Accessible gift-picker focus traversal

Status: **implementing / native verification pending**. Branch: `game/everbloom-village-v19-gift-focus-20261102`.
Mission IDs: **V06**, **V19**, **V20**. This is a bounded existing-baseline correction, not an innovation-catalog feature.

## Reproduced source defect and player consequence
Previously `VillageGiftPanel._navigate` bounded the selection to gift indices 0–1. While a gift was in stock, controller D-pad or keyboard arrows could not reach **Cancel**; the player needed B/Escape, Tab or a pointer. With only the second gift in stock, a disabled first gift could trap the selection. This broke the requirement that critical social UI be navigable without a mouse.

## Implemented interaction and state contract
- When open, Up/Down and controller D-pad Up/Down traverse **available gift buttons followed by Cancel**. Disabled/hidden gifts are skipped. Navigation clamps at either end, without wraparound surprises. Enter/controller A activates the **actually focused** control, so Cancel cannot invoke `Village.act("gift")`.
- Opening focuses the first available gift or Cancel if all preferred gifts are unavailable. Number keys still invoke the existing authoritative gift attempt; out-of-stock and daily limits remain checked by `Village.act`. The existing V opener, B/Escape cancel and pointer/touch controls remain.
- No additional save keys, schema changes, economy grants or item mutations. The 56-day calendar and monotonic `day_epoch` remain owned by Principal and Village's existing domain action. UI focus is transient.
- New native acceptance uses the real assembled game, existing Mira preference order, synthetic keyboard/controller events, empty and partial inventory, year-two save continuity, and exact inventory/social conservation on cancel.

## Ownership, dependencies, assets and budgets
- Exclusive Village files: `scripts/village_gift_panel.gd`, `scripts/village_gift_panel_acceptance.gd`, this document. No edits to Principal's `game.gd`/`save_service.gd`, Farming, Builder, Emergence, or innovation catalogs.
- Original asset plan: existing first-party Godot primitives and authored bilingual strings; future original focus highlights, portraits and gift animations require independent asset provenance.
- Focus traversal creates at most **three temporary Button references per navigation event**, O(2) for current two gift options; no new per-frame work or save bytes. Desktop/mobile frame time and memory have **not been measured**.
- Godot 4.x only. No port, external assets, Codex, PR, spending or publication.

## Acceptance and limitations
- Required: dedicated `everbloom-v06-gifts.yml` native assembled-game regression at exact final branch SHA, general Godot/Python validation at same SHA; inspect raw job logs before claiming PASS.
- Physical controller/touch usability, screen reader, small-screen clipping, translated item names and measured mobile performance remain **unverified**. V06/V19/V20 remain partially complete.
- Cross-loop handoff: Principal should retain exclusive global modal/input/save ownership; Emergence can adversarially verify cancellation against future consent/receipt systems; Builder need not modify houses or NPC placement.
