# SABLESTAR development evidence — 2026-11-01 (America/Chicago)

## Native source milestone, independently checked in GitHub Actions

- Baseline code SHA: `62ef38cde4513d554d2f98be973c9964e0f8b23b`.
- Godot binary: `Godot Engine v4.7.2.stable.official.ed1daf0bf`, fetched from the official release and checked against SHA-256.
- Feature-branch CI run: https://github.com/reppiks490/stacks-on-stacks/actions/runs/41379257781 — **success**.
- Default-branch CI run: https://github.com/reppiks490/stacks-on-stacks/actions/runs/41379347129 — **success**.
- Baseline source tests: **19/19 pass**, Python validator pass.
- Native parse/import: **passed** in the reported runs, including OBJ/SVG/WAV imports.
- Native scene smoke: **120 frames completed headless**, no detected GDScript parser or resource-load errors.

This verifies engine bootstrap and a short noninteractive scene run. It does **not** establish UI quality, playable responsiveness, controller/mobile accessibility, export performance, multiplayer networking, finished AA content, or shipping readiness. CI artifact logs contain the exact evidence.

## Follow-on asset wiring branch

Sableblade OBJ, SABLESTAR/Hollow/Ember icons and PCM WAV cues are being connected to the live player/HUD/game-root sources, and legacy OBJ PBR warnings removed. The above evidence belongs to its exact baseline commit; each follow-on revision requires **fresh** source and headless CI before being considered verified.

- Original asset count: ten source-backed assets, tracked in `assets/provenance.json`.
- No commercially ripped assets are included; no rights to other games' private source presumed.
- No Codex, no new spending and no automation outside the ordinary non-Codex repository workflow.

Next acceptance gates: confirm new asset imports, inspect frame captures, test combat/AI with actual input, validate local saving, establish gamepad/touch controls, and run 10-minute performance profiling and export checks before calling this a playable prototype.
