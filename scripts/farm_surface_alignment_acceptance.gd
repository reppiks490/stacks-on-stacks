extends SceneTree
## Native farm mesh-to-collider alignment acceptance.
## Isolated physics fixture: does NOT establish assembled-player or world collision.
## Run: godot --headless --path . --script scripts/farm_surface_alignment_acceptance.gd
const FarmScript = preload("res://scripts/farm.gd")
const SAMPLES := [
    Vector2(0.0, 0.0), Vector2(-0.50, -0.50),
    Vector2(-0.50, 0.50), Vector2(0.50, -0.50),
    Vector2(0.50, 0.50)
]
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var farm: Node3D = FarmScript.new()
    root.add_child(farm)
    farm.setup(null)
    if farm.beds.size() != 30:
        push_error("Expected 30 planting beds, found %d" % farm.beds.size())
        quit(1)
        return
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    var probes := 0
    for i in range(farm.beds.size()):
        var plot: Dictionary = farm.beds[i]
        var holder: Node3D = plot["holder"]
        var body: StaticBody3D = holder.get_node_or_null("SoilCollision")
        var visual: MeshInstance3D = plot["bed"]
        if body == null or visual == null or visual.mesh == null:
            failures.append("Bed %d missing body or visual mesh" % i)
            continue
        if body.collision_layer & 1 == 0:
            failures.append("Bed %d does not expose terrain layer 1" % i)
        for sample in SAMPLES:
            var local := Vector3(sample.x, 0.0, sample.y)
            var expected := holder.to_global(
                local + Vector3.UP * (visual.position.y + farm._furrow_height(sample.x, sample.y)))
            var ray := PhysicsRayQueryParameters3D.create(
                expected + Vector3.UP * 1.0, expected - Vector3.UP * 1.0)
            ray.collision_mask = 1
            var hit := space.intersect_ray(ray)
            if hit.is_empty() or hit.get("collider") != body:
                failures.append("Bed %d sample %s misses its own soil body" % [i, sample])
                continue
            if absf(hit["position"].y - expected.y) > 0.025:
                failures.append("Bed %d sample %s visual/physics height differs by %.4f" %
                    [i, sample, absf(hit["position"].y - expected.y)])
            if hit["normal"].y < 0.70:
                failures.append("Bed %d sample %s is not walkably upward-facing" % [i, sample])
            probes += 1
    if probes != 150:
        failures.append("Only %d/150 surface samples hit expected colliders" % probes)
    if failures.is_empty():
        print("FARM_SURFACE_ALIGNMENT PASS: 150 mesh/physics height and normal probes")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("FARM_SURFACE_ALIGNMENT FAIL: %d failures" % failures.size())
        quit(1)
