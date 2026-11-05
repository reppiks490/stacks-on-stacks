extends StaticBody3D
## Collision-first cottage shell. Original geometry; NOT final authored art.
## Local +Z is the entrance. Ground plane is local y=0.
@export var width: float = 7.0
@export var depth: float = 5.2
@export var height: float = 3.6
@export var door_width: float = 1.5
@export var door_height: float = 2.45
@export var wall_thickness: float = 0.24

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    _build()

func _solid(name: String, center: Vector3, size: Vector3, tint: Color) -> void:
    var collider := CollisionShape3D.new()
    collider.name = name + "Collision"
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    collider.position = center
    add_child(collider)
    var visual := MeshInstance3D.new()
    visual.name = name + "Visual"
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.position = center
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.86
    visual.material_override = material
    add_child(visual)

func _build() -> void:
    var plaster := Color("#e8dcc1")
    var timber := Color("#74543b")
    var floor_color := Color("#b59b77")
    var half_w := width * 0.5
    var half_d := depth * 0.5
    var side_width := (width - door_width) * 0.5
    _solid("Foundation", Vector3(0, -0.16, 0), Vector3(width + 0.4, 0.32, depth + 0.4), floor_color)
    _solid("BackWall", Vector3(0, height * 0.5, -half_d), Vector3(width, height, wall_thickness), plaster)
    _solid("LeftWall", Vector3(-half_w, height * 0.5, 0), Vector3(wall_thickness, height, depth), plaster)
    _solid("RightWall", Vector3(half_w, height * 0.5, 0), Vector3(wall_thickness, height, depth), plaster)
    _solid("FrontLeft", Vector3(-(door_width + side_width) * 0.5, height * 0.5, half_d), Vector3(side_width, height, wall_thickness), plaster)
    _solid("FrontRight", Vector3((door_width + side_width) * 0.5, height * 0.5, half_d), Vector3(side_width, height, wall_thickness), plaster)
    _solid("DoorLintel", Vector3(0, (height + door_height) * 0.5, half_d), Vector3(door_width, height - door_height, wall_thickness), timber)
    _solid("Ceiling", Vector3(0, height + 0.10, 0), Vector3(width, 0.20, depth), timber)
    for x in [-half_w + 0.12, half_w - 0.12]:
        for z in [-half_d + 0.12, half_d - 0.12]:
            _solid("CornerPost", Vector3(x, height * 0.5, z), Vector3(0.22, height, 0.22), timber)
