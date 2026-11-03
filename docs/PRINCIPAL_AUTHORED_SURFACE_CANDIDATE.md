# P14/P15 authored-surface material integration (isolated candidate)

This is a **real Godot spatial shader asset**, not a finished art pass or evidence of visual quality. It is deliberately not attached to existing gameplay meshes: the source still uses placeholder primitives, and a blind global material swap would obscure that defect.

File: `assets/materials/authored_surface.gdshader`. Assign to **original, UV-unwrapped meshes** only after texture provenance is recorded. Inputs: linear/sRGB albedo, tangent-space normal, scalar roughness, all authored or independently licensed. Do not feed random noise or color-only textures as substitutes for model detail. Adjust `uv_scale` to authored UV density; roughness floor/ceiling avoid glossy plastic; normal strength is bounded; macro modulation is subtle and object-local (not cross-chunk seamless). Materials need a coherent palette and per-surface calibration before shipping.

**Acceptance still required:** Godot 4.7.2 native shader compilation, actual mesh render before/after from identical camera/exposure, desktop/mobile capture and draw-call/frame-time measurements; material-asset SHA256/license ledger; cross-chunk UV/seam review, collision parity, 120-frame smoke and save regression. No renderer or measured GPU data was available during this candidate creation, so these gates are **UNVERIFIED**. Do not integrate into main or describe this as premium finished art.

**Coordination:** Principal P14/P15 owns shader contract and visual gates; Construction owns authored architecture meshes; Emergence owns authored environmental assets; Farming/Village retain their gameplay paths. No existing scene, source, save, or workflow was changed. Godot 4.x only. No Codex.
