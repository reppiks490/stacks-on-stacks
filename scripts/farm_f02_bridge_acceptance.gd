extends SceneTree
## F02: native real Farm.act water-tool transaction + 112-day 30-bed runoff replay.
## Does NOT claim canonical Game save integration; that remains Principal-owned.
const HYDROLOGY = preload("res://scripts/farm_hydrology.gd")
const NETWORK = preload("res://scripts/farm_water_network.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("F02 BRIDGE FAILED: " + message)

func _run() -> void:
    var host = load("res://scripts/farming_test_host.gd").new()
    root.add_child(host)
    host.configure()
    var farm = load("res://scripts/farm.gd").new()
    root.add_child(farm)
    farm.setup(host)
    var network = NETWORK.new(200, 40)
    var first_tick: Dictionary = network.next_day(host.day_epoch(), 0, 0)
    _check(bool(first_tick["ok"]), "initialize reservoir at the real day epoch")
    _check(farm.attach_water_network(network), "attach same-day conserved reservoir")
    _check(farm.beds.size() == 30, "all thirty existing beds preserved")

    for i in range(3):
        var position: Vector3 = farm.beds[i]["holder"].global_position
        _check("cultivated" in farm.act("till", position), "existing till verb %d" % i)
        _check("Planted" in farm.act("plant", position), "existing plant verb %d" % i)

    var first: Vector3 = farm.beds[0]["holder"].global_position
    var energy_before: float = host.energy
    var gold_before: int = host.gold
    var inventory_before: Dictionary = host.inventory.duplicate(true)
    var message: String = farm.act("water", first)
    _check("Irrigated bed 0" in message and "18 water units" in message,
        "real water tool returns player-readable finite delivery")
    _check(int(farm.beds[0]["moisture"]) == 53 and bool(farm.beds[0]["watered"]),
        "water tool adds delivered units, not an unlimited 100 moisture")
    _check(int(network.status()["stored"]) == 20 and network.balance_error() == 0,
        "exact source debit and channel loss")
    _check(is_equal_approx(host.energy, energy_before - 1.0),
        "successful watering charges exactly one stamina")
    var water_after: Dictionary = network.save_state()
    var energy_after: float = host.energy
    _check("already moist" in farm.act("water", first), "double watering denied")
    _check(network.save_state() == water_after and is_equal_approx(host.energy, energy_after),
        "duplicate action changes neither source nor stamina")

    var second: Vector3 = farm.beds[1]["holder"].global_position
    host.energy = 0.0
    var rollback_water: Dictionary = network.save_state()
    var rollback_soil: int = int(farm.beds[1]["moisture"])
    _check("Rest" in farm.act("water", second), "exhausted stamina rejects irrigation")
    _check(network.save_state() == rollback_water and
        int(farm.beds[1]["moisture"]) == rollback_soil and not bool(farm.beds[1]["watered"]),
        "stamina failure rolls source and soil back atomically")
    host.energy = 100.0
    _check("Irrigated bed 1" in farm.act("water", second),
        "remaining finite water irrigates another real bed")
    _check(int(network.status()["stored"]) == 0 and network.balance_error() == 0,
        "source reaches zero without negative water")
    var third: Vector3 = farm.beds[2]["holder"].global_position
    var dry_energy: float = host.energy
    _check("Not enough water" in farm.act("water", third), "dry reservoir denies watering")
    _check(int(farm.beds[2]["moisture"]) == 35 and
        is_equal_approx(host.energy, dry_energy),
        "dry source cannot alter crop or stamina")
    _check(host.gold == gold_before and host.inventory == inventory_before,
        "water actions cannot mint petals or inventory")

    var farm_saved: Array = farm.save_state()
    var network_saved: Dictionary = network.save_state()
    farm.beds[0]["moisture"] = 0
    farm.load_state(farm_saved)
    var restored = NETWORK.new()
    _check(restored.load_state(network_saved), "restore exact nested reservoir ledger")
    _check(farm.attach_water_network(restored), "reattach restored current-day network")
    _check(farm.save_state() == farm_saved and restored.save_state() == network_saved,
        "farm and network independent state roundtrip")
    _check("already moist" in farm.act("water", first),
        "loaded daily gate still rejects duplicate action")
    host.advance_day()
    _check(not farm.attach_water_network(restored),
        "stale-day network cannot be silently attached")

    # Independent two-year catchment: only actual bed overflow enters the
    # reservoir. Soil runoff is never counted twice as retained soil water.
    var h2 = load("res://scripts/farming_test_host.gd").new()
    root.add_child(h2)
    h2.configure()
    var f2 = load("res://scripts/farm.gd").new()
    root.add_child(f2)
    f2.setup(h2)
    var n2 = NETWORK.new(600, 0)
    _check(bool(n2.next_day(h2.day_epoch(), 0, 0)["ok"]), "dry catchment starts at day 1")
    _check(f2.attach_water_network(n2), "attach second catchment")
    var untouched_gold: int = h2.gold
    var untouched_items: Dictionary = h2.inventory.duplicate(true)
    for step in range(112):
        h2.advance_day()
        var rainy: bool = step % 3 == 0
        var weather: String = "Rain" if rainy else "Clear"
        var runoff: int = 0
        var before_total: int = 0
        var after_total: int = 0
        var expected: Array = []
        for i in range(30):
            var bed: Dictionary = f2.beds[i]
            var ledger: Dictionary = HYDROLOGY.advance_day(
                int(bed["moisture"]), 68 if rainy else 0,
                h2.season() == "Summer", int(bed["weeds"]))
            before_total += int(ledger["before"]) + int(ledger["rain"])
            after_total += int(ledger["moisture"]) + int(ledger["runoff"]) + int(ledger["drainage"]) + int(ledger["evaporation"])
            runoff += int(ledger["runoff"])
            expected.append(int(ledger["moisture"]))
            _check(int(ledger["balance_error"]) == 0, "soil balance %d:%d" % [step, i])
        _check(before_total == after_total, "all-bed soil accounting %d" % step)
        var daily: Dictionary = n2.next_day(h2.day_epoch(), runoff, 2)
        _check(bool(daily["ok"]), "one runoff catchment per day %d" % step)
        var before_duplicate: Dictionary = n2.save_state()
        _check(not bool(n2.next_day(h2.day_epoch(), runoff, 2)["ok"]),
            "duplicate daily catchment denied %d" % step)
        _check(n2.save_state() == before_duplicate,
            "duplicate daily catchment does not mint water %d" % step)
        f2.next_day(weather)
        for i in range(30):
            _check(int(f2.beds[i]["moisture"]) == int(expected[i]),
                "real Farm bed hydrology %d:%d" % [step, i])
        _check(n2.balance_error() == 0, "reservoir accounting %d" % step)
        _check(int(n2.status()["stored"]) >= 0 and int(n2.status()["stored"]) <= 600,
            "finite reservoir capacity %d" % step)
        if step % 14 == 13:
            var soil_snapshot: Array = f2.save_state()
            var water_snapshot: Dictionary = n2.save_state()
            var reloaded = NETWORK.new()
            _check(reloaded.load_state(water_snapshot),
                "seasonal reservoir restore %d" % step)
            _check(reloaded.save_state() == water_snapshot,
                "seasonal nested reservoir exact state %d" % step)
            _check(f2.attach_water_network(reloaded),
                "seasonal same-epoch reattachment %d" % step)
            n2 = reloaded
            f2.load_state(soil_snapshot)
            _check(f2.save_state() == soil_snapshot,
                "seasonal 30-bed roundtrip %d" % step)
    _check(h2.day_epoch() == 113, "112 consecutive transitions cross two 56-day years")
    _check(h2.gold == untouched_gold and h2.inventory == untouched_items,
        "hydrology-only two-year replay cannot mint money or items")
    _check(n2.balance_error() == 0, "final conserved catchment balance")
    print("EVERBLOOM F02 BRIDGE NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
