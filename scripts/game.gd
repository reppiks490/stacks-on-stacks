extends Node3D
## The original EVERBLOOM session orchestrator. Offline/single-player source.
const SAVE_PATH := "user://everbloom_save_v1.json"
const SaveService = preload("res://scripts/save_service.gd")
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const TOOLS := ["till", "plant", "water", "harvest", "care", "talk", "forage"]
var day: int = 1
var year: int = 1
var season_index: int = 0
var minute_of_day: float = 360.0
var weather: String = "Clear"
var gold: int = 380
var energy: float = 100.0
var restoration: int = 0
var crops_harvested: int = 0
var social_contacts: Dictionary = {}
var care_actions: int = 0
var inventory: Dictionary = {"turnip_seed":12, "carrot_seed":8, "strawberry_seed":4, "fodder":6, "wild_herb":0, "wood":0, "fish":0, "stone":0}
var crop_definitions: Dictionary = {}
var recipes: Array = []
var seed_order: Array[String] = ["turnip", "carrot", "strawberry", "tomato", "melon", "pumpkin", "winterroot", "bluebell"]
var selected_seed: int = 0
var selected_tool: int = 0
var latest_message: String = "Welcome to Larkspur Valley. Make it your own."
var camera: Camera3D
var sunlight: DirectionalLight3D
var farm
var valley
var village
var animals
var hero
var hud
var game_rng := RandomNumberGenerator.new()

func _ready() -> void:
    _read_data()
    _register_input()
    game_rng.seed = 20261101
    _make_sky()
    valley = _component("res://scripts/valley.gd", "TheLivingValley")
    valley.setup(self)
    farm = _component("res://scripts/farm.gd", "HomesteadSoil")
    farm.setup(self)
    village = _component("res://scripts/village.gd", "LarkspurResidents")
    village.setup(self)
    animals = _component("res://scripts/animals.gd", "HomesteadAnimals")
    animals.setup(self)
    hero = CharacterBody3D.new()
    hero.name = "Farmer"
    hero.set_script(load("res://scripts/farmer.gd"))
    add_child(hero)
    hero.setup(self)
    hero.global_position = Vector3(-15, 1.0, -7)
    camera = Camera3D.new()
    camera.name = "ValleyCamera"
    camera.current = true
    add_child(camera)
    camera.fov = 56.0
    hud = CanvasLayer.new()
    hud.name = "VillageHUD"
    hud.set_script(load("res://scripts/hud.gd"))
    add_child(hud)
    hud.setup(self)
    _show("Welcome home. Tend your garden and befriend the valley.")

func _component(script_path: String, component_name: String):
    var component = Node3D.new()
    component.name = component_name
    component.set_script(load(script_path))
    add_child(component)
    return component

func _read_data() -> void:
    var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/crops.json"))
    if payload is Dictionary:
        for crop in payload.get("crops", []):
            crop_definitions[str(crop.get("id", ""))] = crop
    var recipe_payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
    if recipe_payload is Dictionary:
        recipes = recipe_payload.get("recipes", [])

func _register_input() -> void:
    var bindings = {
        "move_left":[KEY_A, KEY_LEFT], "move_right":[KEY_D, KEY_RIGHT],
        "move_up":[KEY_W, KEY_UP], "move_down":[KEY_S, KEY_DOWN],
        "interact":[KEY_E], "next_seed":[KEY_Q], "craft":[KEY_R],
        "sleep":[KEY_F], "save":[KEY_P], "load":[KEY_O],
        "gift":[KEY_G], "job":[KEY_K], "ship":[KEY_H], "fish":[KEY_J]
    }
    for action in bindings:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for keycode in bindings[action]:
            var evt := InputEventKey.new()
            evt.physical_keycode = keycode
            InputMap.action_add_event(action, evt)
    for number in range(1, 8):
        var action_name = "tool_%d" % number
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        var event := InputEventKey.new()
        event.physical_keycode = KEY_1 + number - 1
        InputMap.action_add_event(action_name, event)

func _make_sky() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#639bd1")
    sky_material.sky_horizon_color = Color("#f6d3ad")
    sky_material.ground_bottom_color = Color("#587562")
    sky_material.ground_horizon_color = Color("#c3cead")
    sky.sky_material = sky_material
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    var holder := WorldEnvironment.new()
    holder.environment = env
    add_child(holder)
    sunlight = DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-47, -25, 0)
    sunlight.light_color = Color("#ffdfad")
    sunlight.light_energy = 1.25
    sunlight.shadow_enabled = true
    add_child(sunlight)

