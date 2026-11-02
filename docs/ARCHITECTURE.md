# Core architecture / engineering contracts

The goal is a new **AA-scope** title borrowing *design principles*, not code, art or franchise identity from reference games. Strong production features are planned, but the current deliverable is a small, original graybox foundation.

## Game loop

Traverse fragmented terrain → choose which Resonance resource to harvest → fight telegraphed enemies → use loot to stabilize or exploit regional gates → change faction affinity, routes and encounter parameters. Future vertical-slice outcome must have combat, movement, world manipulation, consequence, UI and reliable saving in one end-to-end journey.

## Runtime authority and components

- `game_root.gd` owns world/session orchestration, spawn and HUD dispatch.
- `player_actor.gd` owns local movement, health/stamina, live attack admission and target selection.
- `enemy_actor.gd` owns enemy state and telegraphed melee; this **is not** navigation-mesh pathfinding or netcode.
- `world_builder.gd` owns deterministic geometry. The graybox crystal props are destructible; the terrain itself is **not** voxel-destructible.
- `resonance_crystal.gd` owns destructible prop rewards and emits a one-time `shattered` event.
- `beacon.gd` exposes faction choice, only after explicit nearby player interaction.
- `companion.gd` owns local visual follow and limited sustain (not autonomous squad AI).
- `session_state.gd` is the single source of local player/progression/session state.
- `save_service.gd` validates allowlisted, versioned save data, independent of node implementation.
- `hud.gd` owns HUD construction and user messaging.

All content IDs are namespaced; numeric resources have defined caps. Enemy hits need active target checks and time/window verification. Local attack callbacks must not resolve after entity death. Damage never assumes a network-authenticated server. No remote peer authority implemented.

## Future work: prioritized capability domains

| Domain | Intended design | Current status |
|---|---|---|
| Traversal | Grounded sprint, jump, mantle, glide, air dash | Sprint/jump/dodge graybox |
| Combat | Combo windows, guard/parry, poise, abilities, enemy counters | Single strike + pulse, telegraphed AI |
| Destruction | Impact deformation, puzzle terrain, material fracture | Local crystal shatter only |
| Party | Companion tactics, contextual bonds, command wheel | Following healing orb |
| Narrative | Branching quests, companion approval, durable consequences | Two faction affinity choices |
| World | Dense authored biomes, caves, weather, wildlife and streaming | Deterministic boxed arena |
| Survival tension | Light, sound and limited resources in hostile dungeons | Concept design |
| Production | Original skeletal rigs, cinematic pipeline, sound, accessible UI, LOD | Not implemented |
| Platform | PC-first, controller, Android/iOS feasibility and optimization | Mouse/keyboard + stick input only |
| Multiplayer | Server authority, persistence and anti-cheat | Not in scope of this source drop |

## Security / safety / provenance

Original source code only; do not import extracted copyrighted assets into this repository. Research observations should include source/evidence, level of confidence, and independent implementation plan; no conjecture as confirmed native fact. Never trigger Codex via automated workflows, PR bots or agents. No external API keys, telemetry or paid data connectors.
