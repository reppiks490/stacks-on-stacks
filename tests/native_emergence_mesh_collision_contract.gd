extends SceneTree
## Independent physics/geometry regression for the 150m continental terrain.
## Run: godot --headless --path . --script res://tests/native_emergence_mesh_collision_contract.gd
const WORLD = preload("res://scripts/continental_world.gd")
const SIDE := 150.0
const HALF := 2400.0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL " + label)
    else:
        print("PASS " + label)

func _run() -> void:
    var world := WORLD.new()
    root.add_child(world)
    # Deliberately bypass setup: only test original height, mesh and physics contracts.
    var keys := [Vector2i(15,15), Vector2i(16,15), Vector2i(15,16),
        Vector2i(0,0), Vector2i(31,31)]
    var bodies: Array[StaticBody3D] = []
    for key in keys:
        var center := Vector3(-HALF + (key.x + 0.5)*SIDE, 0,
            -HALF + (key.y + 0.5)*SIDE)
        var mesh: ArrayMesh = world._terrain_mesh(center)
        _check(mesh != null and mesh.get_surface_count() > 0, "mesh %s" % key)
        if mesh == null or mesh.get_surface_count() == 0:
            continue
        var shape := mesh.create_trimesh_shape()
        _check(shape != null, "physics shape %s" % key)
        var body := StaticBody3D.new()
        body.position = center
        body.collision_layer = 1
        var collision := CollisionShape3D.new()
        collision.shape = shape
        body.add_child(collision)
        root.add_child(body)
        bodies.append(body)
        var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        var low_x := INF
        var high_x := -INF
        var low_z := INF
        var high_z := -INF
        for v in vertices:
            low_x = minf(low_x,v.x)
            high_x = maxf(high_x,v.x)
            low_z = minf(low_z,v.z)
            high_z = maxf(high_z,v.z)
        _check(absf(low_x + SIDE/2.0) < 0.001 and absf(high_x - SIDE/2.0) < 0.001
            and absf(low_z + SIDE/2.0) < 0.001 and absf(high_z - SIDE/2.0) < 0.001,
            "exact mesh footprint %s" % key)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    for point in [Vector2(-75.0,-75.0),Vector2(-0.05,-75.0),
        Vector2(0.05,-75.0),Vector2(-75.0,-0.05),Vector2(-75.0,0.05),
        Vector2(-2399.0,-2399.0),Vector2(2399.0,2399.0)]:
        var expected: float = world._terrain_height(point.x,point.y)
        var ray := PhysicsRayQueryParameters3D.create(
            Vector3(point.x,expected+100.0,point.y),
            Vector3(point.x,expected-100.0,point.y),1)
        var hit: Dictionary = space.intersect_ray(ray)
        _check(not hit.is_empty(), "terrain ray floor %s" % point)
        if not hit.is_empty():
            _check(absf(float(hit.position.y)-expected) < 0.65,
                "terrain floor matches heightfield %s" % point)
    _check(world._cell_of(Vector2(-2400,-2400)) == Vector2i(0,0),
        "minimum world cell")
    _check(world._cell_of(Vector2(2399.99,2399.99)) == Vector2i(31,31),
        "maximum world cell")
    print("EMERGENCE_MESH_COLLISION failures=%d" % failures)
    quit(1 if failures > 0 else 0)
