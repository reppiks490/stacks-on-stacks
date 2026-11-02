# Emergence E031–E040 social-agency typed-state handoff

**Status:** DESIGN-ONLY, not Godot gameplay, not an approved save migration, not an authorized Phase-C feature implementation. **Owner:** Emergence (E03/E07/E18). **Charter:** `docs/EVERBLOOM_100_ADVANCED_MISSIONS.md` pinned to `b8a1e635792b08b0a3d87b987e593a539ac5c123`. **Starting main:** `21d325eb4f05c90f37c1047a76a48b2a90767e31`. **Frozen source:** `docs/innovation/emergence/phaseB_011_050.json` at `63cab5d05c742c61205933482e38fac2a4086764`, blob `a5def76918e77e0ded7e3e8085444698b4e0b549`.

## Bounded original state contracts

`social_031_040.json` defines ten optional `emergence.eb_e_031`–`040` namespaces, **47** concrete bounded top-level fields and **40** cross-field rule codes. Each preserves its four original source fields; only explicit additive fields are introduced. All list sizes, string lengths, integer epochs and enum values are bounded. A missing optional namespace defaults to inactive; a present malformed namespace must be rejected **atomically** by a future Principal-approved save migration, never partially loaded.

| ID | Distinct player action | State-integrity / denial gate |
| --- | --- | --- |
| E031 | Draft and revise a consent-requested apology | Delivery requires granted consent, revision and epoch-linked receipt; denied delivery cannot award trust. |
| E032 | Trace a rumor through consenting witnesses | Hearsay, fabricated witnesses and nonconsenting accounts cannot become verified evidence. |
| E033 | Negotiate an heirloom exhibition | Public display requires owner, object and current consent; withdrawn consent removes visibility. |
| E034 | Mediate a jointly authored recipe | Exactly two contributors; publication requires approvals at the current revision. |
| E035 | Offer optional nonverbal help | Gesture must be approved; only one recorded contact per monotonic day epoch. |
| E036 | Map a verified favor with permission | Private pins cannot be publicly visible; reciprocity requires a source receipt. |
| E037 | Schedule a reunion respecting travel | Bookings require consenting invitees and feasible travel times. |
| E038 | Mediate a civic dispute | Settlement requires two statements, two affirmative consents and a compromise. |
| E039 | Arrange sequential craft lessons | Completion must be ordered, epoch-stamped and linked to one unique skill receipt. |
| E040 | Host an opt-in story circle | Public index only references latest public version by a consenting participant; retraction hides it. |

**Authority:** Village exclusively owns NPC identity, consent, schedules, trust, relationships, narrative memory and town archives. Principal exclusively owns `day_epoch`, save admission, transaction settlement and exactly-once command receipts. Emergence records only bounded proposals, player choices and references to authoritative receipts. Farming owns inventory, crafting and materials; Construction owns building placements. These schemas are **not** permission to award items, relationship points, skills or NPC movement.

**Input/UI:** Each feature specifies keyboard/mouse focus and confirm/cancel, controller D-pad/stick and buttons, touch-sized inspection and confirmation controls, readable privacy state, captions and reduced-motion alternatives. Actual device parity and user feedback remain untested; player-facing Godot scenes do not yet exist.

**Original art/audio:** Plan original journal cards, restrained NPC gestures, captioned sound cues and scalable low-cost UI. No assets were imported; rights provenance and actual GPU/frame measurements are pending. Planned per-feature caps (64 receipts, 16 participants) constrain CPU work but are **design budgets**, not benchmark results.

## Adversarial verification

`validate_social_031_040.py --self-test` performs schema/source-field validation, ten inactive and ten active fixtures, feature-specific consent/privacy/replay negatives, missing/extra field rejection, type spoofing, unbounded list rejection, receipt duplication and calendar-related consistency checks. Its passing result validates **offline design state**, not native Godot, real save/load, social consequences, controller/touch hardware, or gameplay. Native full-game 112-day replay and real UI/device checks remain release gates.

**Principal/Village approval required:** opt-in `emergence.*` save namespace and versioned migration; Village consent authority and redaction on withdrawal; unique receipt persistence across restart and two-year rollover; no coercive dialogue or private information exposure; no replayed relationship/skill/recipe payouts. Do not integrate E031–E040 until joint 220-catalog semantic and feasibility approval is recorded in issue #2. Existing gameplay bugfixes by other lanes continue independently.

**Repository safety:** This branch creates only four Emergence-owned new files (JSON, validator, handoff and push-only workflow). It does not change `game.gd`, `village.gd`, `save_service.gd`, assets, existing typed-state catalogs, other branches or other repositories. No PR due to unaudited external auto-review risk; no Codex, paid services, forced updates or engine migration.
