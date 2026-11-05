extends Node3D
## Original, physically solid cottage repair slice. Not final authored architecture.
## Each wall segment has a matching static collider; the entrance remains open.
const DEPTH := 5.2
const HEIGHT := 3.8
const THICKNESS := 0.22
const DOOR_WIDTH := 1.35
const DOOR_HEIGHT := 2.45

func build(width: float, plaster: Color, roof_color: Color) -> void:
    var foundation := Color("#827765")
    _solid("Floor", Vector3(0, -0.12, 0), Vector3(width, 0.24, DEPTH), foundation)
    _solid("RearWall", Vector3(0, HEIGHT*0.5, -DEPTH*0.5), Vector3(width, HEIGHT, THICKNESS), plaster)
    for sign_value in [-1.0, 1.0]:
        _solid("SideWall", Vector3(sign_value*width*0.5, HEIGHT*0.5, 0), Vector3(THICKNESS, HEIGHT, DEPTH), plaster)
        var segment_width := (width-DOOR_WIDTH)*0.5
        _solid("EntrancePier", Vector3(sign_value*(DOOR_WIDTH+segment_width)*0.5, HEIGHT*0.5, DEPTH*0.5), Vector3(segment_width, HEIGHT, THICKNESS), plaster)
    _solid("DoorLintel", Vector3(0, (HEIGHT+DOOR_HEIGHT)*0.5, DEPTH*0.5), Vector3(DOOR_WIDTH, HEIGHT-DOOR_HEIGHT, THICKNESS), plaster)
    _solid("RoofUnderlay", Vector3(0, HEIGHT+0.08, 0), Vector3(width+0.45, 0.16, DEPTH+0.45), roof_color)
    # Roof slopes are decorative for now; structural roof collision is the underlay.
    var roof := MeshInstance3D.new()
    roof.name = "RoofSilhouette"
    var shape := PrismMesh.new()
    shape.size = Vector3(width+0.9, 1.65, DEPTH+0.9)
    roof.mesh = shape
    roof.position = Vector3(0, HEIGHT+0.9, 0)
    roof.material_override = _material(roof_color)
    add_child(roof)
    _solid("Threshold", Vector3(0, 0.045, DEPTH*0.5+0.25), Vector3(DOOR_WIDTH, 0.09, 0.5), foundation)

func _material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.86
    return result

func _solid(label: String, center: Vector3, size: Vector3, tint: Color) -> void:
    var body := StaticBody3D.new()
    body.name = label
    body.collision_layer = 1
    body.collision_mask = 1
    body.position = center
    add_child(body)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.material_override = _material(tint)
    body.add_child(visual)
    var collision := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    collision.shape = box
    body.add_child(collision)
