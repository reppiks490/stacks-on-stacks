extends Node3D
## Construction-owned collision-first cottage module. Not production-finished art.
## Instance at ground elevation. The front doorway is an intentional opening.
const WALL_LAYER: int = 1
const WIDTH: float = 7.0
const DEPTH: float = 5.2
const HEIGHT: float = 3.5
const THICKNESS: float = 0.24
const DOOR_WIDTH: float = 1.5
const DOOR_HEIGHT: float = 2.35

func _ready() -> void:
    _solid("floor", Vector3(0, -0.12, 0), Vector3(WIDTH, 0.24, DEPTH))
    _solid("back_wall", Vector3(0, HEIGHT / 2.0, -DEPTH / 2.0), Vector3(WIDTH, HEIGHT, THICKNESS))
    for side in [-1.0, 1.0]:
        _solid("side_wall_%s" % str(side), Vector3(side * WIDTH / 2.0, HEIGHT / 2.0, 0), Vector3(THICKNESS, HEIGHT, DEPTH))
        _solid("front_pier_%s" % str(side), Vector3(side * (WIDTH + DOOR_WIDTH) / 4.0, HEIGHT / 2.0, DEPTH / 2.0), Vector3((WIDTH - DOOR_WIDTH) / 2.0, HEIGHT, THICKNESS))
    _solid("door_lintel", Vector3(0, (HEIGHT + DOOR_HEIGHT) / 2.0, DEPTH / 2.0), Vector3(DOOR_WIDTH, HEIGHT - DOOR_HEIGHT, THICKNESS))
    _solid("roof_collision", Vector3(0, HEIGHT + 0.12, 0), Vector3(WIDTH + 0.5, 0.24, DEPTH + 0.5))
    _solid("interior_partition_left", Vector3(-1.8, 1.1, -0.6), Vector3(0.18, 2.2, 2.0))

func _solid(label: String, center: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = label
    body.collision_layer = WALL_LAYER
    body.collision_mask = WALL_LAYER
    body.position = center
    add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    body.add_child(collider)
    var visible := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visible.mesh = mesh
    body.add_child(visible)
