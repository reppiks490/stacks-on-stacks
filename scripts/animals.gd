extends Node3D
## Original livestock husbandry with care, produce timers and friendship.
var game
var creatures: Array = []

func setup(host) -> void:
    game = host
    var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
    if not payload is Dictionary:
        return
    var index: int = 0
    for profile in payload.get("animals", []):
        var root := Node3D.new()
        root.name = str(profile["name"])
        root.position = Vector3(-5 + index * 3.0, 0.0, -9.0)
        add_child(root)
        var mesh_instance := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.75 if index == 1 else 0.54
        mesh.height = 1.2 if index == 1 else 0.84
        mesh_instance.mesh = mesh
        mesh_instance.position.y = 0.75
        var material := StandardMaterial3D.new()
        material.albedo_color = Color.html(str(profile["palette"]))
        mesh_instance.material_override = material
        root.add_child(mesh_instance)
        var eyes := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.085
        eye_mesh.height = 0.17
        eyes.mesh = eye_mesh
        eyes.position = Vector3(0.3,1.05,0.4)
        var dark := StandardMaterial3D.new()
        dark.albedo_color = Color("#493c3c")
        eyes.material_override = dark
        root.add_child(eyes)
        var label := Label3D.new()
        label.text = str(profile["name"])
        label.font_size = 34
        label.pixel_size = 0.005
        label.position.y = 2.1
        root.add_child(label)
        profile["node"] = root
        profile["bond"] = 0
        profile["last_care"] = -1
        profile["production_counter"] = 0
        creatures.append(profile)
        index += 1

func act(position: Vector3) -> String:
    var closest: Dictionary = {}
    var best_distance: float = 4.0
    for animal in creatures:
        var distance: float = animal["node"].global_position.distance_to(position)
        if distance < best_distance:
            best_distance = distance
            closest = animal
    if closest.is_empty():
        return "Come near the barn and meet your animals."
    var epoch: int = game.season_index * 14 + game.day
    if int(closest["last_care"]) == epoch:
        return "%s has already been cared for today." % closest["name"]
    if not game.consume_item("fodder", 1) and not game.consume_item("wild_herb", 1):
        return "Your animals need fodder or fresh herbs."
    closest["last_care"] = epoch
    closest["bond"] = mini(100, int(closest["bond"]) + int(closest["care_reward"]))
    closest["production_counter"] = int(closest["production_counter"]) + 1
    game.care_actions += 1
    game.add_restoration(1)
    if int(closest["production_counter"]) >= int(closest["production_days"]):
        closest["production_counter"] = 0
        game.grant_item(str(closest["product"]), 1)
        return "%s is thriving! Collected fresh %s." % [closest["name"],closest["product"]]
    return "%s happily accepts your care. Bond %d/100." % [closest["name"],int(closest["bond"])]

func next_day() -> void:
    pass

func save_state() -> Dictionary:
    var output: Dictionary = {}
    for creature in creatures:
        output[str(creature["id"])] = {"bond":creature["bond"],
            "last_care":creature["last_care"],"production_counter":creature["production_counter"]}
    return output

func load_state(saved: Dictionary) -> void:
    for creature in creatures:
        var rid: String = str(creature["id"])
        if saved.has(rid) and saved[rid] is Dictionary:
            var record: Dictionary = saved[rid]
            creature["bond"] = clampi(int(record.get("bond",0)),0,100)
            creature["last_care"] = int(record.get("last_care",-1))
            creature["production_counter"] = clampi(int(record.get("production_counter",0)),0,100)
