extends SceneTree
# Run: godot --headless --path . --script res://tests/native_farm_soil_collision_20261105.gd
# Physical registration check; no player save files touched.
const FARM = preload("res://scripts/farm.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.name = "FarmCollisionHarness"
    get_root().add_child(root)
    var farm := FARM.new()
    root.add_child(farm)
    farm.setup(null)
    if farm.beds.size() != 30:
        _fail("Expected exactly 30 existing beds")
        return
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var body := holder.get_node_or_null("SoilCollision") as StaticBody3D
        if body == null or body.collision_layer != 1:
            _fail("Missing soil collision body or world layer at bed %d" % i)
            return
        var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if shape == null or shape.disabled or not shape.shape is BoxShape3D:
            _fail("Invalid active soil collision shape at bed %d" % i)
            return
    # Wait for physics server synchronization before testing ray contact.
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var p := holder.global_position
        var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 2.0)
        ray.collision_mask = 1
        var hit := space.intersect_ray(ray)
        if hit.is_empty() or hit["collider"] != holder.get_node("SoilCollision"):
            _fail("Downward ray did not contact bed %d" % i)
            return
    print("PASS: 30 farm soil bodies, collision shapes and physics ray contacts")
    quit(0)

func _fail(reason: String) -> void:
    push_error("FAIL: " + reason)
    quit(1)
