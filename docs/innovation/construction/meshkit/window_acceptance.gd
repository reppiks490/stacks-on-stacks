extends SceneTree
## Headless invocation: godot --headless --path . --script res://docs/innovation/construction/meshkit/window_acceptance.gd

func _initialize() -> void:
    var kit = load("res://scripts/construction_original_windowkit.gd")
    var a: ArrayMesh = kit.mullioned_window(1.6, 2.0, 0.12, 0.09)
    assert(a.get_surface_count() == 1, "expected one surface")
    var verts: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    assert(verts.size() == 252, "seven 12-triangle cuboids expected")
    var b: ArrayMesh = kit.mullioned_window(1.6, 2.0, 0.12, 0.09)
    assert(verts == b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "nondeterministic geometry")
    for args in [[0.1, 2.0, 0.12, 0.09], [1.6, 2.0, 0.0, 0.09], [1.6, 2.0, 0.12, 0.7], [1.6, 2.0, 0.12, 0.09, -0.1]]:
        var invalid: ArrayMesh
        if args.size() == 4:
            invalid = kit.mullioned_window(args[0], args[1], args[2], args[3])
        else:
            invalid = kit.mullioned_window(args[0], args[1], args[2], args[3], args[4])
        assert(invalid.get_surface_count() == 0, "invalid dimensions accepted")
    print("WINDOW_MESHKIT_ACCEPTANCE_PASS")
    quit()
