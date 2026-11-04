extends RefCounted
## Temporary collision retrofit for the *currently launched* 145m baseline.
## Do not apply perimeter walls to the 4.8km streamed world.
static func install(valley: Node3D) -> Dictionary:
    var count := 0
    for child in valley.get_children():
        if not child is MeshInstance3D or not child.mesh is BoxMesh:
            continue
        var dimensions: Vector3 = child.mesh.size
        # Thin painted paths and flower decorations are not solid walls.
        if dimensions.y < 0.35 or dimensions.x < 0.3 or dimensions.z < 0.3:
            continue
        # Ground already has a StaticBody3D; avoid duplicate physics surfaces.
        if dimensions.x >= 140.0 and dimensions.z >= 140.0:
            continue
        var body := StaticBody3D.new()
        body.name = "Solid_%s" % child.name
        body.collision_layer = 1
        body.collision_mask = 1
        body.position = child.position
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = dimensions
        shape_node.shape = shape
        body.add_child(shape_node)
        valley.add_child(body)
        count += 1
    # Baseline safety fence only: prevent falling into the void while the
    # continental streaming branch is being independently validated.
    var limit := 72.5
    for side in range(4):
        var boundary := StaticBody3D.new()
        boundary.name = "BaselineBoundary_%d" % side
        boundary.collision_layer = 1
        boundary.collision_mask = 1
        var collider := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(145.0, 12.0, 1.0) if side < 2 else Vector3(1.0, 12.0, 145.0)
        collider.shape = shape
        boundary.position = Vector3(0, 5, -limit if side == 0 else limit) if side < 2 else Vector3(-limit if side == 2 else limit, 5, 0)
        boundary.add_child(collider)
        valley.add_child(boundary)
    return {"solid_props":count, "safety_boundaries":4}
