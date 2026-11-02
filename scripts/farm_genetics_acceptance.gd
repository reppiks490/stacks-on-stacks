extends SceneTree
## F04 native 112-day diploid inheritance, adversarial save and no-mint acceptance.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("F04 GENETICS FAILED: " + message)

func _model():
    return load("res://scripts/farm_genetics.gd").new()

func _genome(y: Array, p: Array, h: Array) -> Dictionary:
    return {"yield": y, "pigment": p, "hardiness": h}

func _same_parent_alleles(child: Dictionary, mother: Dictionary, father: Dictionary) -> bool:
    for gene in ["yield", "pigment", "hardiness"]:
        if not mother[gene].has(child[gene][0]) or not father[gene].has(child[gene][1]):
            return false
    return true

func _run() -> void:
    var model = _model()
    var replay = _model()
    var maternal: Dictionary = _genome([0, 3], [0, 3], [1, 3])
    var paternal: Dictionary = _genome([1, 2], [2, 3], [0, 2])
    var original_inventory: Dictionary = {"turnip_seed": 3, "petals": 100}
    _check(model.save_state() == replay.save_state(), "same initial state")
    _check(model.save_state()["beds"].size() == 30, "thirty canonical beds")
    _check(not model.sow(0, "turnip", maternal, 1)["ok"], "cannot sow before calendar begins")
    _check(not model.advance_day(2)["ok"], "cannot skip first day")
    _check(model.save_state() == replay.save_state(), "early rejection atomic")

    var first_proposals: Array = []
    var second_proposals: Array = []
    for epoch in range(1, 113):
        var a: Dictionary = model.advance_day(epoch)
        var b: Dictionary = replay.advance_day(epoch)
        _check(bool(a.get("ok", false)) and a == b, "monotonic calendar %d" % epoch)
        _check(model.save_state() == replay.save_state(), "deterministic daily state %d" % epoch)
        var before: Dictionary = model.save_state()
        _check(not model.advance_day(epoch)["ok"], "duplicate day denied %d" % epoch)
        _check(model.save_state() == before, "duplicate day atomic %d" % epoch)
        if epoch == 57:
            _check(int(a["year"]) == 2 and int(a["season_index"]) == 0, "56-day year rollover")
        if epoch == 1:
            for index_and_crop in [[0, "turnip", maternal], [1, "turnip", paternal],
                [2, "carrot", maternal]]:
                var i: int = index_and_crop[0]
                var crop_id: String = index_and_crop[1]
                var genome: Dictionary = index_and_crop[2]
                var x: Dictionary = model.sow(i, crop_id, genome, epoch)
                var y: Dictionary = replay.sow(i, crop_id, genome, epoch)
                _check(x == y and x["ok"], "sow original crop %d" % i)
            _check(not model.sow(0, "turnip", maternal, epoch)["ok"], "no duplicate sow")
            _check(not model.pollinate(0, 1, epoch)["ok"], "no instant pollination")
            _check(not model.pollinate(0, 2, epoch)["ok"], "incompatible carrot")
            _check(not model.sow(3, "unknown", maternal, epoch)["ok"], "unknown crop")
            _check(not model.sow(3, "turnip", _genome([4, 0], [1, 1], [1, 1]), epoch)["ok"],
                "out-of-bounds allele")
        if epoch == 2:
            _check(not model.pollinate(0, 1, epoch)["ok"], "parents need two full days")
        if epoch == 3:
            _check(not model.pollinate(0, 0, epoch)["ok"], "self donor disallowed")
            _check(not model.pollinate(0, 2, epoch)["ok"], "cross-species pollen rejected")
            var x: Dictionary = model.pollinate(0, 1, epoch)
            var y: Dictionary = replay.pollinate(0, 1, epoch)
            _check(x["ok"] and x == y, "controlled cross accepted")
            _check(model.status(0)["crossed"], "player sees controlled cross")
            _check(not model.pollinate(0, 1, epoch)["ok"], "one pollen event per plant")
        if epoch == 4:
            _check(not model.propose_seed_save(0, epoch, 2, "F03:0:4:turnip")["ok"],
                "crossed seeds need maturation time")
        if epoch == 5:
            _check(not model.propose_seed_save(0, epoch, 2, "FORGED")["ok"], "receipt shape rejected")
            _check(not model.propose_seed_save(0, epoch, 0, "F03:0:5:turnip")["ok"],
                "zero seed count rejected")
            _check(not model.propose_seed_save(0, epoch, 5, "F03:0:5:turnip")["ok"],
                "unbounded seed count rejected")
            var checkpoint: Dictionary = model.save_state()
            var restored = _model()
            _check(restored.load_state(checkpoint), "pre-proposal checkpoint restored")
            var x: Dictionary = model.propose_seed_save(0, epoch, 4, "F03:0:5:turnip")
            var y: Dictionary = replay.propose_seed_save(0, epoch, 4, "F03:0:5:turnip")
            var z: Dictionary = restored.propose_seed_save(0, epoch, 4, "F03:0:5:turnip")
            _check(x["ok"] and x == y and y == z, "deterministic offspring after reload")
            _check(x["proposals"].size() == 4, "bounded four-seed proposal")
            first_proposals = x["proposals"].duplicate(true)
            for item in first_proposals:
                _check(_same_parent_alleles(item["genome"], maternal, paternal),
                    "all offspring alleles inherited from correct parent")
                _check(item["traits"] == model.phenotype(item["genome"]),
                    "offspring phenotype reproducible")
                _check(item["traits"]["yield_bonus"] >= 0 and item["traits"]["yield_bonus"] <= 2,
                    "offspring yield bounded")
                _check(item["traits"]["color_variant"] >= 0 and item["traits"]["color_variant"] <= 6,
                    "offspring pigment bounded")
                _check(item["traits"]["hardiness"] >= 0 and item["traits"]["hardiness"] <= 3,
                    "offspring hardiness bounded")
            _check(not model.propose_seed_save(0, epoch, 4, "F03:0:5:turnip")["ok"],
                "no duplicate seed proposal")
            _check(not model.clear(0, epoch)["ok"], "same-day seed proposal blocks clearing")
            _check(not model.save_state().has("inventory"), "no authoritative inventory minted")
            _check(original_inventory == {"turnip_seed": 3, "petals": 100},
                "external economy untouched")
        if epoch == 6:
            var x: Dictionary = model.clear(0, epoch)
            var y: Dictionary = replay.clear(0, epoch)
            _check(x["ok"] and x == y, "clear original plant after seed proposal")
            _check(not model.sow(0, "turnip", first_proposals[0]["genome"], epoch)["ok"],
                "no clearing and resowing same day")
        if epoch == 7:
            var x: Dictionary = model.sow(0, "turnip", first_proposals[0]["genome"], epoch)
            var y: Dictionary = replay.sow(0, "turnip", first_proposals[0]["genome"], epoch)
            _check(x["ok"] and x == y, "offspring genotype planted next generation")
            _check(model.status(0)["traits"] == first_proposals[0]["traits"],
                "offspring phenotype persists as planted")
        if epoch == 9:
            var x: Dictionary = model.pollinate(0, 1, epoch)
            var y: Dictionary = replay.pollinate(0, 1, epoch)
            _check(x["ok"] and x == y, "second-generation pollination")
        if epoch == 11:
            var x: Dictionary = model.propose_seed_save(0, epoch, 3, "F03:0:11:turnip")
            var y: Dictionary = replay.propose_seed_save(0, epoch, 3, "F03:0:11:turnip")
            _check(x["ok"] and x == y, "second-generation proposal deterministic")
            second_proposals = x["proposals"].duplicate(true)
            for item in second_proposals:
                _check(_same_parent_alleles(item["genome"], first_proposals[0]["genome"], paternal),
                    "second-generation alleles inherited")
        _check(model.save_state() == replay.save_state(), "post-action replay day %d" % epoch)
        for i in range(30):
            var status: Dictionary = model.status(i)
            _check(bool(status.get("ok", false)) and str(status.get("message", "")) != "",
                "player feedback bed %d day %d" % [i, epoch])
        if epoch % 14 == 0:
            var saved: Dictionary = model.save_state()
            var recovered = _model()
            _check(recovered.load_state(saved), "season checkpoint restore %d" % epoch)
            _check(recovered.save_state() == saved, "exact nested checkpoint %d" % epoch)
            saved["beds"][0]["genome"]["yield"][0] = 3
            _check(model.save_state() == replay.save_state(), "deep snapshot isolation %d" % epoch)

    _check(model.save_state()["last_epoch"] == 112, "two complete 56-day years")
    _check(first_proposals.size() == 4 and second_proposals.size() == 3,
        "two generations of real heritable proposals")
    var stable: Dictionary = model.save_state()
    var invalids: Array = []
    var bad: Dictionary = stable.duplicate(true)
    bad["schema"] = 2
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"].pop_back()
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["crop"] = "forged"
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["genome"]["yield"][0] = 4
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["genome"]["pigment"] = [1]
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["genome"]["new_gene"] = [1, 1]
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["pollen_genome"]["hardiness"][1] = -1
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["pollen_bed"] = 0
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["pollen_epoch"] = 113
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["sown_epoch"] = 113
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["seed_proposed"] = "true"
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][1]["seed_proposed"] = true
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][3]["genome"]["yield"][0] = 2
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["last_action_epoch"] = 113
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["last_epoch"] = 112.0
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["extra"] = 1
    invalids.append(bad)
    bad = stable.duplicate(true)
    bad["beds"][0]["extra"] = 1
    invalids.append(bad)
    for i in range(invalids.size()):
        _check(not model.load_state(invalids[i]), "hostile nested save rejected %d" % i)
        _check(model.save_state() == stable, "hostile save rejection atomic %d" % i)
    _check(not model.advance_day(114)["ok"], "cannot skip a year-two day")
    _check(not model.propose_seed_save(0, 112, 2, "F03:0:112:turnip")["ok"],
        "already-proposed crop cannot mint later seeds")
    _check(not model.pollinate(0, 1, 112)["ok"], "already-pollinated crop cannot cross again")
    _check(not model.sow(29, "turnip", _genome([0, 1], [1, 4], [1, 1]), 112)["ok"],
        "reject invalid genome without touching bed")
    _check(model.save_state() == stable, "all late rejections atomic")
    print("EVERBLOOM F04 GENETICS NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
