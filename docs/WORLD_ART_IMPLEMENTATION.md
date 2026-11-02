# EVERBLOOM world-art implementation: seasonal meadow pass

**Owner:** World Art Director. **Candidate branch:** `game/everbloom-world-art-seasonal-valley-20261102`. **Status:** source implemented; native CI evidence must be attached at the final commit before merge. This document is not an art-completion or device-performance claim.

## Original, rights-safe additions

- **Batched wildflower meadow:** `scripts/valley.gd::_wildflowers` authors a low-poly blossom mesh from Godot's built-in `SphereMesh`, with deterministic positions from RNG seed `20261102`. A single `MultiMeshInstance3D` holds 480 desktop or 180 mobile flowers; per-instance seasonal colors, no textures or downloaded models. The mobile limit is a provisional engineering policy, **not** a measured performance result.
- **Four-season palettes:** spring blossoms, summer greens, autumn copper, winter frost. `_apply_season` changes cached terrain/foliage materials and per-instance blossom colors on season transitions only; no geometry reconstruction or allocation every frame. The original forest remains explorable and foraging points stay fixed.
- **Weather-responsive lake:** rain and mist adjust lake material tint; 32 procedural reeds with seed heads define the shore silhouette. These are decorative and do not change the fishing reach, water physics or navigation.
- **Village landmark:** two authored timber market shelters at the edge of the square improve visual hierarchy without replacing villagers or rewriting the game orchestrator.
- **Calendar correction:** `act()` uses the principal's monotonic `game.day_epoch()` for fishing and foraging, so the same calendar day in another year no longer collides in a continuous session.

**Provenance:** All added geometry, palette constants and placement logic are independently authored project source in `scripts/valley.gd`; only standard Godot procedural meshes/materials are used. No third-party meshes, textures, audio, fonts, shaders, or commercial reference-game extracts are introduced. The existing `assets/provenance.json` inventories disk-based assets; this source-generated geometry is documented here.

## Integration and verification

Native contract runner: `scripts/world_art_acceptance.gd`. Workflow: `.github/workflows/everbloom-world-art-acceptance.yml`, using checksum-verified official Godot 4.7.2, editor import, source parse and engine-run assertions. The existing general project validation also runs on pushes. Require passing **exact final SHA** for both, and principal/QA review of the runtime and code. Do not merge on the basis of a green source-only check.

**Known limitations:** World remains an original procedural graybox; market roofs, reeds and foliage are static. No authored terrain heightmap, dynamic shadows budget, wind animation, proper shoreline collisions, atmospheric audio, 3D character animation, photomode, or real mobile-device profiling yet. The fish/forage last-used epoch is not serialized by `game.gd`'s save schema; reloading a save can reset it. This must be solved jointly with Principal before claiming robust anti-duplication. The grassland uses a single shared flower mesh, not production-quality vegetation. Mobile fallback counts are unbenchmarked; GPU overdraw and draw calls require actual device instrumentation.

## Next art slices (not implemented)

1. A terrain-chunk architecture with heightfield navigation, shoreline gradients and a visual-memory budget; test chunk streaming across fast traversal and saves.
2. Wind-aware instanced foliage and camera-scaled near/mid/far vegetation LOD with motion-reduction control and measurable frame-time budgets.
3. Original weather particles, ambient soundscape, seasonal sky/light transitions, and accessible mood settings; coordinate `game.gd` world environment ownership with Principal.
4. Author-made buildings, interiors, village signage and unique landscape silhouettes. Maintain per-asset provenance and review rights before importing any third-party content.
5. Measured target budgets: initial **design targets only** of 16.7 ms/frame at 60 FPS on a named desktop and 33.3 ms/frame at 30 FPS on a named mobile device; neither is currently verified.

Coordination: GitHub issue #8 for art-lane progress and issue #2 for principal integration. Preserve all other lane files, branches and prior history; never invoke Codex.
