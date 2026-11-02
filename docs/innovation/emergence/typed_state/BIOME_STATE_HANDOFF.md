# Emergence E03/E05/E18 — biome typed-state handoff (E021–E030)

**Scope:** Original Godot 4.x EVERBLOOM project; isolated **design-only** biome-stewardship state contracts. Phase C is **closed** pending Principal's joint 220-feature approval. Nothing here implements an NPC, ecology tick, pathfinder, wildlife, art, inventory, save migration, or player interaction.

## Source and provenance

- Canonical charter: `docs/EVERBLOOM_100_ADVANCED_MISSIONS.md` on explicit branch `game/everbloom-100-mission-charter-20261102`, commit `b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Main at branch claim: `60ddc826630dc7e7279b4f9d2cf7e7ca39a40eec`; issue #2 and `docs/CROSS_LOOP_COORDINATION.md` inspected.
- Frozen original Emergence Phase B: `game/everbloom-emergence-phaseB-100-20261102@63cab5d05c742c61205933482e38fac2a4086764`, `docs/innovation/emergence/phaseB_011_050.json`, blob `a5def76918e77e0ded7e3e8085444698b4e0b549`.
- Previous E011–E020 typed work remains unchanged on `game/everbloom-emergence-e03-typed-state-20261102`. This tranche covers **only E021–E030** and does not replace earlier catalogs.

## Bounded contract inventory

| ID | Feature | Concrete guardrail | External owner |
|---|---|---|---|
| E021 | Mycelium Neighbor Network | Finite graph; unique log edges; connectivity equals verified active links | Valley owns trees/logs |
| E022 | Migratory Seed Hitchhikers | Unique seed IDs, one carrier route, one germination; cell/epoch consistency | Valley wildlife, Farming germination |
| E023 | Mosslight Microhabitats | Bounded shade/moisture observations; comparison requires two distinct plots | Farming water |
| E024 | Beetle Bark Rescue | Species-keyed bounded populations; unique intervention receipts; unknown species rejected | Valley populations, Farming crop effects |
| E025 | Meadow Song Diversity | Unique verified species, provenance, bounded diversity; audio-independent captions | Original art/audio and Valley observations |
| E026 | Turtle Crossing Steward | Finite epoch window and owner-confirmed reachable detour | Valley navigation |
| E027 | Wildflower Succession Diary | Strict stage progression, one advance per epoch, monotonic year-aware history | Valley/Farming habitats |
| E028 | Nocturnal Pollination Pact | Credit receipt linked to unique moth visit; dark-hours gate | Farming harvest effects |
| E029 | River Pebble Sorting Study | Advice tied to verified sites; bounded confidence; **knowledge-only** | Valley/Farming fish/water |
| E030 | Winter Dormancy Sanctuaries | Protected refuge needs reachable detour and explicit monotonic lock interval | Valley navigation, Principal calendar |

**Proposed schema amendment E030:** The Phase-B source has `refuge_ids, occupants, season_lock, detour_path` but cannot encode the exact date of protection expiry. This overlay proposes **version 2** additions `lock_start_epoch` and `lock_end_epoch`. Principal must approve migration. An active legacy v1 lock with ambiguous dates must not be silently reinterpreted as expired or unlocked. Missing optional namespace defaults to no active refuge; malformed present namespace must reject atomically.

**E028 source interpretation:** `credits` is typed as unique visit-linked receipt objects, **not a scalar**. This prevents one moth visit from issuing multiple local credits, but Farming must still own and verify every actual harvest effect and transaction digest. E024 lacks a historical baseline population ledger; this design bounds stored counts and receipt identities but **cannot prove total intervention population conservation** without Valley-owned authoritative history. These are explicit unresolved implementation gates, not claims of solved gameplay.

## Validation and acceptance

Run in an isolated checkout:

```sh
python docs/innovation/emergence/typed_state/validate_biome_021_030.py --self-test
```

The offline stdlib validator enforces ten exact frozen source IDs, 43 top-level bounded fields, 33 cross-field invariants, strict nested types, finite JSON-safe numeric bounds, unique observation/receipt identities, optional-namespace defaults, and intentionally invalid catalog/state cases. It also exercises ten nonempty valid states. The dedicated workflow is push-only, branch-filtered and read-only. **Offline validator PASS is not native Godot PASS**, real save/load proof, measured mobile performance, or semantic approval of the full 220-feature catalog.

### Principal/Farming/Village/Construction handoff

1. Principal decides whether E030's two new epoch fields and E028's receipt interpretation fit the optional save namespace and exact-JSON limits; define forward/backward migration, atomic rejection, and persisted command/effect receipts.
2. Farming verifies E022 germination, E023 water, E024 crop impacts, E028 pollination credits and E029 fish observations against authoritative resources; **no duplicate yields** or invisible water buffs.
3. Village and Construction review path detours where NPC homes, bridges and construction may affect traversability; Valley/Principal owns the actual navigation graph, not Emergence.
4. Emergence continues E031–E110 typed designs and independent negative tests after bounded evidence; full Phase-C native event→choice→effect→save/replay is still gated on joint acceptance. Godot first; no Unreal/Unity port without later owner approval.

**Operational restrictions:** No Codex, PR, auto-review, unapproved spending, proprietary assets, gameplay file edits, merge, publication, force push or branch deletion. Only original code/specifications, existing repo workflows and isolated new Emergence-owned files.
