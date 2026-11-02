# EVERBLOOM — Emergence E03/E04/E18 concrete causal-state tranche

**Status: isolated design-only validation, not runtime implementation, Phase-C approval, or native Godot proof.** 2026-11-02.

## Evidence and ownership

- Explicit charter: `game/everbloom-100-mission-charter-20261102@b8a1e635792b08b0a3d87b987e593a539ac5c123`.
- Isolation baseline: `main@e0d3eaf10daa53f1082f3a253f49711bedcc725c`.
- Frozen source: `docs/innovation/emergence/phaseB_011_050.json` on `63cab5d05c742c61205933482e38fac2a4086764`, Git blob `a5def76918e77e0ded7e3e8085444698b4e0b549`.
- Builder's 220-design audit: `4a718d100a64e0a6af385ab415b3e7dd33b97de6` flagged 200 untyped Phase-B records. This tranche supplies concrete types for **10 of the 100 Emergence Phase-B concepts**; it does not fix the other 190 Phase-B concepts.
- All changes under new `docs/innovation/emergence/typed_state/` and one dedicated read-only CI workflow. No existing Godot gameplay, saves, source catalogs, other roles' files, engine migration, assets or PR changes.

## New contracts and cross-system rules

The machine-readable `causal_011_020.json` resolves **43 state fields** with finite bounded primitives, unique receipt IDs, bounded nested objects, nullability and explicit optional defaults, and **29 declarative cross-field rules**. IDs E011–E020 have distinct state semantics: weather reservations, verified ecology debt, finite relay hops, next-day fatigue obligations, pre-thaw evidence, unique habitat confidence, exclusive forked choices, read-only harvest history, non-overbooked shelter, and epoch-aware sunset deadlines.

**Critical E020 discovery:** Source design `EB-E-020` stores only `deadline_minute`, not the monotonic `day_epoch`. A saved event at 18:00 could otherwise reappear on a later day at the same minute. The typed proposal adds `deadline_epoch` and `settlement_receipt` as **version 2** fields. This is an explicit requested amendment, not an authorized migration: Principal must approve an optional save namespace and reject ambiguous active v1 events; only absent/inactive legacy state may default safely. The original Phase-B catalog is unchanged.

**Authority:** Principal owns calendar, authoritative inventory/currency, SaveService validation and idempotent transaction receipts; Village owns NPC consent/schedules and delivery; Farming owns ecology/crop impacts; Construction owns shelter capacity. Emergence owns only causal event decisions, local journal and read-only projections. Cross-system effects must use owner adapters and must never independently credit items, advance the clock, reserve an NPC, or settle a reward twice.

**Implementation guardrails:** A missing optional Emergence namespace is safe; a malformed present namespace must fail closed before any domain mutation. Exact-world-revision and unique command IDs must be persisted with effect receipts; the current JSON overlay only specifies those receipt contracts, not a working command bus. Numeric bounds are proposals to be reconciled with Principal's exact-JSON limits. Proposed performance/controls are not measured or device-tested.

## Reproducible audit

Run from a checkout containing these files:

```sh
python docs/innovation/emergence/typed_state/validate_causal_011_020.py --self-test
```

The validator checks frozen source field coverage, exact ten IDs, E020's two additive fields, versioning, strict type/default bounds, nonduplicate receipt and NPC keys, cross-field rules, and deliberately malformed catalog/state mutations. This is **offline Python specification QA**; no Godot runtime, player interaction, platform testing, or native save integration is claimed. CI must be inspected at the final exact branch SHA before reporting success.

## Principal acceptance and next bounded steps

1. Principal confirms schema-1 optional extension strategy, maximum payload size and future migration policy; explicitly approves or rejects E020 v2 deadline fields and receipt journal.
2. Village reviews E019 shelter consent, exclusive bed/schedule reservations and E013 recipient delivery. Farming reviews E012 extraction/repair settlement and E015 crop frost protection. Neither role may be bypassed by Emergence.
3. Expand typed state, unique player verbs and concrete resource quotes to E021–E110 in further bounded tranches; Builder independently resolves B011–B110. Review semantic overlaps beyond exact title/ID equality.
4. Only after 220/220 jointly accepted and Principal authorizes Phase C, build real Godot event→choice→owner effect→save/replay slice with native adversarial tests and actual keyboard/controller/touch verification. No Unreal/Unity port until separately authorized.

**No Codex, PR, unapproved spend, proprietary assets, force update, branch deletion or publication.**
