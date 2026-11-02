# Five-loop shared engineering protocol

**Repository:** `reppiks490/stacks-on-stacks`. **New active game:** EVERBLOOM. **Historical SABLESTAR:** preserved in old history/branches ONLY. **Native engine:** Godot 4.7.2, prove compatibility through an exact-head native CI run.

| :00 Principal Architect | docs/MASTER_PLAN.md, docs/CROSS_LOOP_COORDINATION.md, project integration, saving boundaries |
| :12 Farming Architect | scripts/farm.gd, data/crops.json, farm economy and tool progression |
| :24 Village Engineer | scripts/village.gd, data/villagers.json, story/dialogue/relationships |
| :36 World Art Director | scripts/valley.gd, original assets, world presentation, environmental FX |
| :48 QA Release Engineer | tools/validate_project.py, tests/**, non-Codex CI, release evidence |

**Shared contracts:** `scripts/game.gd` is orchestration; each lane owns its component interfaces and documents breaking interface changes before coding. Use repo issues for coordination and review rather than conflicting edits. Check HEAD and active branches before work; avoid duplicate parallel commits on one file. Integration owner verifies all tests and keeps a separate status ledger.

**Safety:** No Codex CLI/agents/reviews/bots/workflows, no automatic Codex-powered PR event; inspect workflows and branch triggers before any mutation. Preserve branches and unique commits; never force-push or silently delete. No unlicensed commercial assets, false test claims, user charges, unrelated repos, public releases or unauthorized external game binaries.

**Merge gate:** native Godot editor import plus headless scene run, Python tests, provenance audit, current main reconciliation, no new unsafe dependencies, and editorial source review. Do not declare multiplayer/mobile, final art, or gameplay completion based on source checks alone.
