extends Node3D
## Collision-first replacement for the existing homestead cottage.
## Original Godot geometry, NOT a finished authored art asset.
const WIDTH := 7.0
const DEPTH := 5.2
const HEIGHT := 3.5
const DOOR_WIDTH := 1.35
const DOOR_HEIGHT := 2.45

func _ready() -> void:
    _surface("Floor", Vector3(0, -0.15, 0), Vector3(WIDTH, 0.3, DEPTH), Color("#ad9675"))
    _surface("BackWall", Vector3(0, HEIGHT / 2.0, -DEPTH / 2.0), Vector3(WIDTH, HEIGHT, 0.25), Color("#eee0c2"))
    for side in [-1.0, 1.0]:
        _surface("SideWall", Vector3(side * WIDTH / 2.0, HEIGHT / 2.0, 0), Vector3(0.25, HEIGHT, DEPTH), Color("#eee0c2"))
    var flank := (WIDTH - DOOR_WIDTH) / 2.0
    for side in [-1.0, 1.0]:
        _surface("FrontWall", Vector3(side * (DOOR_WIDTH + flank) / 2.0, HEIGHT / 2.0, DEPTH / 2.0), Vector3(flank, HEIGHT, 0.25), Color("#eee0c2"))
    _surface("DoorLintel", Vector3(0, (HEIGHT + DOOR_HEIGHT) / 2.0, DEPTH / 2.0), Vector3(DOOR_WIDTH, HEIGHT - DOOR_HEIGHT, 0.25), Color("#72543e"))
    _surface("InteriorPartitionLeft", Vector3(-1.7, 1.35, -0.65), Vector3(0.18, 2.7, 2.0), Color("#c7ae8c"))
    _surface("InteriorPartitionRight", Vector3(1.7, 1.35, -0.65), Vector3(0.18, 2.7, 2.0), Color("#c7ae8c"))
    _surface("Roof", Vector3(0, HEIGHT + 0.3, 0), Vector3(WIDTH + 0.6, 0.35, DEPTH + 0.6), Color("#995e4f"))

func _surface(label: String, at: Vector3, size: Vector3, tint: Color) -> void:
    var body := StaticBody3D.new()
    body.name = label
    body.collision_layer = 1
    body.collision_mask = 1
    body.position = at
    add_child(body)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.8
    visual.material_override = mat
    body.add_child(visual)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    body.add_child(collider)
