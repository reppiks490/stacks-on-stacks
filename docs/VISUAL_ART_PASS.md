# EVERBLOOM — Living World and Avatar Atelier (visual foundation v1)

**Isolated branch:** `visual/everbloom-living-world-avatar-20261102`  
**Engine:** Godot 4.7.2, GL Compatibility.  
**Scope:** first original procedural visual-art pass, not a claim of AAA graphics or production asset completion.

## User-facing changes

- **World:** deterministic seasonal color variation in the 145x145 meadow, MultiMesh instanced grass (3,400 clumps), flowers (900 blossoms) and understory (440 shrubs), additional edge woodland, a nine-tree orchard, market kiosks and fountain, planted pond edge/lily pads, benches, flowerbeds and lanterns.
- **Architecture:** distinct shingled gables, roof trim, timber frames, flower planters, doors and windows, shutters, chimneys and porches layered over the six earlier placeholder cottages.
- **Water:** shader-based wave coloration over the existing Glimmer Lake mesh; its fishing state and collision are unchanged.
- **Player:** original assembled stylized 3D character with articulated walk motion, expressions, hair, clothing, satchel/other accessories, and profile storage independent of game save schema.
- **Customization:** 10 categories (skin tone x10, face x4, hair x8, hair color x12, eye color x7, outerwear x12, trousers x10, silhouette x5, headwear x7, accessory x6). Choices are independently combinable, but this is a stylized mesh assembly system, **not** a rigged scanned human or an imported high-detail commercial avatar.
- **UI:** compact upper-left game and progression ribbon, bottom-left interaction/satchel ribbon, and a toggleable F1 key guide. Preserves the live K job action text.

## Controls

- **C:** open or close character atelier.
- **Tab:** change customization category.
- **Left/Right arrows:** cycle the current category; saves automatically to `user://everbloom_avatar.cfg`.
- **A/D:** rotate the preview while customizing.
- **Escape:** leave the atelier.
- **F1:** display or hide the controls guide.
- Gameplay controls and native save/load remain as before.

## Integration contract

- `scripts/visual_environment.gd` is an additive child constructed by `valley.gd` after original interactive world setup. It must not alter `world.game` state, farmer position, collision or the farm/village/save structures.
- `farmer.gd` owns avatar appearance and local presentation storage. Main game save schema remains unchanged.
- `hud.gd` presentation is changed; its `setup(host)` entry point is preserved. Principal owns long-term HUD integration: reconcile against current `main` rather than replacing a newer Principal version.
- Visual improvement must be judged with an actual desktop screenshot and measured frame pacing. **Headless successful scene import is not image-quality or FPS evidence.**
- Existing `assets/provenance.json` is unchanged because this pass adds no files to `assets/`. Every mesh/shader was authored in project GDScript. All third-party extracted or proprietary assets remain prohibited.
- **No Codex**, paid assets, force pushes, automation changes or branch deletion.

## Verification and future priorities

Run `python tools/validate_project.py` and `python -m unittest discover -s tests -v`; run native Godot 4.7.2 `--headless --path . --editor --import --quit` and `--headless --path . --quit-after 120`; check branch-specific GitHub Actions logs for the exact SHA. Test manually on target GPU for shader behavior, avatar controls, framerate, camera focus and sunlight, and capture before/after screenshot.

The immediate next art pipeline step is **authored high-resolution textures, rigged and skinned characters, bespoke foliage and building meshes, proper terrain topology, animated fabrics, shadows and weather**, using legally clean tools and provenance. Procedural primitives alone cannot deliver the user's ultimate premium-game aesthetic.
