extends SceneTree
# Native, renderer-independent regression for the continental terrain mesh.
# Run: godot --headless --path . --script res://tests/native_emergence_terrain_contact_20261105.gd
const WorldScript = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var world := Node3D.new()
    world.set_script(WorldScript)
    root.add_child(world)
    var mesh: ArrayMesh = world._terrain_mesh(Vector3(75, 0, 75))
    if mesh == null or mesh.get_surface_count() == 0:
        failures.append("terrain mesh absent")
    else:
        var body := StaticBody3D.new()
        body.collision_layer = 1
        root.add_child(body)
        var shape := CollisionShape3D.new()
        shape.shape = mesh.create_trimesh_shape()
        shape.position = Vector3(75, 0, 75)
        body.add_child(shape)
        await physics_frame
        await physics_frame
        for x in [2.0, 40.0, 75.0, 110.0, 148.0]:
            for z in [2.0, 40.0, 75.0, 110.0, 148.0]:
                var from := Vector3(x, 100, z)
                var to := Vector3(x, -100, z)
                var query := PhysicsRayQueryParameters3D.create(from, to, 1)
                var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
                if hit.is_empty():
                    failures.append("missing floor at %.1f,%.1f" % [x,z])
                elif absf(hit.position.y - world._terrain_height(x,z)) > 1.0:
                    failures.append("floor height mismatch at %.1f,%.1f" % [x,z])
    if failures.is_empty():
        print("EMERGENCE TERRAIN CONTACT PASS: 25 physics raycasts")
    else:
        for failure in failures:
            push_error(failure)
        print("EMERGENCE TERRAIN CONTACT FAIL: %d failures" % failures.size())
    quit(0 if failures.is_empty() else 1)
