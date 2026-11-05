extends Node3D
## Original first-party collision-backed cottage assembly. Visual detail is an interim
## authored modular pass, not a claim of final production-quality art.
const WALL_HEIGHT := 3.4
const WALL_THICKNESS := 0.28
var palette: Dictionary = {}

func _ready() -> void:
    _material("plaster", Color("#e7d9bc"))
    _material("timber", Color("#59402e"))
    _material("stone", Color("#8c877e"))
    _material("roof", Color("#965849"))
    _material("glass", Color("#91bbc2"))
    _material("floor", Color("#b9936a"))

func _material(key: String, color: Color) -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.78
    if key == "glass":
        mat.metallic = 0.1
        mat.roughness = 0.14
    palette[key] = mat

func _solid(parent: Node3D, label: String, center: Vector3, size: Vector3, key: String) -> void:
    var body := StaticBody3D.new()
    body.name = label
    body.position = center
    body.collision_layer = 1
    body.collision_mask = 1
    parent.add_child(body)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.material_override = palette[key]
    body.add_child(visual)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    body.add_child(collider)

func _decoration(parent: Node3D, label: String, center: Vector3, size: Vector3, key: String) -> void:
    var visual := MeshInstance3D.new()
    visual.name = label
    visual.position = center
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.material_override = palette[key]
    parent.add_child(visual)

func build_cottage(origin: Vector3, width: float = 7.0) -> void:
    if palette.is_empty():
        _ready()
    var cottage := Node3D.new()
    cottage.name = "SolidWalkableCottage"
    cottage.position = origin
    add_child(cottage)
    var depth := 5.2
    var half := width * 0.5
    _solid(cottage, "FoundationAndFloor", Vector3(0, -0.14, 0), Vector3(width + 0.45, 0.28, depth + 0.45), "stone")
    _solid(cottage, "RearWall", Vector3(0, WALL_HEIGHT * 0.5, -depth * 0.5), Vector3(width, WALL_HEIGHT, WALL_THICKNESS), "plaster")
    for x in [-half, half]:
        _solid(cottage, "SideWall", Vector3(x, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, depth), "plaster")
    # Functional 1.45 m doorway: no collider intersects the opening.
    var opening := 1.45
    var segment := (width - opening) * 0.5
    for sign in [-1.0, 1.0]:
        var x := sign * (opening * 0.5 + segment * 0.5)
        _solid(cottage, "FrontWallPier", Vector3(x, WALL_HEIGHT * 0.5, depth * 0.5), Vector3(segment, WALL_HEIGHT, WALL_THICKNESS), "plaster")
    _solid(cottage, "DoorLintel", Vector3(0, 2.85, depth * 0.5), Vector3(opening, 1.1, WALL_THICKNESS), "timber")
    for x in [-half + 0.16, half - 0.16]:
        for z in [-depth * 0.5 + 0.16, depth * 0.5 - 0.16]:
            _solid(cottage, "StructuralPost", Vector3(x, 1.75, z), Vector3(0.24, 3.5, 0.24), "timber")
    for z in [-depth * 0.5, depth * 0.5]:
        _solid(cottage, "EaveBeam", Vector3(0, 3.4, z), Vector3(width + 0.5, 0.24, 0.28), "timber")
    # Two sloped roof planes have matching static-body collision.
    var slope_length := sqrt(pow(half + 0.55, 2) + pow(1.7, 2))
    var pitch := atan2(1.7, half + 0.55)
    for sign in [-1.0, 1.0]:
        var roof := Node3D.new()
        roof.name = "RoofSlope"
        roof.position = Vector3(sign * (half + 0.55) * 0.5, 4.25, 0)
        roof.rotation.z = -sign * pitch
        cottage.add_child(roof)
        _solid(roof, "RoofPlane", Vector3.ZERO, Vector3(slope_length, 0.20, depth + 1.1), "roof")
        for index in range(9):
            var along := -slope_length * 0.5 + (float(index) + 0.5) * slope_length / 9.0
            _decoration(roof, "ShingleCourse", Vector3(along, 0.13, 0), Vector3(0.09, 0.045, depth + 1.05), "timber")
    # Decorative panes are nonstructural and do not imply a hole through the wall.
    for sign in [-1.0, 1.0]:
        var x := sign * (half - 1.0)
        _decoration(cottage, "WindowGlass", Vector3(x, 2.05, depth * 0.5 + 0.16), Vector3(0.8, 0.95, 0.035), "glass")
        for dy in [-0.5, 0.5]:
            _decoration(cottage, "WindowTrim", Vector3(x, 2.05 + dy, depth * 0.5 + 0.19), Vector3(1.0, 0.10, 0.08), "timber")
    _solid(cottage, "InteriorBench", Vector3(-half + 1.2, 0.4, -1.25), Vector3(1.5, 0.8, 0.65), "floor")
