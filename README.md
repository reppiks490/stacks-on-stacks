# SABLESTAR: The Sundered Expanse

An **original**, standalone 3D action-RPG project. Working title, not a final trademark-cleared commercial name.

**Engine:** Godot 4.7.2 stable (open source; GDScript; no paid dependencies).  
**Status:** foundation/graybox gameplay source, **not** a finished AA game.  
**Repository:** intentionally separate from AEONFALL, ICARUS, and their automations.  
**Codex:** none; do not introduce Codex to project automation.

## Unique premise

Long after the world's night-side sun shattered, nomad Wardens harvest *Resonance* from a lattice of floating ruins. The same energy can heal ecosystems or accelerate their collapse. The protagonist, a defected cartographer called an **Unbound**, must decide who controls the last navigable passages across the Glass Meridian. Its core tension: powerful combat techniques damage the environment and alter which routes, allies and resources remain available.

## Working source currently included

- 3D over-the-shoulder movement, jumping, sprinting, dodge, lock-free camera and gamepad movement support.
- Stamina-limited melee and a charged area ability, enemy windups, stagger and pursuit AI.
- Deterministically assembled graybox ruins, destructible resonance crystals, fragments, collectible drops and a companion orb.
- Two original faction-gate interactions affecting world-state affinity.
- Combat HUD, objective tracking and versioned local save/load (`user://`, no remote server).
- Authored implementation contract, REA evidence taxonomy and offline Python source/contract tests.

No copyrighted game source, franchise characters, maps, 3D models, audio or ripped assets are shipped.

## Run (Godot 4.7.2)

1. Install Godot 4.7.2 from the official Godot website.
2. Import/open this directory as a project using `project.godot`.
3. Press **F6** with `scenes/main.tscn` open, or **F5** to start the project.

**Controls**: WASD move, mouse look, Space jump, Shift sprint, Ctrl dodge, left-click strike, F pulse, E interact, F5 save, F9 load, Esc release/re-capture pointer. Arrow keys and gamepad left stick also move; gamepad buttons are planned beyond analog input. These are graybox keyboard/mouse controls, **not** a verified mobile UI.

Run contract tests: `python -m unittest discover -s tests -v` and `python tools/validate_project.py`.

## Current limitations / no false evidence

Scene syntax and Python design contracts can be checked without Godot, but **native Godot editor compilation and live rendering have not been verified** unless a run log is attached. No device export, multiplayer, finished art, final narrative, destructive voxel terrain, AAA quality, or native mobile touch UI is claimed. Read `docs/STATUS.md` and `docs/ARCHITECTURE.md`.

## Do not conflate source inspiration and extraction

Public games are references for design research. Use REA only on software you are entitled to examine and within applicable rules. The repository contains independently authored implementations, not source/assets from third-party games. See `research/ANALYSIS_PROTOCOL.md`.
