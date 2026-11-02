# EVERBLOOM — Master Production Charter

## Primary creative target
Capture the *emotion and day-to-day loop* of Tree of Tranquility: a welcoming island valley, tending to crops and animals, meaningful friendships, seasonal routines, marriage/family aspirations, part-time jobs, festivals, and a long-running original restoration story. Reference Natsume and Nintendo's official descriptions; never copy names, quests, dialogue, maps, models, or protected artwork.

## Expansion target
In later production waves, add a larger landscape, multiple settlements, exploration abilities (climb/jump/boat), animal companions with abilities, islands and gradual village development. Echoes of Teradea is a functional reference for that scope; not an asset donor.

## Project vision
Working title: **EVERBLOOM: The Living Valley**. Whimsical painterly countryside; hand-crafted settlements, soft seasonal palette, wide animated sky, subdued pastoral music, natural rain and wind, tangible farm work, intimate social simulation, genuinely cozy rather than combat-heavy. Emotional throughline: restore a divided countryside by reconnecting people, ecology and livelihoods. World, villagers and mythology MUST be original.

## Five development lanes
1. Principal Architect (:00): architecture, integration, ownership, persistence, scope, gatekeeping.
2. Farming Architect (:12): soil/crops/weather, livestock, economy, crafting and farming feedback.
3. Village Engineer (:24): real routines, personality, story, gifts, families and events.
4. World Art Director (:36): visual direction, original 3D/2D/audio materials, lighting, traversal and performance.
5. QA Release Engineer (:48): real Godot import/runtime, assets/provenance, determinism, regressions, device/mobile testing and proof.

## Mandatory depth roadmap
**M0** Original playable source foundation + source/nightly CI and honest claims.
**M1** Full farming loop; 4 seasons, livestock, nontrivial weather and economy, tool upgrades.
**M2** Working schedules and persistent dialogue/affection and festival calendar.
**M3** Original beautifully authored valley, interiors, dialogue portraits, ambient soundscape, lighting, LOD and tested accessibility.
**M4** Long-form restoration narrative, relationships and family arcs, authored quests and child-safe community content.
**M5** Expanded world; companion exploration, caves/islands, boats, terrain transitions, original wildlife, cooking/commerce.
**M6** Full game QA, progression balance, controller/mobile UI, save migrations, stability, profiling, QA acceptance and packaging.

## Acceptance law
Never claim a finished game, polished AAA artwork, native/mobile compatibility or original soundtrack without actual evidence. No paid purchases; no automatic Codex invocation in any form. Preserve old SABLESTAR Git history, but remove its files from the new active branch. Development branches, source tests and independent release checks are mandatory. External proprietary assets require verified redistribution rights and legal review before inclusion.

## No-sample production targets (not current completion)
At least 4 genuinely different seasons, complete time and weather cycles, expanded living world, distinctive farm/animal/plant assets, 20+ villagers with schedules, meaningful families, independent farm economy, 40+ crops, 15+ animals, 30+ festivals and many years of progression. These are long-term targets; do not fake completion through schema-only stubs.

## Principal integration milestone — numerical preservation and calendar contracts

The second-year gameplay gate requires no social, farming or animal once-per-day collision when year increases. It must be demonstrated through engine-driven runtime tests, not only source inspection. Farming and husbandry have native acceptance for a 56-day progression; village talk/gift year-two migration landed separately at `df15d515`, with native verification and combined integration still to be confirmed.

Persistence must be fail-closed for malformed schema/negative or fractional inventory, impossible calendar values, non-finite coordinates and unknown schema; never auto-migrate by silently truncating valuable items/currency. Preserve pre-year schema-1 saves with a documented default year of one. The isolated principal save-integrity suite implements 19 native negative-payload assertions, while the wider crash/file-lock/full-state correctness gate remains open. All future feature lines must include reproducible native tests, original asset provenance, accurate issue handoffs and a current-sha QA ledger; source presence is not proof of finished gameplay.

**Save-integrity extension:** nested persisted farming, villager, and animal numeric/types must be rejected or explicitly migrated before any session mutation. The expanded 24-case Godot regression is a development gate and is not a replacement for adversarial full-save fuzzing, crash durability or manual recovery UX.
