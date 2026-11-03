# P17 — Assembled-game golden route (Principal)

**Status:** implementing / awaiting exact-HEAD native CI. This document is a test contract, not a gameplay completion claim.

## Ownership and scope
- Principal-owned NEW files only: `scripts/principal_golden_day_acceptance.gd`, `.github/workflows/everbloom-principal-golden-day.yml`, this document. No existing domain logic or other lanes modified.
- Native test loads `res://scenes/main.tscn`, calls actual Farm/Animals/Village/Festivals/Game/SaveService APIs, and saves in isolated GitHub Actions `XDG_DATA_HOME`. No mock ledgers, no externally copied assets.
- **Important gameplay constraint:** the original spring festival occurs on day 3, while its village shift and crop harvest occur on day 4. A single-calendar-day route cannot contain all these actions under the current authored schedules; the test therefore covers one coherent four-day progression, with day-4 golden checkpoint.

## Deterministic player verbs and acceptance
1. Day 1: till/plant/water one real turnip bed; reject duplicate planting; care for a real hen once; talk with Mira once; save complete state.
2. Days 2–3: sleep, water, verify crop growth and monotonically increasing `day_epoch`. Day 3 contribute two seeds at the original Spring Seed Exchange, check exact currency, ribbon, energy and duplicate denial.
3. Day 4: harvest mature turnip; verify exact item/energy/lifetime count and no double harvest. Simulate Mira's commute using `sync_schedule(false, delta)`, deny paid work before physical arrival, allow one 24-petal shift after arrival, deny repeat work.
4. Save full domain snapshot, destroy actual game scene, instantiate a new scene, load, compare farm, animals/paddocks, village social/job memory, festival receipts, inventory, money, energy and player position. Deny replayed shift after restart. Re-save and confirm nested idempotence.

**Controls and player feedback:** these are direct production action APIs with production response strings. Live keyboard actions include interaction/tool selection, job `K`, festival `T`, sleep and save/load. Gamepad and touch semantic equivalence, rendered HUD response, physical hardware and device usability remain **unverified**; this test does not simulate those devices.

**Original asset plan:** use the existing original primitive crop, animal, NPC, festival and world meshes only. Any future replacement art must pass P15 license/provenance review. No third-party Harvest Moon resources.

**Dependencies:** P01 authoritative inventory/currency and interaction signatures; P02 monotonic 56-day calendar; P04/P05 save boundary and recovery; Farming crop/animal implementations; Village commute/paid work; Emergence festival ledger. No new schema keys.

**Performance:** CI headless test has a 75-second wall-clock timeout and a 12-minute job budget; neither is a measured desktop/mobile FPS, draw-call, GPU or memory benchmark. P13 remains open.

**Reproducibility:** use the dedicated push-only workflow, checksum-verified official Godot 4.7.2, exact `GITHUB_SHA` checkout, native import and script run, fail on script errors, archive logs. General native validation runs independently. No Codex, PR, force, spend, publication or engine port.

**Limitations:** this verifies service-level player actions across an actual scene, not physical player traversal, pathfinding, real-device controls, audiovisual polish, Windows file-lock durability, or full P17 mission closure. A failure is a real regression signal requiring repair before integration.
