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
    _check(SaveService.validate_payload(base), "mutating deep duplicates corrupted valid fixture")
    print("PRINCIPAL SAVE VALIDATION: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
