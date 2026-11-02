extends SceneTree
const HYDROLOGY = preload("res://scripts/farm_hydrology.gd")
## Native engine acceptance, not a mock of the farm/animal scripts.
## Run: godot --headless --path . --script res://scripts/farming_acceptance.gd
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("FARM ACCEPTANCE FAILED: " + message)

func _run() -> void:
    var host = load("res://scripts/farming_test_host.gd").new()
    root.add_child(host)
    host.configure()
    var farm = load("res://scripts/farm.gd").new()
    root.add_child(farm)
    farm.setup(host)
    var animals = load("res://scripts/animals.gd").new()
    root.add_child(animals)
    animals.setup(host)

    _check(farm.beds.size() == 30, "expected thirty working beds")
    _check(animals.creatures.size() == 3, "expected three distinct animals")
    var first: Vector3 = farm.beds[0]["holder"].global_position
    var first_bed: Dictionary = farm.beds[0]
    _check("cultivated" in farm.act("till", first), "till action")
    _check(bool(first_bed["tilled"]), "tilling persisted")
    host.inventory["turnip_seed"] = 0
    var gold_before: int = host.gold
    _check("Purchased" in farm.act("plant", first), "seed shop fallback")
    _check(host.gold == gold_before - 12, "exact seed price charged")
    _check(str(first_bed["crop"]) == "turnip", "seed planted")
    _check("drink" in farm.act("water", first), "watering works")
    var energy_after_water: float = host.energy
    _check("already moist" in farm.act("water", first), "double watering denied")
    _check(is_equal_approx(host.energy, energy_after_water), "double watering costs no energy")
    for i in range(4):
        host.advance_day()
        farm.next_day("Clear")
        if i == 2:
            farm.act("water", first)
    _check(int(first_bed["age"]) >= 3, "watered crop matures")
    var crops_before: int = host.crops_harvested
    _check("Harvested" in farm.act("harvest", first), "mature crop harvest")
    _check(host.crops_harvested > crops_before, "crop yield credited")
    _check(host.restoration > 0, "harvest contributes to restoration")
    _check(str(first_bed["last_family"]) == "brassica", "rotation family tracked")
    host.selected_seed = 1
    _check("Planted" in farm.act("plant", first), "rotate into carrot")
    _check(int(first_bed["rotation_bonus"]) == 1, "family rotation recognized")

    # Repeat-bearing berries must require multiple additional growth days.
    host.selected_seed = 2
    var second: Vector3 = farm.beds[1]["holder"].global_position
    _check("cultivated" in farm.act("till", second), "second bed tilled")
    _check("Planted" in farm.act("plant", second), "berries planted")
    for i in range(5):
        farm.act("water", second)
        host.advance_day()
        farm.next_day("Clear")
    _check(int(farm.beds[1]["age"]) >= 5, "berries reach maturity")
    _check("Harvested" in farm.act("harvest", second), "first berry harvest")
    _check(str(farm.beds[1]["crop"]) == "strawberry", "regrow crop retained")
    _check(not ("Harvested" in farm.act("harvest", second)), "no same-day harvest duplication")
    for i in range(3):
        farm.act("water", second)
        host.advance_day()
        farm.next_day("Clear")
    _check("Harvested" in farm.act("harvest", second), "berry regrowth harvest")

    # Seasonal expiration is a real engine transition.
    host.day = 14
    host.season_index = 0
    host.selected_seed = 0
    var third: Vector3 = farm.beds[2]["holder"].global_position
    farm.act("till", third)
    var spring_sowing: String = farm.act("plant", third)
    _check(str(farm.beds[2]["crop"]) == "turnip", "spring turnip planted: " + spring_sowing)
    host.advance_day()
    farm.next_day("Rain")
    _check(host.season() == "Summer", "season rollover")
    _check(str(farm.beds[2]["crop"]) == "", "out-of-season turnip expires")

    # A second year must never reuse the previous year's animal-care epoch.
    host.day = 14
    host.season_index = 3
    host.year = 1
    var animal_position: Vector3 = animals.creatures[0]["node"].global_position
    var care_before: int = host.care_actions
    _check("Hazel Hen" in animals.act(animal_position), "animal care works")
    _check(host.care_actions == care_before + 1, "one care credited")
    _check("already been cared" in animals.act(animal_position), "same-day care blocked")
    _check(host.care_actions == care_before + 1, "no duplicate care reward")
    host.advance_day()
    animals.next_day()
    _check(host.year == 2 and host.day_epoch() == 57, "monotonic second-year epoch")
    _check("Hazel Hen" in animals.act(animal_position), "care permitted next year")
    _check(host.care_actions == care_before + 2, "care increments in year two")

    # Save migration, validation and deep persistence.
    var snapshot: Array = farm.save_state()
    _check(snapshot.size() == 30, "complete soil snapshot")
    snapshot[0]["fertility"] = -500
    snapshot[0]["moisture"] = 10000
    farm.load_state(snapshot)
    _check(int(farm.beds[0]["fertility"]) == 0, "fertility save clamped")
    _check(int(farm.beds[0]["moisture"]) == 100, "moisture save clamped")
    var old_save: Array = farm.save_state()
    old_save[0] = {"tilled":true,"crop":"","age":0,"watered":false,"watered_days":0}
    farm.load_state(old_save)
    _check(int(farm.beds[0]["fertility"]) == 80, "old farm save defaults migrate")
    var animal_snapshot: Dictionary = animals.save_state()
    animal_snapshot["hen"]["health"] = -200
    animal_snapshot["hen"]["happiness"] = 500
    animals.load_state(animal_snapshot)
    _check(int(animals.creatures[0]["health"]) == 0, "animal health save clamped")
    _check(int(animals.creatures[0]["happiness"]) == 100, "animal happiness save clamped")

    # One full calendar year of native simulation with deterministic weather.
    var initial_epoch: int = host.day_epoch()
    for i in range(56):
        host.advance_day()
        farm.next_day("Rain" if i % 7 == 0 else "Clear")
        animals.next_day()
        _check(host.day_epoch() == initial_epoch + i + 1, "calendar monotonic step %d" % i)
        for bed in farm.beds:
            _check(int(bed["moisture"]) >= 0 and int(bed["moisture"]) <= 100,
                "soil moisture bounds")
            _check(int(bed["fertility"]) >= 0 and int(bed["fertility"]) <= 100,
                "soil fertility bounds")
    _check(host.year == 3, "full-year loop returns to spring in year three")
    for item in host.inventory:
        _check(int(host.inventory[item]) >= 0, "inventory nonnegative")
    _check(host.gold >= 0, "gold nonnegative")
    _check(host.energy >= 0.0, "energy nonnegative")
    # A limited paddock conserves bought feed, then regrows on the following day.
    host.weather = "Clear"
    var pasture: Dictionary = animals.paddocks[animals._active_paddock_index()]
    pasture["forage"] = 1
    var cow_position: Vector3 = animals.creatures[1]["node"].global_position
    var pasture_gold: int = host.gold
    var pasture_fodder: int = int(host.inventory.get("fodder", 0))
    _check("fresh pasture grass" in animals.act(cow_position), "spring grazing consumes pasture")
    _check(int(pasture["forage"]) == 0, "grazing consumes finite pasture")
    _check(host.gold == pasture_gold and int(host.inventory["fodder"]) == pasture_fodder,
        "pasture grazing does not consume money or fodder")
    host.advance_day()
    animals.next_day()
    _check(int(pasture["forage"]) == 1, "active pasture recovers one forage per day")
    var sheep_position: Vector3 = animals.creatures[2]["node"].global_position
    _check("fresh pasture grass" in animals.act(sheep_position), "second grazing on regenerated land")
    _check(int(pasture["forage"]) == 0, "recovered forage not duplicated")
    var paddock_snapshot: Dictionary = animals.save_state()
    _check(paddock_snapshot.has("__paddocks__"), "paddock ecology is persisted")
    paddock_snapshot["__paddocks__"][0]["forage"] = -300
    paddock_snapshot["__paddocks__"][1]["forage"] = 900
    animals.load_state(paddock_snapshot)
    _check(int(animals.paddocks[0]["forage"]) == 0, "negative saved pasture clamped")
    _check(int(animals.paddocks[1]["forage"]) == 7,
        "oversized saved pasture clamped")

    # In winter or rain no free grazing is available; failed care must be atomic.
    host.season_index = 3
    host.day = 5
    host.weather = "Rain"
    host.inventory["fodder"] = 0
    host.inventory["wild_herb"] = 0
    host.gold = 0
    var denied_care_count: int = host.care_actions
    var denied_bond: int = int(animals.creatures[1]["bond"])
    var denied_product: int = int(host.inventory.get("milk", 0))
    _check("need fodder" in animals.act(cow_position), "zero feed and budget denies care")
    _check(host.care_actions == denied_care_count and host.gold == 0,
        "failed care cannot credit actions or spend negative currency")
    _check(int(animals.creatures[1]["bond"]) == denied_bond and
        int(host.inventory.get("milk", 0)) == denied_product,
        "failed care cannot increase bond or mint products")

    # Three separate, paid rainy-day care actions produce one compost, not infinite fertilizer.
    host.year = 5
    host.season_index = 0
    host.day = 1
    host.weather = "Rain"
    host.inventory["fodder"] = 3
    var hen_position: Vector3 = animals.creatures[0]["node"].global_position
    animals.creatures[0]["compost_counter"] = 0
    var compost_before: int = int(host.inventory.get("compost", 0))
    for i in range(3):
        _check("Hazel Hen" in animals.act(hen_position), "barn care advances compost ledger")
        var second_care: String = animals.act(hen_position)
        _check("already been cared" in second_care,
            "compost interactions remain day-gated")
        host.advance_day()
        animals.next_day()
    _check(int(host.inventory.get("compost", 0)) == compost_before + 1,
        "three care days yield exactly one compost")
    _check(int(host.inventory.get("fodder", 0)) == 0,
        "rainy day feed conservation")
    var compost_snapshot: Dictionary = animals.save_state()
    compost_snapshot["hen"]["compost_counter"] = 999
    animals.load_state(compost_snapshot)
    _check(int(animals.creatures[0]["compost_counter"]) == 2, "compost ledger clamped")

    # Compost is a real soil input through the already-owned till tool.
    first_bed["tilled"] = true
    first_bed["weeds"] = 0
    first_bed["fertility"] = 20
    host.energy = 50.0
    var soil_energy: float = host.energy
    _check("animal compost" in farm.act("till", first), "animal compost fertilizes the farm")
    _check(int(first_bed["fertility"]) == 52, "compost restores exactly 32 fertility")
    _check(int(host.inventory.get("compost", 0)) == compost_before,
        "compost consumed exactly once")
    _check(is_equal_approx(host.energy, soil_energy - 2.0), "mulching costs stamina")
    var soil_fertility_after: int = int(first_bed["fertility"])
    _check(not ("Enriched" in farm.act("till", first)), "cannot mulch without inputs")
    _check(int(first_bed["fertility"]) == soil_fertility_after,
        "failed fertilization cannot mint fertility")

    # Severe weed competition blocks growth until physically cleared.
    first_bed["crop"] = "turnip"
    first_bed["age"] = 0
    first_bed["watered_days"] = 0
    first_bed["weeds"] = 4
    first_bed["watered"] = true
    host.advance_day()
    farm.next_day("Rain")
    _check(int(first_bed["age"]) == 0, "heavy weeds block crop growth even after rain")
    _check("cleared the weeds" in farm.act("till", first), "existing tool clears weed pressure")
    _check(int(first_bed["weeds"]) == 0, "clearing weeds fixes crop competition")


    # F02: real farm integration plus a 112-day conserved water ledger.
    # The model is deliberately pure: repeated inputs must yield identical outputs.
    var dry_day: Dictionary = HYDROLOGY.advance_day(35, 0, true, 0)
    var wet_day: Dictionary = HYDROLOGY.advance_day(35, 68, true, 0)
    _check(int(wet_day["moisture"]) > int(dry_day["moisture"]),
        "rain materially improves retained moisture")
    var saturated_day: Dictionary = HYDROLOGY.advance_day(95, 68, false, 0)
    _check(int(saturated_day["runoff"]) > 0 and int(saturated_day["drainage"]) > 0,
        "saturated soil accounts for runoff and deep drainage")
    var water_a: int = 35
    var water_b: int = 35
    for step in range(112):
        var rain_units: int = 68 if step % 7 == 0 else 0
        var seasonal_day: int = step % 56
        var summer_day: bool = seasonal_day >= 14 and seasonal_day < 28
        var ledger_a: Dictionary = HYDROLOGY.advance_day(
            water_a, rain_units, summer_day, step % 6)
        var ledger_b: Dictionary = HYDROLOGY.advance_day(
            water_b, rain_units, summer_day, step % 6)
        _check(int(ledger_a["balance_error"]) == 0, "water conserved on day %d" % step)
        _check(int(ledger_a["before"]) + int(ledger_a["rain"]) ==
            int(ledger_a["runoff"]) + int(ledger_a["drainage"]) +
            int(ledger_a["evaporation"]) + int(ledger_a["moisture"]),
            "complete daily water balance %d" % step)
        _check(int(ledger_a["moisture"]) == int(ledger_b["moisture"]),
            "two-year hydrology replay deterministic %d" % step)
        _check(int(ledger_a["moisture"]) >= 0 and int(ledger_a["moisture"]) <= 100,
            "two-year hydrology remains bounded %d" % step)
        water_a = int(ledger_a["moisture"])
        water_b = int(ledger_b["moisture"])
    var audit_bed: Dictionary = farm.beds[29]
    audit_bed["moisture"] = 95
    audit_bed["weeds"] = 0
    var expected_rain: Dictionary = HYDROLOGY.advance_day(95, 68, false, 0)
    host.season_index = 0
    host.advance_day()
    farm.next_day("Rain")
    _check(int(audit_bed["moisture"]) == int(expected_rain["moisture"]),
        "actual thirty-bed farm uses conserved hydrology")
    var saved_hydrology: Array = farm.save_state()
    _check(int(saved_hydrology[29]["moisture"]) == int(expected_rain["moisture"]),
        "water state is persisted through the existing save contract")
    audit_bed["moisture"] = 0
    farm.load_state(saved_hydrology)
    _check(int(audit_bed["moisture"]) == int(expected_rain["moisture"]),
        "farm reload restores exact conserved water state")


    # F02 mainline reconciliation: verify every real bed on 112 consecutive days.
    # The independently computed model must match Farm.next_day, including
    # variable weeds, summer heat and rainfall; no inventory/currency minting.
    var pre_replay_gold: int = host.gold
    var pre_replay_inventory: Dictionary = host.inventory.duplicate(true)
    for replay_day in range(112):
        host.advance_day()
        var replay_weather: String = "Rain" if replay_day % 9 == 0 else "Clear"
        var replay_summer: bool = host.season() == "Summer"
        var expected_bed_water: Array = []
        for bed_index in range(farm.beds.size()):
            var bed_before: Dictionary = farm.beds[bed_index]
            var expected_ledger: Dictionary = HYDROLOGY.advance_day(
                int(bed_before["moisture"]), 68 if replay_weather == "Rain" else 0,
                replay_summer, int(bed_before["weeds"]))
            expected_bed_water.append(int(expected_ledger["moisture"]))
            _check(int(expected_ledger["balance_error"]) == 0,
                "real-bed input ledger conserved %d:%d" % [replay_day, bed_index])
        farm.next_day(replay_weather)
        for bed_index in range(farm.beds.size()):
            _check(int(farm.beds[bed_index]["moisture"]) == int(expected_bed_water[bed_index]),
                "30-bed hydrology transition %d:%d" % [replay_day, bed_index])
        if replay_day % 14 == 13:
            var checkpoint: Array = farm.save_state()
            farm.load_state(checkpoint)
            for bed_index in range(farm.beds.size()):
                _check(int(farm.beds[bed_index]["moisture"]) ==
                    int(checkpoint[bed_index]["moisture"]),
                    "two-year water save/reload %d:%d" % [replay_day, bed_index])
    _check(host.gold == pre_replay_gold,
        "hydrology-only replay does not mint or spend petals")
    _check(host.inventory == pre_replay_inventory,
        "hydrology-only replay does not duplicate inventory")

    # Adversarial boundary inputs are normalized before water accounting.
    for moisture_input in [-10, 0, 1, 90, 100, 130]:
        for rain_input in [-12, 0, 68, 240]:
            for weed_input in [-3, 0, 5, 30]:
                for summer_input in [false, true]:
                    var bounded: Dictionary = HYDROLOGY.advance_day(
                        moisture_input, rain_input, summer_input, weed_input)
                    _check(int(bounded["balance_error"]) == 0,
                        "normalized boundary inputs conserve water")
                    _check(int(bounded["moisture"]) >= 0 and
                        int(bounded["moisture"]) <= 100,
                        "boundary inputs never overfill or underflow soil")
                    _check(int(bounded["runoff"]) >= 0 and
                        int(bounded["drainage"]) >= 0 and
                        int(bounded["evaporation"]) >= 0,
                        "boundary outflows remain nonnegative")

    print("EVERBLOOM FARM NATIVE ACCEPTANCE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
