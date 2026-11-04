extends SceneTree
## Native physics regression for all playable farm plots, not just the first.
## Run: godot --headless --path . --script res://tests/native_farm_all_beds_grounding_test.gd
const FARM = preload("res://scripts/farm.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, description: String) -> void:
    if not value:
        failures += 1
        push_error("FAIL " + description)

func _run() -> void:
    var host := FarmHost.new()
    root.add_child(host)
    var farm := FARM.new()
    root.add_child(farm)
    farm.setup(host)
    _assert(farm.beds.size() == 30, "preserve 30 plots")
    await physics_frame
    await physics_frame
    var space := farm.get_world_3d().direct_space_state
    for i in range(farm.beds.size()):
        var holder: Node3D = farm.beds[i]["holder"]
        var body := holder.get_node_or_null("SoilCollision") as StaticBody3D
        _assert(body != null, "bed %d has a physical body" % i)
        if body == null:
            continue
        _assert(body.collision_layer & 1 != 0, "bed %d world layer" % i)
        var shape := body.get_node_or_null("FurrowSurface") as CollisionShape3D
        _assert(shape != null and shape.shape != null and not shape.disabled, "bed %d enabled collision shape" % i)
        var center := holder.global_position
        var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2.0, center + Vector3.DOWN * 2.0)
        ray.collision_mask = 1
        var hit := space.intersect_ray(ray)
        _assert(not hit.is_empty() and hit.get("collider") == body, "bed %d downward ray hits its own furrow" % i)
    var original: Array = farm.save_state()
    farm.load_state(original)
    _assert(farm.save_state() == original, "30-plot state roundtrip unchanged")
    print("FARM ALL-BED GROUNDING: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    farm.queue_free()
    host.queue_free()
    quit(0 if failures == 0 else 1)

class FarmHost:
    extends Node
    var crop_definitions := {}
    func day_epoch() -> int:
        return 0
