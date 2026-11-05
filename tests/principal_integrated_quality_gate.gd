extends SceneTree
## Fail-closed inspection of the ordinary playable game. No render or art claims.
## godot --headless --path . --script res://tests/principal_integrated_quality_gate.gd
const START := "res://scenes/main.tscn"
const WORLD_SIZE := 4800.0
const CHUNK_SIZE := 150.0
const GRID_SIZE := 32
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load(START)
    if packed == null:
        _fail("ordinary startup scene cannot load")
        _done()
        return
    var game: Node = packed.instantiate()
    get_root().add_child(game)
    for i in range(120):
        await physics_frame
    var hero := game.get_node_or_null("Farmer") as CharacterBody3D
    if hero == null:
        _fail("ordinary startup does not instantiate a CharacterBody3D hero")
    else:
        var shape := hero.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if shape == null or shape.disabled or shape.shape == null:
            _fail("hero lacks enabled physical collision")
        if not _has_authored_character(hero):
            _fail("hero has no integrated skinned Skeleton3D / MeshInstance3D")
        if not _has_animation(hero):
            _fail("hero has no integrated AnimationPlayer or AnimationTree")
    var valley := game.get_node_or_null("TheLivingValley") as Node3D
    if valley == null:
        _fail("ordinary startup lacks world node")
    else:
        var space := valley.get_world_3d().direct_space_state
        _ray(space, Vector3(-28,2,-14), Vector3(-18,2,-14), "farmhouse wall")
        _ray(space, Vector3(18,2,10), Vector3(26,2,10), "town wall")
        _ray(space, Vector3(0,8,0), Vector3(0,-8,0), "homestead floor")
        _ray(space, Vector3(75,8,0), Vector3(75,-8,0), "ground beyond legacy edge")
        _ray(space, Vector3(150,8,0), Vector3(150,-8,0), "adjacent streamed chunk ground")
        _ray(space, Vector3(225,8,0), Vector3(225,-8,0), "second streamed chunk ground")
    if not _world_contract_present():
        _fail("4800m / 32x32 / 150m streamed world contract not found in runtime source")
    _done()

func _has_authored_character(node: Node) -> bool:
    if node is Skeleton3D:
        for child in node.find_children("*", "MeshInstance3D", true, false):
            if child is MeshInstance3D and child.skin != null:
                return true
    for child in node.get_children():
        if _has_authored_character(child):
            return true
    return false

func _has_animation(node: Node) -> bool:
    if node is AnimationPlayer or node is AnimationTree:
        return true
    for child in node.get_children():
        if _has_animation(child):
            return true
    return false

func _world_contract_present() -> bool:
    # Static source guard is intentionally not proof of streaming behavior.
    # It prevents a small legacy-only world from being called continental.
    var path := "res://scripts/valley.gd"
    if not FileAccess.file_exists(path):
        return false
    var source := FileAccess.get_file_as_string(path)
    var has_grid := source.contains(str(GRID_SIZE))
    var has_chunk := source.contains(str(int(CHUNK_SIZE)))
    var has_extent := source.contains(str(int(WORLD_SIZE)))
    return has_grid and has_chunk and has_extent

func _ray(space: PhysicsDirectSpaceState3D, origin: Vector3, destination: Vector3, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(origin, destination)
    query.collision_mask = 0xFFFFFFFF
    if space.intersect_ray(query).is_empty():
        _fail("no collision at " + label)

func _fail(message: String) -> void:
    failures.append(message)
    printerr("EVERBLOOM BLOCKER: " + message)

func _done() -> void:
    if failures.is_empty():
        print("PASS: basic integrated quality probes; visual/FPS/manual traversal still require separate evidence")
        quit(0)
    else:
        printerr("FAIL: %d integrated quality blockers" % failures.size())
        quit(1)
