# EVERBLOOM E18 — pinned-source Emergence 100-contract reconciliation

**Missions:** E03, E18 (independent design and adversarial QA). **Phase C: CLOSED.** This is not playable feature implementation, a Godot test of these proposed systems, a device benchmark, or a release sign-off.

## Frozen sources and authority

The read-only audit uses ten original Emergence typed-state JSON tranches, E011–E110, each from its own isolated engineering branch, and the two frozen Emergence Phase-B catalog files at commit `63cab5d05c742c61205933482e38fac2a4086764`. Every source path, immutable commit and Git blob SHA is in `SOURCE_EVIDENCE.json`. The Python validator fetches each pinned commit (or reads a local `--source-dir` mirror), verifies Git's **actual blob-byte SHA-1**, and recomputes every projected field, mapping, namespace, flag and negative acceptance from the original JSON. A changed source blob or projection fails closed. This is stronger than checking a manually copied list of SHA strings.

Reproduce with `python3 docs/innovation/emergence/typed100_sourceaudit/validate_typed100_sources.py --self-test` from this branch; network access to GitHub raw content is needed unless the twelve pinned files are supplied under `--source-dir` with their repository-relative paths. The push-only workflow executes this exact check. The existing general non-Codex workflow separately performs baseline Python and Godot native import/smoke/save checks. Neither proves new emergent gameplay.

## Source-derived findings (design risks, not runtime defects)

- **100/100** unique expected typed IDs and normalized titles; **100/100** original catalog titles and source-field lists match their typed projections. The three initially apparent missing fields have explicit valid adapters: E069 `safety_radius -> safety_radius_cm`, `companion_position -> companion_distance_cm`; E073 `consent -> contributors`; E077 `owner -> owner_id`.
- **40** E031–E070 namespaces use unpadded `emergence.eb_e_31`–`70` instead of three-digit numbering. These are existing design namespaces, not proof of an active save migration defect. Principal must choose a stable canonical alias/migration policy before integrating them.
- **37** receipt-/ledger-/claim-like array fields lack declarative `unique_by` across the 100 typed contracts. Dedicated validators may enforce uniqueness; this finding does **not** assert receipt duplication at runtime. Principal must own cross-domain command idempotence; per-contract schemas must declare or document their uniqueness mechanism.
- **61** contracts contain at least one top-level integer field allowing `-1` as a not-yet-observed epoch sentinel. This is not a valid annual action epoch. Principal must explicitly distinguish sentinel from `day_epoch >= 1`, and enforce monotonic 56-day-year checks for actual events.
- **20** typed projections omit player verbs, **20** dependencies, **30** original asset plans, **20** performance budgets, **30** embedded positive fixture declarations, and **40** explicit `receipt_contract` objects. Most original source catalogs contain the corresponding broader design details, and some validators have fixtures externally. These are typed-projection completeness flags, not claims that the whole catalog lacks the information.
- **E102 Community Search Grid**: the frozen source catalog and the typed-state contract both contain the unrelated **eclipse-puzzle** negative acceptance. The earlier isolated erratum remains **proposed, not applied**. Correct original `acceptance.adversarial`, `godot_acceptance`, `adversarial_tests` and typed `negative_case` together under Emergence owner review; re-pin source SHA and regenerate tests. Do not silently rewrite frozen source evidence.
- All 100 have keyboard/mouse, controller and touch *design declarations*. No measured input parity or mobile performance is claimed.

## Cross-loop release gates

**Village** must own NPC consent, identity, privacy, withdrawal, and scheduling across E036/E077/E040/E075 and Construction B084. **Principal** must own stable namespace migration, atomic inventory/relationship effect receipts, `day_epoch` sentinel policy, save admission, replay deduplication and full assembled-game regression. **Emergence** must repair E102 after reviewed catalog changes, keep isolated contract negative tests, and reject overlapping rewards, invalid consent, duplicate command IDs and invalid save fields. The 220-feature roster's distinct IDs/titles and isolated typed validations do **not** establish semantic uniqueness or integrated Godot playability.

The validator checks the 12 pinned blobs and rejects 27 deliberate hostile mutations to its source-derived projection. It cannot simulate actual player interactions, prove authoritative owner transaction integration, establish license provenance for future art, or measure desktop/mobile performance. Native Godot 4.x baseline CI is a separate check.

**Isolation:** only new `docs/innovation/emergence/typed100_sourceaudit/` files and a dedicated push-only workflow. No changes to frozen catalogs, game source, save files, assets, other lanes, main, other branches or repositories. No PR (generic workflow has a pull_request trigger), no Codex, force, merge, paid service, publication or premature engine port. Exact-final-SHA CI and issue #2 handoff are required before calling this audit verified.
