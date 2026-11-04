extends SceneTree
## Native, fail-closed acceptance of the ordinary Everbloom launch.
## Run: godot --headless --path . --script res://tests/principal_live_quality_gate.gd
## Does not write user saves, mutate player state or require external assets.
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _require(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)
        push_error("QUALITY BLOCKER: " + reason)

func _run() -> void:
    var main_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
    _require(main_path == "res://scenes/main.tscn", "Unexpected ordinary launch scene: " + main_path)
    var packed: PackedScene = load(main_path) as PackedScene
    _require(packed != null, "Main scene does not import")
    if packed == null:
        quit(1)
        return
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    await physics_frame
    var hero: Node = game.get_node_or_null("Farmer")
    _require(hero is CharacterBody3D, "Real launch lacks CharacterBody3D Farmer")
    var valley: Node = game.get_node_or_null("TheLivingValley")
    _require(valley != null, "Real launch lacks valley")
    if hero != null:
        var skeletons: Array[Node] = hero.find_children("*", "Skeleton3D", true, false)
        _require(not skeletons.is_empty(), "Farmer has no integrated rigged Skeleton3D")
        var animators: Array[Node] = hero.find_children("*", "AnimationPlayer", true, false)
        _require(not animators.is_empty(), "Farmer has no integrated AnimationPlayer")
    if valley != null:
        var colliders: Array[Node] = valley.find_children("*", "CollisionShape3D", true, false)
        _require(colliders.size() > 1, "Only terrain or no collisions found; solid buildings/props unproven")
    for i in range(120):
        await physics_frame
    _require(is_instance_valid(game), "Main game freed during 120-frame smoke")
    print("PRINCIPAL LIVE QUALITY GATE: " + ("PASS" if failures.is_empty() else "BLOCKED: " + str(failures.size()) + " failures"))
    quit(0 if failures.is_empty() else 1)
