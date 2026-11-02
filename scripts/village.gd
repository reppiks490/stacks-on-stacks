extends Node3D
## Original town characters with affection and daily contact caps.
var game
var residents: Array = []
var affection: Dictionary = {}
var last_talk: Dictionary = {}
var last_gift: Dictionary = {}

func setup(host) -> void:
    game = host
    var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/villagers.json"))
    if not payload is Dictionary:
        return
    for resident in payload.get("villagers", []):
        var spot: Array = resident["home"]
        var container := Node3D.new()
        container.name = str(resident["name"])
        container.position = Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
        add_child(container)
        var body := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.38
        mesh.height = 1.7
        body.mesh = mesh
        body.position.y = 0.9
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.html(str(resident["palette"]))
        body.material_override = mat
        container.add_child(body)
        var label := Label3D.new()
        label.text = str(resident["name"]) + " • " + str(resident["role"])
        label.font_size = 36
        label.pixel_size = 0.006
        label.position = Vector3(0,2.3,0)
        container.add_child(label)
        resident["node"] = container
        residents.append(resident)
        affection[str(resident["id"])] = 0

func act(action: String, position: Vector3) -> String:
    var selected: Dictionary = {}
    var best_distance: float = 4.2
    for resident in residents:
        var distance: float = resident["node"].global_position.distance_to(position)
        if distance < best_distance:
            best_distance = distance
            selected = resident
    if selected.is_empty():
        return "Visit a resident of Larkspur Village."
    var rid: String = str(selected["id"])
    # Calendar epoch is monotonic across years, preventing annual gift/talk locks.
    var epoch: int = game.day_epoch()
    if action == "gift":
        if int(last_gift.get(rid, -1)) == epoch:
            return "%s smiles. One gift each day is enough." % selected["name"]
        var found: String = ""
        for gift in selected["preferences"]:
            if int(game.inventory.get(gift,0)) > 0:
                found = str(gift)
                break
        if found == "":
            return "Bring %s a thoughtful local gift." % selected["name"]
        if game.consume_item(found, 1):
            last_gift[rid] = epoch
            affection[rid] = clampi(int(affection.get(rid, 0)) + 12, 0, 1000)
            game.add_restoration(2)
            return "%s loved your gift of %s. Friendship blossoms." % [selected["name"], found]
        return "No suitable gift in your pouch."
    var lines: Array = selected["dialogue"]
    var phrase: String = str(lines[epoch % lines.size()])
    if int(last_talk.get(rid, -1)) != epoch:
        last_talk[rid] = epoch
        affection[rid] = clampi(int(affection.get(rid, 0)) + 4, 0, 1000)
        game.social_contacts[rid] = true
        game.add_restoration(1)
    return "%s: “%s” (friendship %d)" % [selected["name"], phrase, int(affection[rid])]

func next_day() -> void:
    pass

func save_state() -> Dictionary:
    return {"affection":affection,"talked":last_talk,"gifted":last_gift}

func load_state(state: Dictionary) -> void:
    var loaded: Dictionary = state.get("affection", {})
    for rid in affection:
        if loaded.has(rid):
            affection[rid] = clampi(int(loaded[rid]),0,1000)
    last_talk = state.get("talked", {})
    last_gift = state.get("gifted", {})
