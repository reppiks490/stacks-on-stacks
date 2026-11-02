# EVERBLOOM: 100 Advanced Mission Charter

Created November 2, 2026 for GitHub repository reppiks490/stacks-on-stacks. This charter assigns 20 individually scoped missions to EACH of five hourly loops: 100 assignments in total. Assignments are obligations and plans, NOT completed features.

## Mandatory engineering policy

- **Engine plan:** develop and validate the working baseline with Godot 4.x. Only AFTER reliable playable Godot baseline: evaluate Unreal Engine 5 vs Unity 6, create port feasibility/feature parity report, then seek owner's direction before migrating. Avoid Unreal/Unity changes until authorized.
- **No Codex whatsoever:** CLI, agent, cloud, code reviews, bots and Codex-powered GitHub workflows are disallowed. No unapproved paid services, publishing, destructive Git, force pushes, copying proprietary Harvest Moon assets or stealing protected game resources.
- **Original stylized realism:** richly detailed painterly life simulation; accessible mobile/PC input and performance tiers. Every new image, mesh, audio asset, animation and library needs verified provenance.
- **Preserve all existing game source:** current game.gd, farm.gd, village.gd, animals.gd, valley.gd, farmer.gd, HUD, saves and native CI. Do not replace established systems with empty shells. Use safe isolated branches, disjoint path claims, GitHub issue #2 and docs/CROSS_LOOP_COORDINATION.md.
- **Proof obligations:** each completed mission requires durable design/code/assets, exact commit SHA, reproducible native Godot test or an explicit testing blocker, substantive player-facing acceptance, dependencies, performance impact and next task.
- **Shared innovation phase gates:** B and E jointly specify 20 entirely distinct player-facing ideas first (B10, E10); only once 20 are documented, author 200 more (B100, E100) for a combined **220 fully scoped unique new feature concepts**. Deduplicate and reject superficial variations. ONLY AFTER verified 220-feature ledger begin implementation of this new innovation backlog. Existing Principal/Farming/Village baseline work and defect repairs continue regardless.
- **Every feature idea must specify:** ID, novelty audit, player's direct actions and feedback, real use case, interactions with farm/village/building/world, state model, controls (mouse/touch/controller), prerequisites, implementation steps, original asset needs, save and replay, engineering effort, hardware budget, Godot acceptance and Unreal/Unity migration adapter assumptions.
- **QA and art still have owners:** after replacing standalone QA/Art loops, Principal owns cross-system release and native test gates, every domain owns its own tests, Emergence owns adversarial feature QA and art-experience requirements, and Builder owns procedural modular 3D environment/house asset kits. All workers enforce rigorous provenance and stylized-realism visual direction.
- **Current integration constraints:** calendar uses monotonic day_epoch=(year-1)*56+season_index*14+day, and integrated save states must preserve nested crop, animal, village and future structure data. Avoid stale documentation and branch-head assumptions.
- **Each run:** inspect current exact HEAD, open issues, conflicts, CI, feature ledger and mission progress; choose highest-value unblocked work; build, test and record evidence; avoid claiming unverified platform capability. Status values: planned/specifying/ready/implementing/native-tested/integrated/blocked.

## Mission roster

### P: Principal Systems Architect — 20 scoped missions

