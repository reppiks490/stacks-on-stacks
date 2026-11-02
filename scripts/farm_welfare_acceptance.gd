extends SceneTree
## F11 native Godot acceptance: 112 days, deterministic replay, economic settlement,
## strict nested save rejection, care outcomes. Run with --headless --script.
var assertions: int = 0
var failures: int = 0
var bank_a: Dictionary = {"fodder":1000, "energy":3000, "gold":1000}
var bank_b: Dictionary = {"fodder":1000, "energy":3000, "gold":1000}

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("F11 WELFARE FAILED: " + description)

func _settle(cost: Dictionary, bank: Dictionary) -> bool:
    for item in cost:
        if not bank.has(item) or int(bank[item]) < int(cost[item]):
            return false
    for item in cost:
        bank[item] = int(bank[item]) - int(cost[item])
    return true

func _settle_a(cost: Dictionary) -> bool:
    return _settle(cost, bank_a)

func _settle_b(cost: Dictionary) -> bool:
    return _settle(cost, bank_b)

func _reject(_cost: Dictionary) -> bool:
    return false

func _new_model():
    var model = load("res://scripts/farm_animal_welfare.gd").new()
    _check(model.setup(1), "initial setup")
    return model

func _run() -> void:
    var model = _new_model()
    var twin = _new_model()
    _check(model.animals.size() == 3, "three existing species IDs")
    _check(model.quote_action("hen", "feed") == {"fodder":1}, "feed quote")
    _check(model.quote_action("unknown", "feed").is_empty(), "unknown animal rejected")
    _check(model.act("hen", "feed", 1, Callable(self, "_reject")) == "denied:unpaid", "failed settlement denied")
    _check(int(model.animals["hen"]["nutrition"]) == 65, "failed settlement preserves nutrition")
    _check(model.act("hen", "feed", 2, Callable(self, "_settle_a")) == "denied:epoch", "future action denied")
    var before: int = int(bank_a["fodder"])
    _check(model.act("hen", "feed", 1, Callable(self, "_settle_a")).begins_with("ok:"), "authorized feed")
    _check(model.act("hen", "feed", 1, Callable(self, "_settle_a")) == "denied:duplicate", "duplicate denied")
    _check(int(bank_a["fodder"]) == before - 1, "exactly one ration charged")
    _check(twin.act("hen", "feed", 1, Callable(self, "_settle_b")).begins_with("ok:"), "twin authorized feed")
    _check(model.save_state() == twin.save_state(), "same initial event gives same state")
    _check(bank_a == bank_b, "identical settlement accounting")

    # Illness treatment cannot create an instantaneous cure.
    model.animals["cow"]["sickness"] = 50
    twin.animals["cow"]["sickness"] = 50
    _check(model.act("cow", "treat", 1, Callable(self, "_settle_a")).begins_with("ok:"), "paid veterinary treatment")
    _check(twin.act("cow", "treat", 1, Callable(self, "_settle_b")).begins_with("ok:"), "twin veterinary treatment")
    _check(int(model.animals["cow"]["sickness"]) == 50, "no instant cure")
    _check(int(model.animals["cow"]["treatment_days"]) == 3, "multiday treatment")
    _check(model.act("cow", "treat", 1, Callable(self, "_settle_a")) == "denied:duplicate", "no repeated vet charge")
    var previous_sickness: int = 50
    var checkpoints: int = 0
    for step in range(112):
        var epoch: int = step + 1
        var weather: String = "Storm" if step % 11 == 0 else ("Heat" if step % 13 == 0 else "Clear")
        var spaces: Dictionary = {"hen":70, "cow":70, "sheep":25 if step % 9 == 0 else 70}
        for id in ["hen", "cow", "sheep"]:
            if not (id == "hen" and epoch == 1):
                var answer_a: String = model.act(id, "feed", epoch, Callable(self, "_settle_a"))
                var answer_b: String = twin.act(id, "feed", epoch, Callable(self, "_settle_b"))
                _check(answer_a == answer_b and answer_a.begins_with("ok:"), "feed replay %s/%d" % [id, epoch])
            if step % 4 == 0:
                var groom_a: String = model.act(id, "groom", epoch, Callable(self, "_settle_a"))
                var groom_b: String = twin.act(id, "groom", epoch, Callable(self, "_settle_b"))
                _check(groom_a == groom_b and groom_a.begins_with("ok:"), "groom replay")
            if step % 3 == 0:
                var social_a: String = model.act(id, "socialize", epoch, Callable(self, "_settle_a"))
                var social_b: String = twin.act(id, "socialize", epoch, Callable(self, "_settle_b"))
                _check(social_a == social_b and social_a.begins_with("ok:"), "social replay")
        _check(not model.next_day(epoch + 2, weather, spaces), "skipped epoch rejected")
        _check(not model.next_day(epoch + 1, "Unknown", spaces), "invalid weather rejected")
        _check(not model.next_day(epoch + 1, weather, {"hen":70}), "partial space rejected")
        _check(model.next_day(epoch + 1, weather, spaces), "valid next day")
        _check(twin.next_day(epoch + 1, weather, spaces), "twin next day")
        _check(not model.next_day(epoch + 1, weather, spaces), "duplicate day denied")
        _check(model.save_state() == twin.save_state(), "112-day deterministic equality")
        _check(bank_a == bank_b, "economy equality")
        _check(model.day_epoch == epoch + 1, "monotonic epoch")
        if step < 3:
            _check(int(model.animals["cow"]["sickness"]) <= previous_sickness, "treatment reduces illness gradually")
            previous_sickness = int(model.animals["cow"]["sickness"])
        for id in ["hen", "cow", "sheep"]:
            var status: Dictionary = model.forecast(id)
            _check(status.size() > 0 and int(status["risk"]) >= 0 and int(status["risk"]) <= 5, "finite forecast")
            for key in ["nutrition", "mood", "grooming", "social", "space", "health", "sickness"]:
                _check(int(status[key]) >= 0 and int(status[key]) <= 100, "finite %s/%s" % [id, key])
        if (step + 1) % 14 == 0:
            var json: String = JSON.stringify(model.save_state())
            var decoded: Variant = JSON.parse_string(json)
            var restored = _new_model()
            _check(restored.load_state(decoded), "JSON nested restore")
            _check(restored.save_state() == model.save_state(), "JSON restore exact state")
            model = restored
            checkpoints += 1
    _check(checkpoints == 8 and model.day_epoch == 113, "two 56-day years with eight checkpoints")
    for key in bank_a:
        _check(int(bank_a[key]) >= 0, "nonnegative economy")
    _check(bank_a == bank_b, "exact debits across two years")

    var good: Dictionary = model.save_state()
    var original: String = JSON.stringify(good)
    var broken: Array = []
    var missing: Dictionary = good.duplicate(true)
    missing["animals"].erase("hen")
    broken.append(missing)
    var negative: Dictionary = good.duplicate(true)
    negative["animals"]["cow"]["nutrition"] = -1
    broken.append(negative)
    var forged: Dictionary = good.duplicate(true)
    forged["animals"]["hen"]["temperament"] = 999
    broken.append(forged)
    var future: Dictionary = good.duplicate(true)
    future["animals"]["sheep"]["last_actions"]["feed"] = 999999
    broken.append(future)
    var nested: Dictionary = good.duplicate(true)
    nested["animals"]["cow"]["last_actions"] = {"feed":1}
    broken.append(nested)
    var extra: Dictionary = good.duplicate(true)
    extra["animals"]["wolf"] = {}
    broken.append(extra)
    var fractional: Dictionary = good.duplicate(true)
    fractional["animals"]["hen"]["health"] = 22.5
    broken.append(fractional)
    var wrong_version: Dictionary = good.duplicate(true)
    wrong_version["version"] = 9
    broken.append(wrong_version)
    for bad in broken:
        _check(not model.load_state(bad), "hostile nested state rejected")
        _check(JSON.stringify(model.save_state()) == original, "hostile load atomic")

    var cared = _new_model()
    var neglected = _new_model()
    for epoch in range(1, 29):
        for verb in ["feed", "groom", "socialize"]:
            _check(cared.act("hen", verb, epoch, Callable(self, "_settle_a")).begins_with("ok:"), "care action accepted")
        var space: Dictionary = {"hen":70, "cow":70, "sheep":70}
        _check(cared.next_day(epoch + 1, "Clear", space), "cared day")
        _check(neglected.next_day(epoch + 1, "Clear", space), "neglected day")
    _check(int(cared.animals["hen"]["nutrition"]) > int(neglected.animals["hen"]["nutrition"]), "care improves nutrition")
    _check(int(cared.animals["hen"]["mood"]) > int(neglected.animals["hen"]["mood"]), "care improves mood")
    _check(int(cared.animals["hen"]["health"]) >= int(neglected.animals["hen"]["health"]), "care preserves health")

    print("F11 WELFARE NATIVE ACCEPTANCE: %d assertions, %d failures, %d checkpoints, 112 days" % [assertions, failures, checkpoints])
    quit(0 if failures == 0 else 1)
