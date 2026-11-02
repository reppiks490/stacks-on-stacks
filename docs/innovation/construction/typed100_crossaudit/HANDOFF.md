# EVERBLOOM Construction B19 — independent typed100 cross-tranche audit

**Status:** evidence snapshot and reproducible *design-level* validation. **Phase C CLOSED.** This does not prove playable Godot construction, mobile parity, runtime idempotence, or save migration.

## Source freeze and scope
- Canonical `main` inspected at `e90fe68d070fdc141129ebbe1da6bbcd72cd2bc8`.
- Charter pinned to `b8a1e635792b08b0a3d87b987e593a539ac5c123`; coordination document and issue #2 inspected.
- 220-record readiness ledger frozen from `game/everbloom-construction-220-readiness-20261102`, blob `783b7bca5af5d52e23f4af439d2aa6e36111afa4`.
- All TEN Construction Phase-B typed tranches (`EB-B-011` through `EB-B-110`) were read at explicit isolated branch refs. The evidence manifest pins each tranche's exact blob SHA and preserves 100 per-feature field maps, quoted materials, controls, fixture counts and schema risk flags.
- No frozen source, catalog, Godot script, save, original asset, or other lane is modified.

## Source-derived findings (220 flags, not 220 distinct defects)

| Kind | Affected contracts | Meaning |
|---|---:|---|
| Noncanonical save namespace | 10 (B031–B040) | `construction.eb_b_31` through `_40` omit the canonical three-digit ID padding. Existing names are unique but would complicate stable registration/migration. Do not silently rename persisted namespaces. |
| Receipt uniqueness not expressed in declarative schema | 60 (B011–B070) | Earlier `fields.receipts` arrays lack an explicit `unique_items` constraint. Their separate validators may reject duplicates; this audit does **not** claim an actual duplicate-resource exploit. |
| `day_epoch=-1` permitted by field schema | 60 (B011–B070) | Could be a deliberate uninitialized sentinel. Principal must decide whether such snapshots may persist and how annual once-per-day actions reject it. A 56-day year still requires monotonic epoch for completed actions. |
| Material quote not repeated in typed tranche | 10 (B011–B020) | Source catalog contains a proposed quote; early typed tranche only lists unverified materials. No debit authority exists. |
| Player verbs not repeated in typed tranche | 10 (B011–B020) | Source catalog retains verbs. |
| Dependencies not repeated in typed tranche | 50 (B011–B060) | Original source catalog remains authoritative until an approved combined schema exists. |
| Original asset plan not repeated in typed tranche | 10 (B011–B020) | No evidence of missing source-level asset plan; the typed document is not self-contained. |
| Performance budget not repeated in typed tranche | 10 (B011–B020) | No device measurements claimed. |

**Positive reconciliation:** 100 distinct expected IDs and matching titles; 100/100 source state fields map to a declared root (including legitimate nested adapters such as `nodes[*].depends_on`); no typed/source material-quote disagreements among 90 contracts with explicit typed quotes; all 100 have keyboard/mouse, gamepad/controller, and touch input declarations, at least one valid fixture and one negative fixture, and a receipt field. The input declarations and fixtures are design evidence, not native interaction proof.

## Integration ownership and required decisions

1. **Principal P02/P03/P04/P09:** approve the canonical namespace scheme and versioned migration aliases; define whether `day_epoch=-1` can be saved, require a globally durable idempotency key and exact once-per-epoch checks. Save/load must roundtrip nested domain fields without double debit. Principal owns final Phase-C gate.
2. **Construction B02/B03/B13/B19:** reconcile the 10 civic namespace aliases and early schema declarations on new reviewed revisions, preserving original frozen evidence; provide typed socket collision and undo dependency contracts before the first cottage.
3. **Farming F19:** settle finite material provenance and resource reservations; proposed catalog costs must not directly mutate inventory.
4. **Village:** provide authoritative NPC permission, privacy/revocation and labor-slot contracts for community structures.
5. **Emergence E18:** independently check cross-lane negative tests, including memory-consent overlap and E102 erratum; coordinate with Principal release QA.

## Reproduce

```sh
python3 docs/innovation/construction/typed100_crossaudit/validate_typed100.py --self-test
```

This checks the frozen **evidence snapshot**, its 100-ID coverage, 10 source blob references, state-field projections, cost/input/fixture consistency, 220 expected finding flags, deterministic JSON roundtrip, and adversarial evidence tampering. It does **not** fetch and re-hash the remote source blobs at test time; each source blob SHA and ref is provided for independent verification. The separate generic native Godot workflow checks only the pre-existing baseline, not these unimplemented innovations.

No Codex, PR, force push, merge, paid action, proprietary assets, publication or Unreal/Unity port.