**P01 — Runtime contract ownership**
- Scope: Calendar, input, inventory, economy, domain lifecycle, authority signatures.
- Acceptance: Cross-domain native test has no double action or circular ownership.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P02 — Monotonic annual calendar**
- Scope: 56-day year, monotonic day_epoch, minute clock and weather causality.
- Acceptance: Two-year replay never collides on once-per-day actions.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P03 — Deterministic command replay**
- Scope: Seeded RNG, command envelopes, stable event ordering and replay logs.
- Acceptance: Replaying same session yields identical serialized state hash.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P04 — Transactional persistence**
- Scope: Versioned domain snapshots, atomic writes, backup restoration and migrations.
- Acceptance: No items, money or relationships lost/duplicated on recovery.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P05 — Crash and corrupt-save adversarial suite**
- Scope: Inject torn files, invalid types, stale backups and nested invalid payloads.
- Acceptance: State remains unchanged on rejection with explicit recovery reasons.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P06 — Engine-neutral domain architecture**
- Scope: Portable schema, business rules and state transitions versus Godot node adapters.
- Acceptance: Domain invariants testable without Godot scene graph.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P07 — Unified player interaction router**
- Scope: Inspect/use/place/talk/build/harvest command gating and reach checks.
- Acceptance: Keyboard, touch and controller produce equivalent valid results.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P08 — Streaming and stable world IDs**
- Scope: Chunk partitioning, world coordinates, travel boundaries and persistent actor IDs.
- Acceptance: Unload/reload preserves NPCs, crops, structures and quest state.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P09 — Entity lifecycle and ownership**
- Scope: Spawn, destroy, despawn, revive, partial construction and references.
- Acceptance: No orphan IDs, ghost collisions or duplicated loot after reload.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P10 — Feature dependency registry**
- Scope: Feature versioning, enable flags, compatibility constraints and migrations.
- Acceptance: An optional feature can be toggled safely without save corruption.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P11 — Input and device adaptation**
- Scope: Keyboard/mouse, analog sticks, touch gestures and context actions.
- Acceptance: Same scripted task reaches same state through three control maps.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P12 — Accessibility and localization**
- Scope: Subtitles, contrast, reduced motion, scalable UI, remapping, readable strings.
- Acceptance: Missing localization and inaccessible critical actions trigger test failures.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P13 — Profiling and resource budgets**
- Scope: Frame time, memory, draw calls, tick cost, physics and scene import benchmarks.
- Acceptance: Measured tier-specific budgets; clearly distinguish native from inferred data.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P14 — Stylized realism rendering contracts**
- Scope: Painterly forms with realistic light, water, weather, seasons and LODs.
- Acceptance: Visual system has provenance and measurable desktop/mobile quality tiers.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P15 — Asset license and supply chain**
- Scope: Asset hashes, attribution, permissions, license manifests and security checks.
- Acceptance: Unlicensed or unverifiable external assets blocked from integration.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P16 — Non-Codex native CI architecture**
- Scope: Headless import, script tests, integration gates, data validators and safe workflows.
- Acceptance: Exact-head tested GitHub runs with no Codex invocations.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P17 — Whole-day golden gameplay route**
- Scope: Crop, livestock, moving NPC, paid shift, event, sleep, save, restart, load.
- Acceptance: Replayed day conserves every tracked resource and relationship.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P18 — Cross-loop integration manager**
- Scope: Disjoint file claims, conflict detection, change reviews and bounded work handoffs.
- Acceptance: Every integration reports exact commit, test and unresolved blockers.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P19 — Playable Godot baseline criteria**
- Scope: Functional minimum day loop, original visuals, 4 seasons, safe progression.
- Acceptance: Native playable checkpoint evaluated on PC with honest mobile gaps.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**P20 — Later engine decision architecture**
- Scope: Evaluate Unreal 5 versus Unity 6 pipelines and adapter boundaries after baseline.
- Acceptance: No premature port; parity and performance plan requires owner approval.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

### F: Farming and Ecology Architect — 20 scoped missions

