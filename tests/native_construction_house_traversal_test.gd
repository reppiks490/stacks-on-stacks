extends SceneTree
## Construction lane: exact launch-scene wall/door/floor regression.
## Run: godot --headless --path . --script res://tests/native_construction_house_traversal_test.gd
const Valley = preload("res://scripts/valley.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error("CONSTRUCTION FAIL: " + label)

func _ray(space: PhysicsDirectSpaceState3D, start: Vector3, finish: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
    return space.intersect_ray(query)

func _run() -> void:
    var valley := Node3D.new()
    valley.set_script(Valley)
    root.add_child(valley)
    valley.setup(null)
    for frame in range(120):
        await physics_frame
    var space := root.get_world_3d().direct_space_state
    var houses: Array[Node] = []
    for child in valley.get_children():
        if child is StaticBody3D and child.name == "SolidHouse":
            houses.append(child)
    _check(houses.size() >= 6, "All original farmhouse and town houses have structural bodies")
    for house in houses:
        var body := house as StaticBody3D
        var center := body.global_position
        var front_z := center.z + 2.6
        _check(body.collision_layer & 1 != 0, "House collision layer: " + str(center))
        _check(_ray(space, center + Vector3(0, 1.1, 4.5), center + Vector3(0, 1.1, 1.6)).is_empty(), "Doorway clear: " + str(center))
        _check(not _ray(space, center + Vector3(0, 1.1, -4.5), center + Vector3(0, 1.1, -1.6)).is_empty(), "Back wall blocks: " + str(center))
        _check(not _ray(space, center + Vector3(-5.0, 1.1, 0), center + Vector3(-1.0, 1.1, 0)).is_empty(), "Side wall blocks: " + str(center))
        _check(not _ray(space, center + Vector3(0, 2.0, 0), center + Vector3(0, -1.0, 0)).is_empty(), "Floor supports: " + str(center))
    if failures.is_empty():
        print("CONSTRUCTION PASS: 120 physics frames, structural walls, open entrances, floor contact")
        quit(0)
    else:
        print("CONSTRUCTION FAIL count: ", failures.size())
        quit(1)
