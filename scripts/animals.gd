extends Node3D
## EVERBLOOM original humane livestock care. One care/production per monotonic day.
## Public contract unchanged: setup, act(position), next_day, save_state, load_state.
const MAX_BOND := 100
const FEED_PRICE := 6
var game
var creatures: Array = []
var material_cache: Dictionary = {}

func setup(host) -> void:
    game = host
    var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
    if not payload is Dictionary:
        return
    var index: int = 0
    for raw_profile in payload.get("animals", []):
        var profile: Dictionary = raw_profile.duplicate(true)
        var root := Node3D.new()
        root.name = str(profile["name"])
        root.position = Vector3(-5.0 + float(index) * 3.0, 0.0, -9.0)
        add_child(root)
        var body := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.75 if index == 1 else 0.54
        mesh.height = 1.2 if index == 1 else 0.84
        mesh.radial_segments = 16
        mesh.rings = 10
        body.mesh = mesh
        body.position.y = 0.75
        body.material_override = _mat(Color.html(str(profile["palette"])))
        root.add_child(body)
        var head := MeshInstance3D.new()
        var head_mesh := SphereMesh.new()
        head_mesh.radius = 0.36
        head_mesh.height = 0.68
        head.mesh = head_mesh
        head.position = Vector3(0.0, 1.02, 0.52)
        head.material_override = body.material_override
        root.add_child(head)
        for side in [-1.0, 1.0]:
            var eye := MeshInstance3D.new()
            var eye_mesh := SphereMesh.new()
            eye_mesh.radius = 0.07
            eye_mesh.height = 0.14
            eye.mesh = eye_mesh
            eye.position = Vector3(side * 0.18, 1.08, 0.78)
            eye.material_override = _mat(Color("#493c3c"))
            root.add_child(eye)
        var label := Label3D.new()
        label.text = str(profile["name"])
        label.font_size = 34
        label.pixel_size = 0.005
        label.position.y = 2.1
        root.add_child(label)
        profile["node"] = root
        profile["bond"] = 0
        profile["happiness"] = 68
        profile["health"] = 85
        profile["hunger"] = 35
        profile["cleanliness"] = 90
        profile["last_care"] = -1
        profile["production_counter"] = 0
        profile["neglect_days"] = 0
        creatures.append(profile)
        index += 1

func _mat(tint: Color) -> StandardMaterial3D:
    var key: String = tint.to_html()
    if material_cache.has(key):
        return material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.88
    material_cache[key] = mat
    return mat

func _feed_one() -> String:
    if game.consume_item("fodder", 1):
        return "fodder"
    if game.consume_item("wild_herb", 1):
        return "wild herbs"
    if int(game.gold) >= FEED_PRICE:
        game.gold -= FEED_PRICE
        return "a fresh feed ration"
    return ""

func act(position: Vector3) -> String:
    var selected: Dictionary = {}
    var best_distance: float = 4.0
    for animal in creatures:
        var distance: float = animal["node"].global_position.distance_to(position)
        if distance < best_distance:
            best_distance = distance
            selected = animal
    if selected.is_empty():
        return "Come near the barn and meet your animals."
    var epoch: int = game.day_epoch()
    if int(selected["last_care"]) == epoch:
        return "%s has already been cared for today." % selected["name"]
    var feed: String = _feed_one()
    if feed == "":
        return "You need fodder, wild herbs, or %d petals for a ration." % FEED_PRICE
    selected["last_care"] = epoch
    selected["hunger"] = maxi(0, int(selected["hunger"]) - 48)
    selected["cleanliness"] = mini(100, int(selected["cleanliness"]) + 18)
    selected["happiness"] = mini(100, int(selected["happiness"]) + 9)
    selected["health"] = mini(100, int(selected["health"]) + 4)
    selected["neglect_days"] = 0
    selected["bond"] = mini(MAX_BOND, int(selected["bond"]) + int(selected["care_reward"]))
    game.care_actions += 1
    game.add_restoration(1)
    if int(selected["health"]) < 45 or int(selected["happiness"]) < 35:
        return "%s ate %s and needs gentle recovery before producing." % [selected["name"], feed]
    selected["production_counter"] = int(selected["production_counter"]) + 1
    if int(selected["production_counter"]) >= int(selected["production_days"]):
        selected["production_counter"] = 0
        game.grant_item(str(selected["product"]), 1)
        return "%s enjoyed %s and offered fresh %s. Bond %d/100." % [
            selected["name"], feed, selected["product"], int(selected["bond"])]
    return "%s enjoyed %s. Happiness %d/100, bond %d/100." % [
        selected["name"], feed, int(selected["happiness"]), int(selected["bond"])]

func next_day() -> void:
    var previous_day: int = game.day_epoch() - 1
    for i in range(creatures.size()):
        var animal: Dictionary = creatures[i]
        var fed_yesterday: bool = int(animal["last_care"]) == previous_day
        animal["hunger"] = mini(100, int(animal["hunger"]) + (10 if fed_yesterday else 24))
        animal["cleanliness"] = maxi(0, int(animal["cleanliness"]) - (5 if fed_yesterday else 11))
        if fed_yesterday:
            animal["happiness"] = mini(100, int(animal["happiness"]) + 2)
            animal["neglect_days"] = 0
        else:
            animal["neglect_days"] = mini(365, int(animal["neglect_days"]) + 1)
            animal["happiness"] = maxi(0, int(animal["happiness"]) - 8)
            if int(animal["hunger"]) >= 75:
                animal["health"] = maxi(0, int(animal["health"]) - 7)
            if int(animal["neglect_days"]) >= 3:
                animal["production_counter"] = 0
        # The quiet paddock shifts daily without stochastic physics or extra assets.
        animal["node"].position.z = -9.0 + float((game.day_epoch() + i * 3) % 3) * 0.24

func save_state() -> Dictionary:
    var output: Dictionary = {}
    for creature in creatures:
        output[str(creature["id"])] = {
            "bond":creature["bond"], "happiness":creature["happiness"],
            "health":creature["health"], "hunger":creature["hunger"],
            "cleanliness":creature["cleanliness"], "last_care":creature["last_care"],
            "production_counter":creature["production_counter"],
            "neglect_days":creature["neglect_days"]
        }
    return output

func load_state(saved: Dictionary) -> void:
    for creature in creatures:
        var rid: String = str(creature["id"])
        if not saved.has(rid) or not saved[rid] is Dictionary:
            continue
        var record: Dictionary = saved[rid]
        for key in ["bond", "happiness", "health", "hunger", "cleanliness"]:
            creature[key] = clampi(int(record.get(key, creature[key])), 0, 100)
        creature["last_care"] = clampi(int(record.get("last_care", -1)), -1, game.day_epoch())
        creature["production_counter"] = clampi(int(record.get("production_counter", 0)),
            0, int(creature["production_days"]) - 1)
        creature["neglect_days"] = clampi(int(record.get("neglect_days", 0)), 0, 365)
