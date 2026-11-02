extends CharacterBody3D
## Telegraph-led local AI: idle -> chase -> windup -> recover -> stagger.
signal defeated(enemy: Node3D)

enum Mode { IDLE, CHASE, WINDUP, RECOVER, STAGGER, DEAD }
const SPEED := 3.8
const ATTACK_RANGE := 2.1
const DETECTION_RANGE := 17.0
const WINDUP_SECONDS := 0.75
const RECOVERY_SECONDS := 1.5
const GRAVITY := 19.6

var player
var hp: float = 55.0
var damage: float = 12.0
var mode: Mode = Mode.IDLE
var _mode_time: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _dead: bool = false

func _ready() -> void:
    add_to_group("hostiles")
    add_to_group("damageable")
    collision_layer = 2
    collision_mask = 1
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.55
    capsule.radius = 0.42
    collider.shape = capsule
    add_child(collider)
    _mesh = MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.42
    mesh.height = 1.55
    _mesh.mesh = mesh
    add_child(_mesh)
    _mat = StandardMaterial3D.new()
    _mat.albedo_color = Color(0.21, 0.59, 0.60)
    _mat.metallic = 0.30
    _mesh.material_override = _mat

func _physics_process(delta: float) -> void:
    if _dead:
        return
    _mode_time = maxf(0.0, _mode_time - delta)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = -0.05
    if not is_instance_valid(player):
        velocity.x = 0.0
        velocity.z = 0.0
        move_and_slide()
        return
    var towards: Vector3 = player.global_position - global_position
    towards.y = 0.0
    var distance := towards.length()
    match mode:
        Mode.IDLE:
            _mat.albedo_color = Color(0.21, 0.59, 0.60)
            if distance < DETECTION_RANGE:
                mode = Mode.CHASE
        Mode.CHASE:
            _mat.albedo_color = Color(0.32, 0.63, 0.52)
            if distance <= ATTACK_RANGE:
                mode = Mode.WINDUP
                _mode_time = WINDUP_SECONDS
            elif distance > DETECTION_RANGE * 1.6:
                mode = Mode.IDLE
            elif distance > 0.01:
                var direction := towards / distance
                velocity.x = direction.x * SPEED
                velocity.z = direction.z * SPEED
                rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 7.0, 1.0))
        Mode.WINDUP:
            _mat.albedo_color = Color(0.95, 0.22, 0.23)
            if _mode_time <= 0.0:
                if is_instance_valid(player) and distance <= ATTACK_RANGE + 0.45 and player.has_method("receive_damage"):
                    player.receive_damage(damage)
                mode = Mode.RECOVER
                _mode_time = RECOVERY_SECONDS
        Mode.RECOVER:
            _mat.albedo_color = Color(0.62, 0.38, 0.35)
            if _mode_time <= 0.0:
                mode = Mode.CHASE
        Mode.STAGGER:
            _mat.albedo_color = Color(0.92, 0.85, 0.25)
            if _mode_time <= 0.0:
                mode = Mode.CHASE
    if mode != Mode.CHASE:
        velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
    move_and_slide()

func take_damage(amount: float, _instigator: Node) -> void:
    if _dead or amount <= 0.0:
        return
    hp -= amount
    if hp <= 0.0:
        _dead = true
        mode = Mode.DEAD
        remove_from_group("damageable")
        remove_from_group("hostiles")
        defeated.emit(self)
        queue_free()
    else:
        mode = Mode.STAGGER
        _mode_time = 0.22
