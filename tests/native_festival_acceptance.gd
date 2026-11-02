extends SceneTree
## Real native integration of the actual EVERBLOOM main scene and festival loop.
## Calls gameplay methods deliberately; does not fake a keyboard/mobile playthrough.
var assertions: int = 0
var failures: int = 0
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, note: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("FESTIVAL ACCEPTANCE FAILED: " + note)

func _run() -> void:
    var main_scene: PackedScene = load("res://scenes/main.tscn")
    _check(main_scene != null, "main scene loadable")
    if main_scene == null:
        quit(1)
        return
    var game = main_scene.instantiate()
    root.add_child(game)
    _check(game.festivals != null, "festival component instantiated in actual scene")
    _check(InputMap.has_action("festival"), "interact input registered")
    _check(game.festivals.entries.size() == 12, "twelve authored original events")
    _check(game.festivals.next_occasion().get("days_until", -1) == 2,
           "Spring Day 1: first festival in two days")
    var site := Vector3(30.0, 0.0, 0.0)
    game.day = 3
    game.minute_of_day = 600.0
    game.festivals.refresh()
    _check(game.festivals.stage.visible, "original event stage appears on festival day")
    _check(str(game.festivals.today()["id"]) == "spring_seed_exchange", "first festival identity")
    var start_gold: int = game.gold
    var start_ribbons: int = int(game.inventory.get("festival_ribbon", 0))
    var first_item: int = int(game.inventory.get("turnip_seed", 0))
    _check("Visit the lantern stage" in game.festivals.act(Vector3(-15.0, 1.0, 0.0)),
           "remote festival payout denied")
    _check(game.gold == start_gold, "remote input does not grant currency")
    _check(int(game.inventory.get("turnip_seed", 0)) == first_item,
           "remote input consumes no resources")
    game.minute_of_day = 420.0
    _check("between 8:00 and 20:00" in game.festivals.act(site),
           "festival closed before posted hours")
    game.minute_of_day = 1200.0
    _check("between 8:00 and 20:00" in game.festivals.act(site),
           "festival closed after posted hours")
    game.minute_of_day = 600.0
    game.inventory["turnip_seed"] = 0
    _check("Bring 2 turnip_seed" in game.festivals.act(site),
           "item requirement enforced")
    _check(game.gold == start_gold, "missing offering cannot grant currency")
    game.inventory["turnip_seed"] = 2
    var earned: String = game.festivals.act(site)
    _check("Thank you" in earned, "valid contribution accepted")
    _check(game.gold == start_gold + 26, "exact first event currency award")
    _check(int(game.inventory["turnip_seed"]) == 0, "exact item debit")
    _check(int(game.inventory.get("festival_ribbon", 0)) == start_ribbons + 1,
           "original ribbon awarded")
    _check(game.festivals.awarded.size() == 1, "one event ledger entry")
    var gold_after: int = game.gold
    _check("already contributed" in game.festivals.act(site), "same-year re-entry denied")
    _check(game.gold == gold_after, "same-year re-entry cannot duplicate currency")

    # Test all 12 original festivals and annual idempotency in the real scene.
    var first_year_awards: int = 1
    for occasion in game.festivals.entries:
        var event: Dictionary = occasion
        game.season_index = SEASONS.find(str(event["season"]))
        game.day = int(event["day"])
        game.year = 1
        game.minute_of_day = 650.0
        game.energy = 100.0
        game.festivals.refresh()
        _check(game.festivals.stage.visible, "event stage visible: " + str(event["id"]))
        _check(game.festivals.today().get("id", "") == event["id"],
               "season/day lookup: " + str(event["id"]))
        var key: String = "1:" + str(event["id"])
        if game.festivals.awarded.has(key):
            continue
        var item: String = str(event["donation"]["item"])
        var quantity: int = int(event["donation"]["quantity"])
        var value_before: int = int(game.inventory.get(item, 0))
        game.inventory[item] = quantity + 1
        var gold_before: int = game.gold
        var ribbon_before: int = int(game.inventory.get("festival_ribbon", 0))
        var care_before: int = game.restoration
        var contribution: String = game.festivals.act(site)
        _check("Thank you" in contribution, "event contribution completed: " + key)
        _check(int(game.inventory[item]) == 1, "single consumable debit: " + key)
        _check(game.gold == gold_before + int(event["reward"]["petals"]), "exact petals: " + key)
        _check(int(game.inventory.get("festival_ribbon", 0)) == ribbon_before + 1,
               "exact ribbon: " + key)
        _check(game.restoration == mini(100, care_before + int(event["reward"]["restoration"])),
               "bounded restoration: " + key)
        _check(is_equal_approx(game.energy, 97.0), "bounded interaction energy: " + key)
        var replay_currency: int = game.gold
        _check("already contributed" in game.festivals.act(site), "duplicate rejected: " + key)
        _check(game.gold == replay_currency, "no duplicate reward: " + key)
        _check(int(game.inventory[item]) == 1, "no duplicate item debit: " + key)
        first_year_awards += 1

    _check(first_year_awards == 12, "all twelve yearly events playable")
    _check(game.festivals.awarded.size() == 12, "all event awards tracked uniquely")
    game.season_index = 3
    game.day = 14
    game.festivals.refresh()
    _check(not game.festivals.stage.visible, "stage disappears when no event is scheduled")
    game.year = 2
    game.season_index = 0
    game.day = 3
    game.minute_of_day = 600.0
    game.energy = 100.0
    game.festivals.refresh()
    game.inventory["turnip_seed"] = 4
    var year_two_gold: int = game.gold
    _check("Thank you" in game.festivals.act(site),
           "year-two festival allowed at same calendar date")
    _check(game.gold == year_two_gold + 26, "year-two currency awarded once")
    _check(game.festivals.awarded.size() == 13, "year-two isolated entitlement")
    _check("already contributed" in game.festivals.act(site),
           "year-two same-day duplicate rejected")

    # Save and load the real game (schema-1 remains backward compatible).
    game.hero.global_position = site + Vector3(0.0, 1.0, 0.0)
    var records: Dictionary = game.festivals.save_state()
    _check(int(records.get("schema", 0)) == 1, "festival save format preserved")
    _check(records.get("awarded", []).size() == 13, "all earned awards serialized")
    game.save_game(false)
    game.festivals.awarded.clear()
    _check(game.festivals.awarded.is_empty(), "test mutated the live award cache")
    game.load_game()
    _check(game.festivals.awarded.size() == 13, "awards restored from native saved game")
    _check(game.year == 2 and game.day == 3, "calendar restored with festival ledger")
    _check("already contributed" in game.festivals.act(site),
           "reload cannot pay twice")

    # Legacy schema-1 payload without festivals data must load as no active grants.
    game.festivals.load_state({})
    _check(game.festivals.awarded.is_empty(), "legacy save defaults to no award history")
    # Forged future year and unknown IDs are ignored by domain load validation.
    game.festivals.load_state({"awarded":["5:spring_seed_exchange",
                                                 "2:not_an_event",
                                                 "2:spring_seed_exchange"]})
    _check(game.festivals.awarded.size() == 1, "future/unknown awards ignored")
    _check(game.festivals.awarded.has("2:spring_seed_exchange"),
           "valid historical award retained")
    print("EVERBLOOM FESTIVAL NATIVE ACCEPTANCE: %d assertions, %d failures" % [
          assertions, failures])
    quit(0 if failures == 0 else 1)
