extends RefCounted
## Collision contract shared by homestead, settlements and scenic landmarks.
## The character capsule is layer 1 by default. Structural colliders use layer 1.
## Keep flowers, roads, terrain decals and small ornaments nonblocking.
static func solid_box(mesh_instance: MeshInstance3D, dimensions: Vector3, purpose: String = "structure") -> StaticBody3D:
    var body:=StaticBody3D.new()
    body.name="Solid_"+purpose
    body.collision_layer=1
    body.collision_mask=1
    mesh_instance.add_child(body)
    var shape:=BoxShape3D.new()
    shape.size=dimensions
    var collider:=CollisionShape3D.new()
    collider.name="PhysicalVolume"
    collider.shape=shape
    body.add_child(collider)
    body.add_to_group("everbloom_world_solid")
    return body

static func perimeter_barrier(chunk: Node3D, local_position: Vector3, dimensions: Vector3, label: String) -> StaticBody3D:
    # One physics barrier per perimeter tile, rather than a drop into the void.
    var body:=StaticBody3D.new()
    body.name="WorldPerimeter_"+label
    body.position=local_position
    body.collision_layer=1
    body.collision_mask=1
    chunk.add_child(body)
    var collider:=CollisionShape3D.new()
    var shape:=BoxShape3D.new()
    shape.size=dimensions
    collider.shape=shape
    body.add_child(collider)
    body.add_to_group("everbloom_world_perimeter")
    return body
