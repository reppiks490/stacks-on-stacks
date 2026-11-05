extends SceneTree
## Native construction collision contract; run with godot --headless --path . --script res://tests/native_solid_cottage_test.gd
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := Node3D.new()
    root.add_child(scene)
    var cottage := Node3D.new()
    cottage.set_script(load("res://scripts/solid_cottage.gd"))
    scene.add_child(cottage)
    cottage.build(7.0, Color.WHITE, Color.BROWN)
    await physics_frame
    await physics_frame
    var space := scene.get_world_3d().direct_space_state
    var checks := [
        {"name":"rear wall", "from":Vector3(0,1.3,-4), "to":Vector3(0,1.3,0), "hit":true},
        {"name":"side wall", "from":Vector3(5,1.3,0), "to":Vector3(2,1.3,0), "hit":true},
        {"name":"front pier", "from":Vector3(2.5,1.3,4), "to":Vector3(2.5,1.3,1), "hit":true},
        {"name":"doorway", "from":Vector3(0,1.3,4), "to":Vector3(0,1.3,1), "hit":false},
        {"name":"floor", "from":Vector3(0,2,0), "to":Vector3(0,-2,0), "hit":true}
    ]
    var failures := 0
    for check in checks:
        var query := PhysicsRayQueryParameters3D.create(check["from"],check["to"])
        query.collision_mask = 1
        var found := not space.intersect_ray(query).is_empty()
        if found != check["hit"]:
            push_error("FAIL: " + check["name"])
            failures += 1
    if failures == 0:
        print("PASS: 5 solid cottage wall/door/floor raycast contracts")
    quit(1 if failures else 0)
