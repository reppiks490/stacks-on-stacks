extends Node3D
## Data-driven seasonal soil and crop growth, independent of NPC and art layers.
var game
var beds: Array = []
var soil_tint := Color("#795844")
var field_origin := Vector3(-20,0,-1)

func setup(host) -> void:
    game = host
    for z in range(5):
        for x in range(6):
            var position = field_origin + Vector3(float(x)*1.8, 0.0, float(z)*1.8)
            var holder := Node3D.new()
            holder.position = position
            add_child(holder)
            var bed := MeshInstance3D.new()
            var shape := BoxMesh.new()
            shape.size = Vector3(1.48, 0.18, 1.48)
            bed.mesh = shape
            bed.position.y = 0.10
            holder.add_child(bed)
            var growth := Node3D.new()
            growth.position.y = 0.21
            holder.add_child(growth)
            var plot = {"holder":holder,"bed":bed,"growth":growth,"tilled":false,"crop":"",
                        "age":0,"watered":false,"watered_days":0}
            beds.append(plot)
            _paint(plot)

func _mat(tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.9
    return mat

func _nearest(origin: Vector3) -> int:
    var nearest = -1
    var best = 2.8
    for i in range(beds.size()):
        var distance: float = beds[i]["holder"].global_position.distance_to(origin)
        if distance < best:
            best = distance
            nearest = i
    return nearest

func act(tool: String, origin: Vector3) -> String:
    var index = _nearest(origin)
    if index < 0:
        return "Move closer to an individual planting bed."
    var plot: Dictionary = beds[index]
    if tool == "till":
        if bool(plot["tilled"]):
            return "This bed is already cultivated."
        if not game.spend_energy(2):
            return "No energy left for digging."
        plot["tilled"] = true
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
        if not game.consume_item(crop + "_seed", 1):
            return "You have no %s seeds left." % crop
        plot["crop"] = crop
        plot["age"] = 0
        plot["watered"] = false
        plot["watered_days"] = 0
        _paint(plot)
        return "Planted %s seeds." % crop
    if tool == "water":
        if str(plot["crop"]) == "":
            return "There is no seedling to water."
        if bool(plot["watered"]):
            return "The soil is already moist today."
        if not game.spend_energy(1):
            return "Rest to refill your watering can."
        plot["watered"] = true
        _paint(plot)
        return "The seedlings drink in the cool water."
    if tool == "harvest":
        var crop_id: String = str(plot["crop"])
        if crop_id == "":
            return "This planting bed is empty."
        var crop_data: Dictionary = game.crop_definitions[crop_id]
        if int(plot["age"]) < int(crop_data["days"]) or int(plot["watered_days"]) < int(crop_data["water_days"]):
            return "These plants need a little more time."
        game.grant_item(crop_id, int(crop_data["yield"]))
        game.crops_harvested += int(crop_data["yield"])
        game.add_restoration(1)
        plot["crop"] = ""
        plot["age"] = 0
        plot["watered"] = false
        plot["watered_days"] = 0
        _paint(plot)
        return "Gathered %d freshly grown %s!" % [int(crop_data["yield"]), crop_id]
    return "Choose a farming tool."

func next_day(new_weather: String) -> void:
    for plot in beds:
        if str(plot["crop"]) != "":
            var crop_data: Dictionary = game.crop_definitions.get(plot["crop"], {})
            if not game.season() in crop_data.get("seasons", []):
                plot["crop"] = ""
                plot["age"] = 0
                plot["watered_days"] = 0
            else:
                if bool(plot["watered"]) or new_weather == "Rain":
                    plot["age"] = int(plot["age"]) + 1
                    plot["watered_days"] = int(plot["watered_days"]) + 1
        plot["watered"] = new_weather == "Rain"
        _paint(plot)

func _paint(plot: Dictionary) -> void:
    var soil = Color("#8d624b") if bool(plot["tilled"]) else Color("#8ab17b")
    if bool(plot["watered"]):
        soil = soil.darkened(0.18)
    plot["bed"].material_override = _mat(soil)
    var growth: Node3D = plot["growth"]
    for child in growth.get_children():
        child.queue_free()
    if str(plot["crop"]) == "":
        return
    var definition: Dictionary = game.crop_definitions[plot["crop"]]
    var proportion: float = clampf(float(plot["age"]) / maxf(1.0,float(definition["days"])),0.05,1.0)
    var stem := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.06
    cylinder.bottom_radius = 0.09
    cylinder.height = 0.25 + proportion * 0.8
    stem.mesh = cylinder
    stem.position.y = cylinder.height * 0.5
    stem.material_override = _mat(Color("#579e56"))
    growth.add_child(stem)
    var fruit := MeshInstance3D.new()
    var orb := SphereMesh.new()
    orb.radius = 0.08 + proportion * 0.30
    orb.height = orb.radius * 2.0
    fruit.mesh = orb
    fruit.position.y = cylinder.height + 0.1
    fruit.material_override = _mat(Color.html(str(definition["color"])))
    growth.add_child(fruit)

func save_state() -> Array:
    var records: Array = []
    for bed in beds:
        records.append({"tilled":bed["tilled"],"crop":bed["crop"],"age":bed["age"],
                         "watered":bed["watered"],"watered_days":bed["watered_days"]})
    return records

func load_state(records: Array) -> void:
    if records.size() != beds.size():
        return
    for i in range(beds.size()):
        var record = records[i]
        if not record is Dictionary:
            continue
        var crop_id: String = str(record.get("crop", ""))
        if crop_id != "" and not game.crop_definitions.has(crop_id):
            continue
        for key in ["tilled","crop","age","watered","watered_days"]:
            beds[i][key] = record.get(key, beds[i][key])
        beds[i]["age"] = clampi(int(beds[i]["age"]),0,100)
        beds[i]["watered_days"] = clampi(int(beds[i]["watered_days"]),0,100)
        _paint(beds[i])