**F01 — Soil biogeochemistry**
- Scope: Texture, compaction, nutrients, pH, carbon and fertility transitions.
- Acceptance: Conserved finite state under a multiseason deterministic test.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F02 — Water and irrigation hydrology**
- Scope: Rainfall, evapotranspiration, runoff, channels, reservoirs and drainage.
- Acceptance: Water accounting and moisture stress behave reproducibly.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F03 — Crop physiology and phenology**
- Scope: Growth-degree days, germination, flowering, maturation, winter dormancy.
- Acceptance: All crop stages and seasonal failures tested natively.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F04 — Seeds and breeding genetics**
- Scope: Heritable yield, colors, hardiness, seed saving and controlled cross pollination.
- Acceptance: Offspring traits reproduce from seed and remain bounded.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F05 — Weed and pest management**
- Scope: Habitat competition, risk factors, integrated interventions and pest ecology.
- Acceptance: Preventive actions show causal yield change.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F06 — Plant disease management**
- Scope: Humidity, spread radius, sanitation, immunity, quarantine and treatment.
- Acceptance: No unbounded disease propagation or impossible instant cure.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F07 — Orchards and perennial systems**
- Scope: Tree age, pruning, rootstocks, fruit quality and multiyear crops.
- Acceptance: Accurate yearly behavior after save/restore.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F08 — Greenhouse microclimates**
- Scope: Temperature, ventilation, energy, seasonal daylight and humidity.
- Acceptance: Growth differs under controls with charged energy cost.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F09 — Farm equipment progression**
- Scope: Upgradeable tools, fatigue, wear, repair and mechanized operations.
- Acceptance: Tool operation respects stamina, durability and economy rules.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F10 — Irregular plot and terrain interactions**
- Scope: Slope-aware beds, plough footprints, agricultural zoning and paths.
- Acceptance: Construction and farm placement cannot overlap illegally.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F11 — Animal welfare simulation**
- Scope: Nutrition, mood, grooming, social needs, space, temperament and sickness.
- Acceptance: Needs remain finite and care actions persist across years.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F12 — Herd lineage and reproduction**
- Scope: Species life cycles, ancestry, breeding eligibility and capacity safeguards.
- Acceptance: No uncontrolled population explosion or invalid offspring.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F13 — Pasture rotational grazing**
- Scope: Forage, paddocks, regrowth, manure and nutritional land effects.
- Acceptance: No negative forage; calendar and move operations idempotent.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F14 — Pollinator habitat networks**
- Scope: Bee colonies, flower density, migration and habitat corridors.
- Acceptance: Habitat improvements measurably change crop yield.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F15 — Fishing and wetland ecology**
- Scope: Fish stocks, fishing rods, seasons, water temperature and stewardship.
- Acceptance: Stable population conservation and viable gathering loop.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F16 — Artisan and processing economy**
- Scope: Dairy, preserves, fermentation, weaving, production machines and perishability.
- Acceptance: No inventory multiplication or negative recipe inputs.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F17 — Market pricing and logistics**
- Scope: Orders, village supply, quality grading, demand shocks and transport.
- Acceptance: Payouts reconcile exactly with delivered inventory.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F18 — Extreme weather adaptation**
- Scope: Heat waves, storms, flooding, frost, drought and affordable recovery.
- Acceptance: Disasters produce bounded recovery and deterministic effects.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F19 — Building material contracts**
- Scope: Timber, stone, fiber, masonry, dyes, food and labor to construction.
- Acceptance: Build/cancel transaction reserves and returns correct materials.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**F20 — Multiyear integrated farm proof**
- Scope: Crop/animal/market stress replay with actual player feedback and UI tests.
- Acceptance: Native Godot run passes two-year save/load conservation.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

### V: Village Life and Narrative Engineer — 20 scoped missions

