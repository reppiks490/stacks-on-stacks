extends SceneTree
## Native physics regression for contiguous streamed terrain, independent of save data.
## Run: godot --headless --path . --script res://tests/native_emergence_seam_raycast_test.gd
const World = preload("res://scripts/continental_world.gd")
var failures: Array[String] = []
var assertions := 0

func verify(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures.append(message)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var world := World.new()
    root.add_child(world)
    var bodies: Array[StaticBody3D] = []
    # Four physically adjacent chunks with their exact runtime mesh and trimesh.
    for x in [-75.0, 75.0]:
        for z in [-75.0, 75.0]:
            var origin := Vector3(x, 0.0, z)
            var mesh: ArrayMesh = world._terrain_mesh(origin)
            var body := StaticBody3D.new()
            body.position = origin
            body.collision_layer = 1
            world.add_child(body)
            var shape := CollisionShape3D.new()
            shape.shape = mesh.create_trimesh_shape()
            body.add_child(shape)
            bodies.append(body)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    # Check center four-way join, x/z edges, and either side of each join.
    for x in [-20.0, -0.05, 0.0, 0.05, 20.0]:
        for z in [-20.0, -0.05, 0.0, 0.05, 20.0]:
            var start := Vector3(x, 80.0, z)
            var finish := Vector3(x, -80.0, z)
            var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
            var hit: Dictionary = space.intersect_ray(query)
            verify(not hit.is_empty(), "missing terrain collider at (%f,%f)" % [x,z])
            if not hit.is_empty():
                verify(absf(float(hit.position.y) - world._terrain_height(x,z)) < 0.3,
                    "visual/physics terrain mismatch at (%f,%f)" % [x,z])
    for body in bodies:
        verify(body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D,
            "streamed terrain body missing collision shape")
    print("EVERBLOOM_SEAM_RAYCAST assertions=%d failures=%d" % [assertions,failures.size()])
    for failure in failures:
        push_error(failure)
    quit(1 if not failures.is_empty() else 0)
