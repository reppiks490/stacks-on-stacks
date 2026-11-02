extends SceneTree
## F07 actual Godot deterministic four-year orchard, harvest conservation and hostile save QA.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("F07 ORCHARD FAILED: " + message)

func _model():
    return load("res://scripts/farm_orchard_ecology.gd").new()

func _ledger_ok(snapshot: Dictionary) -> bool:
    var remaining: int = 0
    for tree in snapshot["trees"]:
        remaining += int(tree["fruit_units"])
    var l: Dictionary = snapshot["ledger"]
    return int(l["generated"]) == int(l["harvested"]) + int(l["spoiled"]) + remaining

func _run() -> void:
    var cared = _model()
    var replay = _model()
    var control = _model()
    var inventory: Dictionary = {"apple_dwarf_sapling": 2, "pear_standard_sapling": 2,
        "plum_dwarf_sapling": 2, "petals": 900, "apple": 0, "pear": 0}
    _check(cared.save_state()["trees"].size() == 8, "eight separate orchard slots; 30 beds untouched")
    _check(cared.save_state() == replay.save_state(), "deterministic initial state")
    _check(not cared.advance_day(2, 18, 5)["ok"], "skipped epoch rejected")
    _check(not cared.plant(0, "apple", "dwarf", 1)["ok"], "cannot plant before day begins")
    _check(not cared.prune(0, 1)["ok"], "cannot prune before day begins")
    _check(not cared.harvest(0, 1)["ok"], "cannot harvest before day begins")
    _check(cared.save_state() == replay.save_state(), "invalid early commands atomic")
    var harvested_units: int = 0
    var control_units: int = 0
    var pruned_quality: int = 0
    var control_quality: int = 0
    for epoch in range(1, 225):
        var season: int = int(((epoch - 1) % 56) / 14)
        var temperature: int = [18, 29, 16, 0][season]
        var rain: int = 0 if epoch % 9 == 0 else 6
        var a: Dictionary = cared.advance_day(epoch, temperature, rain)
        var b: Dictionary = replay.advance_day(epoch, temperature, rain)
        var c: Dictionary = control.advance_day(epoch, temperature, rain)
        _check(a == b and a["ok"] and c["ok"], "exact deterministic day %d" % epoch)
        _check(cared.save_state() == replay.save_state(), "replay state %d" % epoch)
        var before_duplicate: Dictionary = cared.save_state()
        _check(not cared.advance_day(epoch, temperature, rain)["ok"], "duplicate epoch rejected %d" % epoch)
        _check(cared.save_state() == before_duplicate, "duplicate epoch atomic %d" % epoch)
        if epoch == 1:
            for slot in range(8):
                var species: String = ["apple", "pear", "plum"][slot % 3]
                var stock: String = "dwarf" if slot % 2 == 0 else "standard"
                var x: Dictionary = cared.plant(slot, species, stock, epoch)
                var y: Dictionary = replay.plant(slot, species, stock, epoch)
                var z: Dictionary = control.plant(slot, species, stock, epoch)
                _check(x == y and x["ok"] and z["ok"], "original sapling %d" % slot)
                _check(x["item_required"] == species + "_" + stock + "_sapling", "authoritative external sapling receipt %d" % slot)
            _check(not cared.plant(0, "apple", "dwarf", epoch)["ok"], "occupied orchard slot rejected")
            _check(not cared.plant(8, "apple", "dwarf", epoch)["ok"], "out-of-range orchard slot rejected")
            _check(not cared.plant(0, "invented", "dwarf", epoch)["ok"], "unknown species rejected")
        if (epoch - 1) % 56 == 1:
            for slot in range(8):
                var x: Dictionary = cared.prune(slot, epoch)
                var y: Dictionary = replay.prune(slot, epoch)
                _check(x == y and x["ok"], "annual spring pruning %d/%d" % [epoch, slot])
                _check(not cared.prune(slot, epoch)["ok"], "annual duplicate pruning rejected %d/%d" % [epoch, slot])
                _check(cared.save_state() == replay.save_state(), "pruning replay %d/%d" % [epoch, slot])
        if (epoch - 1) % 56 == 31:
            for slot in range(8):
                var available: int = int(cared.status(slot)["fruit_units"])
                if epoch <= 56:
                    _check(available == 0, "saplings do not fruit during first year")
                    _check(not cared.harvest(slot, epoch)["ok"], "immature fruit denied")
                else:
                    var quality: int = int(cared.status(slot)["quality"])
                    var control_available: int = int(control.status(slot)["fruit_units"])
                    var control_q: int = int(control.status(slot)["quality"])
                    _check(available > 0 and control_available > 0, "mature autumn fruit available")
                    var x: Dictionary = cared.harvest(slot, epoch)
                    var y: Dictionary = replay.harvest(slot, epoch)
                    var z: Dictionary = control.harvest(slot, epoch)
                    _check(x == y and x["ok"] and z["ok"], "authorized harvest proposal %d/%d" % [epoch, slot])
                    _check(int(x["quantity"]) == available and int(x["quality"]) == quality, "quality and units exact")
                    _check(not cared.harvest(slot, epoch)["ok"], "duplicate harvest rejected")
                    _check(cared.save_state() == replay.save_state(), "harvest replay exact")
                    harvested_units += available
                    control_units += control_available
                    pruned_quality += quality
                    control_quality += control_q
        if epoch == 57:
            _check(a["year"] == 2 and a["season_index"] == 0, "year-two rollover")
        if epoch == 113:
            _check(a["year"] == 3, "year-three rollover")
        if epoch == 169:
            _check(a["year"] == 4, "year-four rollover")
        if epoch == 65:
            var snapshot: Dictionary = cared.save_state()
            _check(not cared.prune(0, epoch)["ok"], "pruning outside spring rejected")
            _check(not cared.advance_day(epoch + 1, 99, 6)["ok"], "hostile temperature rejected")
            _check(not cared.advance_day(epoch + 1, 18, -1)["ok"], "hostile rainfall rejected")
            _check(not cared.advance_day(epoch + 2, 18, 6)["ok"], "skipped day rejected")
            _check(cared.save_state() == snapshot, "invalid commands do not mutate")
        for slot in range(8):
            var info: Dictionary = cared.status(slot)
            _check(info["ok"], "player feedback %d/%d" % [epoch, slot])
            _check(int(info["age_days"]) >= 0 and int(info["health"]) >= 0 and int(info["health"]) <= 100, "finite age and health")
            _check(int(info["fruit_units"]) >= 0 and int(info["fruit_units"]) <= 20, "bounded fruit")
            _check(int(info["quality"]) >= 0 and int(info["quality"]) <= 5, "bounded quality")
            _check(bool(info["dormant"]) == (season == 3), "winter dormancy transitions")
        _check(_ledger_ok(cared.save_state()), "fruit conservation every day %d" % epoch)
        _check(_ledger_ok(control.save_state()), "untreated control conservation %d" % epoch)
        if epoch % 14 == 0:
            var snapshot: Dictionary = cared.save_state()
            var restored = _model()
            _check(restored.load_state(snapshot), "14-day nested snapshot accepted %d" % epoch)
            _check(restored.save_state() == snapshot, "snapshot exact equality %d" % epoch)
            _check(not restored.advance_day(epoch, temperature, rain)["ok"], "restored duplicate day denied")
            if epoch % 28 == 0:
                var json_restored = _model()
                _check(json_restored.load_json(JSON.stringify(snapshot)), "JSON nested roundtrip %d" % epoch)
                _check(json_restored.save_state() == snapshot, "JSON exact state %d" % epoch)
            var exposed: Dictionary = snapshot.duplicate(true)
            exposed["trees"][0]["health"] = 0
            _check(cared.save_state() == snapshot, "deep snapshot isolation %d" % epoch)
        _check(cared.save_state() == replay.save_state(), "post-action exact replay %d" % epoch)
    _check(harvested_units > control_units, "annual pruning increases actual harvest proposal units")
    _check(pruned_quality > control_quality, "annual pruning improves fruit quality")
    _check(harvested_units == int(cared.save_state()["ledger"]["harvested"]), "cared harvested ledger matches returned units")
    _check(control_units == int(control.save_state()["ledger"]["harvested"]), "control harvested ledger matches returned units")
    _check(inventory == {"apple_dwarf_sapling": 2, "pear_standard_sapling": 2,
        "plum_dwarf_sapling": 2, "petals": 900, "apple": 0, "pear": 0}, "no unauthorized inventory or currency mutation")
    _check(not cared.save_state().has("gold") and not cared.save_state().has("inventory"), "no economic authority in orchard state")
    _check(not cared.status(-1)["ok"] and not cared.status(8)["ok"], "invalid player inspection rejected")
    var pristine: Dictionary = cared.save_state()
    var invalids: Array = []
    var bad: Dictionary
    bad = pristine.duplicate(true); bad["schema"] = 2; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = 2000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"].pop_back(); invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0] = []; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["health"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["health"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["health"] = 1.5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["species"] = "fake"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["rootstock"] = "fake"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["stress"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["age_days"] = 225; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["pruned_year"] = 5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["harvested_year"] = 5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["fruit_units"] = 21; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["quality"] = 6; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["dormant"] = "true"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["last_action_epoch"] = 225; invalids.append(bad)
    bad = pristine.duplicate(true); bad["trees"][0]["unexpected"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["ledger"]["generated"] += 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["ledger"]["harvested"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["ledger"]["spoiled"] = 10000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["ledger"]["unexpected"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["unexpected"] = 1; invalids.append(bad)
    for i in range(invalids.size()):
        _check(not cared.load_state(invalids[i]), "invalid nested save rejected %d" % i)
        _check(cared.save_state() == pristine, "rejected save atomic %d" % i)
    var recovered = _model()
    _check(recovered.load_json(JSON.stringify(pristine)), "final JSON restored")
    _check(recovered.save_state() == pristine, "final JSON state equality")
    bad = pristine.duplicate(true); bad["trees"][0]["health"] = 12.5
    _check(not recovered.load_json(JSON.stringify(bad)), "fractional JSON rejected")
    _check(not recovered.load_json("{bad"), "malformed JSON rejected")
    _check(recovered.save_state() == pristine, "invalid JSON atomic")
    _check(not recovered.advance_day(224, 18, 6)["ok"], "restored duplicate epoch rejected")
    _check(recovered.advance_day(225, 18, 6)["ok"], "restored year-five transition")
    print("EVERBLOOM F07 ORCHARD NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
