extends Node3D
## EVERBLOOM's original, deterministic soil/season farming system.
## Public contract: setup(game), act(tool, position), next_day(weather),
## save_state(), load_state(records). No shared game.gd modifications required.
const BED_COUNT := 30
const STATE_KEYS := ["tilled","crop","age","watered","watered_days","moisture",
    "fertility","weeds","stress","last_family","rotation_bonus",
    "seed_vigor","last_harvest_epoch"]
const QUALITY_NAMES := ["", "rustic", "fresh", "fine", "excellent", "heirloom"]
var game
var beds: Array = []
var field_origin := Vector3(-20.0, 0.0, -1.0)
var materials: Dictionary = {}

func setup(host) -> void:
    game = host
    for z in range(5):
        for x in range(6):
            var index: int = z * 6 + x
            var holder := Node3D.new()
            holder.name = "Bed_%02d" % index
            holder.position = field_origin + Vector3(float(x) * 1.8, 0.0, float(z) * 1.8)
            add_child(holder)
            var bed := MeshInstance3D.new()
            var bed_mesh := BoxMesh.new()
            bed_mesh.size = Vector3(1.48, 0.18, 1.48)
            bed.mesh = bed_mesh
            bed.position.y = 0.1
            holder.add_child(bed)
            var growth := Node3D.new()
            growth.position.y = 0.21
            holder.add_child(growth)
            var stem := MeshInstance3D.new()
            var stem_mesh := CylinderMesh.new()
            stem_mesh.top_radius = 0.06
            stem_mesh.bottom_radius = 0.09
            stem_mesh.height = 1.0
            stem.mesh = stem_mesh
            stem.material_override = _mat(Color("#579e56"))
            growth.add_child(stem)
            var fruit := MeshInstance3D.new()
            var orb := SphereMesh.new()
            orb.radius = 0.3
            orb.height = 0.6
            orb.radial_segments = 12
            orb.rings = 8
            fruit.mesh = orb
            growth.add_child(fruit)
            var weed := MeshInstance3D.new()
            var weed_mesh := SphereMesh.new()
            weed_mesh.radius = 0.2
            weed_mesh.height = 0.4
            weed.mesh = weed_mesh
            weed.position = Vector3(0.42, 0.22, -0.35)
            weed.material_override = _mat(Color("#47673b"))
            growth.add_child(weed)
            var plot := {
                "holder":holder, "bed":bed, "growth":growth, "stem":stem,
                "fruit":fruit, "weed":weed, "tilled":false, "crop":"",
                "age":0, "watered":false, "watered_days":0,
                "moisture":35, "fertility":80, "weeds":0, "stress":0,
                "last_family":"", "rotation_bonus":0, "seed_vigor":0,
                "last_harvest_epoch":-1
            }
            beds.append(plot)
            _paint(plot)

func _mat(tint: Color) -> StandardMaterial3D:
    var key: String = tint.to_html()
    if materials.has(key):
        return materials[key]
    var result := StandardMaterial3D.new()
    result.albedo_color = tint
    result.roughness = 0.86
    materials[key] = result
    return result

func _nearest(origin: Vector3) -> int:
    var nearest: int = -1
    var best: float = 2.8
    for i in range(beds.size()):
        var distance: float = beds[i]["holder"].global_position.distance_to(origin)
        if distance < best:
            best = distance
            nearest = i
    return nearest

