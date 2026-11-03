# EVERBLOOM — Solid World and Character Rebuild

**Status:** isolated development branch `fix/everbloom-solid-world-character-rebuild-20261102`, based on `feature/everbloom-continental-expansion-20261102`. Original `main`, branches, saves and the five hourly engineering automations remain unchanged. No Codex was used.

## Reported defects, evidence and repairs

### Players walked through entire buildings
Previous `scripts/valley.gd` and `scripts/continental_world.gd` produced much of the architecture with `MeshInstance3D` nodes alone. These had no collision volumes. `scripts/world_collision.gd` now attaches corresponding layer-1 `StaticBody3D` / `CollisionShape3D` colliders to structural walls, houses, posts, fences and market components. `scripts/premium_scenery.gd` adds walkable bridge-plank and structural landmark volumes. `scripts/sculpted_architecture.gd` creates physical house envelopes and sloped `ConcavePolygonShape3D` roof colliders; porch and chimney collider transforms are aligned with their visible surfaces.

### Players fell off the edge of the old 145-unit homestead
Originally the extended terrain mesh rendered beyond the 145-unit ground slab, but a real Godot ray test showed **no physics hits beyond ~72.5 units**. Source-only and 120-frame smoke tests had not tested terrain support. `scripts/continental_world.gd` now enables `backface_collision` on the generated static trimesh, adds explicit outer-border barriers and naturally raised perimeter height, and restores the last safe grounded position on severe falls. `tests/native_solidity_acceptance.gd` tests real player capsule sweeps, farmhouse/bridge ray hits, border collider, and real terrain ray hits at x=70, 73.5, 78, 118, 146, 155 and 190. **No ray-miss assertion may be removed to make CI green.**

### NPCs and the farmer were stacked primitive shapes
`scripts/sculpted_humanoid.gd` replaces assembled sphere/box heads and torsos with originally authored `SurfaceTool` multiring meshes, clothing silhouettes, eyebrow and nose variations, contoured facial parts, faceted hair/locks, body proportions, accessories and joint pivots. It is used by the farmer, all frontier residents, and the six original Larkspur villagers.

The user-facing `C` atelier now has **18 persistent categories**, up from 10: skin, face, jaw, brow, nose, mouth, eyes, eye size, hairstyle, hair color, hair length, outfit, pants, build, height, footwear, headwear and accessory. The original saved `user://everbloom_avatar.cfg` categories still load; missing new categories take defaults. The original local `everbloom_save_v1.json` schema is unchanged. New resident `AnimatableBody3D` physical presence replaces ghost characters.

This is a **better-authored procedural mesh and pose-rig foundation**, not yet a commissioned artist's skinned/skeletal 3D model. Facial micro-animation, cloth physics and bespoke high-poly PBR models remain production tasks.

### World structures, plants and horizon looked like random boxes and balls
`scripts/sculpted_architecture.gd` now supplies gabled meshes with roof tile shader, painted plaster surface, facade/window meshes, porch, chimney and collision. Core homestead and the 28 settlement house types call this shared kit. `scripts/sculpted_foliage.gd` generates pointed leaf canopies, tapered trunks and irregular rock meshes for original orchard, surrounding woodlands, valley groves and 4.8 km streamed terrain. The old rows of giant spherical hills near the former valley edge and doubled-up cottage roofs were retired.

The 4,800 × 4,800 footprint and 32 × 32 chunk grid are preserved. Streaming stays within the 3 × 3 neighborhood.

## Verification and limits

The non-Codex workflow `.github/workflows/everbloom-solid-world-acceptance.yml` performs source contracts, Godot 4.7.2 import/parse, native physical collision acceptance and native sculpted-avatar acceptance. The older `everbloom-native-validation.yml` also runs Python/data checks, main scene smoke (120 frames) and save/recovery test.

Pass criteria cannot be inferred from GitHub commit presence; inspect exact-HEAD job conclusions and diagnostic logs. The physically grounded run before this document added 20 solidity assertions and 11 avatar assertions, all passed at `bffab194693ef6cc93c7c17404bbe6f9ac9ee14f`. Subsequent commits require their own exact-HEAD CI.

**Not verified:** interactive desktop graphics quality or actual user GPU FPS; persistent smooth 60 FPS on PC or 30 FPS on mobile; collision/entry/navigation for every decorative object in all 28 settlements; a true infinite world; completed 4.8 km bespoke terrain art; shipped rigged facial animation; or release-quality interiors.

## Manual acceptance route (Windows)

1. Use a separate Git worktree for the repair branch; never overwrite the owner's active folder.
2. Launch the `project.godot` inside the newly created worktree.
3. Walk into the front wall of the farmhouse. The player must stop.
4. Walk onto the original footbridge. The player must stand on solid steps.
5. Move beyond the original x=72.5 homestead edge; terrain should be solid beyond x=190, not a fall into void.
6. Press M and visit a distant city, verify authored houses and residents; press C and inspect each of the 18 avatar categories.
7. Test outer border behavior and F9 30-second frame-time measurement on the real GPU.
8. Check save/load and wardrobe compatibility, then report screenshots and GPU measurements. A headless job cannot replace visual inspection.

## Remaining art-production gates

Adopt fully authored/rigged original or independently licensed GLB human/animal meshes; bespoke anatomy and facial morphs, cloth layers and real skeleton animation; terrain/architecture kit textures with high-resolution physically based normal/roughness maps; scenic composition and custom landmarks per region; NPC navmesh/schedules/door systems; high-fidelity water, sound, atmosphere, wind and weather; device-specific HLOD/impostors; measured desktop/mobile performance. No unapproved commercial game extraction or paid tools.
