# EVERBLOOM Construction B051–B060 material-processing typed-state handoff

**Mission ownership:** Construction Inventor, B19 (ten of the 100 Phase-B concepts), B12 (materials and crafting), B16 (original modular visual contracts), B13 (replay/undo design), B18 (community supply dependency), and B20 (future gated gameplay). **Status:** design-only; no new playable mechanics. **Godot:** 4.x only. **Canonical main at claim:** `07546c9402bd0d44c899719a115c1a46b91d85cc`. **Frozen source catalog:** `f6b61bd73dede5703dcf8ef45ea24d47e28b8065`. **Phase C:** CLOSED pending Principal joint 220-feature approval.

## Explicit feature semantics and negative tests

| ID | Original mechanic | Bounded nested state | Rejected conditions |
| --- | --- | --- | --- |
| B051 | Waterwheel Timber Sawmill | `log_batches`, `plank_yield` | Log/plank/sawdust/waste mass mismatch, unsafe feed, output without waterwheel rotation, produced output not equal batch sum. |
| B052 | Clayfire Pottery Kiln | `kiln_batches`, `heat_curve` | Clay/tile/scrap mass mismatch, insufficient fictional fuel, premium quality without cooling/hold time, future firing epoch. |
| B053 | Glasssong Window Foundry | `glass_batches`, `anneal_ticks` | Pane mass mismatch, unearned low stress, incomplete annealing, release in the future. |
| B054 | Stonecut Facet Bench | `cut_planes`, `stone_offcuts` | Input mass mismatch, excessive cut depth, offcut account mismatch. |
| B055 | Cordage Spinning Wheel | `fiber_batches`, `rope_grade` | Fiber mass mismatch, insufficient twist for sturdy grade, load greater than rated finite capacity. |
| B056 | Forgefast Hardware Table | `iron_lots`, `hardware_recipe` | Metal mass mismatch, fuel/heat budget mismatch, unearned hardware output, impossible tool-wear recovery. |
| B057 | Pigmentbinder Plaster Mill | `plaster_batches`, `finish_life` | Applied mass mismatch, excessive coat thickness, long finish life on wet substrate, future application. |
| B058 | Pressedleaf Tile Workshop | `tile_molds`, `emboss_depth` | Tile mass mismatch, emboss depth exceeds thickness/mold, false crack count or mold count. |
| B059 | Salvage Sorting Yard | `salvage_lots`, `grade_scores` | Unbalanced recovered mass, grading unverified lots, credited mass exceeds reusable mass, reused source receipt across lots. |
| B060 | Handcarved Furniture Studio | `furniture_blueprints`, `joinery_nodes` | Timber mass mismatch, orphan joints, unsupported load or load exceeding blueprint rating. |

**Schema:** strict JSON-only fields, bounded signed integer units, no booleans as integers, finite `day_epoch`, unique nested IDs, unique capped local receipts, no unknown keys or control characters. Inactive legacy default means no active material work. Active state requires site ID, revision >=1, epoch >=1. Each state has two active valid variants, one inactive default, three or four targeted invalid examples and fifteen shared adversarial mutations. JSON canonical roundtrips are tested offline. The Python validator rejects duplicate JSON object keys and NaN/Infinity. Its results are design-contract checks, not gameplay simulations.

## Authority and integration boundaries

**Construction** owns nonmutating previews, geometry, in-world station art, local state proposals and UI explanation. **Principal** owns authoritative material/coin inventory, durable replay prevention, immutable source receipt IDs, full-game atomic save/migration and output settlement. **Farming** owns extraction and resource acquisition; **Valley** owns water flow/terrain/collision/navigation; **Village** owns public permits, NPC labor and consent. Material-processing output is NEVER minted by these design contracts. The B059 local source-receipt uniqueness check does not prove that a source receipt exists in the authoritative demolition ledger or has not been consumed elsewhere; Principal must supply that cross-domain proof. Capped local `receipts` cannot guarantee lifetime anti-replay.

**Important catalog limitation:** B051–B060 source resource quotes are *unapproved proposals* (e.g., glass consumed to create a glass foundry, stone spent to construct a furniture studio). They require Farming/Principal material-economy review and cannot become live charges until acquisition, recipe feasibility, item IDs, inventory conservation and refunds are approved. The fictional kiln/forge simulations are game abstractions, not real hazardous construction or fire guidance.

**Controls and feedback:** Each source concept specifies mouse/keyboard, controller and touch preview-adjust-confirm-cancel, plus status messages, rejected reasons and undo previews. This handoff preserves the exact source controls, original asset plans and unmeasured desktop/mobile preview budgets. No physical controller/touch, measured FPS, scene animation, original model generation or device verification has occurred. The future material station art kit requires independently authored meshes, UVs, sound and provenance records with mobile LOD and color-independent validity cues.

## Reproducibility, migration and acceptance

Run `python3 docs/innovation/construction/typed_state/validate_material_051_060.py`. Dedicated push-only non-Codex workflow `.github/workflows/everbloom-construction-b19-material-types.yml` runs that offline validator. The generic native workflow also runs on pushes, but **a generic Godot baseline pass does not prove B051–B060 gameplay**. Record exact SHA and workflow run only after inspecting GitHub execution status.

Proposed namespaces `construction.eb_b_051`–`construction.eb_b_060` are not yet registered with SaveService. Principal must explicitly approve migration; absent namespace stays inactive, present malformed nested namespace fails atomic admission. Do not silently clamp/normalize, double-spend, or grant output on reload. Future native Godot acceptance must use actual `game.gd` and `save_service.gd`: preview a sawmill or furniture station, confirm once with authoritative input quote, show player feedback, cancel/undo with one inverse transaction, save/restart/load, repeat the same command ID, cross epochs 56→57 and 112→113, and verify identical material/currency totals and no duplicate output. Test mouse, keyboard, gamepad and touch adapters separately, then measure desktop/mobile performance.

**No code under `scripts/`, no gameplay assets, no save data, no other engineering lanes and no existing branches modified.** No PR or engine port authorized. Semantic overlap and novelty require Principal review before any feature integration.
