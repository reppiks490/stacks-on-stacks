extends SceneTree
## Physical floor regression for the four outer corners of the existing 32x32 continent.
## Run: godot --headless --path . --script res://tests/native_emergence_outer_boundary_floor_20261105.gd
## This verifies the terrain mesh/collision contract, NOT the live hero boundary clamp.
const World = preload("res://scripts/continental_world.gd")
const HALF := 2400.0
const SIDE := 150.0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := World.new()
    root.add_child(world)
    var corners := [Vector2i(0,0), Vector2i(0,31), Vector2i(31,0), Vector2i(31,31)]
    for key in corners:
        var origin := Vector3(-HALF + (float(key.x) + 0.5) * SIDE, 0.0,
            -HALF + (float(key.y) + 0.5) * SIDE)
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        _check(mesh.get_surface_count() > 0, "missing perimeter terrain mesh %s" % key)
        var body := StaticBody3D.new()
        body.position = origin
        body.collision_layer = 1
        world.add_child(body)
        var shape := CollisionShape3D.new()
        shape.shape = mesh.create_trimesh_shape()
        body.add_child(shape)
        _check(shape.shape != null, "missing perimeter collision %s" % key)
        var center := world._cell_of(Vector2(origin.x,origin.z))
        _check(center == key, "incorrect outer cell mapping %s" % key)
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for key in corners:
        var origin := Vector3(-HALF + (float(key.x) + 0.5) * SIDE, 0.0,
            -HALF + (float(key.y) + 0.5) * SIDE)
        for dx in [-73.0,0.0,73.0]:
            for dz in [-73.0,0.0,73.0]:
                var x: float = origin.x + dx
                var z: float = origin.z + dz
                var expected: float = world._terrain_height(x,z)
                var ray := PhysicsRayQueryParameters3D.create(
                    Vector3(x,expected+50.0,z),Vector3(x,expected-50.0,z),1)
                var hit: Dictionary = space.intersect_ray(ray)
                _check(not hit.is_empty(), "void floor at %s local %s,%s" % [key,dx,dz])
                if not hit.is_empty():
                    _check(absf(float(hit["position"].y)-expected) < 0.45,
                        "perimeter collision height diverges at %s %s,%s" % [key,dx,dz])
    _check(world._cell_of(Vector2(-HALF,-HALF)) == Vector2i.ZERO,
        "negative corner mapping failed")
    _check(world._cell_of(Vector2(HALF,HALF)) == Vector2i(31,31),
        "positive corner mapping failed")
    if failures.is_empty():
        print("PASS: 4 perimeter chunks, 36 physical floor raycasts, bounded cell indices")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FAIL: %d perimeter terrain assertions" % failures.size())
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
