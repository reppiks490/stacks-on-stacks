# EVERBLOOM 4.8 km Premium World Framework

Branch: `feature/everbloom-continental-expansion-20261102`

This branch is an isolated, non-destructive Godot 4.7.2 expansion candidate. It is not merged into `main` and does not claim final AA/AAA visual quality.

## What is implemented

### World and rendering foundation
- 4,800 × 4,800 world contract, divided into 32 × 32 150-unit chunks.
- Only a 3 × 3 neighborhood around the player is kept active.
- Continuous rolling terrain generated from world coordinates; adjacent chunk edges share height values.
- Collision is created from the same terrain mesh, while the original homestead and settlement cores are flattened for existing interactions.
- 28 named destinations across villages, towns, ports, cities, capitals and kingdoms.
- Scrollable continental atlas, waystone travel and panorama camera.
- Dense MultiMesh grass, flowers, tree canopies, trunks and rocks for bounded draw-call cost.

### Authored procedural art framework
- `scripts/premium_scenery.gd` adds original hand-shaped petal meshes using SurfaceTool, ornamental bridges, flowered garden arches, scenic gazebos, banners and dense settlement garden dressing.
- Custom ShaderMaterial surfaces add procedural color/grain/roughness variation without importing proprietary textures.
- Homestead and loaded settlements instantiate this dressing at runtime.
- Earlier visual pass retains improved cottage facades, shutters, flower boxes, porches, chimneys, orchard, pond planting and lanterns.
- This is a **procedural authored-geometry framework**, not a substitute for a future Blender-quality rigged-character / bespoke-mesh asset pass.

### Character and movement
- Persistent character atelier: skin, face, hair, hair color, eye color, outerwear, trousers, silhouette, headwear and accessories.
- Smooth acceleration and braking, gravity, jumping, slope limits, sprint stamina and different mounted handling.
- Tameable mounts, riding speed, adoptable pets and following behavior.

### Living-world mechanics
- Frontier residents with professions, basic schedules, friendship, conversations, daily commissions and gifts.
- Scheduled flea-market fashion with wearable purchases.
- Persistent exploration journal records first visits to settlements and biomes.
- First discovery grants bounded petals/restoration and is saved separately from the schema-1 farm save.
- Existing farming, village, festivals, animal care, save/recovery and economy systems remain present.

## Controls added by this branch

- Shift: sprint
- Space: jump
- C: character atelier
- M: continental atlas
- V: panorama view
- L: explorer journal
- U: frontier NPC interaction / market
- N: mount / dismount
- B: pet interaction
- F9: start/stop 30-second real-device performance benchmark
- F10: hide/show performance overlay
- F1: full field guide

Existing farming, village, save/load and festival keys remain intact.

## Desktop performance measurement contract

`scripts/desktop_profiler.gd` reads actual Godot runtime monitors. It records:
- FPS mean, minimum, maximum and p10
- mean frame time and p95 frame time
- average draw calls
- peak reported static memory
- benchmark duration and sample count
- player position at the end of the sample

The report is written to `user://everbloom_performance_latest.json`.

A CI/headless pass proves the profiler parses and the game starts. It **does not measure the user's Windows GPU performance**. Press F9 in the running game and actively walk/ride through farm, wilderness and a city for 30 seconds to produce a real desktop result.

## Windows launch and reset

`tools/launch_everbloom.ps1` finds the installed Godot executable rather than assuming a fixed WinGet path.

Normal launch never deletes progress.

`-ResetSaves` is intentionally separate: it locates exactly one EVERBLOOM Godot user-data directory, requires typing `RESET`, creates a timestamped backup in Documents, then removes only known EVERBLOOM progression/profile files. It includes farm save, avatar, frontier social, companions and exploration profiles.

## Performance and quality rules

- No Codex in any form.
- No paid assets or copied commercial-game resources.
- MultiMesh is used for high-count repeated scenery.
- Loaded terrain stays bounded to 9 chunks.
- Performance targets such as 60 FPS desktop / 30 FPS constrained mobile are **targets until measured on hardware**.
- Do not claim visual completion from headless CI.
- Future authored asset work should replace temporary procedural character/building geometry with original or rights-verified rigged meshes, texture atlases, PBR maps and LODs while preserving these runtime contracts.
