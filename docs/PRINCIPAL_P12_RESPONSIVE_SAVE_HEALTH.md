# P11/P12/P16/P18 — Responsive Save Health modal (Godot 4.x)

## Ownership and scope
Principal-owned changes: `scripts/principal_save_health_panel.gd`, `scripts/principal_save_health_panel_acceptance.gd` and this document. No change to `scripts/save_service.gd`, domain saves, Village, Farming, original assets, or innovation catalogs. Based on canonical `main@d9c52f1b34956e2264c6b10d491aeac5bb628c78`. The pinned charter was read at `b8a1e635792b08b0a3d87b987e593a539ac5c123`.

## Player-visible behavior
- Narrow portrait (width < 540 and height >= 460): full-width inset modal, text-size and Refresh/Return buttons stack vertically, preserving 44px minimum touch targets.
- Short landscape: full-width inset modal, paired controls stay in two columns to preserve report height.
- Desktop: centered 80%-width modal with two-column controls.
- Title wraps, diagnostic report remains vertically scrollable, text size remains adjustable from 85% to 160%, English and Spanish text and existing keyboard/controller/touch input semantics remain.
- Viewport changes recompute geometry even when the report is open; no gameplay/save fields change. Diagnostics remain read-only.

## Deterministic native acceptance
The existing assembled-game native runner exercises a real Save Health modal over an actual game scene, a corrupt primary and valid backup. Additional viewport checks resize the headless Godot root to 320x568, 640x360 and 1280x720, verifying control reflow, report minimum height, in-panel controls at 160% Spanish scale, desktop restoration, and unmodified selected backup. Native CI: `.github/workflows/everbloom-principal-save-health-ui.yml` (push-only, official checksum-pinned Godot 4.7.2), plus general validation.

## Limits and budgets
This is viewport-size simulation on Linux, **not** physical mobile/controller, screen-reader or GPU performance proof. No additional textures, shaders, meshes, audio, network requests or save bytes. Reflow is O(1) on viewport size changes, with five static controls and no per-frame layout polling. Device memory/frame-time measurement remains P13 work. Ultra-short (<460px tall) portrait screens may still require a future alternate reduced-chrome presentation. Touch dragging is provided by Godot ScrollContainer; physical gestures remain unverified.

## Dependencies and next acceptance
Requires the existing Principal Save Health UI, Village modal exclusion, and SaveService.inspect_save_health(). Keep all other loop files untouched. Native Godot exact-HEAD CI must pass before integration. Subsequent P11/P12 tasks: real device touch, hardware gamepad focus and screen-reader support. Innovation Phase C remains CLOSED.
