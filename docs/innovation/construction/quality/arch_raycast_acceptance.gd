extends SceneTree
## B16/B17 native collision probe for existing arch. Run:
## godot --headless --path . --script res://docs/innovation/construction/quality/arch_raycast_acceptance.gd
## No player saves, global gameplay state, or new feature systems are touched.
const KIT = preload("res://docs/innovation/construction/quality/stone_voussoir_arch.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := Node3D.new()
    scene.name = "IsolatedArchPhysicsAcceptance"
    root.add_child(scene)
    var arch: Node3D = KIT.make_arch()
    scene.add_child(arch)
    # Static concave bodies must enter the physics world before ray queries.
    await physics_frame
    await physics_frame
    var space := scene.get_world_3d().direct_space_state
    var crest := _probe(space, Vector3(0.0, 1.32, -2.0), Vector3(0.0, 1.32, 2.0))
    assert(not crest.is_empty(), "Arch crown lacks front-to-back collision")
    assert(crest["collider"] is StaticBody3D, "Arch collision is not static")
    assert(absf(crest["position"].z + 0.21) < 0.04, "Crown collision disagrees with 0.42m visual depth")
    var doorway := _probe(space, Vector3(0.0, 0.7, -2.0), Vector3(0.0, 0.7, 2.0))
    assert(doorway.is_empty(), "Arch obstructs clear central doorway")
    var side := _probe(space, Vector3(1.30, 0.20, -2.0), Vector3(1.30, 0.20, 2.0))
    assert(not side.is_empty(), "Arch spring stone has no collision")
    var outside := _probe(space, Vector3(2.0, 1.0, -2.0), Vector3(2.0, 1.0, 2.0))
    assert(outside.is_empty(), "Arch has collision outside its visual silhouette")
    print("B16/B17 ARCH PHYSICS PASS: crown/side solid; doorway/exterior clear; front depth aligned")
    scene.queue_free()
    quit(0)

func _probe(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(start, end)
    query.collide_with_bodies = true
    query.collide_with_areas = false
    return space.intersect_ray(query)
