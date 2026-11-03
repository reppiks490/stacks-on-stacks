extends SceneTree
## Run: godot --headless --path . --script res://docs/innovation/construction/meshkit/native_acceptance.gd
const Kit = preload("res://scripts/construction_original_meshkit.gd")

func _initialize() -> void:
    var failures := 0
    var roof := Kit.gabled_roof(7.0, 5.2, 2.2)
    var beam := Kit.tapered_beam(3.0, 0.22, 0.17, 8)
    if roof.get_surface_count() != 1:
        failures += 1
    elif roof.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() != 12:
        failures += 1
    if beam.get_surface_count() != 1:
        failures += 1
    elif beam.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() != 48:
        failures += 1
    if Kit.gabled_roof(-1.0, 5.0, 2.0).get_surface_count() != 0:
        failures += 1
    if Kit.tapered_beam(3.0, 0.2, 0.1, 2).get_surface_count() != 0:
        failures += 1
    var again := Kit.gabled_roof(7.0, 5.2, 2.2)
    if roof.get_surface_count() == 1 and again.get_surface_count() == 1:
        if roof.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != again.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
            failures += 1
    print("CONSTRUCTION ORIGINAL MESHKIT: ", 5 - failures, "/5 checks; failures=", failures)
    quit(0 if failures == 0 else 1)
