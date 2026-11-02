extends Node3D
## Original non-combat local companion. A mobile-friendly visual helper.
var follow_target: Node3D
var _heal_cooldown: float = 8.0
var _mesh: MeshInstance3D

func _ready() -> void:
    _mesh = MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = 0.26
    shape.height = 0.52
    _mesh.mesh = shape
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.95, 0.75, 0.35)
    material.emission_enabled = true
    material.emission = Color(0.6, 0.35, 0.06)
    material.emission_energy_multiplier = 1.0
    _mesh.material_override = material
    add_child(_mesh)

func _process(delta: float) -> void:
    if not is_instance_valid(follow_target):
        return
    var goal := follow_target.global_position + Vector3(-1.15, 1.9 + sin(Time.get_ticks_msec() / 480.0) * 0.18, 1.35)
    global_position = global_position.lerp(goal, minf(1.0, delta * 4.0))
    _heal_cooldown -= delta
    if _heal_cooldown <= 0.0:
        _heal_cooldown = 8.0
        if follow_target.has_method("restore_health") and float(follow_target.get("hp")) <= 54.0:
            follow_target.call("restore_health", 7.0)
