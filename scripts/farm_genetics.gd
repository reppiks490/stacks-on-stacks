extends RefCounted
## F04 original bounded diploid seed-genetics domain candidate.
## No inventory, money, crop harvest, or save-service mutations occur here.
const BED_COUNT := 30
const MAX_EPOCH := 2000000
const GENES := ["yield", "pigment", "hardiness"]
const CROPS := ["turnip", "carrot", "strawberry", "tomato", "melon", "pumpkin", "winterroot", "bluebell"]
const BED_FIELDS := ["crop", "genome", "sown_epoch", "pollen_bed", "pollen_genome", "pollen_epoch", "seed_proposed", "last_action_epoch"]
var _state: Dictionary = {}

func _init() -> void:
    var beds: Array = []
    for i in range(BED_COUNT):
        beds.append(_empty_bed())
    _state = {"schema": 1, "last_epoch": 0, "beds": beds}

func _neutral_genome() -> Dictionary:
    return {"yield": [1, 1], "pigment": [1, 1], "hardiness": [1, 1]}

func _empty_bed() -> Dictionary:
    return {"crop": "", "genome": _neutral_genome(), "sown_epoch": -1,
        "pollen_bed": -1, "pollen_genome": _neutral_genome(),
        "pollen_epoch": -1, "seed_proposed": false, "last_action_epoch": -1}

func _reject(message: String) -> Dictionary:
    return {"ok": false, "message": message}

func _integer(value: Variant) -> bool:
    return typeof(value) == TYPE_INT

func _valid_genome(value: Variant) -> bool:
    if typeof(value) != TYPE_DICTIONARY:
        return false
    var genome: Dictionary = value
    if genome.size() != GENES.size():
        return false
    for gene in GENES:
        if not genome.has(gene) or typeof(genome[gene]) != TYPE_ARRAY:
            return false
        var pair: Array = genome[gene]
        if pair.size() != 2:
            return false
        for allele in pair:
            if not _integer(allele) or allele < 0 or allele > 3:
                return false
    return true

func _valid(payload: Variant) -> bool:
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    var state: Dictionary = payload
    if state.size() != 3 or not state.has("schema") or not state.has("last_epoch") or not state.has("beds"):
        return false
    if not _integer(state["schema"]) or state["schema"] != 1:
        return false
    if not _integer(state["last_epoch"]) or state["last_epoch"] < 0 or state["last_epoch"] > MAX_EPOCH:
        return false
    if typeof(state["beds"]) != TYPE_ARRAY or state["beds"].size() != BED_COUNT:
        return false
    for i in range(BED_COUNT):
        if typeof(state["beds"][i]) != TYPE_DICTIONARY:
            return false
        var bed: Dictionary = state["beds"][i]
        if bed.size() != BED_FIELDS.size():
            return false
        for key in BED_FIELDS:
            if not bed.has(key):
                return false
        if typeof(bed["crop"]) != TYPE_STRING or not _valid_genome(bed["genome"]) or not _valid_genome(bed["pollen_genome"]):
            return false
        for key in ["sown_epoch", "pollen_bed", "pollen_epoch", "last_action_epoch"]:
            if not _integer(bed[key]):
                return false
        if typeof(bed["seed_proposed"]) != TYPE_BOOL:
            return false
        if bed["last_action_epoch"] < -1 or bed["last_action_epoch"] > state["last_epoch"]:
            return false
        if bed["pollen_bed"] < -1 or bed["pollen_bed"] >= BED_COUNT or bed["pollen_bed"] == i:
            return false
        if bed["crop"] == "":
            if bed["sown_epoch"] != -1 or bed["pollen_bed"] != -1 or bed["pollen_epoch"] != -1 or bed["seed_proposed"]:
                return false
            if bed["genome"] != _neutral_genome() or bed["pollen_genome"] != _neutral_genome():
                return false
        else:
            if not CROPS.has(bed["crop"]) or bed["sown_epoch"] < 1 or bed["sown_epoch"] > state["last_epoch"]:
                return false
            if bed["pollen_bed"] == -1:
                if bed["pollen_epoch"] != -1 or bed["seed_proposed"] or bed["pollen_genome"] != _neutral_genome():
                    return false
            elif bed["pollen_epoch"] < bed["sown_epoch"] + 2 or bed["pollen_epoch"] > state["last_epoch"]:
                return false
    return true

func save_state() -> Dictionary:
    return _state.duplicate(true)

func load_state(payload: Variant) -> bool:
    if not _valid(payload):
        return false
    _state = (payload as Dictionary).duplicate(true)
    return true

func advance_day(epoch: int) -> Dictionary:
    if epoch < 1 or epoch > MAX_EPOCH or epoch != int(_state["last_epoch"]) + 1:
        return _reject("Day epoch must advance exactly once.")
    _state["last_epoch"] = epoch
    return {"ok": true, "day_epoch": epoch,
        "year": int((epoch - 1) / 56) + 1,
        "season_index": int(((epoch - 1) % 56) / 14)}

func phenotype(genome: Variant) -> Dictionary:
    if not _valid_genome(genome):
        return _reject("Invalid diploid genome.")
    var y: Array = genome["yield"]
    var p: Array = genome["pigment"]
    var h: Array = genome["hardiness"]
    return {"ok": true, "yield_bonus": clampi(int((y[0] + y[1] + 1) / 3), 0, 2),
        "color_variant": clampi(int(p[0] + p[1]), 0, 6),
        "hardiness": clampi(int((h[0] + h[1]) / 2), 0, 3)}

