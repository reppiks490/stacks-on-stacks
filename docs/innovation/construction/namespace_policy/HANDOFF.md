# EVERBLOOM Construction B13/B19 — non-authoritative namespace migration dry-run

**Phase C CLOSED.** This is a reviewed-policy candidate and deterministic offline validator, not playable construction, a Godot save migration, or permission to change inventory. Original catalog and typed-state sources remain untouched.

## Pinned source and disjoint ownership

- Charter: explicit `game/everbloom-100-mission-charter-20261102` at `b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Starting canonical main: `d9c52f1b34956e2264c6b10d491aeac5bb628c78`; other roles continue advancing independently.
- Source evidence: `game/everbloom-construction-b19-typed100-crossaudit-20261102@d73fc5641552ab192e57ed7327e815c3370d0181`, blob `586fc1998741af620fa3251734f3376cf75cb2dd`. The new policy derives exactly 100 IDs and their original namespace/epoch fields from this immutable evidence. Source evidence is itself a crossaudit projection of ten separately pinned typed-state tranches; it is not a live game save.
- This branch only adds `docs/innovation/construction/namespace_policy/` and a dedicated non-Codex workflow. No shared gameplay, original catalogs, saves, assets or other-lane files are modified.

## Proposed policy, requiring Principal P02/P03/P04 approval

1. Canonical namespace `construction.eb_b_NNN` for B011–B110. Exactly ten civic contracts B031–B040 currently use unpadded `construction.eb_b_NN`; treat as **versioned aliases**, not automatic deletion. Reject payloads containing both alias and canonical state. Unknown future namespaces are preserved unchanged.
2. For 100 known feature states, reject malformed revision, epoch, receipts and duplicate receipts **globally** (not merely within one feature). Receipt IDs are proposed globally unique idempotency keys. Confirm whether current validators or real settlements use scoped keys before integrating.
3. Exactly 60 early typed contracts allow `day_epoch=-1`. Dry-run permits this only for an inert draft (`revision=0`, no receipts); it forbids action receipts until epoch >=1. Later 40 contracts reject -1. `day_epoch=0` likewise cannot contain activity. Principal must approve any actual sentinel behavior.
4. Reject future epochs, booleans masquerading as integers, negative revisions, malformed receipt types, and alias conflicts. Use monotonic `day_epoch`; 56-day year boundaries are 56→57 and 112→113. Never use season/day alone for once-per-day checks.
5. Copy the full nested state map and preserve unknown fields. Reject input atomically without mutating it. Repeat migration must be idempotent. **This tool does not validate full nested feature schemas**; no money, materials, construction placement, NPC permissions, live save service, or game scene is touched.

## Reproducible source-backed test

```bash
python3 docs/innovation/construction/namespace_policy/validate_policy.py --source .pinned_construction_audit/docs/innovation/construction/typed100_crossaudit/SOURCE_EVIDENCE.json --self-test
```

Dedicated GitHub Actions workflow checks out the branch under test and independently checks out pinned source commit `d73fc564...` in `.pinned_construction_audit`. It re-hashes raw bytes using Git blob SHA-1 and verifies 100 source mappings, alias/epoch distribution and deterministic positive/negative migration tests. General non-Codex workflow separately verifies pre-existing Godot baseline at the branch exact HEAD; this does not prove construction features run in Godot.

## Integration gates and negative tests

- **Principal:** approve canonical namespace aliases, global receipt key scope, inert sentinel semantics and full typed schema migration, then implement only after joint 220 ledger gate. Add native assembled save/load and corrupt-state rejection tests.
- **Farming:** approve authoritative material reservations and rollback receipts; no proposed material quote may debit resources by itself.
- **Village/Emergence:** audit NPC consent and cross-feature receipt collisions; no resident memory may be copied without privacy policy.
- **Construction:** once approved, design Godot adapters for B02/B03/B13; first complete cottage only after 220 gate and exact-HEAD native tests. Touch/controller equivalence and real-device performance are not demonstrated here.

No Codex, PR, force push, merge, paid action, proprietary asset, publication, or premature engine port.
