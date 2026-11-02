# EVERBLOOM V05/V19 — Earned NPC chapter progress (bounded increment)

Status: **implementing; native acceptance pending**. This is original Godot 4.x game code, not a proposal or a Construction/Emergence innovation-ledger implementation.

## Player interaction and feedback

Visit any of the six original villagers and open **Ask a neighbor [U]** using its mouse/touch button, keyboard U, or controller right-stick click. The conversation overlay now displays two readable, spoiler-free chapter trackers: **Work memory** and **Trust memory**. Before unlocking, they show the exact remaining paid shifts and friendship points; after unlocking, they show **Ready to discuss**. The UI translates these status lines into Spanish alongside the existing English/Spanish topic labels, using C, controller X, or the language button. The tracker is display-only: it cannot start a conversation, grant currency, consume an item, alter friendship, or reveal locked dialogue. The existing four topic buttons retain keyboard 1–4, focus + Enter, gamepad D-pad/A, and mouse/touch selection; Escape/B and Cancel close without rewards. The scrollable menu accommodates extra progress text on shorter logical viewports without removing any focusable topic choice.

## Deterministic state and dependency contract

The authoritative data are the already-persisted `village.memories[rid].jobs`, `village.affection[rid]`, and `data/village_life.json` `conversation_topics[*].requires`. New read-only `village.chapter_progress(rid)` returns stable, sorted chapter IDs, an unlock flag, and nonnegative deficits `jobs_remaining` / `friendship_remaining`. It uses the same `_topic_unlocked` predicate as the actual dialogue router. A legitimate paid shift changes the jobs count; genuine friendship actions change affection. The display refreshes when the player opens the menu or switches locale. Existing locked replies remain unavailable through `available_topics` and cannot be invoked directly for a bypass. No new save keys, currencies, social rewards, resource receipts, game calendar actions, or year-dependent counters are introduced. Year rollover remains based on monotonic `day_epoch` in the existing domain.

Village owns `scripts/village.gd`, `scripts/village_topic_panel.gd`, `scripts/village_topic_panel_acceptance.gd` and this note. Principal owns `scripts/game.gd`, `scripts/save_service.gd`, shared UI/input, calendar and assembled save authority; Farming, Builder and Emergence files are untouched. The innovation Phase-C gate is not changed.

## Original asset plan and performance

All visual components are first-party authored labels and built-in Godot controls; no copied art, proprietary assets, purchased libraries or new textures. Progress is computed only when opening a menu or changing locale, at O(k log k) over the fixed four-topic resident catalog; there is no new per-frame simulation or persistent memory allocation. The display uses a bounded two-line tracker for the current six villagers. Device frame time, physical touchscreen/gamepad behavior, screen-reader support and actual small-screen clipping **remain unmeasured**. The ScrollContainer is a logical-layout safeguard, not a claim of mobile acceptance.

## Regression acceptance

`scripts/village_topic_panel_acceptance.gd` must execute with native Godot 4.x against the exact candidate SHA. It checks six resident topic contracts, initial locked deficits, English/Spanish tracker parity, conservation during menu operations, real paid-shift unlock, 80-point trust unlock, existing choice routing, locked-topic rejection, multiyear replay, assembled save/reload and reconstruction of progress from persisted fields. Also require general import/parse, 120-frame smoke, native save recovery and existing Village suites before integration. Any failure is a blocker, not a reason to claim completion.

**Known gaps:** no persistent player-authored dialogue decisions or deep NPC agency, no physical input/device measurements, no production assets or comprehensive accessibility audit. V05/V19/V20 remain partially complete.
