#!/usr/bin/env python3
"""Static, source-backed checks; deliberately NOT Godot engine compilation."""
from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'data/game_rules.json'
SCRIPTS = ROOT / 'scripts'
REQUIRED = [
    'project.godot', 'scenes/main.tscn', 'README.md',
    'data/game_rules.json', 'docs/ARCHITECTURE.md',
    'docs/STATUS.md', 'research/ANALYSIS_PROTOCOL.md',
    'research/SYSTEM_INSPIRATION_MATRIX.md',
    'scripts/game_root.gd','scripts/player_actor.gd',
    'scripts/enemy_actor.gd', 'scripts/combat_rules.gd',
    'scripts/world_builder.gd', 'scripts/session_state.gd',
    'scripts/save_service.gd','scripts/hud.gd',
    'scripts/faction_beacon.gd', 'scripts/resonance_crystal.gd',
    'scripts/resonance_fragment.gd', 'scripts/companion_orb.gd',
]
REQUIRED_COMPONENTS = {
    'session_state.gd': ['collect_fragment(', 'choose_faction(', 'objective_text(', 'from_save_data(', 'chosen_faction != ""'],
    'player_actor.gd': ['func strike(', 'func pulse(', 'func dodge(', 'func receive_damage(', 'Combat.STRIKE_COST', 'Combat.PULSE_COST', 'Combat.DODGE_COST'],
    'enemy_actor.gd': ['enum Mode', 'Mode.WINDUP', 'Mode.STAGGER', 'func take_damage(', 'defeated.emit('],
    'resonance_crystal.gd': ['_broken = true', 'remove_from_group("damageable")', 'shattered.emit('],
    'save_service.gd': ['MAX_SAVE_BYTES', 'user://', 'JSON.parse_string(', 'from_save_data('],
}


def validate() -> list[str]:
    errors: list[str] = []
    for name in REQUIRED:
        path = ROOT / name
        if not path.is_file() or not path.read_text(encoding='utf-8').strip():
            errors.append(f'Missing or empty required file: {name}')
    if errors:
        return errors
    try:
        data = json.loads(MANIFEST.read_text(encoding='utf-8'))
    except (ValueError, OSError) as exc:
        return [f'Invalid manifest: {exc}']
    if data.get('project_id') != 'SABLESTAR-ORIGINAL-001' or data.get('schema_version') != 1:
        errors.append('Original project/schema identity changed')
    factions = data.get('factions', [])
    enemies = data.get('enemy_archetypes', [])
    regions = data.get('world', {}).get('region_definitions', [])
    if [x.get('id') for x in factions] != ['FAC-01','FAC-02']:
        errors.append('Faction IDs must remain unique and stable')
    if [x.get('id') for x in enemies] != ['ENM-01','ENM-02']:
        errors.append('Enemy archetype IDs changed')
    if [x.get('id') for x in regions] != ['REG-S1','REG-S2','REG-S3','REG-S4']:
        errors.append('Region IDs or design backlog changed')
    if data.get('evidence', {}).get('godot_engine_run') != 'not_run':
        errors.append('No Godot native execution evidence supplied')
    if data.get('evidence', {}).get('native_mobile') != 'not_run':
        errors.append('No mobile native test evidence supplied')
    if data.get('evidence', {}).get('third_party_assets_copied') is not False:
        errors.append('Copyright/provenance policy drift')
    if data.get('design', {}).get('enabled_multiplayer') is not False:
        errors.append('No multiplayer authority model implemented')
    for name, tokens in REQUIRED_COMPONENTS.items():
        source = (SCRIPTS / name).read_text(encoding='utf-8')
        code = '\n'.join(line.split('#',1)[0] for line in source.splitlines())
        for token in tokens:
            if token not in code:
                errors.append(f'{name} missing source contract {token}')
    for gd in SCRIPTS.glob('*.gd'):
        source = gd.read_text(encoding='utf-8')
        for res in re.findall(r'(?:preload|load)\(\s*"res://([^"\n]+)"', source):
            if not (ROOT / res).is_file():
                errors.append(f'{gd.name} references nonexistent res://{res}')
        if 'codex' in source.lower() or 'chatgpt-codex-connector' in source.lower():
            errors.append(f'Prohibited Codex integration in {gd.name}')
    main = (ROOT/'scenes/main.tscn').read_text(encoding='utf-8')
    if 'res://scripts/game_root.gd' not in main:
        errors.append('Main scene no longer has its game root')
    project = (ROOT/'project.godot').read_text(encoding='utf-8')
    if 'res://scenes/main.tscn' not in project:
        errors.append('Project main scene mismatch')
    if any((ROOT / x).exists() for x in ('.github/workflows/codex.yml', '.github/workflows/auto-code-review.yml')):
        errors.append('Unexpected automatic AI coding/review workflow')
    # Both available combat specs must agree; reject silent balance drift.
    constants=(SCRIPTS/'combat_rules.gd').read_text(encoding='utf-8')
    rules=data['combat']
    links={'STRIKE_DAMAGE':'strike_damage','STRIKE_COST':'strike_cost',
           'STRIKE_COOLDOWN':'strike_cooldown_seconds','STRIKE_RANGE':'strike_range_meters',
           'PULSE_DAMAGE':'pulse_damage','PULSE_COST':'pulse_cost',
           'PULSE_COOLDOWN':'pulse_cooldown_seconds','PULSE_RADIUS':'pulse_radius_meters',
           'DODGE_COST':'dodge_cost','DODGE_DURATION':'dodge_duration_seconds'}
    for symbol,field in links.items():
        match=re.search(rf'^const {symbol}\s*:=\s*([0-9.]+)\s*$',constants,re.M)
        if match is None or float(match.group(1)) != float(rules[field]):
            errors.append(f'Combat constant mismatch: {symbol} vs {field}')
    return errors


def main() -> int:
    errors=validate()
    for x in errors:
        print('FAIL:',x)
    if errors:
        return 1
    print('PASS: original project manifest, local game contracts, IDs, resources, source imports and evidence truthfulness')
    print('NOTE: static inspection only; native Godot parser, build, runtime, export and mobile tests NOT RUN')
    return 0

if __name__=='__main__':
    sys.exit(main())
