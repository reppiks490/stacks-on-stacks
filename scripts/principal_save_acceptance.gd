extends SceneTree
## Principal native save-boundary regression. Only run on an isolated CI runner.
## Unlike text-only tests, this executes the real Godot GDScript validator.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, context: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("PRINCIPAL SAVE VALIDATION FAIL: " + context)

func _run() -> void:
    var base: Dictionary = {
        "schema": 1, "year": 2, "day": 14, "season": 3,
        "minute": 900.0, "gold": 125, "energy": 85.0,
        "weather": "Clear", "restoration": 7,
        "crops_harvested": 1, "care_actions": 0,
        "inventory": {"turnip": 3, "fodder": 0},
        "farm": [], "village": {"affection": {}, "talked": {}, "gifted": {}},
        "animals": {"hen": {"last_care": -1}}, "hero_position": [0.0, 1.0, 0.0]
    }
    _check(SaveService.validate_payload(base), "valid schema-1 snapshot rejected")
    var legacy: Dictionary = base.duplicate(true)
    legacy.erase("year")
    _check(SaveService.validate_payload(legacy), "pre-year schema-1 compatibility lost")
    var bad: Dictionary = base.duplicate(true)
    bad["schema"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional schema was accepted")
    bad = base.duplicate(true)
    bad["year"] = 0
    _check(not SaveService.validate_payload(bad), "year zero was accepted")
    bad = base.duplicate(true)
    bad["day"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional day was accepted")
    bad = base.duplicate(true)
    bad["season"] = 4
    _check(not SaveService.validate_payload(bad), "impossible season accepted")
    bad = base.duplicate(true)
    bad["minute"] = INF
    _check(not SaveService.validate_payload(bad), "infinite minute accepted")
    bad = base.duplicate(true)
    bad["energy"] = NAN
    _check(not SaveService.validate_payload(bad), "NaN energy accepted")
    bad = base.duplicate(true)
    bad["energy"] = 110
    _check(not SaveService.validate_payload(bad), "overfilled energy accepted")
    bad = base.duplicate(true)
    bad["gold"] = -25
    _check(not SaveService.validate_payload(bad), "negative currency accepted")
    bad = base.duplicate(true)
    bad["gold"] = 4.75
    _check(not SaveService.validate_payload(bad), "fractional currency accepted")
    bad = base.duplicate(true)
    bad["inventory"]["turnip"] = -1
    _check(not SaveService.validate_payload(bad), "negative inventory accepted")
    bad = base.duplicate(true)
    bad["inventory"]["turnip"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional inventory accepted")
    bad = base.duplicate(true)
    bad["restoration"] = 101
    _check(not SaveService.validate_payload(bad), "restoration above 100 accepted")
    bad = base.duplicate(true)
    bad["hero_position"][0] = INF
    _check(not SaveService.validate_payload(bad), "infinite player coordinate accepted")
    bad = base.duplicate(true)
    bad["farm"] = [null]
    _check(not SaveService.validate_payload(bad), "malformed farm record accepted")
    bad = base.duplicate(true)
    bad["animals"]["hen"] = "not an animal state"
    _check(not SaveService.validate_payload(bad), "malformed animal state accepted")
    bad = base.duplicate(true)
    bad["inventory"]["turnip"] = 9007199254740992.0
    _check(not SaveService.validate_payload(bad), "integer precision overflow accepted")
    bad = base.duplicate(true)
    bad["village"]["talked"] = "tampered social state"
    _check(not SaveService.validate_payload(bad), "malformed daily social map accepted")
    bad = base.duplicate(true)
    bad["farm"] = [{"age": 1.5}]
    _check(not SaveService.validate_payload(bad), "fractional soil age accepted")
    bad = base.duplicate(true)
    bad["animals"]["hen"]["health"] = "impossible health"
    _check(not SaveService.validate_payload(bad), "invalid animal health accepted")
    bad = base.duplicate(true)
    bad["animals"]["hen"]["last_care"] = -5
    _check(not SaveService.validate_payload(bad), "impossible animal epoch accepted")
    bad = base.duplicate(true)
    bad["social_contacts"] = {"mira": "not a boolean"}
    _check(not SaveService.validate_payload(bad), "invalid social contact flag accepted")
    # Ecology + village-life contracts introduced after the original 24 fixtures.
    var integrated: Dictionary = base.duplicate(true)
    integrated["animals"]["__paddocks__"] = [
        {"forage": 7}, {"forage": 4}, {"forage": 1}]
    integrated["animals"]["hen"]["compost_counter"] = 2
    integrated["village"]["worked"] = {"mira": 56}
    integrated["village"]["festivals"] = {"2:seed_lantern_walk": true}
    integrated["village"]["memories"] = {
        "mira": {"talks": 5, "gifts": 1, "jobs": 1, "festivals": 1,
                 "last_gift_item": "wild_herb", "last_gift_epoch": 56}}
    _check(SaveService.validate_payload(integrated),
           "valid ecology + village-life state was rejected")
    bad = integrated.duplicate(true)
    bad["animals"]["__paddocks__"] = {"forage": 7}
    _check(not SaveService.validate_payload(bad), "paddock array shape accepted as dict")
    bad = integrated.duplicate(true)
    bad["animals"]["__paddocks__"][0]["forage"] = -1
    _check(not SaveService.validate_payload(bad), "negative grazing capacity accepted")
    bad = integrated.duplicate(true)
    bad["animals"]["hen"]["compost_counter"] = "full"
    _check(not SaveService.validate_payload(bad), "malformed compost counter accepted")
    bad = integrated.duplicate(true)
    bad["village"]["worked"]["mira"] = "last year"
    _check(not SaveService.validate_payload(bad), "malformed job epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["festivals"]["2:seed_lantern_walk"] = 123
    _check(not SaveService.validate_payload(bad), "invalid festival attendance accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["jobs"] = "unbounded"
    _check(not SaveService.validate_payload(bad), "malformed employment memory accepted")

    # This is the actual assembled Game coordinator and its real domain saves,
    # running on a disposable CI user:// filesystem; never a live player's slot.
    for file_path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH,
                             SaveService.TEMP_PATH]:
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
    var session = load("res://scripts/game.gd").new()
    root.add_child(session)
    _check(InputMap.has_action("job"), "principal K job action not installed")
    var job_key_mapped: bool = false
    for evt in InputMap.action_get_events("job"):
        if evt is InputEventKey and evt.physical_keycode == KEY_K:
            job_key_mapped = true
    _check(job_key_mapped, "K key not mapped to part-time jobs")
    session.year = 3
    session.season_index = 1
    session.day = 12
    session.gold = 901
    session.inventory["turnip"] = 17
    session.village.memories["mira"]["talks"] = 9
    session.animals.paddocks[0]["forage"] = 5
    session.save_game(false)
    _check(FileAccess.file_exists(SaveService.SAVE_PATH),
           "assembled gameplay failed to create a valid save")
    var saved: Dictionary = SaveService.read_payload()
    _check(int(saved.get("year", -1)) == 3, "assembled year did not persist")
    _check(saved.get("animals", {}).get("__paddocks__", []).size() == 3,
           "assembled grazing state did not persist")
    _check(saved.get("village", {}).get("memories", {}).has("mira"),
           "assembled village memory did not persist")
    session.gold = 0
    session.inventory["turnip"] = 0
    session.year = 1
    session.day = 1
    session.animals.paddocks[0]["forage"] = 0
    session.village.memories["mira"]["talks"] = 0
    session.load_game()
    _check(session.gold == 901, "assembled game currency failed to restore")
    _check(int(session.inventory["turnip"]) == 17,
           "assembled game inventory failed to restore")
    _check(session.year == 3 and session.season_index == 1 and session.day == 12,
           "assembled calendar failed to restore")
    _check(int(session.animals.paddocks[0]["forage"]) == 5,
           "assembled paddock failed to restore")
    _check(int(session.village.memories["mira"]["talks"]) == 9,
           "assembled village memory failed to restore")
    _check(SaveService.validate_payload(base), "mutating deep duplicates corrupted valid fixture")
    print("PRINCIPAL SAVE VALIDATION: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
