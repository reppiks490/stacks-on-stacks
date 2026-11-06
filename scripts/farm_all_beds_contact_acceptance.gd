extends SceneTree
## Native Farming lane acceptance: every existing bed must be physically walkable.
## Run: godot --headless --path . --script scripts/farm_all_beds_contact_acceptance.gd
## Isolated farm fixture, not proof of assembled-game terrain or visual quality.
const FarmScript = preload("res://scripts/farm.gd")
const BED_COUNT := 30
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    get_root().add_child(world)
    var farm: Node3D = FarmScript.new()
    world.add_child(farm)
    farm.setup(null)
    if farm.beds.size() != BED_COUNT:
        push_error("Expected 30 farm beds; found %d" % farm.beds.size())
        quit(1)
        return
    var probe := CharacterBody3D.new()
    probe.collision_layer = 2
    probe.collision_mask = 1
    probe.floor_snap_length = 0.3
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.22
    capsule.height = 1.2
    collider.shape = capsule
    probe.add_child(collider)
    world.add_child(probe)
    await physics_frame
    for index in range(BED_COUNT):
        var holder: Node3D = farm.beds[index]["holder"]
        var body: StaticBody3D = holder.get_node_or_null("SoilCollision")
        if body == null or body.collision_layer & 1 == 0:
            failures.append("Bed %d missing solid layer-1 soil collider" % index)
            continue
        # Test center and two opposite furrow shoulders; use a fresh probe
        # position each time, never inherit the previous bed's grounded state.
        for offset in [Vector3.ZERO, Vector3(0.45, 0, 0.35), Vector3(-0.45, 0, -0.35)]:
            probe.global_position = holder.global_position + offset + Vector3.UP * 1.8
            probe.velocity = Vector3.ZERO
            await physics_frame
            var touched := false
            var lowest_foot := INF
            for frame in range(120):
                probe.velocity = Vector3.DOWN * 6.0
                probe.move_and_slide()
                lowest_foot = minf(lowest_foot, probe.global_position.y - capsule.height * 0.5)
                if probe.is_on_floor():
                    touched = true
                await physics_frame
            if not touched:
                failures.append("Bed %d offset %s never grounded" % [index, str(offset)])
            if lowest_foot < holder.global_position.y - 0.20:
                failures.append("Bed %d offset %s penetrated soil: %.3f" % [index, str(offset), lowest_foot])
    if failures.is_empty():
        print("FARM_ALL_BEDS_CONTACT PASS: 30 beds x 3 positions x 120 physics frames")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        print("FARM_ALL_BEDS_CONTACT FAIL: %d failures" % failures.size())
        quit(1)
