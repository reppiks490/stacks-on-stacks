extends SceneTree
## Native farm geometry/physics regression; run with Godot --headless --path . --script res://tests/native_farm_furrow_collision_test.gd
const FARM_SCRIPT = preload("res://scripts/farm.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + label)
    else:
        print("PASS: " + label)

func _run() -> void:
    var farm := FARM_SCRIPT.new()
    root.add_child(farm)
    var host := FarmHost.new()
    root.add_child(host)
    farm.setup(host)
    _check(farm.beds.size() == 30, "30 existing planting beds retained")
    var first: Dictionary = farm.beds[0]
    var body := first["holder"].get_node_or_null("SoilCollision") as StaticBody3D
    _check(body != null, "soil static body exists")
    if body != null:
        _check(body.collision_layer == 1, "soil belongs to world collision layer")
        _check(body.get_node("FurrowSurface") is CollisionShape3D, "soil has physics shape")
    await physics_frame
    await physics_frame
    var space := farm.get_world_3d().direct_space_state
    var center: Vector3 = first["holder"].global_position
    var query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 3, 0), center + Vector3(0, -3, 0))
    query.collision_mask = 1
    var hit: Dictionary = space.intersect_ray(query)
    _check(not hit.is_empty(), "downward traversal probe contacts physical ground")
    if not hit.is_empty():
        _check(hit.get("collider") == body, "probe hits matching soil body")
    var before: Array = farm.save_state()
    farm.load_state(before)
    _check(farm.save_state() == before, "farm save roundtrip remains stable")
    farm.queue_free()
    host.queue_free()
    print("FARM FURROW PHYSICS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    quit(0 if failures == 0 else 1)

class FarmHost:
    extends Node
    var crop_definitions := {}
    func day_epoch() -> int:
        return 0
