extends SceneTree
## Native regression for the REAL continental terrain generator (not a mock).
## Run: godot --headless --path . --script res://tests/native_emergence_physical_seam_oracle_20261105.gd
const World = preload("res://scripts/continental_world.gd")
const SIDE := 150.0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := World.new()
    root.add_child(world)
    var keys := [Vector2i(16,16), Vector2i(17,16), Vector2i(16,17)]
    var origins: Array[Vector3] = []
    for key in keys:
        var origin := Vector3(-2400.0 + (float(key.x) + 0.5) * SIDE, 0.0,
            -2400.0 + (float(key.y) + 0.5) * SIDE)
        origins.append(origin)
        var mesh: ArrayMesh = world._terrain_mesh(origin)
        _assert(mesh.get_surface_count() > 0, "terrain mesh missing for %s" % key)
        var body := StaticBody3D.new()
        body.name = "PhysicalTerrain_%s" % key
        body.position = origin
        body.collision_layer = 1
        world.add_child(body)
        var collision := CollisionShape3D.new()
        collision.shape = mesh.create_trimesh_shape()
        body.add_child(collision)
        _assert(collision.shape != null, "trimesh collision missing for %s" % key)
    # Verify exact shared-edge world heights, including both corner endpoints.
    for n in range(25):
        var offset := -75.0 + float(n) * (SIDE / 24.0)
        var x := origins[0].x + 75.0
        var z := origins[0].z + offset
        var a: float = world._terrain_height(x,z)
        var b: float = world._terrain_height(origins[1].x - 75.0,z)
        _assert(absf(a-b) < 0.00001, "east-west seam height mismatch at %d" % n)
        var zx := origins[0].x + offset
        var zz := origins[0].z + 75.0
        var c: float = world._terrain_height(zx,zz)
        var d: float = world._terrain_height(zx,origins[2].z - 75.0)
        _assert(absf(c-d) < 0.00001, "north-south seam height mismatch at %d" % n)
    await physics_frame
    await physics_frame
    var space := world.get_world_3d().direct_space_state
    for i in range(1,24):
        var offset := -75.0 + float(i) * (SIDE / 24.0)
        for dx in [-0.10,0.10]:
            var px := origins[0].x + 75.0 + dx
            var pz := origins[0].z + offset
            _floor_hit(space,world,Vector3(px,0,pz),"east-west seam %d %s" % [i,dx])
            var qx := origins[0].x + offset
            var qz := origins[0].z + 75.0 + dx
            _floor_hit(space,world,Vector3(qx,0,qz),"north-south seam %d %s" % [i,dx])
    if failures.is_empty():
        print("PASS: native terrain shared-edge heights, trimesh floors and bilateral seam raycasts")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FAIL: %d terrain physical seam assertions" % failures.size())
        quit(1)

func _floor_hit(space: PhysicsDirectSpaceState3D,world: Node3D,point: Vector3,label: String) -> void:
    var expected: float = world._terrain_height(point.x,point.z)
    var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 60.0,
        point + Vector3.DOWN * 80.0,1)
    var hit: Dictionary = space.intersect_ray(query)
    _assert(not hit.is_empty(), "no physical floor at " + label)
    if not hit.is_empty():
        _assert(absf(float(hit["position"].y)-expected) < 0.35,
            "visual/physics floor mismatch at " + label)

func _assert(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
