extends SceneTree
# Run: godot --headless --path . --script tests/native_continent_boundary_test.gd
func _initialize() -> void:
    var world := Node3D.new()
    world.set_script(load("res://scripts/continental_world.gd"))
    root.add_child(world)
    var checked := 0
    for key in [Vector2i(0,0), Vector2i(31,31), Vector2i(0,16), Vector2i(16,31), Vector2i(16,16)]:
        var chunk := Node3D.new()
        world.add_child(chunk)
        world._install_outer_boundary(chunk,key)
        var expected := int(key.x == 0 or key.x == 31) + int(key.y == 0 or key.y == 31)
        var found := 0
        for child in chunk.get_children():
            if child is StaticBody3D and child.name == "PhysicalWorldBoundary":
                found += 1
                assert(child.collision_layer & 1 != 0)
                assert(child.get_child_count() == 1)
                var collider: CollisionShape3D = child.get_child(0)
                assert(collider.shape is BoxShape3D)
                assert(collider.shape.size.y >= 60.0)
        assert(found == expected, "Boundary count mismatch at %s" % str(key))
        checked += 1
    print("PASS native continent boundary geometry: %d cells" % checked)
    quit(0)
