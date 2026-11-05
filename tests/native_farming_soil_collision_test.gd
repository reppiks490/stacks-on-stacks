extends SceneTree
# Farming-only native geometry/collision acceptance; run with Godot --headless.
# Does not assert full-game visual quality or FPS.
const FarmScript = preload("res://scripts/farm.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var farm := Node3D.new()
    farm.set_script(FarmScript)
    root.add_child(farm)
    farm.setup(null)
    await process_frame
    var failures: Array[String] = []
    if farm.beds.size() != 30:
        failures.append("Expected 30 farm beds")
    var space := root.get_world_3d().direct_space_state
    for i in range(farm.beds.size()):
        var plot: Dictionary = farm.beds[i]
        var holder: Node3D = plot["holder"]
        var body := holder.get_node_or_null("SoilCollision") as StaticBody3D
        if body == null:
            failures.append("Bed %d missing StaticBody3D" % i)
            continue
        var shape := body.get_node_or_null("FurrowSurface") as CollisionShape3D
        if shape == null or shape.shape == null:
            failures.append("Bed %d missing collision shape" % i)
            continue
        if body.collision_layer & 1 == 0:
            failures.append("Bed %d not on world collision layer" % i)
        var mesh := plot["bed"] as MeshInstance3D
        if mesh.mesh == null:
            failures.append("Bed %d missing render mesh" % i)
        elif not mesh.mesh is ArrayMesh:
            failures.append("Bed %d uses non-authored primitive mesh" % i)
    await physics_frame
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var origin := holder.global_position + Vector3(0, 3, 0)
        var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 8)
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            failures.append("Bed %d has no downward physics hit" % i)
        elif not hit["collider"] is StaticBody3D:
            failures.append("Bed %d hit unexpected collider" % i)
    if failures.is_empty():
        print("PASS farm: 30 mesh/shape/layer checks and 30 physics raycasts")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
