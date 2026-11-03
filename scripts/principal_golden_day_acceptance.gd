extends SceneTree
## P17: assembled-game, deterministic golden route; CI user:// MUST be isolated.
## Calls real domain methods. Not a claim of physical input or rendered gameplay.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("PRINCIPAL GOLDEN ROUTE FAIL: " + label)

## Godot JSON decoding can change numeric Variant types; compare saved domain
## structures by keys and scalar values, not by nested container identity/type.
func _json_equivalent(left: Variant, right: Variant) -> bool:
    if left is Dictionary and right is Dictionary:
        if left.size() != right.size():
            return false
        for key in left:
            if not right.has(key) or not _json_equivalent(left[key], right[key]):
                return false
        return true
    if left is Array and right is Array:
        if left.size() != right.size():
            return false
        for index in range(left.size()):
            if not _json_equivalent(left[index], right[index]):
                return false
        return true
    var left_type: int = typeof(left)
    var right_type: int = typeof(right)
    if left_type in [TYPE_INT, TYPE_FLOAT] and right_type in [TYPE_INT, TYPE_FLOAT]:
        return float(left) == float(right)
    return left == right

func _run() -> void:
    # Never destroy existing player saves or assume a stranded lock is stale.
    var protected_paths: Array[String] = [
        SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH
    ]
    for index in range(1, SaveService.MAX_QUARANTINE_SLOTS + 1):
        protected_paths.append("%s%03d" % [SaveService.QUARANTINE_PREFIX, index])
    for path in protected_paths:
        if FileAccess.file_exists(path):
            _check(false, "test user:// not isolated: " + path)
            quit(1)
            return
    if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SaveService.WRITE_LOCK_PATH)):
        _check(false, "existing writer lock must never be removed")
        quit(1)
        return

    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "load actual main scene")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    _check(game.day_epoch() == 1, "start at monotonic epoch 1")
    _check(game.farm.beds.size() == 30, "live farm contains thirty beds")
    _check(game.animals.creatures.size() == 3, "live barn contains three animals")
    _check(game.village.residents.size() == 6, "live village contains six residents")

    # Day 1: actual till, seed debit, watering and duplicate denial.
    var bed_pos: Vector3 = game.farm.beds[0]["holder"].global_position + Vector3(0, 1, 0)
    var starting_seed: int = int(game.inventory.get("turnip_seed", 0))
    var energy_before: float = game.energy
    _check("cultivated" in game.farm.act("till", bed_pos), "player tills a real bed")
    _check("Planted turnip" in game.farm.act("plant", bed_pos), "player plants turnip")
    _check(int(game.inventory.get("turnip_seed", 0)) == starting_seed - 1,
           "planting debits exactly one seed")
    _check(is_equal_approx(game.energy, energy_before - 3.0),
           "tilling and planting debit exact energy")
    var seed_after_plant: int = int(game.inventory["turnip_seed"])
    var energy_after_plant: float = game.energy
    _check("Cultivate an empty bed" in game.farm.act("plant", bed_pos),
           "duplicate planting rejected")
    _check(int(game.inventory["turnip_seed"]) == seed_after_plant
           and is_equal_approx(game.energy, energy_after_plant),
           "duplicate planting cannot debit resources")
    _check("seedlings" in game.farm.act("water", bed_pos), "day-one watering succeeds")
    _check(bool(game.farm.beds[0]["watered"]), "water state is visible in domain")

    # Day 1: barn care grants at most one receipt per animal and epoch.
    var hen_pos: Vector3 = game.animals.creatures[0]["node"].global_position + Vector3(0, 1, 0)
    var care_before: int = game.care_actions
    _check("Hazel Hen" in game.animals.act(hen_pos), "player cares for live hen")
    _check(game.care_actions == care_before + 1, "care counter increments once")
    var after_care: Dictionary = game.animals.save_state()
    var after_care_items: Dictionary = game.inventory.duplicate(true)
    var after_care_gold: int = game.gold
    _check("already been cared for today" in game.animals.act(hen_pos),
           "second animal care denied in same epoch")
    _check(game.animals.save_state() == after_care and game.inventory == after_care_items
           and game.gold == after_care_gold and game.care_actions == care_before + 1,
           "denied care cannot mint product, fodder, currency or bond")

    # Day 1: real village conversation records once-only affection and memory.
    var mira: Dictionary = game.village.residents[0]
    var mira_pos: Vector3 = mira["node"].global_position
    var affection_before: int = int(game.village.affection["mira"])
    _check("Mira:" in game.village.act("talk", mira_pos), "resident responds to talk")
    _check(int(game.village.affection["mira"]) == affection_before + 4,
           "first talk earns four affection")
    _check("Mira:" in game.village.act("talk", mira_pos), "second talk has dialogue")
    _check(int(game.village.affection["mira"]) == affection_before + 4
           and int(game.village.memories["mira"]["talks"]) == 1,
           "repeat conversation cannot farm affection or memory count")
    game.save_game(false)
    _check(SaveService.validate_payload(SaveService.read_payload()),
           "day-one full-domain save validates")

    # Day 2: sleep advances epoch and crop growth; water again.
    game.next_day()
    _check(game.day_epoch() == 2 and game.day == 2, "sleep advances to day two")
    _check(int(game.farm.beds[0]["age"]) == 1, "crop grows through real day transition")
    _check("seedlings" in game.farm.act("water", bed_pos), "day-two watering")
    game.next_day()
    _check(game.day_epoch() == 3 and int(game.farm.beds[0]["age"]) == 2,
           "day-three growth and epoch progression")
    _check("seedlings" in game.farm.act("water", bed_pos), "day-three watering")

    # Day 3: original festival is a real transaction, not a mocked award.
    game.minute_of_day = 600.0
    var festival_position := Vector3(30, 0, 0)
    var festival_seed_before: int = int(game.inventory.get("turnip_seed", 0))
    var festival_gold_before: int = game.gold
    var festival_energy_before: float = game.energy
    var festival_ribbon_before: int = int(game.inventory.get("festival_ribbon", 0))
    _check("Thank you" in game.festivals.act(festival_position),
           "original Spring 3 festival contribution succeeds")
    _check(game.gold == festival_gold_before + 26
           and int(game.inventory["turnip_seed"]) == festival_seed_before - 2,
           "festival settles exact payout and donation")
    _check(is_equal_approx(game.energy, festival_energy_before - 3.0)
           and int(game.inventory.get("festival_ribbon", 0)) == festival_ribbon_before + 1,
           "festival charges energy and grants one ribbon")
    var festival_settled: Dictionary = game.inventory.duplicate(true)
    var festival_gold_settled: int = game.gold
    _check("already contributed" in game.festivals.act(festival_position),
           "festival duplicate is denied")
    _check(game.inventory == festival_settled and game.gold == festival_gold_settled,
           "festival replay cannot duplicate reward or debit")
    game.save_game(false)
    _check(SaveService.read_payload().get("festivals", {}).get("awarded", []).size() == 1,
           "festival receipt persisted in assembled save")

    # Day 4: harvest, then a moving NPC must actually reach the paid worksite.
    game.next_day()
    _check(game.day_epoch() == 4 and int(game.farm.beds[0]["age"]) == 3,
           "three growth days mature the turnip")
    var turnips_before: int = int(game.inventory.get("turnip", 0))
    var harvested_before: int = game.crops_harvested
    var harvest_energy_before: float = game.energy
    _check("Harvested" in game.farm.act("harvest", bed_pos), "mature crop harvest")
    var harvest_quantity: int = int(game.inventory.get("turnip", 0)) - turnips_before
    _check(harvest_quantity >= 2 and harvest_quantity <= 3,
           "harvest follows original crop yield and bounded quality")
    _check(game.crops_harvested == harvested_before + harvest_quantity
           and is_equal_approx(game.energy, harvest_energy_before - 1.0),
           "harvest inventory, lifetime count and energy reconcile")
    var post_harvest_inventory: Dictionary = game.inventory.duplicate(true)
    _check("empty" in game.farm.act("harvest", bed_pos),
           "non-regrowing turnip cannot be harvested twice")
    _check(game.inventory == post_harvest_inventory,
           "repeat harvest never duplicates items")

    game.minute_of_day = 500.0
    game.village.sync_schedule(true)
    var village_square_pos: Vector3 = mira["node"].global_position
    game.minute_of_day = 600.0
    game.village.sync_schedule(false, 0.1)
    var moving_pos: Vector3 = mira["node"].global_position
    _check(moving_pos.distance_to(village_square_pos) > 0.0,
           "NPC physically begins commuting toward work")
    var job_gold_before: int = game.gold
    var job_energy_before: float = game.energy
    _check("still on their way" in game.village.act("job", moving_pos),
           "paid work denied while NPC has not arrived")
    _check(game.gold == job_gold_before
           and is_equal_approx(game.energy, job_energy_before),
           "commute denial preserves resources")
    game.village.sync_schedule(true)
    var work_pos: Vector3 = mira["node"].global_position
    _check("Earned 24 petals" in game.village.act("job", work_pos),
           "real NPC work shift pays after arrival")
    _check(game.gold == job_gold_before + 24
           and is_equal_approx(game.energy, job_energy_before - 12.0),
           "paid shift conserves exact currency and stamina")
    var paid_gold: int = game.gold
    var paid_energy: float = game.energy
    _check("already helped here today" in game.village.act("job", work_pos),
           "duplicate paid shift rejected")
    _check(game.gold == paid_gold and is_equal_approx(game.energy, paid_energy),
           "repeat work cannot mint money or debit energy")
    _check(int(game.village.memories["mira"]["jobs"]) == 1,
           "paid work recorded once in social memory")

    # Save, destroy the actual scene, recreate it, and restore every domain.
    game.hero.global_position = Vector3(26, 1, 11)
    game.save_game(false)
    var checkpoint: Dictionary = SaveService.read_payload()
    _check(SaveService.validate_payload(checkpoint), "golden checkpoint valid")
    _check(int(checkpoint.get("year", 0)) == 1
           and int(checkpoint.get("day", 0)) == 4, "checkpoint calendar exact")
    _check(int(checkpoint.get("gold", -1)) == paid_gold,
           "checkpoint money exact")
    _check(_json_equivalent(checkpoint.get("inventory", {}), game.inventory),
           "checkpoint inventory exact")
    _check(_json_equivalent(checkpoint.get("farm", []), game.farm.save_state()),
           "checkpoint all 30 beds exact")
    _check(_json_equivalent(checkpoint.get("animals", {}), game.animals.save_state()),
           "checkpoint animal and paddock fields exact")
    _check(_json_equivalent(checkpoint.get("village", {}), game.village.save_state()),
           "checkpoint social and paid-work memory exact")
    _check(_json_equivalent(checkpoint.get("festivals", {}), game.festivals.save_state()),
           "checkpoint festival receipts exact")
    game.queue_free()
    await process_frame
    var resumed = packed.instantiate()
    root.add_child(resumed)
    resumed.load_game()
    _check(resumed.day_epoch() == 4 and resumed.gold == paid_gold,
           "fresh scene restores calendar and money")
    _check(_json_equivalent(resumed.inventory, checkpoint["inventory"]),
           "fresh scene restores inventory without duplication")
    _check(_json_equivalent(resumed.farm.save_state(), checkpoint["farm"]),
           "fresh scene restores all nested crop fields")
    _check(_json_equivalent(resumed.animals.save_state(), checkpoint["animals"]),
           "fresh scene restores livestock and pasture")
    _check(_json_equivalent(resumed.village.save_state(), checkpoint["village"]),
           "fresh scene restores relationship, dialogue and shift receipts")
    _check(_json_equivalent(resumed.festivals.save_state(), checkpoint["festivals"]),
           "fresh scene restores festival award ledger")
    _check(is_equal_approx(resumed.energy, float(checkpoint["energy"])),
           "fresh scene restores exact energy")
    _check(resumed.hero.global_position.distance_to(Vector3(26, 1, 11)) < 0.01,
           "fresh scene restores world position")
    resumed.village.sync_schedule(true)
    var restored_mira_pos: Vector3 = resumed.village.residents[0]["node"].global_position
    _check("already helped here today" in resumed.village.act("job", restored_mira_pos),
           "restarted game cannot pay same shift twice")
    _check(resumed.gold == paid_gold and _json_equivalent(resumed.inventory, checkpoint["inventory"]),
           "restarted duplicate denial conserves money and items")
    resumed.save_game(false)
    var resaved: Dictionary = SaveService.read_payload()
    _check(_json_equivalent(resaved.get("farm", []), checkpoint["farm"])
           and _json_equivalent(resaved.get("animals", {}), checkpoint["animals"])
           and _json_equivalent(resaved.get("village", {}), checkpoint["village"])
           and _json_equivalent(resaved.get("festivals", {}), checkpoint["festivals"]),
           "repeat save is idempotent for all nested domains")
    _check(_json_equivalent(resaved.get("inventory", {}), checkpoint["inventory"])
           and int(resaved.get("gold", -1)) == paid_gold,
           "repeat save never duplicates inventory or currency")
    resumed.queue_free()
    await process_frame

    # Only remove test-created artifacts in the isolated CI data directory.
    for path in protected_paths:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                   "clean isolated test file " + path)
    print("PRINCIPAL GOLDEN ROUTE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
