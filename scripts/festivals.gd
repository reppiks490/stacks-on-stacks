extends Node3D
## Original 12-event seasonal village celebration service.
## Economic admission is synchronous, year-bound, one award per festival.
## External NPC schedules and visual assets remain independently owned.

const DATA_PATH := "res://data/festivals.json"
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const ENERGY_COST := 3.0
var game
var venue: Dictionary = {}
var entries: Array = []
var awarded: Dictionary = {}
var stage: Node3D
var lanterns: Array = []
var sign: Label3D
var last_drawn_epoch: int = -1

func setup(host) -> void:
    game = host
    var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not payload is Dictionary or int(payload.get("schema_version", 0)) != 1:
        push_error("EVERBLOOM festival catalog unavailable or invalid")
        return
    entries = payload.get("festivals", [])
    venue = payload.get("venue", {})
    _make_stage()
    refresh()

func _color(hex: String) -> StandardMaterial3D:
    var surface := StandardMaterial3D.new()
    surface.albedo_color = Color.html(hex)
    surface.roughness = 0.78
    return surface

func _box(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    instance.mesh = shape
    instance.position = at
    instance.material_override = _color(color)
    parent.add_child(instance)
    return instance

func _orb(parent: Node3D, at: Vector3, size: float, color: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = size
    shape.height = size * 2.0
    shape.radial_segments = 12
    shape.rings = 8
    instance.mesh = shape
    instance.position = at
    instance.material_override = _color(color)
    parent.add_child(instance)
    return instance

func _make_stage() -> void:
    if venue.is_empty():
        return
    var site: Array = venue.get("square", [30.0, 0.0, 0.0])
    stage = Node3D.new()
    stage.name = "LanternFestivalSquare"
    stage.position = Vector3(float(site[0]), float(site[1]), float(site[2]))
    add_child(stage)
    _box(stage, Vector3(0.0, 0.23, 0.0), Vector3(6.5, 0.42, 5.0), "#c09a72")
    _box(stage, Vector3(0.0, 0.48, -2.25), Vector3(5.5, 0.3, 0.36), "#805b4b")
    for side in [-1.0, 1.0]:
        _box(stage, Vector3(side * 2.7, 2.1, -1.6), Vector3(0.22, 3.6, 0.22), "#805b4b")
        _orb(stage, Vector3(side * 2.7, 3.95, -1.6), 0.40, "#f9da91")
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(side * 2.7, 3.90, -1.6)
        lamp.light_color = Color("#f5cf95")
        lamp.light_energy = 0.55
        lamp.omni_range = 5.0
        lamp.shadow_enabled = false
        stage.add_child(lamp)
        lanterns.append(lamp)
    _box(stage, Vector3(0.0, 3.65, -1.6), Vector3(5.4, 0.18, 0.18), "#805b4b")
    sign = Label3D.new()
    sign.name = "FestivalAnnouncement"
    sign.text = "EVERBLOOM FESTIVAL"
    sign.font_size = 52
    sign.pixel_size = 0.004
    sign.position = Vector3(0, 2.6, -1.9)
    sign.modulate = Color("#fff4db")
    stage.add_child(sign)
    stage.visible = false

func _process(_delta: float) -> void:
    if game == null or stage == null:
        return
    if last_drawn_epoch != game.day_epoch():
        refresh()
    if stage.visible:
        var pulse: float = 0.75 + 0.12 * sin(float(Time.get_ticks_msec()) / 660.0)
        for lamp in lanterns:
            lamp.light_energy = pulse

func refresh() -> void:
    if game == null:
        return
    last_drawn_epoch = game.day_epoch()
    if stage == null:
        return
    var occasion: Dictionary = today()
    stage.visible = not occasion.is_empty()
    if not occasion.is_empty():
        sign.text = str(occasion.get("title", "EVERBLOOM"))
        sign.modulate = Color.html(str(occasion.get("color", "#fff4db")))

func today() -> Dictionary:
    if game == null:
        return {}
    for raw in entries:
        var occasion: Dictionary = raw
        if str(occasion.get("season", "")) == game.season() and int(occasion.get("day", 0)) == game.day:
            return occasion
    return {}

func next_occasion() -> Dictionary:
    if game == null or entries.is_empty():
        return {}
    var starting: int = game.season_index * 14 + game.day - 1
    for offset in range(1, 57):
        var year_slot: int = (starting + offset) % 56
        var season_name: String = SEASONS[int(year_slot / 14)]
        var day_number: int = year_slot % 14 + 1
        for raw in entries:
            var occasion: Dictionary = raw
            if str(occasion["season"]) == season_name and int(occasion["day"]) == day_number:
                return {"days_until":offset, "title":str(occasion["title"])}
    return {}

func _entry_key(occasion: Dictionary) -> String:
    return "%d:%s" % [game.year, str(occasion["id"])]

func status_line() -> String:
    var occasion: Dictionary = today()
    if not occasion.is_empty():
        var required: Dictionary = occasion["donation"]
        if awarded.has(_entry_key(occasion)):
            return str(occasion["title"]) + " — celebrated this year."
        return "Festival today: %s | Bring %d %s | T by the village lanterns" % [
            str(occasion["title"]), int(required["quantity"]), str(required["item"])]
    var upcoming: Dictionary = next_occasion()
    if not upcoming.is_empty():
        return "Next festival: %s in %d days" % [
            str(upcoming["title"]), int(upcoming["days_until"])]
    return "The village calendar is being prepared."

func act(player_position: Vector3) -> String:
    var occasion: Dictionary = today()
    if occasion.is_empty():
        return status_line()
    var site: Array = venue.get("square", [30.0, 0.0, 0.0])
    var center := Vector3(float(site[0]), float(site[1]), float(site[2]))
    if player_position.distance_to(center) > float(venue.get("radius", 8.0)):
        return "Visit the lantern stage in Larkspur Village to join today's celebration."
    var hour: float = float(game.minute_of_day) / 60.0
    if hour < float(venue.get("open_hour", 8)) or hour >= float(venue.get("close_hour", 20)):
        return "The festival takes place between 8:00 and 20:00."
    var key: String = _entry_key(occasion)
    if awarded.has(key):
        return "You already contributed to %s this year. Enjoy the festivities!" % occasion["title"]
    var gift: Dictionary = occasion["donation"]
    var item: String = str(gift["item"])
    var required: int = int(gift["quantity"])
    if int(game.inventory.get(item, 0)) < required:
        return "Bring %d %s to %s before the fair ends." % [
            required, item, occasion["title"]]
    if game.energy < ENERGY_COST:
        return "Rest before helping your neighbors celebrate."
    if not game.spend_energy(ENERGY_COST):
        return "You need energy to contribute."
    if not game.consume_item(item, required):
        # Only the present synchronous session may undo its own energy debit.
        game.energy = minf(100.0, game.energy + ENERGY_COST)
        return "Your contribution was not available. No item was spent."
    var reward: Dictionary = occasion["reward"]
    game.gold += int(reward["petals"])
    game.grant_item("festival_ribbon", int(reward["ribbons"]))
    game.add_restoration(int(reward["restoration"]))
    awarded[key] = true
    return "%s: Thank you for sharing %s! +%d petals, +%d valley care, +1 ribbon." % [
        occasion["title"], item, int(reward["petals"]), int(reward["restoration"])]

func next_day() -> void:
    refresh()

func save_state() -> Dictionary:
    return {"schema":1, "awarded":awarded.keys()}

func load_state(payload: Dictionary) -> void:
    # Optional in legacy schema-1 saves; avoid future-year or invented event grants.
    awarded = {}
    var records: Variant = payload.get("awarded", [])
    if not records is Array:
        refresh()
        return
    var ids: Dictionary = {}
    for occasion in entries:
        ids[str(occasion["id"])] = true
    var examined: int = 0
    for raw in records:
        if examined >= 5000:
            break
        examined += 1
        if not raw is String:
            continue
        var parts: PackedStringArray = str(raw).split(":")
        if parts.size() != 2 or not parts[0].is_valid_int():
            continue
        var claimed_year: int = int(parts[0])
        if claimed_year < 1 or claimed_year > game.year or not ids.has(parts[1]):
            continue
        awarded[str(raw)] = true
    refresh()