func status(bed_index: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT:
        return _reject("Unknown planting bed.")
    var bed: Dictionary = _state["beds"][bed_index]
    if bed["crop"] == "":
        return {"ok": true, "crop": "", "message": "Empty bed; select a seed."}
    var traits: Dictionary = phenotype(bed["genome"])
    return {"ok": true, "crop": bed["crop"], "traits": traits,
        "crossed": bed["pollen_bed"] >= 0, "seed_proposed": bed["seed_proposed"],
        "message": "%s: yield +%d, pigment %d, hardiness %d." % [
            bed["crop"], traits["yield_bonus"], traits["color_variant"], traits["hardiness"]]}

func sow(bed_index: int, crop_id: String, genome: Variant, epoch: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT or not CROPS.has(crop_id) or not _valid_genome(genome):
        return _reject("Invalid seed, genotype or planting bed.")
    if epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Sowing requires the current day epoch.")
    var bed: Dictionary = _state["beds"][bed_index]
    if bed["crop"] != "" or bed["last_action_epoch"] == epoch:
        return _reject("Bed occupied or already used today.")
    bed["crop"] = crop_id
    bed["genome"] = (genome as Dictionary).duplicate(true)
    bed["sown_epoch"] = epoch
    bed["pollen_bed"] = -1
    bed["pollen_genome"] = _neutral_genome()
    bed["pollen_epoch"] = -1
    bed["seed_proposed"] = false
    bed["last_action_epoch"] = epoch
    return {"ok": true, "message": "Seed lineage registered; inventory debit remains external."}

func pollinate(mother_index: int, donor_index: int, epoch: int) -> Dictionary:
    if mother_index < 0 or mother_index >= BED_COUNT or donor_index < 0 or donor_index >= BED_COUNT or mother_index == donor_index:
        return _reject("Select two different planting beds.")
    if epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Pollination requires the current day.")
    var mother: Dictionary = _state["beds"][mother_index]
    var donor: Dictionary = _state["beds"][donor_index]
    if mother["crop"] == "" or mother["crop"] != donor["crop"]:
        return _reject("Only two established plants of the same crop may cross.")
    if epoch - int(mother["sown_epoch"]) < 2 or epoch - int(donor["sown_epoch"]) < 2:
        return _reject("Both parents must establish for two days.")
    if mother["pollen_bed"] != -1 or mother["last_action_epoch"] == epoch:
        return _reject("Mother plant already pollinated or used today.")
    mother["pollen_bed"] = donor_index
    mother["pollen_genome"] = donor["genome"].duplicate(true)
    mother["pollen_epoch"] = epoch
    mother["last_action_epoch"] = epoch
    return {"ok": true, "message": "Controlled cross registered; wait for seed maturity."}

func _offspring(mother: Dictionary, bed_index: int, seed_index: int, epoch: int) -> Dictionary:
    var child: Dictionary = {}
    for locus in range(GENES.size()):
        var gene: String = GENES[locus]
        var maternal: Array = mother["genome"][gene]
        var paternal: Array = mother["pollen_genome"][gene]
        var maternal_pick: int = (epoch * 31 + bed_index * 7 + seed_index * 17 + locus * 13 + int(maternal[0]) * 5) % 2
        var paternal_pick: int = (epoch * 19 + int(mother["pollen_bed"]) * 11 + seed_index * 7 + locus * 3 + int(paternal[1]) * 5) % 2
        child[gene] = [maternal[maternal_pick], paternal[paternal_pick]]
    return child

func propose_seed_save(bed_index: int, epoch: int, harvested_units: int, harvest_receipt: String) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT or epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Invalid bed or day.")
    if harvested_units < 1 or harvested_units > 4:
        return _reject("Seed proposal size must be between one and four.")
    var mother: Dictionary = _state["beds"][bed_index]
    if mother["crop"] == "" or mother["pollen_bed"] < 0 or mother["seed_proposed"]:
        return _reject("No eligible, unused controlled cross.")
    if epoch - int(mother["pollen_epoch"]) < 2 or mother["last_action_epoch"] == epoch:
        return _reject("Seeds are immature or the plant was already used today.")
    if harvest_receipt != "F03:%d:%d:%s" % [bed_index, epoch, mother["crop"]]:
        return _reject("Matching external harvest authorization is required.")
    var proposals: Array = []
    for seed_index in range(harvested_units):
        var child: Dictionary = _offspring(mother, bed_index, seed_index, epoch)
        proposals.append({"genome": child, "traits": phenotype(child)})
    mother["seed_proposed"] = true
    mother["last_action_epoch"] = epoch
    # Proposals are NOT inventory items. External authority must settle a receipt atomically.
    return {"ok": true, "crop": mother["crop"], "proposals": proposals,
        "receipt": "F04:%d:%d:%d" % [bed_index, int(mother["sown_epoch"]), epoch],
        "message": "%d seed genotypes proposed; no seeds credited." % harvested_units}

func clear(bed_index: int, epoch: int) -> Dictionary:
    if bed_index < 0 or bed_index >= BED_COUNT or epoch < 1 or epoch != _state["last_epoch"]:
        return _reject("Invalid bed or day.")
    var bed: Dictionary = _state["beds"][bed_index]
    if bed["crop"] == "" or bed["last_action_epoch"] == epoch:
        return _reject("No crop to clear or already used today.")
    var cleared: Dictionary = _empty_bed()
    cleared["last_action_epoch"] = epoch
    _state["beds"][bed_index] = cleared
    return {"ok": true, "message": "Plant lineage cleared; no inventory credited."}
