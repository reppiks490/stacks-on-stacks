# EVERBLOOM V19 — Earned dialogue history language filter

**Mission IDs:** V19 (accessible social recap), V03 (authentic memory presentation), V20 (year-spanning acceptance). **Status:** implementing; only declare native-tested/integrated after exact-head GitHub Actions receipts. Godot 4.x is the sole active engine.

## Player interaction and state semantics

The existing Neighbors & Memories journal adds a focusable **All / English / Español** history filter. The button displays the number of matching, genuinely spoken entries. Pointer/touch activates the button, keyboard **F** and controller **D-pad Left** cycle modes. Filtering is purely a view: it reads each resident's existing bounded `dialogue_log`, matches the saved original `locale`, preserves the chronological record and displays three entries per page. Switching filters moves to the newest valid matching page; switching residents retains the chosen filter and shows a truthful empty state. Changing UI language does not translate historical spoken text or rewrite its provenance.

## Authority and dependencies

Village owns `scripts/village_social_journal.gd` and the new native acceptance. Existing `scripts/village.gd` owns the original transcript; Principal owns `game.gd`, `save_service.gd`, global time/input and save admission. No new save fields, game rewards, NPC behavior, item transactions, currency, friendship or festival receipts. The V05 earned-chapters isolated branch owns different files; this increment deliberately does not edit them. Construction and Emergence's 220-concept gate is unaffected.

## Native acceptance and controls

The dedicated push-only non-Codex Godot 4.7.2 workflow imports the actual project and runs the assembled game. The native runner generates twelve **real player talks** in English/Spanish across two 56-day years, saves and reloads through the real game, then checks filtered and unfiltered pagination, empty residents, bilingual labels, synthetic touch-button/keyboard/controller routes, narrow-width margins, text scaling, modal pause and strict resource/social conservation. The existing V19 and general regression suites must remain green. These are simulated device events, **not physical controller/touchscreen or screen-reader validation**.

## Art, performance, limits and port contract

Uses only original UI labels and Godot primitive controls; no third-party art or proprietary assets. Filtering scans at most twelve entries for the selected resident (O(12) per interaction), adds one persistent button and no per-frame history scan. Frame time, memory, mobile clipping, screen-reader support and real device ergonomics remain **unmeasured**. The filter is a presentation adapter over an engine-neutral saved `{epoch, locale, text}` transcript; no Unreal/Unity port is authorized. Future improvements: accessible screen-reader announcements, long-text small-screen audit and opt-in advanced dialogue follow-ups.
