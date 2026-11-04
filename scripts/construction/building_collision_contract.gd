extends RefCounted
## Construction-only collision contract for authored building scenes.
## Attach to an existing authored building's StaticBody3D; not a visual asset.
## Building meshes and collision volumes must share the same local origin.
const SOLID_LAYER: int = 1
const MIN_THICKNESS: float = 0.08

static func add_solid(body: StaticBody3D, name: String, center: Vector3, size: Vector3) -> CollisionShape3D:
    assert(body != null and body.is_inside_tree())
    assert(size.x >= MIN_THICKNESS and size.y >= MIN_THICKNESS and size.z >= MIN_THICKNESS)
    body.collision_layer |= SOLID_LAYER
    var shape := BoxShape3D.new()
    shape.size = size
    var collider := CollisionShape3D.new()
    collider.name = name
    collider.shape = shape
    collider.position = center
    body.add_child(collider)
    return collider

static func add_wall_with_door(body: StaticBody3D, origin: Vector3, width: float, height: float, thickness: float, opening_width: float, opening_height: float) -> void:
    assert(width > opening_width and opening_width > 0.0)
    assert(height > opening_height and opening_height > 0.0)
    assert(thickness >= MIN_THICKNESS)
    var pier_width := (width - opening_width) * 0.5
    add_solid(body, "DoorLeftPier", origin + Vector3(-(opening_width + pier_width) * 0.5, height * 0.5, 0), Vector3(pier_width, height, thickness))
    add_solid(body, "DoorRightPier", origin + Vector3((opening_width + pier_width) * 0.5, height * 0.5, 0), Vector3(pier_width, height, thickness))
    add_solid(body, "DoorLintel", origin + Vector3(0, (height + opening_height) * 0.5, 0), Vector3(opening_width, height - opening_height, thickness))

static func validate_solid(body: StaticBody3D) -> bool:
    if body == null or (body.collision_layer & SOLID_LAYER) == 0:
        return false
    var count := 0
    for child in body.get_children():
        if child is CollisionShape3D and not child.disabled and child.shape != null:
            count += 1
    return count > 0
