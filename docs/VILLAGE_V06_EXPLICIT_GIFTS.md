# EVERBLOOM V06 — Explicit favorite/preferred gift selection

**Mission:** V06 (meaningful gift culture), V19 (accessible social input), V20 (year-spanning regression). **Status:** bounded Godot gameplay candidate; not mission completion or verified mobile UX. **Engine:** Godot 4.x only.

## Player interaction and visible feedback

The original G key continues the legacy automatic first-available-preference gift action. The new **Choose a gift [V]** button opens a bilingual selection modal near a real resident. Keyboard V, controller D-pad Right, or pointer/touch button open it; 1/2, arrow keys + Enter, D-pad Up/Down + A, or touch/click choose an item. Escape/B/Cancel closes without a gift. Each resident's existing authored `preferences` list (two entries) is shown in stable order with current inventory counts and favorite/preferred distinctions; out-of-stock choices are visibly disabled. No fictional stock is displayed.

The selected item is passed to the existing authoritative `village.act("gift", hero_position, item_id)` route. The old two-argument route is preserved. The Village domain independently checks resident proximity, per-resident once-per-monotonic-day gift cap, authored preference membership, available inventory, and atomic `game.consume_item(item, 1)` before awarding friendship/restoration. A favorite grants 18 friendship; another preferred item grants 12. Gift memory records the actual chosen item and favorite status. Invalid, unavailable, out-of-range, repeated or cancelled selections cannot consume items or create rewards.

## Save, time and integration

No new save fields, settings, global input map, player inventory type, asset IDs, or Principal-owned files. Existing nested `village.memories` records the selected gift's `last_gift_item`, `last_gift_epoch`, `last_gift_favorite` and later `recalled_gift_epoch`. The calendar authority is `game.day_epoch()` (56 days per year); the panel's locale, focus and open state are transient presentation state. A full assembled-game save/load must conserve inventory, gold, energy, restoration and the entire nested Village snapshot.

**Village exclusive files:** `scripts/village.gd`, new `scripts/village_gift_panel.gd`, `scripts/village_gift_panel_acceptance.gd`, this handoff and a dedicated push-only CI workflow. Principal retains `game.gd`, `save_service.gd`, HUD and global calendar/input authority. Builder retains actual home interiors and movement/navigation; Emergence retains independent dynamic storylets. This increment is existing baseline bugfix/gameplay and does not touch the gated 220-concept innovation catalog.

## Original assets, accessibility and performance

The gift menu is composed entirely of native Godot labels, buttons, and original palette colors. Future first-party resident portrait expressions, gift handover animation, sound effects and translated item-display names require original art and documented rights. Existing English/Spanish menu chrome is localized, but raw internal item IDs and the older G-route feedback remain English: full localization is **not** achieved. The modal provides focusable controls and >=44 px touch targets; keyboard/controller routes are synthetic native input acceptance only, not physical-device certification. Narrow-screen clipping, screen readers, controller hardware, mobile battery/GPU and real touchscreen ergonomics remain unverified.

Bounded UI: two buttons per opened resident, O(6) nearest-neighbor scan on opening/confirmation, O(2) inventory/label refresh, no per-frame simulation expansion beyond the existing button-disabled/locale check. Performance target is under 0.2 ms for a gift-menu refresh on desktop and under 0.5 ms on mobile; **these are budgets, not measured results**. Device profiling is required before acceptance.

## Deterministic native acceptance

`scripts/village_gift_panel_acceptance.gd` instantiates the actual assembled `Game`, opens the modal, exercises mouse/touch-equivalent button signals, synthetic keyboard/controller events, English/Spanish labels, original preference order, invalid and empty item rejection, repeat denial, gift recollection, full JSON save/reload and a year-two (epoch 57) gift. It verifies selected-item inventory conservation, exact affection/restoration, modal mutual exclusion with social journal/topic picker and the original G route. The push-only `everbloom-v06-gifts.yml` checks official checksum-pinned Godot 4.7.2 import and the native acceptance log. General CI also runs on push.

**Limitations:** No gift-giving animation, nuanced emotional-intent tagging beyond authored favorite/preferred distinction, festival traditions, taste-history preferences, physical-device evidence or production mobile profiling. V06/V19/V20 remain **partially implemented** even if exact-SHA CI passes. Do not claim the wider 100 missions or 220 concepts are complete.
