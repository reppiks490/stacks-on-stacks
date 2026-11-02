extends SceneTree
## F09 actual native Godot: 112-day replay, bounded tools, receipts, hostile save.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("F09 EQUIPMENT FAILED: " + message)

func _model():
    return load("res://scripts/farm_equipment_progression.gd").new()

func _conserved(s: Dictionary) -> bool:
    for name in ["energy", "timber", "ore", "fiber"]:
        var ledger: Dictionary = s["resources"][name]
        if int(ledger["credited"]) != int(ledger["spent"]) + int(ledger["available"]):
            return false
        if int(ledger["available"]) < 0:
            return false
    return true

func _run() -> void:
    var cared = _model()
    var replay = _model()
    _check(cared.save_state() == replay.save_state(), "deterministic initial tool state")
    _check(cared.save_state()["tools"].size() == 4, "four original tools")
    _check(cared.save_state()["tools"][0]["last_beds"].size() == 30, "30 existing bed IDs supported")
    _check(not cared.advance_day(2)["ok"], "no skipped calendar days")
    _check(not cared.operate("hoe", 0, 1)["ok"], "no work before calendar begins")
    _check(not cared.credit_resources(1, {"energy": 20, "timber": 5, "ore": 5, "fiber": 5})["ok"], "no early credits")
    _check(cared.save_state() == replay.save_state(), "early rejections atomic")
    var first_hoe: Dictionary = {}
    var final_hoe: Dictionary = {}
    for epoch in range(1, 113):
        var day_a: Dictionary = cared.advance_day(epoch)
        var day_b: Dictionary = replay.advance_day(epoch)
        _check(day_a == day_b and day_a["ok"], "deterministic calendar %d" % epoch)
        _check(int(day_a["year"]) == int((epoch - 1) / 56) + 1, "56-day year rollover %d" % epoch)
        var unchanged: Dictionary = cared.save_state()
        _check(not cared.advance_day(epoch)["ok"], "duplicate day rejected %d" % epoch)
        _check(cared.save_state() == unchanged, "duplicate day atomic %d" % epoch)
        var allocation: Dictionary = {"energy": 20, "timber": 5, "ore": 5, "fiber": 5}
        var credit_a: Dictionary = cared.credit_resources(epoch, allocation)
        var credit_b: Dictionary = replay.credit_resources(epoch, allocation)
        _check(credit_a == credit_b and credit_a["ok"], "finite supplies credited %d" % epoch)
        unchanged = cared.save_state()
        _check(not cared.credit_resources(epoch, allocation)["ok"], "duplicate daily supply rejected %d" % epoch)
        _check(cared.save_state() == unchanged, "duplicate credit atomic %d" % epoch)
        _check(_conserved(cared.save_state()), "all four resource ledgers conserved %d" % epoch)
        if epoch == 2 or epoch == 14 or epoch == 28:
            var quote: Dictionary = cared.preview_upgrade("hoe")
            _check(quote["ok"], "upgrade quote %d" % epoch)
            var a: Dictionary = cared.upgrade("hoe", epoch)
            var b: Dictionary = replay.upgrade("hoe", epoch)
            _check(a == b and a["ok"], "accounted tier upgrade %d" % epoch)
            _check(int(a["tier"]) == (1 if epoch == 2 else (2 if epoch == 14 else 3)), "tier progression %d" % epoch)
            unchanged = cared.save_state()
            _check(not cared.upgrade("hoe", epoch)["ok"], "no duplicate upgrade %d" % epoch)
            _check(cared.save_state() == unchanged, "duplicate upgrade atomic %d" % epoch)
        if epoch % 8 == 0:
            for name in ["hoe", "watering_can"]:
                var quote: Dictionary = cared.preview_repair(name)
                _check(quote["ok"] and int(quote["restored_wear"]) > 0, "repair has real wear %s %d" % [name, epoch])
                var a: Dictionary = cared.repair(name, epoch)
                var b: Dictionary = replay.repair(name, epoch)
                _check(a == b and a["ok"], "finite repair %s %d" % [name, epoch])
                unchanged = cared.save_state()
                _check(not cared.repair(name, epoch)["ok"], "duplicate/free repair denied %s %d" % [name, epoch])
                _check(cared.save_state() == unchanged, "repair rejection atomic %s %d" % [name, epoch])
        var bed: int = (epoch - 1) % 30
        var other: int = epoch % 30
        var work_a: Dictionary = cared.operate("hoe", bed, epoch)
        var work_b: Dictionary = replay.operate("hoe", bed, epoch)
        _check(work_a == work_b and work_a["ok"], "deterministic hoe operation %d" % epoch)
        if epoch == 1:
            first_hoe = work_a.duplicate(true)
        if epoch == 112:
            final_hoe = work_a.duplicate(true)
        var water_a: Dictionary = cared.operate("watering_can", other, epoch)
        var water_b: Dictionary = replay.operate("watering_can", other, epoch)
        _check(water_a == water_b and water_a["ok"], "deterministic watering %d" % epoch)
        unchanged = cared.save_state()
        _check(not cared.operate("hoe", bed, epoch)["ok"], "duplicate per-bed tool action rejected %d" % epoch)
        _check(cared.save_state() == unchanged, "duplicate operation atomic %d" % epoch)
        _check(_conserved(cared.save_state()), "finite resource conservation after work %d" % epoch)
        _check(cared.save_state() == replay.save_state(), "full replay equality %d" % epoch)
        if epoch % 14 == 0:
            var snapshot: Dictionary = cared.save_state()
            var restored = _model()
            _check(restored.load_state(snapshot), "nested state restored %d" % epoch)
            _check(restored.save_state() == snapshot, "exact nested equality %d" % epoch)
            var json_restored = _model()
            _check(json_restored.load_json(JSON.stringify(snapshot)), "JSON roundtrip %d" % epoch)
            _check(json_restored.save_state() == snapshot, "JSON equality %d" % epoch)
            _check(_conserved(json_restored.save_state()), "JSON resource conservation %d" % epoch)
    _check(first_hoe["work_units"] == 1 and final_hoe["work_units"] == 4, "paid upgrades increase tool efficiency")
    _check(int(final_hoe["energy_spent"]) < int(first_hoe["energy_spent"]), "upgrades reduce energy cost")
    _check(int(cared.save_state()["last_epoch"]) == 112, "two full 56-day years")
    _check(int(cared.status("hoe")["tool"]["tier"]) == 3, "highest tool tier persists")
    _check(not cared.preview_upgrade("hoe")["ok"], "max-tier upgrade refused")
    _check(_conserved(cared.save_state()), "final finite resource conservation")
    var pristine: Dictionary = cared.save_state()
    var invalids: Array = []
    var bad: Dictionary
    bad = pristine.duplicate(true); bad["schema"] = 2; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = 0; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_epoch"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["fatigue"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["fatigue"] = 1.5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["last_credit_epoch"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["resources"]["energy"]["available"] += 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["resources"]["timber"]["spent"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["resources"]["ore"]["credited"] = 10000001; invalids.append(bad)
    bad = pristine.duplicate(true); bad["resources"]["fiber"]["extra"] = 1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["resources"].erase("energy"); invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"].pop_back(); invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0] = []; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["name"] = "invented"; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["tier"] = 4; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["wear"] = 101; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["uses"] = -1; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["last_repair"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["last_upgrade"] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["last_beds"].pop_back(); invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["last_beds"][0] = 113; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["last_beds"][0] = 1.5; invalids.append(bad)
    bad = pristine.duplicate(true); bad["tools"][0]["extra"] = true; invalids.append(bad)
    bad = pristine.duplicate(true); bad["unexpected"] = 1; invalids.append(bad)
    for i in range(invalids.size()):
        _check(not cared.load_state(invalids[i]), "malformed nested save rejected %d" % i)
        _check(cared.save_state() == pristine, "rejected save leaves state unchanged %d" % i)
    _check(not cared.load_json("{broken"), "malformed JSON rejected")
    _check(cared.save_state() == pristine, "malformed JSON atomic")
    _check(not cared.load_json(JSON.stringify({"schema": 1})), "partial JSON rejected")
    _check(cared.save_state() == pristine, "partial JSON atomic")
    _check(not cared.operate("hoe", 30, 112)["ok"], "bed 30 out of bounds")
    _check(not cared.operate("invalid", 0, 112)["ok"], "unknown tool rejected")
    _check(not cared.credit_resources(112, {"energy": -1, "timber": 0, "ore": 0, "fiber": 0})["ok"], "duplicate and invalid credit rejected")
    _check(cared.save_state() == pristine, "late invalid operations atomic")
    var depleted = _model()
    _check(depleted.advance_day(1)["ok"], "depleted fixture day")
    _check(depleted.credit_resources(1, {"energy": 1, "timber": 0, "ore": 0, "fiber": 0})["ok"], "one energy unit credited")
    var low: Dictionary = depleted.save_state()
    _check(not depleted.operate("hoe", 0, 1)["ok"], "insufficient energy rejects work")
    _check(depleted.save_state() == low, "no partial energy debit")
    _check(not depleted.upgrade("hoe", 1)["ok"], "insufficient materials reject upgrade")
    _check(depleted.save_state() == low, "no free upgrades")
    var worn = _model()
    for epoch in range(1, 15):
        _check(worn.advance_day(epoch)["ok"], "worn fixture day %d" % epoch)
        _check(worn.credit_resources(epoch, {"energy": 10, "timber": 0, "ore": 0, "fiber": 0})["ok"], "worn fixture energy %d" % epoch)
        var attempt: Dictionary = worn.operate("hoe", (epoch - 1) % 30, epoch)
        _check(attempt["ok"] == (epoch <= 13), "worn tool fails closed at durability limit %d" % epoch)
    _check(int(worn.status("hoe")["durability"]) == 1, "wear is not negative or silently repaired")
    _check(_conserved(worn.save_state()), "worn tool conserved energy")
    print("EVERBLOOM F09 EQUIPMENT NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