func act(tool: String, origin: Vector3) -> String:
    var index: int = _nearest(origin)
    if index < 0:
        return "Move closer to a planting bed."
    var plot: Dictionary = beds[index]
    if tool == "till":
        if bool(plot["tilled"]):
            if int(plot["weeds"]) > 0:
                if not game.spend_energy(2.0):
                    return "You need energy to clear the weeds."
                plot["weeds"] = 0
                _paint(plot)
                return "You cleared the weeds and opened the soil to sunlight."
            var use_compost: bool = int(game.inventory.get("compost", 0)) > 0
            var use_herbs: bool = int(game.inventory.get("wild_herb", 0)) >= 2
            if int(plot["fertility"]) < 90 and (use_compost or use_herbs):
                if not game.spend_energy(2.0):
                    return "You need energy to enrich the soil."
                var amendment: String = "compost" if use_compost else "wild_herb"
                var amount: int = 1 if use_compost else 2
                if not game.consume_item(amendment, amount):
                    return "Amendment unavailable. Please try again."
                plot["fertility"] = mini(100, int(plot["fertility"]) + (32 if use_compost else 24))
                plot["moisture"] = mini(100, int(plot["moisture"]) + 12)
                _paint(plot)
                return "Enriched the soil with %s. Fertility restored." % (
                    "animal compost" if use_compost else "wild herb mulch")
            return "Already cultivated. Clear weeds or add compost / two wild herbs."
        if not game.spend_energy(2.0):
            return "No energy left for digging."
        plot["tilled"] = true
        plot["fertility"] = mini(100, int(plot["fertility"]) + 3)
        _paint(plot)
        return "You cultivated the rich loam."
    if tool == "plant":
        if not bool(plot["tilled"]) or str(plot["crop"]) != "":
            return "Cultivate an empty bed before sowing."
        var crop: String = game.current_seed()
        if not game.crop_definitions.has(crop):
            return "That seed is unknown."
        var definition: Dictionary = game.crop_definitions[crop]
        if not game.season() in definition["seasons"]:
            return "These seeds cannot grow during %s." % game.season()
        var price: int = int(definition.get("seed_price", 0))
        var has_seed: bool = int(game.inventory.get(crop + "_seed", 0)) > 0
        if not has_seed and (price <= 0 or int(game.gold) < price):
            return "No %s seeds. You need %d petals to purchase one." % [crop, price]
        if not game.spend_energy(1.0):
            return "You are too tired to sow seeds."
        if has_seed:
            if not game.consume_item(crop + "_seed", 1):
                return "Seed pouch changed. Please try again."
        else:
            game.gold -= price
        var family: String = str(definition.get("family", crop))
        var previous: String = str(plot["last_family"])
        plot["rotation_bonus"] = 1 if previous != "" and previous != family else 0
        plot["seed_vigor"] = (index * 7 + game.day_epoch() * 3 + crop.length()) % 3
        plot["crop"] = crop
        plot["age"] = 0
        plot["watered"] = false
        plot["watered_days"] = 0
        plot["stress"] = 0
        _paint(plot)
        if has_seed:
            return "Planted %s. Seed vigor %d/2." % [crop, int(plot["seed_vigor"])]
        return "Purchased and planted %s for %d petals." % [crop, price]
    if tool == "water":
        if str(plot["crop"]) == "":
            return "There is no seedling to water."
        if bool(plot["watered"]) or int(plot["moisture"]) >= 95:
            return "The soil is already moist today."
        if not game.spend_energy(1.0):
            return "Rest to refill your watering can."
        plot["watered"] = true
        plot["moisture"] = 100
        _paint(plot)
        return "The seedlings drink in the cool water."
    if tool == "harvest":
        var crop_id: String = str(plot["crop"])
        if crop_id == "":
            return "This planting bed is empty."
        var crop_data: Dictionary = game.crop_definitions[crop_id]
        if int(plot["age"]) < int(crop_data["days"]) or int(plot["watered_days"]) < int(crop_data["water_days"]):
            return "These plants need a little more time."
        if int(plot["last_harvest_epoch"]) == game.day_epoch():
            return "This bed has already been harvested today."
        if not game.spend_energy(1.0):
            return "You need energy to harvest."
        var quality: int = clampi(1 + int(int(plot["fertility"]) >= 65)
            + int(int(plot["stress"]) == 0) + int(plot["rotation_bonus"])
            + int(int(plot["seed_vigor"]) == 2) - int(int(plot["weeds"]) >= 2), 1, 5)
        var amount: int = int(crop_data["yield"]) + int(quality >= 4)
        game.grant_item(crop_id, amount)
        game.crops_harvested += amount
        game.add_restoration(1 + int(quality == 5))
        plot["fertility"] = maxi(0, int(plot["fertility"]) - int(crop_data.get("nutrient_draw", 6)))
        plot["last_family"] = str(crop_data.get("family", crop_id))
        plot["last_harvest_epoch"] = game.day_epoch()
        var regrow: int = int(crop_data.get("regrow_days", 0))
        if regrow > 0:
            plot["age"] = maxi(0, int(crop_data["days"]) - regrow)
            plot["watered_days"] = maxi(0, int(crop_data["water_days"]) - regrow)
            plot["watered"] = false
        else:
            plot["crop"] = ""
            plot["age"] = 0
            plot["watered"] = false
            plot["watered_days"] = 0
            plot["stress"] = 0
        _paint(plot)
        return "Harvested %d %s (%s quality)!" % [amount, crop_id, QUALITY_NAMES[quality]]
    return "Choose a farming tool."

