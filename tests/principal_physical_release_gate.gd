extends SceneTree
## Principal release gate: exercise the ordinary startup scene, not a sample.
## Run: godot --headless --path . --script res://tests/principal_physical_release_gate.gd
## A failing exit code is intentional while known physical defects remain.
const START_SCENE := "res://scenes/main.tscn"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load(START_SCENE)
    if packed == null:
        _fail("ordinary main scene failed to load")
        _finish()
        return
    var root: Node = packed.instantiate()
    get_root().add_child(root)
    for frame in range(120):
        await physics_frame
    var hero: Node = root.get_node_or_null("Farmer")
    if hero == null or not (hero is CharacterBody3D):
        _fail("ordinary main scene lacks CharacterBody3D Farmer")
    else:
        var player: CharacterBody3D = hero as CharacterBody3D
        if player.get_node_or_null("CollisionShape3D") == null:
            _fail("player collider absent or renamed; inspect actual player scene")
    var space := root.get_world_3d().direct_space_state if root is Node3D else null
    if space == null:
        _fail("physics world unavailable")
        _finish()
        return
    # Horizontal probes through the center of known farmhouse and town shells.
    # A decorative mesh alone cannot satisfy these physics queries.
    _expect_hit(space, Vector3(-28, 2, -14), Vector3(-18, 2, -14), "farmhouse wall")
    _expect_hit(space, Vector3(18, 2, 10), Vector3(26, 2, 10), "town wall")
    # Ground at the original homestead and just outside its historical edge.
    # The latter must be supported by streamed terrain or a documented safe bound.
    _expect_hit(space, Vector3(0, 8, 0), Vector3(0, -8, 0), "homestead floor")
    _expect_hit(space, Vector3(75, 8, 0), Vector3(75, -8, 0), "terrain beyond legacy 145m floor")
    _finish()

func _expect_hit(space: PhysicsDirectSpaceState3D, origin: Vector3, end: Vector3, label: String) -> void:
    var query := PhysicsRayQueryParameters3D.create(origin, end)
    query.collision_mask = 0xFFFFFFFF
    var result := space.intersect_ray(query)
    if result.is_empty():
        _fail("missing tangible collision: " + label)

func _fail(message: String) -> void:
    failures.append(message)
    printerr("EVERBLOOM RELEASE BLOCKER: " + message)

func _finish() -> void:
    if failures.is_empty():
        print("EVERBLOOM physical release probes PASS; authored-art and traversal gates remain separate.")
        quit(0)
    else:
        printerr("EVERBLOOM physical release probes FAIL: %d blockers" % failures.size())
        quit(1)