**V01 — Persistent NPC identity and agency**
- Scope: Traits, motivations, occupation, memories, affect and unique goals.
- Acceptance: NPC remains recognizable and state-consistent after reload.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V02 — Constraint-based life schedules**
- Scope: Jobs, commuting, meals, recreation, errands, sleep and dynamic interruptions.
- Acceptance: No overlaps or unreachable destinations in simulated weeks.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V03 — Long-horizon personal memory**
- Scope: Promises, kindness, betrayal, conversation topics and favors.
- Acceptance: NPC reacts to historical actions accurately after year rollover.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V04 — Social relationship network**
- Scope: Family, rivals, mentors, neighborhoods, friendships and reputation propagation.
- Acceptance: No global unbounded social score gains.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V05 — Conditional dialogue graph**
- Scope: Dialogue predicates, player knowledge, tone, branch effects and fallback replies.
- Acceptance: All response branches reachable and localized.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V06 — Meaningful gift culture**
- Scope: Taste histories, emotional intent, tradition, context and limits.
- Acceptance: Gifts affect interpretable memory beyond raw affection.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V07 — Town jobs and working economy**
- Scope: Paid shifts, task minigames, opening hours, wages and reputation.
- Acceptance: Correct schedule gating and conserved payment.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V08 — Physical village restoration**
- Scope: Building repairs, town services, paths, public spaces and community consequences.
- Acceptance: Changes persist in world and NPC navigation.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V09 — Multiseason festival network**
- Scope: Original competitions, annual ceremonies, memory, deadlines and reward models.
- Acceptance: Exactly-once yearly triggers and late-join fallback.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V10 — Community deliberation and projects**
- Scope: Town council, funding, volunteers, priority tradeoffs and shared planning.
- Acceptance: Player choices induce traceable town changes.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V11 — Romance with autonomy**
- Scope: Consent-aware mature age-appropriate relationships and nuanced boundaries.
- Acceptance: No forced courtship and multiple respectful outcomes.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V12 — Home and family routines**
- Scope: Partnership, household schedules, shared resources, chores and home preference.
- Acceptance: Family routine integrated with constructed house and save state.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V13 — Multigenerational legacy**
- Scope: Child growth, mentoring, inherited memories and milestone arcs.
- Acceptance: Aging consistent with annual epoch and save migrations.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V14 — Resident-generated storylets**
- Scope: Friendship disputes, discoveries, requests, unexpected reunions and recovery.
- Acceptance: Events nonduplicative, deterministic and opt-in where sensitive.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V15 — Shops and local supply chains**
- Scope: Inventory, prices, economic stress and resource feedback to farms/builds.
- Acceptance: Money and goods conserved across linked domains.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V16 — Quest dependency orchestration**
- Scope: Alternative solutions, prerequisite graphs, time-sensitive narrative recovery.
- Acceptance: No unreachable permanent softlocks.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V17 — Interregional towns and travel**
- Scope: Distinct villages, services, customs, migration and trips.
- Acceptance: Home schedules progress properly during travel.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V18 — Companion and pet bonds**
- Scope: Adoption, training, care, optional assistance and family integration.
- Acceptance: No mandatory punitive care or lost companion states.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V19 — Accessible social UI and story recap**
- Scope: Captions, dialogue log, relationship indicators and gamepad/touch choices.
- Acceptance: All critical stories navigable without mouse.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**V20 — Year-spanning village acceptance**
- Scope: Deep NPC schedule/dialogue/festival/save/replay suite and honest native testing.
- Acceptance: Godot tests prove living village interactions and social continuity.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

### B: Construction and Creative Systems Inventor — 20 scoped missions

