extends StaticBody3D
## Original local breakable prop. One reward event; no voxel-terrain claim.
signal shattered(at: Vector3)

var durability: float = 34.0
var _broken: bool = false
var _mesh: MeshInstance3D

func _ready() -> void:
    add_to_group("damageable")
    collision_layer = 1
    collision_mask = 1
    var collider := CollisionShape3D.new()
    var form := CylinderShape3D.new()
    form.radius = 0.72
    form.height = 2.4
    collider.shape = form
    add_child(collider)
    _mesh = MeshInstance3D.new()
    var visual := CylinderMesh.new()
    visual.top_radius = 0.12
    visual.bottom_radius = 0.73
    visual.height = 2.4
    _mesh.mesh = visual
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.54, 0.20, 0.80)
    material.metallic = 0.15
    material.emission_enabled = true
    material.emission = Color(0.22, 0.06, 0.38)
    material.emission_energy_multiplier = 1.2
    _mesh.material_override = material
    add_child(_mesh)

func take_damage(amount: float, _instigator: Node) -> void:
    if _broken or amount <= 0.0:
        return
    durability -= amount
    if durability <= 0.0:
        _broken = true
        remove_from_group("damageable")
        shattered.emit(global_position)
        queue_free()
