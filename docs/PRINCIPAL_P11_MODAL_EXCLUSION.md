# Principal P05/P11/P18 — Save Health modal exclusion

**Owner:** Principal Systems Architect. **Scope:** a bounded fix to the already playable Godot 4.x Save Health UI. **Status:** candidate; exact-HEAD native CI pending. **Authority:** `scripts/principal_save_health_panel.gd` only; no changes to Village modal scripts, save formats, economy, gameplay inventory or innovation ledger.

## Player interaction and feedback

The read-only Save Health inspector remains available from **Y** (keyboard), **Start** (controller), and its on-screen touch button when the valley is unpaused and no other Village modal is active. When a conversation-topic picker or social journal is already visible, these actions cannot open another modal over it. A separate pause also blocks opening; it must not be silently undone by dismissing Save Health. When allowed, the inspector retains its existing bilingual diagnostic report, 44–48 px touch controls, focusable close/refresh actions, scrolling, pause/restore behavior, and explicit save/load lockout.

## State and domain contracts

- `game.village.topic_panel.panel.visible` and `game.village.social_journal.panel.visible` are read-only presentation signals owned by Village.
- `SceneTree.paused` is an additional admission gate. The inspector never claims ownership of another modal's pause state.
- Existing `SaveService.inspect_save_health()` remains the sole diagnostic authority. No writes, lock removal, recovery promotion, inventory/currency mutation, RNG, or calendar transitions occur.
- No save migration, new state field, or engine-neutral schema change is required. Monotonic 56-day `day_epoch` and cross-domain save/load contracts remain untouched.
- Revisit the shared modal admission contract if additional overlay types are added; avoid introducing a circular dependency or editing another lane's files.

## Native acceptance, provenance and performance

The assembled-game test in `scripts/principal_save_health_panel_acceptance.gd` checks actual Village topic and journal nodes, keyboard/controller/touch denial while those panels are visible, independent pause conservation, normal successful opening, bilingual diagnostic reports and byte-for-byte save conservation. The existing checksum-pinned Godot 4.7.2 **push-only** `.github/workflows/everbloom-principal-save-health-ui.yml` runs import/parse and native acceptance; general Godot/Python validation is a separate required gate. All test save files are isolated under a temporary CI profile; never run the destructive fixture in a real player profile.

No new assets: original procedural Godot controls and system fonts only. The admission check is constant-time over two panel references and a pause flag; this is an algorithmic estimate, **not** a measured device frame budget. Actual Windows controller navigation, touch devices, screen readers, and desktop/mobile performance remain unverified.

**Integration:** check both final exact-SHA workflows and up-to-date `main`; reconcile only disjoint changes via non-force fast-forward. No PR because general validation has a `pull_request` trigger and external auto-review cannot be ruled out. No Codex, paid services, publication, proprietary assets or premature engine port. Innovation Phase C remains closed.