**B01 — End-to-end physical house assembly**
- Scope: Foundation, posts, framing, floors, walls, roof, windows, doors, rooms and finishing.
- Acceptance: Plan demonstrates cottage assembly with meaningful material/structural rules.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B02 — Hybrid click-and-stick placement**
- Scope: Auto-socket, soft magnet, freeform, grid, guided blueprint and continuous placement.
- Acceptance: One consistent mouse/touch/controller command model and undo previews.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B03 — Typed attachment socket system**
- Scope: Compatible anchors, wall ports, transform math, rotation and tolerance.
- Acceptance: Impossible intersections and attachment types rejected.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B04 — Terrain-adaptive foundations**
- Scope: Slopes, terraces, piers, ground grading and terrain occupation.
- Acceptance: Safe ghost preview flags unstable or overlapping footprint.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B05 — Parametric roof and wall editor**
- Scope: Corners, roof pitch, arches, roof sections, beams, wall openings and room editing.
- Acceptance: Deterministic watertight structure geometry under edits.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B06 — Functional doors and windows**
- Scope: Hinges, openings, weather protection, ventilation, light and path clearance.
- Acceptance: Dynamic collision/navigation graphs update correctly.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B07 — Building structural integrity**
- Scope: Load paths, pillars, bracing, weight limits and damage recovery.
- Acceptance: Clear visual explanations for invalid constructions.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B08 — Utility network simulation**
- Scope: Fictional in-game plumbing, heating, lighting and power routing.
- Acceptance: Capacity/connections simulated safely without real-world hazardous guidance.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B09 — Multi-floor architecture**
- Scope: Mezzanines, stairs, ramps, platforms, balconies, attics and multi-level placement.
- Acceptance: Every occupied floor remains traversable and recoverable.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B10 — Precision interior decorator**
- Scope: Furniture move/rotate/scale constraints, grouping, paint, lighting and templates.
- Acceptance: No dupes or object losses through save, undo and relocation.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B11 — Blueprint system**
- Scope: Capture/preview/save/clone house templates and player-defined modular parts.
- Acceptance: Versioned template applies using checked inventory costs.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B12 — Construction labor and crafting**
- Scope: Material fabrication, builder crews, project durations and supply deliveries.
- Acceptance: Time and resource ledger reconcile exact costs.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B13 — Construction undo/redo and state recovery**
- Scope: Action journal, rollback, partial builds, relocation and demolition refunds.
- Acceptance: Arbitrary valid edit history restores same exact dwelling.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B14 — Player-centered multimodal building UI**
- Scope: Context tablet, smart snapping, precision nudge, touch gestures and accessibility.
- Acceptance: Equivalent build session in keyboard, controller and mobile.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B15 — Consequential housing gameplay**
- Scope: Shelter, warmth, storage, family privacy, farming productivity and NPC comfort.
- Acceptance: Completed buildings cause real cross-system effects.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B16 — Original architecture asset generator**
- Scope: Stylized realistic beams, roofing, modular furniture, texture atlases and weathering.
- Acceptance: Every emitted asset original/rights-verified with LOD budget.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B17 — Interactive construction physics**
- Scope: Movable furnishings, bounded rigid bodies, attachment stability and material feedback.
- Acceptance: No mobile physics explosions or collision softlocks.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B18 — Community construction events**
- Scope: Restoration contracts, storm rebuilding, resident help, contests and seasonal constraints.
- Acceptance: Event/quest resolution has failure recovery and saved consequences.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B19 — World creation catalog ownership**
- Scope: Author 10 original features of first shared 20, then 100 of next 200.
- Acceptance: Unique IDs, player verbs, schema, platform controls, cost and acceptance for each.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**B20 — Construction Godot vertical slice**
- Scope: ONLY after shared 220 catalog completed, build modular first complete cottage interactions.
- Acceptance: Native Godot build proves place/undo/save/load without phantom inventory.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

### E: Emergent Gameplay and Events Inventor — 20 scoped missions

