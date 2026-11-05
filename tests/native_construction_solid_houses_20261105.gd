extends SceneTree
# Native structural smoke; run with godot --headless --path . --script res://tests/native_construction_solid_houses_20261105.gd
func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var valley := Node3D.new()
    valley.set_script(load("res://scripts/valley.gd"))
    root.add_child(valley)
    valley._house(Vector3.ZERO, Color.WHITE, Color.RED, 7.0)
    var house: Node3D = valley.get_node("SolidHouse")
    var solids := 0
    var colliders := 0
    for child in house.get_children():
        if child is StaticBody3D:
            solids += 1
            for part in child.get_children():
                if part is CollisionShape3D and part.shape != null:
                    colliders += 1
    if solids != 8 or colliders != 8:
        push_error("Expected 8 structural collision bodies, got %d / %d" % [solids, colliders])
        quit(1)
        return
    # Opening spans x +/-0.75 and y 0..2.65, with no front collider in it.
    for body in house.get_children():
        if not body is StaticBody3D:
            continue
        if absf(body.position.z - 2.6) > 0.001:
            continue
        var shape: BoxShape3D = body.get_node("CollisionShape3D").shape
        var min_x: float = body.position.x - shape.size.x*0.5
        var max_x: float = body.position.x + shape.size.x*0.5
        var min_y: float = body.position.y - shape.size.y*0.5
        if min_x < 0.0 and max_x > 0.0 and min_y < 2.65:
            push_error("Doorway obstructed by structural collision")
            quit(1)
            return
    print("PASS: eight collidable structural sections; doorway opening remains clear")
    quit(0)
