extends SceneTree
const NETWORK = preload("res://scripts/farm_water_network.gd")
## Run with official Godot 4.x: --headless --path . --script res://scripts/farm_water_network_acceptance.gd
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("FARM WATER NETWORK FAILED: " + message)

func _run() -> void:
    var network = NETWORK.new(120, 60)
    _check(int(network.status()["stored"]) == 60, "initial finite stock")
    _check(network.balance_error() == 0, "initial balance")
    var before: Dictionary = network.save_state()
    _check(not bool(network.irrigate(0, 20, 1)["ok"]), "no pre-day withdrawal")
    _check(network.save_state() == before, "pre-day denial atomic")
    var rain: Dictionary = network.next_day(1, 70, 3)
    _check(bool(rain["ok"]), "first day accepted")
    _check(int(rain["captured"]) == 60 and int(rain["spilled"]) == 10,
        "finite reservoir overflow")
    _check(int(rain["evaporated"]) == 3 and int(rain["stored"]) == 117,
        "evaporation debits finite stock")
    var water: Dictionary = network.irrigate(0, 20, 1)
    _check(bool(water["ok"]), "irrigation accepted")
    _check(int(water["delivered"]) == 18 and int(water["channel_loss"]) == 2,
        "channel efficiency accounts for every source unit")
    _check(int(network.status()["stored"]) == 97, "source debit exactly twenty")
    _check(network.balance_error() == 0, "rain/overflow/evaporation/irrigation balance")
    var once: Dictionary = network.save_state()
    for rejected in [
        network.irrigate(0, 20, 1), network.irrigate(-1, 5, 1),
        network.irrigate(30, 5, 1), network.irrigate(1, 31, 1),
        network.irrigate(1, 0, 1), network.irrigate(1, 98, 1),
        network.irrigate(1, 20, 2), network.next_day(1, 70, 3),
        network.next_day(3, 70, 3), network.next_day(2, -1, 3),
        network.next_day(2, 0, -1)
    ]:
        _check(not bool(rejected["ok"]), "invalid command rejected")
        _check(network.save_state() == once, "invalid command does not mutate stock")
    _check(bool(network.next_day(2, 0, 0)["ok"]), "sequential day accepted")
    _check(bool(network.irrigate(0, 20, 2)["ok"]), "new day unlocks irrigation")
    var saved: Dictionary = network.save_state()
    var restored = NETWORK.new()
    _check(restored.load_state(saved), "deep load of conserved schema")
    _check(restored.save_state() == saved, "save/load exact roundtrip")
    _check(not bool(restored.irrigate(0, 20, 2)["ok"]),
        "daily duplicate remains denied after reload")
    var exported: Dictionary = restored.save_state()
    exported["withdrawals_today"][0] = 0
    _check(restored.save_state() == saved, "exported nested arrays cannot alias active state")

    var baseline: Dictionary = restored.save_state()
    var invalid: Array = [
        {"stored": -1}, {"stored": 9999}, {"capacity": 0}, {"schema": 2},
        {"inflow_total": -1}, {"delivered_total": 999999},
        {"last_epoch": -5}, {"withdrawals_today": [0, 0]},
        {"withdrawals_today": [true]}, {"initial": 121},
        {"spill_total": 999999}, {"channel_loss_total": -1},
        {"extra_key": 1}, {"last_epoch": 2.5}
    ]
    for mutation in invalid:
        var damaged: Dictionary = baseline.duplicate(true)
        for key in mutation:
            damaged[key] = mutation[key]
        _check(not restored.load_state(damaged), "forged snapshot rejected")
        _check(restored.save_state() == baseline, "forged load cannot alter live state")
    _check(not restored.load_state([]), "wrong root type rejected")
    _check(restored.save_state() == baseline, "wrong root type atomic")

    # Two independent 112-day simulations with 30-bed allocations and
    # checkpoints. Year 2 begins at epoch 57, not at season/day alias 1.
    var a = NETWORK.new(250, 120)
    var b = NETWORK.new(250, 120)
    for epoch in range(1, 113):
        var runoff: int = 75 if epoch % 7 == 0 else (9 if epoch % 3 == 0 else 0)
        var evap: int = 4 if epoch % 56 >= 14 and epoch % 56 < 28 else 2
        var day_a: Dictionary = a.next_day(epoch, runoff, evap)
        var day_b: Dictionary = b.next_day(epoch, runoff, evap)
        _check(day_a == day_b and bool(day_a["ok"]), "two-year deterministic catchment day %d" % epoch)
        for bed in range(30):
            if (epoch + bed) % 5 == 0:
                var requested: int = 5 + bed % 24
                var tx_a: Dictionary = a.irrigate(bed, requested, epoch)
                var tx_b: Dictionary = b.irrigate(bed, requested, epoch)
                _check(tx_a == tx_b, "two-year deterministic channel %d:%d" % [epoch, bed])
                if bool(tx_a["ok"]):
                    var after_tx: Dictionary = a.save_state()
                    _check(not bool(a.irrigate(bed, requested, epoch)["ok"]),
                        "repeated watering cannot mint delivery %d:%d" % [epoch, bed])
                    _check(a.save_state() == after_tx, "duplicate action atomic")
        _check(a.balance_error() == 0 and b.balance_error() == 0,
            "conservation on day %d" % epoch)
        _check(a.save_state() == b.save_state(), "deterministic full state day %d" % epoch)
        _check(int(a.status()["stored"]) >= 0 and
            int(a.status()["stored"]) <= int(a.status()["capacity"]),
            "finite reservoir stock day %d" % epoch)
        if epoch % 14 == 0:
            var checkpoint: Dictionary = a.save_state()
            var reload = NETWORK.new()
            _check(reload.load_state(checkpoint), "season checkpoint load day %d" % epoch)
            a = reload
            _check(a.save_state() == b.save_state(), "season checkpoint exact parity")
        if epoch == 56 or epoch == 57:
            _check(int(a.status()["day_epoch"]) == epoch,
                "56-day annual boundary does not alias %d" % epoch)

    # Exhaustion: zero water cannot be withdrawn, but rain can restore stock.
    var dry = NETWORK.new(10, 0)
    _check(bool(dry.next_day(1, 0, 0)["ok"]), "dry catchment advances")
    _check(not bool(dry.irrigate(0, 1, 1)["ok"]), "empty catchment cannot create water")
    _check(bool(dry.next_day(2, 10, 0)["ok"]), "new runoff replenishes reservoir")
    _check(bool(dry.irrigate(0, 10, 2)["ok"]), "full stock supports finite irrigation")
    _check(int(dry.status()["stored"]) == 0 and dry.balance_error() == 0,
        "exhausted reservoir conserves source/delivery/loss")

    print("EVERBLOOM FARM WATER NETWORK NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