**E01 — Prior-capability novelty audit**
- Scope: Map existing EverBloom mechanics, collisions, concepts and original differentiation.
- Acceptance: Each proposed feature compared to current source; reskins rejected.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E02 — Initial feature catalog tranche**
- Scope: Author 10 varied new mechanics complementing Builder's 10.
- Acceptance: Shared exact 20 IDs fully specced and reviewed before expansion.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E03 — Two-hundred feature expansion**
- Scope: Author 100 additional advanced systems complementing Builder's 100.
- Acceptance: Combined 220 total unique spec IDs before new feature implementation.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E04 — Emergent world event director**
- Scope: Causal trigger graph, priorities, cooldowns and player-choice consequences.
- Acceptance: Event storms and duplication prevented by deterministic replay.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E05 — Ecosystem-wide feedback loops**
- Scope: Biodiversity, biomes, symbiosis, animal movement and player stewardship.
- Acceptance: Visible bounded environmental consequences over seasons.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E06 — Inventive festivals and rituals**
- Scope: Community-created traditions, celebratory events, year-long competitions.
- Acceptance: Genuine changing rules and durable town memory.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E07 — Procedural personal storylines**
- Scope: Narrative constraints, NPC emergent requests, rare opportunities and outcomes.
- Acceptance: No incoherent/missing story transitions after reload.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E08 — Regional economic shocks**
- Scope: Caravan arrival, supply-chain disruptions, contracts and town economic adaptation.
- Acceptance: Effects are challenging but never exploitative or fatal softlock.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E09 — Exploration and traversal inventions**
- Scope: Watercraft, climbing, mount abilities, trail tools and dynamic secret paths.
- Acceptance: Input accessibility and meaningful exploration progression.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E10 — Utility animal companion systems**
- Scope: Companions with unique farming, tracking, scouting and town abilities.
- Acceptance: Balanced progression, autonomy and fail-safe accessibility.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E11 — World mysteries and treasure logic**
- Scope: Clues, secret societies, ruins, cultural history and puzzle solving.
- Acceptance: Multiple viable paths plus persistent journal and hints.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E12 — Player-organized town projects**
- Scope: Village markets, monuments, bridges, celebrations and restoration campaigns.
- Acceptance: NPC labor/resources visible in completed outcomes.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E13 — Creativity and maker economy**
- Scope: Craft combinations, textile dyeing, furniture personalization and exhibitions.
- Acceptance: Unique player creation state with reversible resource costs.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E14 — Weather and astronomical wonders**
- Scope: Seasonal rare encounters, meteor nights, auroras and environmental challenges.
- Acceptance: Predictable difficulty, grounded calendar and seeded tests.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E15 — Nonlinear mastery pathways**
- Scope: Optional skill trees, lifestyle specializations and adaptive difficulty.
- Acceptance: No early choice ruins future gameplay or forces grinding.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E16 — Offline collaboration experiences**
- Scope: NPC co-build and chore sharing without dependency on online multiplayer.
- Acceptance: Whole game functional offline with simple local state.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E17 — Privacy-safe feature instrumentation**
- Scope: Opt-in local-only playtest metrics, perf traces and instrumentation hooks.
- Acceptance: No telemetry transmitted and privacy-default verified.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E18 — Independent adversarial gameplay QA**
- Scope: Fuzz save/replay, input parity, feature gating, denial and long-session regressions.
- Acceptance: Every major feature has native negative tests and exact SHA receipts.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E19 — Cinematic stylized-realistic quality**
- Scope: Art direction, camera feel, seasonal lighting, audio, 3D VFX and touch fallbacks.
- Acceptance: Original/rights-verified assets plus measured performance tiers.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

**E20 — Emergent Godot implementation slice**
- Scope: ONLY after 220-feature validated roster, implement coherent event/farming/village vertical slice.
- Acceptance: Native CI verifies event encounter, choices, effect, save and replay.
- Deliverable: original code/data/technical specification, dependency contracts, tests, accurate status and exact GitHub receipts.

## Innovation feature ledger contract

Phase A: 20 concept entries, ten owned by B and ten by E. Phase B: 200 additional entries, 100 owned by B and 100 by E; total 220. Maintain a machine-readable CSV/JSON ledger with feature IDs, audit, ownership, priority, implementability, user controls, gameplay effects, test gates and precise phase completion receipts. Do not count this 100-mission charter as the 220 concept ledger.

Phase C: after ledger verification, rank and implement coherent Godot vertical slices, starting with a meaningful from-foundation-to-roof house construction mechanic and integrated NPC/farming emergent event. Build native Godot acceptance with save/reload, controller/touch mapping and fair economy. Future Unreal/Unity migration is a separate approved project after genuine Godot baseline acceptance.
