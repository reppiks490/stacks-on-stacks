extends Node3D
## Original playable graybox assembly. This node owns exactly one local session.
const SessionState = preload("res://scripts/session_state.gd")
const SaveService = preload("res://scripts/save_service.gd")
const WorldBuilder = preload("res://scripts/world_builder.gd")
const PlayerActor = preload("res://scripts/player_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const Fragment = preload("res://scripts/resonance_fragment.gd")
const Companion = preload("res://scripts/companion_orb.gd")
const GameHUD = preload("res://scripts/hud.gd")
const PULSE_CUE = preload("res://assets/audio/resonance_pulse.wav")
const COVENANT_CUE = preload("res://assets/audio/covenant_seal.wav")

var session
var player
var hud
var world
var _pending_beacon: Node3D
var _is_restoring: bool = false
var _cue_player: AudioStreamPlayer

func _ready() -> void:
    session = SessionState.new()
    _cue_player = AudioStreamPlayer.new()
    _cue_player.volume_db = -8.0
    add_child(_cue_player)
    _make_lighting()
    world = WorldBuilder.new()
    world.name = "TheBrokenMeridian"
    add_child(world)
    world.breakable_created.connect(_on_crystal_created)
    world.beacon_created.connect(_on_beacon_created)
    world.construct(session.world_seed)

    player = PlayerActor.new()
    player.name = "UnboundWarden"
    player.position = Vector3(0, 1.15, 0)
    add_child(player)
    player.died.connect(_on_player_died)
    player.pulse_used.connect(_on_pulse_used)

    var companion := Companion.new()
    companion.name = "CinderCompanion"
    companion.follow_target = player
    companion.position = Vector3(1, 2, 1)
    add_child(companion)

    hud = GameHUD.new()
    add_child(hud)
    hud.faction_chosen.connect(_on_faction_chosen)
    for at in [Vector3(-5, 0.6, -7), Vector3(6, 0.6, 8), Vector3(13, 0.6, -11)]:
        _spawn_fragment(at)
    for i in range(7):
        var enemy := EnemyActor.new()
        enemy.name = "Glassbound_%02d" % i
        enemy.position = Vector3(-18.0 + i * 6.0, 0.9, 15.0 + float(i % 2) * 4.0)
        enemy.player = player
        enemy.hp += float(i % 3) * 6.0
        add_child(enemy)
        enemy.defeated.connect(_on_enemy_defeated)
    hud.notify("The Meridian is waking. Recover fragments and choose a covenant.", 6.0)

func _make_lighting() -> void:
    var environment := WorldEnvironment.new()
    var sky := Environment.new()
    sky.background_mode = Environment.BG_COLOR
    sky.background_color = Color(0.04, 0.05, 0.10)
    sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    sky.ambient_light_color = Color(0.40, 0.48, 0.68)
    sky.ambient_light_energy = 0.65
    environment.environment = sky
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-54, 31, -16)
    sun.light_energy = 1.05
    sun.light_color = Color(0.77, 0.80, 1.0)
    add_child(sun)

func _process(_delta: float) -> void:
    if not is_instance_valid(player) or not is_instance_valid(hud):
        return
    hud.update_stats(player.hp, player.stamina, session)

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if hud.choice_is_open():
        return
    match event.keycode:
        KEY_E:
            _interact_near_player()
        KEY_F5:
            session.health = player.hp
            if SaveService.write_save(session):
                hud.notify("Local journey saved")
            else:
                hud.notify("Save failed (local device)")
        KEY_F9:
            if SaveService.read_save(session):
                player.restore_from_save(session.health)
                _apply_faction_effects()
                hud.notify("Local journey restored; world objects reset")
            else:
                hud.notify("No compatible local save found")

func _interact_near_player() -> void:
    var closest: Node3D
    var best := 3.4
    for candidate in get_tree().get_nodes_in_group("interactables"):
        if not is_instance_valid(candidate) or not (candidate is Node3D):
            continue
        var candidate_3d: Node3D = candidate as Node3D
        var distance: float = player.global_position.distance_to(candidate_3d.global_position)
        if distance < best:
            closest = candidate
            best = distance
    if is_instance_valid(closest) and closest.has_method("interact"):
        closest.call("interact")
    else:
        hud.notify("No resonant device nearby")

func _on_crystal_created(crystal: Node3D) -> void:
    crystal.connect("shattered", Callable(self, "_on_crystal_shattered"))

func _on_crystal_shattered(at: Vector3) -> void:
    _spawn_fragment(at + Vector3(-0.45, 0.4, 0.1))
    _spawn_fragment(at + Vector3(0.5, 0.4, -0.2))
    hud.notify("Resonance fractured — fragments released")

func _spawn_fragment(at: Vector3) -> void:
    var fragment := Fragment.new()
    fragment.position = at
    add_child(fragment)
    fragment.collected.connect(_on_fragment_collected)

func _on_fragment_collected() -> void:
    session.collect_fragment(1)
    hud.notify("Resonance fragment recovered (%d)" % session.fragments, 1.8)

func _on_enemy_defeated(enemy: Node3D) -> void:
    var at := enemy.global_position
    session.register_enemy_defeat()
    _spawn_fragment(at + Vector3(0, 0.45, 0))
    hud.notify("Glassbound defeated (%d)" % session.total_kills, 2.0)

func _on_beacon_created(beacon: Node3D) -> void:
    beacon.connect("interaction_requested", Callable(self, "_on_beacon_requested"))

func _on_beacon_requested(beacon: Node3D) -> void:
    if session.chosen_faction != "":
        hud.notify("Your covenant is already sealed")
        return
    _pending_beacon = beacon
    hud.open_choice()

func _on_faction_chosen(id: String) -> void:
    if not is_instance_valid(_pending_beacon):
        hud.notify("No valid beacon was selected")
        return
    if player.global_position.distance_to(_pending_beacon.global_position) > 3.8:
        hud.notify("Too far from the beacon")
        return
    if session.choose_faction(id):
        _apply_faction_effects()
        _play_source_cue(COVENANT_CUE)
        hud.notify("Covenant sealed: " + ("Ember Cartographers" if id == "FAC-01" else "Hollow Accord"), 6.0)
    _pending_beacon = null

func _apply_faction_effects() -> void:
    # Proof of consequence: Hollow amplifies pulse, Ember retains ordinary pulse.
    player.pulse_multiplier = 1.22 if session.chosen_faction == "FAC-02" else 1.0

func _on_pulse_used() -> void:
    _play_source_cue(PULSE_CUE)
    hud.notify("RESONANCE PULSE — environmental and enemy impact", 1.8)

func _on_player_died() -> void:
    if _is_restoring:
        return
    _is_restoring = true
    hud.notify("Unbound fallen. Recovering at the Meridian anchor...", 3.0)
    await get_tree().create_timer(2.2).timeout
    if is_instance_valid(player):
        player.restore_from_save(120.0)
    _is_restoring = false

func _play_source_cue(cue: AudioStream) -> void:
    if not is_instance_valid(_cue_player):
        return
    _cue_player.stop()
    _cue_player.stream = cue
    _cue_player.play()
