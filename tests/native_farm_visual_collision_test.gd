extends SceneTree
## Native regression for Farming's isolated visual/physics branch.
## Run: godot --headless --path . --script res://tests/native_farm_visual_collision_test.gd
## This checks instantiated nodes and visual-state flags, NOT actual wall traversal or screenshot quality.

class FarmHost:
    extends Node
    var crop_definitions := {"turnip": {"days": 10, "color": "#ca6f79", "seasons": ["Spring"], "water_days": 5, "yield": 2}}
    func day_epoch() -> int:
        return 1

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host := FarmHost.new()
    root.add_child(host)
    var script := load("res://scripts/farm.gd")
    check(script != null, "farm.gd failed to load")
    if script == null:
        quit(1)
        return
    var farm: Node3D = script.new()
    root.add_child(farm)
    farm.setup(host)
    check(farm.beds.size() == 30, "30 planting beds must remain")
    var shape_count := 0
    for plot in farm.beds:
        var body := plot["holder"].get_node_or_null("SoilCollision") as StaticBody3D
        if body != null and body.collision_layer == 1:
            var collider := body.get_node_or_null("FurrowSurface") as CollisionShape3D
            if collider != null and collider.shape != null and not collider.disabled:
                shape_count += 1
    check(shape_count == 30, "Each farm bed needs an enabled solid soil collision shape")
    var first: Dictionary = farm.beds[0]
    first["crop"] = "turnip"
    first["age"] = 0
    farm._paint(first)
    check(not first["fruit"].visible, "Fruit must not appear on sowing day")
    check(not first["foliage"].visible, "Full leaves must not appear before germination")
    first["age"] = 5
    farm._paint(first)
    check(first["foliage"].visible, "Midgrowth foliage should be visible")
    check(not first["fruit"].visible, "Fruit must not appear at half maturity")
    first["age"] = 10
    farm._paint(first)
    check(first["fruit"].visible, "Mature crop should show produce")
    var snapshot: Array = farm.save_state()
    check(snapshot.size() == 30, "Save still contains exactly 30 beds")
    check(not snapshot[0].has("fruit"), "Transient render nodes must not leak into save schema")
    first["age"] = 0
    farm.load_state(snapshot)
    check(int(farm.beds[0]["age"]) == 10, "Load must restore growth stage")
    check(farm.beds[0]["fruit"].visible, "Load must repaint mature crop")
    print("FARM_VISUAL_COLLISION_TEST failures=%d beds=%d shapes=%d" % [failures.size(), farm.beds.size(), shape_count])
    quit(0 if failures.is_empty() else 1)
