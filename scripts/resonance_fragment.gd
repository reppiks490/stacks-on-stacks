extends Area3D
## Collectible shard that can be picked up exactly once.
signal collected
var _taken := false
var _mesh: MeshInstance3D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var collider := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.72
    collider.shape = sphere
    add_child(collider)
    _mesh = MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = 0.31
    shape.height = 0.62
    _mesh.mesh = shape
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.9, 0.91)
    mat.emission_enabled = true
    mat.emission = Color(0.04, 0.42, 0.66)
    mat.emission_energy_multiplier = 1.6
    _mesh.material_override = mat
    add_child(_mesh)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    _mesh.rotate_y(delta * 1.8)

func _on_body_entered(body: Node3D) -> void:
    if _taken or not body.is_in_group("players"):
        return
    _taken = true
    collected.emit()
    queue_free()
