extends SceneTree
## Farming-owned native physics acceptance. Run from the Godot project root:
## godot --headless --path . --script scripts/farm_contact_acceptance.gd
## This tests the isolated farm branch, NOT the assembled ordinary game.
const FarmScript = preload("res://scripts/farm.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.name = "FarmContactAcceptance"
    get_root().add_child(root)
    var farm: Node3D = FarmScript.new()
    root.add_child(farm)
    farm.setup(null)
    _check(farm.beds.size() == 30, "exactly 30 farm beds")
    var bodies: Array[StaticBody3D] = []
    for i in range(farm.beds.size()):
        var plot: Dictionary = farm.beds[i]
        var holder: Node3D = plot["holder"]
        var body: StaticBody3D = holder.get_node_or_null("SoilCollision")
        _check(body != null, "bed %d has soil body" % i)
        if body == null:
            continue
        bodies.append(body)
        _check(body.collision_layer & 1 != 0, "bed %d is on world collision layer" % i)
        var collider: CollisionShape3D = body.get_node_or_null("FurrowSurface")
        _check(collider != null and collider.shape != null and not collider.disabled,
            "bed %d has enabled collision geometry" % i)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var p := holder.global_position
        var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0,
            p + Vector3.DOWN * 3.0)
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        _check(not hit.is_empty(), "bed %d downward ray hits solid soil" % i)
        if not hit.is_empty():
            _check(bodies.has(hit["collider"]), "bed %d ray hits a farm soil body" % i)
            _check(absf(hit["position"].y - p.y) < 0.5,
                "bed %d collision surface matches visible bed elevation" % i)
    if failures.is_empty():
        print("FARM_CONTACT_ACCEPTANCE PASS: 30 beds, physics ray hits and surface alignment")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_CONTACT_ACCEPTANCE FAIL: %d assertions" % failures.size())
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
