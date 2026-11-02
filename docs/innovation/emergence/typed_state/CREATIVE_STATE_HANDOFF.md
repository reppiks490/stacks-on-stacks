# Emergence E081–E090: original creative experiments — typed-state handoff

**Scope:** E03, E13, E18. **Status:** Phase-B design-only, not playable. This document is not an approval to implement. Source: frozen `game/everbloom-emergence-phaseB-100-20261102`, `docs/innovation/emergence/phaseB_051_110.json`, blob `eb7c590f43c92ded0e328ecfdf7003fa7c06ceac`. Exclusive ownership: `docs/innovation/emergence/typed_state/creative_081_090.*` and dedicated workflow. Existing gameplay, saves, art, inventory and other lanes untouched.

## Ten original player activities

| ID | Player verb and intended feedback | Invariant and negative case |
| --- | --- | --- |
| E081 | Brew fictional botanical ink, write a journal page; ink gauge and authorship indicator | Finite receipt-backed ink; pages cannot exceed consumed batch units; public sharing requires consent |
| E082 | Guide deterministic marbling strokes; preview paper edition | One paid edition; cancellation cannot keep output and refund pigments; ordered touch/controller gesture samples |
| E083 | Choose fictional glaze and compare kiln outcomes; preview color | Receipt must match vessel and recipe; no duplicate sale/glaze from a single firing |
| E084 | Compose chime notes; readable score and optional audio | Ordered bounded notes and tempo; muted players use the same note editor |
| E085 | Press permitted flower specimen into journal; show origin | Protected specimens blocked, collection epoch and unique receipt required |
| E086 | Mix fictional nonmedical scent; formula and share controls | Exact ingredient sum; no unconsented NPC use or invented medicinal benefit |
| E087 | Pose puppets on a keyframe timeline; captioned theater preview | No public show reward without cleared stage and performer consent; canceled show has no payout |
| E088 | Plate existing cooked food; inspect visual arrangement and score | Layout references paid ingredients; no additional nutrition or duplicate dish inventory |
| E089 | Assemble a decorative miniature habitat; notes and provenance view | Finite materials; no real-world biome/habitat score effects |
| E090 | Repair original folk instrument; inspect wear and opt-in music session | Finite repair materials, bounded durability, no duplicate value creation |

## Interface ownership and authority

**Principal:** sole source of authoritative `day_epoch` (56 days/year), `expected_revision`, command receipts, material/energy debits, awards, save versioning and atomic recovery. Embedded strings are **untrusted proposed references**, not proof that an external debit or reward occurred. Principal must resolve receipt uniqueness across all domain features and crash-replay, not merely within a saved feature instance.

**Farming:** real herb/flower/food provenance and protected-collection permissions; no E085 collection before Farming habitat and inventory approval. **Construction:** owns kilns, studios, furniture/workshop footprint and physical object IDs. **Village:** owns NPC consent, privacy, public-performance scheduling, opt-in participation and contest adjudication. **Emergence:** owns the creative output contract and deterministic aesthetic choices, not external currency, NPC mood, habitat, inventory or building geometry.

## Save, controls and quality

Each optional namespace `emergence.creative.081..090` has a concrete nested version-2 contract with **exactly the four source fields** plus `revision`, `day_epoch` and bounded `command_receipts`. Absent optional namespace may default; a present malformed namespace must reject atomically. `day_epoch=(year-1)*56+season_index*14+day`; never derive once-per-year checks from day-of-season alone. Two-year replay, duplicate command IDs, stale revisions, canceled transactions, and crash recovery require native assembled-game acceptance **after** Phase-C authorization. Proposed V2 is not an approved save migration.

**Keyboard/mouse:** focus/inspect, arrow/pointer choices, remappable confirm/cancel. **Gamepad:** D-pad/stick focus, shoulder choice changes, A/B confirm/cancel. **Touch:** 44px+ controls, tap-to-preview, long-press details; optional stroke sampling must have discrete accessible alternatives. **Accessibility:** readable score/pose/ink patterns without sound or color, captions, scalable controls, reduced motion. Controls here are specifications, not measured device parity.

**Original asset plan:** self-authored botanical ink marks, pigment swirls, ceramic color swatches, chime note glyphs, plant press, fictional scent bottle, paper puppets, plating props, tabletop diorama and folk instrument; each needs a provenance manifest and simplified mobile fallback. No extracted third-party game assets. Existing source proposes 8 active instances, 0.4ms desktop/0.2ms mobile logic and 4 extra mobile draw calls; these are **unmeasured targets**, not benchmarks.

## Tests, unresolved gates and handoff

`validate_creative_081_090.py --self-test` verifies source field coverage, strict nested shapes, bounded state, 20 positive/default fixtures, deterministic JSON roundtrips, adversarial wrong types/fields, receipt duplication and ten feature-specific exploit attempts. It cannot prove runtime settlement, native Godot, visual quality, actual player interactions or hardware budgets. CI should use only push-triggered Python; the existing generic workflow separately checks the unchanged Godot baseline. No PR: generic validation has a pull_request trigger and automatic review cannot be ruled out.

**Before implementation:** Principal must approve semantic 220/220 catalog, exact resource quotes, real receipt authority and save migrations; Village must approve consent/contest bookings; Farming must approve finite harvest resources; Construction must approve workshop IDs and craft transactions. **Phase C remains CLOSED**. Next E091–E100 only after fresh source/coordination review. No Codex, spending, publication, force push, blind merge, proprietary assets or engine port.