func next_day(new_weather: String) -> void:
    var rainy: bool = new_weather == "Rain"
    var summer: bool = game.season() == "Summer"
    for i in range(beds.size()):
        var plot: Dictionary = beds[i]
        var moisture: int = int(plot["moisture"])
        if rainy:
            moisture = mini(100, moisture + 68)
        var can_grow: bool = (bool(plot["watered"]) or rainy or moisture >= 45) and int(plot["weeds"]) < 4
        var crop_id: String = str(plot["crop"])
        if crop_id != "":
            var crop_data: Dictionary = game.crop_definitions.get(crop_id, {})
            if not game.season() in crop_data.get("seasons", []):
                _clear_crop(plot)
            elif can_grow and int(plot["fertility"]) > 12:
                plot["age"] = mini(100, int(plot["age"]) + 1)
                plot["watered_days"] = mini(100, int(plot["watered_days"]) + 1)
                plot["stress"] = maxi(0, int(plot["stress"]) - 1)
                var nutrient_draw: int = int(crop_data.get("nutrient_draw", 6))
                plot["fertility"] = maxi(0, int(plot["fertility"]) - maxi(1, nutrient_draw / 3))
            else:
                plot["stress"] = mini(9, int(plot["stress"]) + 1)
                var tolerance: int = int(crop_data.get("drought_tolerance", 1))
                if int(plot["stress"]) > tolerance + 2:
                    _clear_crop(plot)
        elif bool(plot["tilled"]):
            plot["fertility"] = mini(100, int(plot["fertility"]) + 2)
        if bool(plot["tilled"]) and (game.day_epoch() + i * 7) % 9 == 0:
            plot["weeds"] = mini(5, int(plot["weeds"]) + 1)
        moisture -= (22 if rainy else (35 if summer else 29)) + int(plot["weeds"]) * 2
        plot["moisture"] = clampi(moisture, 0, 100)
        plot["watered"] = false
        _paint(plot)

func _clear_crop(plot: Dictionary) -> void:
    plot["crop"] = ""
    plot["age"] = 0
    plot["watered"] = false
    plot["watered_days"] = 0
    plot["stress"] = 0

func _paint(plot: Dictionary) -> void:
    var soil: Color = Color("#8d624b") if bool(plot["tilled"]) else Color("#8ab17b")
    if int(plot["moisture"]) >= 45:
        soil = soil.darkened(0.17)
    if int(plot["fertility"]) < 25:
        soil = soil.lerp(Color("#aa9a80"), 0.36)
    plot["bed"].material_override = _mat(soil)
    var weed: MeshInstance3D = plot["weed"]
    weed.visible = int(plot["weeds"]) > 0
    weed.scale = Vector3.ONE * (0.6 + float(plot["weeds"]) * 0.18)
    var stem: MeshInstance3D = plot["stem"]
    var fruit: MeshInstance3D = plot["fruit"]
    var crop_id: String = str(plot["crop"])
    stem.visible = crop_id != ""
    fruit.visible = crop_id != ""
    if crop_id == "":
        return
    var definition: Dictionary = game.crop_definitions[crop_id]
    var proportion: float = clampf(float(plot["age"]) / maxf(1.0, float(definition["days"])), 0.08, 1.0)
    var stem_height: float = 0.2 + proportion * 0.85
    stem.scale = Vector3(1, stem_height, 1)
    stem.position.y = stem_height * 0.5
    fruit.scale = Vector3.ONE * (0.28 + proportion * 0.85)
    fruit.position.y = stem_height + 0.12
    fruit.material_override = _mat(Color.html(str(definition["color"])))

func save_state() -> Array:
    var records: Array = []
    for bed in beds:
        var state: Dictionary = {}
        for key in STATE_KEYS:
            state[key] = bed[key]
        records.append(state)
    return records

func load_state(records: Array) -> void:
    if records.size() != BED_COUNT or beds.size() != BED_COUNT:
        return
    for i in range(BED_COUNT):
        if not records[i] is Dictionary:
            continue
        var record: Dictionary = records[i]
        var crop_id: String = str(record.get("crop", ""))
        if crop_id != "" and not game.crop_definitions.has(crop_id):
            continue
        var plot: Dictionary = beds[i]
        plot["tilled"] = bool(record.get("tilled", false))
        plot["crop"] = crop_id
        plot["age"] = clampi(int(record.get("age", 0)), 0, 100)
        plot["watered"] = bool(record.get("watered", false))
        plot["watered_days"] = clampi(int(record.get("watered_days", 0)), 0, 100)
        plot["moisture"] = clampi(int(record.get("moisture", 35)), 0, 100)
        plot["fertility"] = clampi(int(record.get("fertility", 80)), 0, 100)
        plot["weeds"] = clampi(int(record.get("weeds", 0)), 0, 5)
        plot["stress"] = clampi(int(record.get("stress", 0)), 0, 9)
        plot["last_family"] = str(record.get("last_family", "")).substr(0, 32)
        plot["rotation_bonus"] = clampi(int(record.get("rotation_bonus", 0)), 0, 1)
        plot["seed_vigor"] = clampi(int(record.get("seed_vigor", 0)), 0, 2)
        plot["last_harvest_epoch"] = clampi(int(record.get("last_harvest_epoch", -1)), -1, game.day_epoch())
        _paint(plot)
