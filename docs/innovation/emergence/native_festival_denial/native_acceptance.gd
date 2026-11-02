extends SceneTree
## E06/E18 independent native regression against the actual EVERBLOOM main scene.
## Direct gameplay service calls, NOT physical keyboard/controller/touch proof.
## All user:// writes must be isolated by the dedicated CI XDG_DATA_HOME.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("EMERGENCE FESTIVAL QA FAILED: " + label)

func _run() -> void:
    # Never erase a user's existing save or an unverified writer lock.
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH,
            SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(false, "nonempty user save slot: " + path)
            quit(1)
            return
    if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
            SaveService.WRITE_LOCK_PATH)):
        _check(false, "existing writer lock; refuse to run")
        quit(1)
        return

    var scene: PackedScene = load("res://scenes/main.tscn")
    _check(scene != null, "actual game scene is available")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    _check(game.festivals.entries.size() == 12, "twelve authored festival definitions")
    _check(game.day_epoch() == 1, "initial epoch is one")
    var site := Vector3(30.0, 0.0, 0.0)
    var granted: int = 0
    var year_counts: Dictionary = {1:0, 2:0}
    var seen_keys: Dictionary = {}

    # Advance via the real Game.next_day(), not manual date assignment.
    # Each real day also writes the full Farm/Village/Animals/Festival snapshot.
    for elapsed in range(112):
        if elapsed > 0:
            game.next_day()
        _check(game.day_epoch() == elapsed + 1,
                "monotonic epoch at elapsed day %d" % elapsed)
        _check(game.year == 1 + int(elapsed / 56),
                "year changes only at 56-day boundary: %d" % elapsed)
        var occasion: Dictionary = game.festivals.today()
        if occasion.is_empty():
            continue
        var key: String = "%d:%s" % [game.year, str(occasion["id"])]
        _check(not seen_keys.has(key), "one calendar appearance per year: " + key)
        seen_keys[key] = true
        game.minute_of_day = 600.0
        game.energy = 100.0
        game.festivals.refresh()
        _check(game.festivals.stage.visible, "event stage visible: " + key)
        var item: String = str(occasion["donation"]["item"])
        var required: int = int(occasion["donation"]["quantity"])
        var petals: int = int(occasion["reward"]["petals"])
        var care: int = int(occasion["reward"]["restoration"])
        var ribbons_before: int = int(game.inventory.get("festival_ribbon", 0))
        var gold_before: int = game.gold
        var awarded_before: int = game.festivals.awarded.size()

        # Denial cases must leave economic state unchanged.
        game.inventory[item] = required
        _check("Visit the lantern stage" in game.festivals.act(site + Vector3(30, 0, 0)),
                "remote interaction rejected: " + key)
        _check(game.gold == gold_before and game.festivals.awarded.size() == awarded_before,
                "remote denial has no payout: " + key)
        game.minute_of_day = 420.0
        _check("between 8:00 and 20:00" in game.festivals.act(site),
                "closed-hours interaction rejected: " + key)
        game.minute_of_day = 600.0
        game.inventory[item] = 0
        _check("Bring" in game.festivals.act(site),
                "missing contribution rejected: " + key)
        _check(game.gold == gold_before and game.festivals.awarded.size() == awarded_before,
                "missing contribution has no payout: " + key)
        game.inventory[item] = required
        game.energy = 0.0
        _check("Rest before" in game.festivals.act(site),
                "exhaustion rejected: " + key)
        _check(game.gold == gold_before and game.festivals.awarded.size() == awarded_before,
                "exhaustion has no payout: " + key)
        game.energy = 100.0
        var care_before: int = game.restoration

        # Exactly one successful, costed award per event and year.
        _check("Thank you" in game.festivals.act(site),
                "valid contribution accepted: " + key)
        _check(game.gold == gold_before + petals, "exact petals: " + key)
        _check(int(game.inventory[item]) == 0, "exact material debit: " + key)
        _check(int(game.inventory.get("festival_ribbon", 0)) == ribbons_before + 1,
                "exact ribbon: " + key)
        _check(is_equal_approx(game.energy, 97.0), "exact energy debit: " + key)
        _check(game.restoration == mini(100, care_before + care),
                "bounded restoration: " + key)
        _check(game.festivals.awarded.size() == awarded_before + 1,
                "exactly one receipt: " + key)
        granted += 1
        year_counts[game.year] = int(year_counts[game.year]) + 1

        # Save, reload and hostile replay on the SAME day must not pay twice.
        game.save_game(false)
        var snapshot: Dictionary = SaveService.read_payload()
        _check(SaveService.validate_payload(snapshot), "full-domain save accepted: " + key)
        _check(snapshot.get("festivals", {}).get("awarded", []).size() == granted,
                "festival ledger roundtrip: " + key)
        _check(snapshot.get("animals", {}).has("__paddocks__"),
                "animal paddocks survive festival save: " + key)
        _check(snapshot.get("village", {}).has("memories"),
                "village memories survive festival save: " + key)
        game.load_game()
        _check(game.festivals.awarded.has(key), "receipt survives reload: " + key)
        game.inventory[item] = required
        var replay_gold: int = game.gold
        var replay_ribbons: int = int(game.inventory.get("festival_ribbon", 0))
        var replay_energy: float = game.energy
        _check("already contributed" in game.festivals.act(site),
                "same-day replay rejected after load: " + key)
        _check(game.gold == replay_gold and
                int(game.inventory.get("festival_ribbon", 0)) == replay_ribbons and
                int(game.inventory[item]) == required and
                is_equal_approx(game.energy, replay_energy),
                "replay conserves all tracked resources: " + key)
        game.inventory[item] = 0

    _check(granted == 24, "all 12 original events awarded once in each of two years")
    _check(int(year_counts[1]) == 12 and int(year_counts[2]) == 12,
            "exactly 12 awards per 56-day year")
    _check(seen_keys.size() == 24 and game.festivals.awarded.size() == 24,
            "24 distinct annual receipts")
    game.next_day()
    _check(game.year == 3 and game.day_epoch() == 113 and
            game.season_index == 0 and game.day == 1,
            "112-day rollover reaches year three spring day one")
    var valid: Dictionary = SaveService.read_payload()
    _check(SaveService.validate_payload(valid), "year-three complete save valid")
    _check(valid.get("festivals", {}).get("awarded", []).size() == 24,
            "year-three save retains all 24 receipts")

    # A corrupt receipt array must fail BEFORE any domain load or reward.
    var duplicate: Dictionary = valid.duplicate(true)
    duplicate["festivals"]["awarded"].append(duplicate["festivals"]["awarded"][0])
    _check(not SaveService.validate_payload(duplicate),
            "duplicated annual receipt rejected by real save boundary")
    var future: Dictionary = valid.duplicate(true)
    future["festivals"]["awarded"].append("4:spring_seed_exchange")
    _check(not SaveService.validate_payload(future),
            "future-year receipt rejected by real save boundary")
    var invented: Dictionary = valid.duplicate(true)
    invented["festivals"]["awarded"].append("2:invented_reward")
    _check(not SaveService.validate_payload(invented),
            "invented event receipt rejected by real save boundary")
    _check(SaveService.read_payload() == valid,
            "negative validation cannot mutate on-disk good snapshot")

    # CI has its own XDG_DATA_HOME; do not delete any existing files.
    print("EVERBLOOM EMERGENCE FESTIVAL NATIVE: %d assertions, %d failures; %d awards" %
            [assertions, failures, granted])
    quit(0 if failures == 0 else 1)
