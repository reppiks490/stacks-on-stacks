extends SceneTree
## Farming-owned negative traversal oracle. This is an isolated farm fixture,
## not proof that the ordinary assembled player/world scene is solid.
## Run: godot --headless --path . --script scripts/farm_soil_traversal_acceptance.gd
const FarmScript = preload("res://scripts/farm.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var farm: Node3D = FarmScript.new()
    root.add_child(farm)
    farm.setup(null)
    _check(farm.beds.size() == 30, "expected 30 beds")
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    var offsets := [Vector2.ZERO, Vector2(-0.55, -0.55), Vector2(0.55, -0.55),
        Vector2(-0.55, 0.55), Vector2(0.55, 0.55)]
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var body: StaticBody3D = holder.get_node_or_null("SoilCollision")
        _check(body != null, "bed %d missing soil collider" % i)
        if body == null:
            continue
        for offset in offsets:
            var p := holder.global_position + Vector3(offset.x, 0.0, offset.y)
            var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0,
                p + Vector3.DOWN * 2.0)
            query.collision_mask = 1
            var hit := space.intersect_ray(query)
            _check(not hit.is_empty(), "bed %d missing ground at %s" % [i, offset])
            if hit.is_empty():
                continue
            _check(hit["collider"] == body,
                "bed %d contact resolves to wrong body at %s" % [i, offset])
            _check(absf(hit["position"].y - (holder.global_position.y + 0.1)) < 0.15,
                "bed %d collision height diverges from mesh at %s" % [i, offset])
    if failures.is_empty():
        print("FARM_SOIL_TRAVERSAL_ACCEPTANCE PASS: 150 isolated bed contacts")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_SOIL_TRAVERSAL_ACCEPTANCE FAIL: %d checks" % failures.size())
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
