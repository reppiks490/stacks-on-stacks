# Construction B101–B110 architectural-art typed-state handoff

**Mission B19/B16; status: design only.** All ten frozen Phase-B concepts now have bounded nested types and adversarial fixtures. **Phase C CLOSED.** No new Godot gameplay, meshes, sound assets, save integration, money transactions, or measured device performance.

**Frozen source:** `game/everbloom-construction-phaseB-100-20261102@f6b61bd73dede5703dcf8ef45ea24d47e28b8065`, blob `d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b`.

## Per-feature deterministic contracts

- **B101 Living Trellis:** sunlit unique window anchors, vine age, growth stage and no future pruning.
- **B102 Coppergreen Patina:** deterministic moisture/sealant/age finish progression, without structural effects.
- **B103 Seasonal Awning:** angle/wind/anchor rules determine wear and shade; invalid support rejected.
- **B104 Shadowlace Lantern:** unique bounded screen cutouts, finite lamp fuel and deterministic shadow projection.
- **B105 Timber Sound Garden:** original surface-specific audio, exactly one bounded footstep event.
- **B106 Mirrorpond Courtyard:** water <= finite capacity; cosmetic recirculation cannot create water.
- **B107 Frostlace Windows:** below-freezing humidity/heat and unique mask cells determine coverage.
- **B108 Kinetic Sculpture:** balanced blades, finite bearing wear and capped animation speed.
- **B109 Celestial Roof Aperture:** roof clearance and monotonic calendar window determine star visibility.
- **B110 Heritage Facade:** original motif IDs and versioned finishes cannot grant structural or weather bonuses.

## Integration and proof boundaries

Principal owns inventory, money, atomic receipt replay, `day_epoch=(year-1)*56+season_index*14+day`, optional save namespaces and migration. Synthetic fixture receipts must never enter live saves or economy. Farming owns weather, plants, finite water and materials; Valley owns world geometry, roof occlusion, collision, stable IDs and navigation; Village owns consent and access; Emergence owns astronomical events. No feature can independently grant cross-domain rewards.

Controls are **planned**, not device tested: keyboard/mouse toolbar, drag, precision scroll, Enter/Escape; controller radial selection, sticks, shoulders, A/B; touch drag/steppers and >=44px confirm/cancel. Always offer text/color-independent errors, reduced-motion and muted sound options. Original asset plan: self-authored trellis, patina metal, cloth shade, cutout screen, surface tiles, water basin, frost decals, rotor, aperture and facade motifs with creator/rights/SHA256/LOD manifest. No proprietary third-party assets.

**Unmeasured performance targets:** desktop <=2ms preview, 60fps, <=64 nearby anchors; mobile <=4ms preview, 30fps, <=24 anchors. Cache meshes, bound VFX/audio, use static animation rather than uncontrolled rigidbodies. Physical devices and original audio/meshes remain untested/unbuilt.

**Blocking gates:** independent semantic review of all 220; Principal authorization; unknown material IDs (iron/glass/fiber/dye/clay/seed); authoritative weather/water/roof/consent contracts; actual Godot placement/undo/commit, assembled save migration, 112-day replay, negative economy tests, controller/touch parity, and device profiling. This Python validator checks design fixtures only, not playable behavior.
