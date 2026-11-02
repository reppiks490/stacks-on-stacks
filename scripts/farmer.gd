extends CharacterBody3D
## Movement remains physics-driven and free of third-party mechanics/assets.
var game
var walking_speed: float = 7.0
var movement_input: Vector2 = Vector2.ZERO
var coat: MeshInstance3D

func setup(host) -> void:
    game = host
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.75
    collision.shape = shape
    collision.position.y = 0.91
    add_child(collision)
    coat = MeshInstance3D.new()
    var body := CapsuleMesh.new()
    body.radius = 0.38
    body.height = 1.7
    coat.mesh = body
    coat.position.y = 0.91
    coat.material_override = _mat(Color("#518a78"))
    add_child(coat)
    var head := MeshInstance3D.new()
    var face := SphereMesh.new()
    face.radius = 0.3
    face.height = 0.58
    head.mesh = face
    head.position.y = 1.94
    head.material_override = _mat(Color("#edc5a1"))
    add_child(head)
    var brim := MeshInstance3D.new()
    var hat := CylinderMesh.new()
    hat.top_radius = 0.31
    hat.bottom_radius = 0.55
    hat.height = 0.16
    brim.mesh = hat
    brim.position.y = 2.2
    brim.material_override = _mat(Color("#b88758"))
    add_child(brim)

func _mat(tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.88
    return mat

func _physics_process(delta: float) -> void:
    var axis := Input.get_vector("move_left","move_right","move_up","move_down")
    var direction := Vector3(axis.x, 0.0, axis.y)
    velocity.x = direction.x * walking_speed
    velocity.z = direction.z * walking_speed
    if not is_on_floor():
        velocity.y -= 22.0 * delta
    else:
        velocity.y = 0.0
    move_and_slide()
    if direction.length() > 0.05:
        rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 9.0)