func _process(delta: float) -> void:
    if hero == null:
        return
    minute_of_day += delta * 1.0
    if minute_of_day >= 1320.0:
        next_day()
    var hour_ratio: float = clampf((minute_of_day - 360.0) / 960.0, 0.0, 1.0)
    if sunlight != null:
        sunlight.rotation_degrees.x = -14.0 - 77.0 * sin(hour_ratio * PI)
        sunlight.light_energy = 0.32 + 1.15 * sin(hour_ratio * PI)
    if camera != null:
        var target: Vector3 = hero.global_position + Vector3(12.0, 15.0, 18.0)
        camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 5.0))
        camera.look_at(hero.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_echo():
        return
    if event.is_action_pressed("interact"):
        _interact()
    elif event.is_action_pressed("next_seed"):
        selected_seed = (selected_seed + 1) % seed_order.size()
        _show("Selected seed: %s" % current_seed())
    elif event.is_action_pressed("gift"):
        _show(village.act("gift", hero.global_position))
    elif event.is_action_pressed("job"):
        _show(village.act("job", hero.global_position))
    elif event.is_action_pressed("ship"):
        _ship()
    elif event.is_action_pressed("fish"):
        _show(valley.act("fish", hero.global_position))
    elif event.is_action_pressed("craft"):
        craft_first_available()
    elif event.is_action_pressed("sleep"):
        next_day()
    elif event.is_action_pressed("save"):
        save_game()
    elif event.is_action_pressed("load"):
        load_game()
    else:
        for i in range(7):
            if event.is_action_pressed("tool_%d" % (i+1)):
                selected_tool = i
                _show("Equipped %s" % TOOLS[i])

func _interact() -> void:
    var mode: String = TOOLS[selected_tool]
    var result: String = ""
    if mode in ["till", "plant", "water", "harvest"]:
        result = farm.act(mode, hero.global_position)
    elif mode == "care":
        result = animals.act(hero.global_position)
    elif mode == "talk":
        result = village.act("talk", hero.global_position)
    else:
        result = valley.act("forage", hero.global_position)
    _show(result)

func _show(message: String) -> void:
    latest_message = message
    print("EVERBLOOM: ", message)

func current_seed() -> String:
    return seed_order[selected_seed]

func spend_energy(amount: float) -> bool:
    if energy < amount:
        return false
    energy -= amount
    return true

func grant_item(id: String, quantity: int) -> void:
    if quantity <= 0:
        return
    inventory[id] = int(inventory.get(id, 0)) + quantity

func consume_item(id: String, quantity: int) -> bool:
    if quantity <= 0 or int(inventory.get(id, 0)) < quantity:
        return false
    inventory[id] = int(inventory[id]) - quantity
    return true

func next_day() -> void:
    day += 1
    if day > 14:
        day = 1
        season_index = (season_index + 1) % SEASONS.size()
        if season_index == 0:
            year += 1
    weather = "Rain" if (day * 13 + season_index * 5) % 7 < 2 else ("Mist" if day % 11 == 0 else "Clear")
    minute_of_day = 360.0
    energy = 100.0
    farm.next_day(weather)
    animals.next_day()
    village.next_day()
    _show("%s, Day %d — %s. The valley awakens." % [SEASONS[season_index], day, weather])
    save_game(false)

func season() -> String:
    return SEASONS[season_index]

func day_epoch() -> int:
    ## Monotonic day index; prevents annual repeat of once-per-day actions.
    return (year - 1) * 56 + season_index * 14 + day

func _ship() -> void:
    if hero.global_position.distance_to(Vector3(-5, 0, -5)) > 5.0:
        _show("Visit the wooden shipping chest by the barn.")
        return
    var total: int = 0
    for crop in crop_definitions:
        var count: int = int(inventory.get(crop, 0))
        if count > 0:
            total += count * int(crop_definitions[crop].get("sell_price", 0))
            inventory[crop] = 0
    gold += total
    _show("Shipped produce for %d petals." % total)

func craft_first_available() -> void:
    for recipe in recipes:
        var ingredients: Dictionary = recipe["inputs"]
        var affordable: bool = true
        for item in ingredients:
            if int(inventory.get(item, 0)) < int(ingredients[item]):
                affordable = false
        if affordable:
            for item in ingredients:
                consume_item(item, int(ingredients[item]))
            var output: Dictionary = recipe["output"]
            for product in output:
                grant_item(product, int(output[product]))
            energy = minf(100.0, energy + float(recipe.get("energy", 0)))
            _show("Crafted %s." % str(recipe["id"]))
            return
    _show("No recipe can be crafted from your current inventory.")

func add_restoration(points: int) -> void:
    restoration = mini(100, restoration + maxi(0, points))

func save_game(with_feedback: bool = true) -> void:
    var payload: Dictionary = {
        "schema":1,"year":year,"day":day,"season":season_index,"minute":minute_of_day,
        "gold":gold,"energy":energy,"weather":weather,"restoration":restoration,
        "crops_harvested":crops_harvested,"social_contacts":social_contacts,
        "care_actions":care_actions,"inventory":inventory,
        "farm":farm.save_state(),"village":village.save_state(),
        "animals":animals.save_state(),
        "hero_position":[hero.global_position.x,hero.global_position.y,hero.global_position.z]
    }
    if not SaveService.write_payload(payload):
        _show("Save failed; previous valid data preserved if available.")
        return
    if with_feedback:
        _show("Your valley progress was saved locally.")

func load_game() -> void:
    var content: Dictionary = SaveService.read_payload()
    if content.is_empty():
        _show("No valid primary or backup save; current session preserved.")
        return
    year = maxi(1, int(content.get("year", 1)))
    day = clampi(int(content.get("day", 1)), 1, 14)
    season_index = clampi(int(content.get("season", 0)), 0, 3)
    minute_of_day = clampf(float(content.get("minute", 360.0)), 360.0, 1319.0)
    weather = str(content.get("weather", "Clear"))
    gold = maxi(0, int(content.get("gold", 0)))
    energy = clampf(float(content.get("energy", 100.0)), 0.0, 100.0)
    restoration = clampi(int(content.get("restoration", 0)), 0, 100)
    crops_harvested = maxi(0, int(content.get("crops_harvested", 0)))
    social_contacts = content.get("social_contacts", {})
    care_actions = maxi(0, int(content.get("care_actions", 0)))
    inventory = content.get("inventory", {})
    farm.load_state(content.get("farm", []))
    village.load_state(content.get("village", {}))
    animals.load_state(content.get("animals", {}))
    var pos: Array = content.get("hero_position", [])
    if pos.size() == 3:
        hero.global_position = Vector3(float(pos[0]), maxf(1.0, float(pos[1])), float(pos[2]))
    _show("Loaded saved life in the valley.")
