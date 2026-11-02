extends CharacterBody3D
## Local third-person action actor; attacks cannot bypass stamina/cooldown.
signal died
signal struck(target: Node)
signal pulse_used

const Combat = preload("res://scripts/combat_rules.gd")
const SPEED := 7.2
const SPRINT_SPEED := 10.0
const JUMP_SPEED := 8.0
const GRAVITY := 19.6

var hp: float = 120.0
var stamina: float = 100.0
var pulse_multiplier: float = 1.0
var _next_strike_at: float = 0.0
var _next_pulse_at: float = 0.0
var _invulnerable_until: float = 0.0
var _dodge_until: float = 0.0
var _dodge_vector: Vector3 = Vector3.ZERO
var _alive: bool = true
var _camera_pivot: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _sword: MeshInstance3D

func _ready() -> void:
    add_to_group("players")
    collision_layer = 1
    collision_mask = 1
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.37
    capsule.height = 1.9
    collider.shape = capsule
    add_child(collider)

    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.37
    mesh.height = 1.9
    body.mesh = mesh
    var matte := StandardMaterial3D.new()
    matte.albedo_color = Color(0.20, 0.27, 0.36)
    matte.metallic = 0.5
    matte.roughness = 0.38
    body.material_override = matte
    add_child(body)

    _sword = MeshInstance3D.new()
    var blade := BoxMesh.new()
    blade.size = Vector3(0.12, 1.25, 0.19)
    _sword.mesh = blade
    _sword.position = Vector3(0.50, 0.05, -0.35)
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.81, 0.74, 0.9)
    steel.metallic = 0.75
    _sword.material_override = steel
    add_child(_sword)

    _camera_pivot = Node3D.new()
    _camera_pivot.position = Vector3(0, 1.25, 0)
    add_child(_camera_pivot)
    _arm = SpringArm3D.new()
    _arm.spring_length = 5.5
    _arm.rotation.x = -0.24
    _camera_pivot.add_child(_arm)
    _camera = Camera3D.new()
    _camera.current = true
    _camera.fov = 72.0
    _arm.add_child(_camera)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _camera_pivot.rotation.y -= event.relative.x * 0.003
        _arm.rotation.x = clampf(_arm.rotation.x - event.relative.y * 0.003, -1.0, 0.45)
    if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        if event.button_index == MOUSE_BUTTON_LEFT:
            strike()
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                else:
                    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            KEY_F:
                pulse()
            KEY_CTRL:
                dodge()

func _physics_process(delta: float) -> void:
    if not _alive:
        return
    stamina = minf(100.0, stamina + (11.0 if Input.is_key_pressed(KEY_SHIFT) else 18.0) * delta)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = JUMP_SPEED
    else:
        velocity.y = -0.05

    var input_axis := Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        input_axis.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        input_axis.y += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_axis.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_axis.x += 1.0
    if Input.get_connected_joypads().size() > 0:
        var joy := Input.get_connected_joypads()[0]
        input_axis.x += Input.get_joy_axis(joy, JOY_AXIS_LEFT_X)
        input_axis.y += Input.get_joy_axis(joy, JOY_AXIS_LEFT_Y)
    input_axis = input_axis.limit_length(1.0)
    var forward := -_camera_pivot.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var right := _camera_pivot.global_transform.basis.x
    right.y = 0.0
    right = right.normalized()
    var movement := (right * input_axis.x - forward * input_axis.y).normalized()
    var now := Time.get_ticks_msec() / 1000.0
    if now < _dodge_until:
        velocity.x = _dodge_vector.x * 17.0
        velocity.z = _dodge_vector.z * 17.0
    else:
        var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) and stamina > 1.5 else SPEED
        if speed == SPRINT_SPEED and input_axis.length() > 0.1:
            stamina = maxf(0.0, stamina - 9.0 * delta)
        velocity.x = move_toward(velocity.x, movement.x * speed, 18.0 * delta)
        velocity.z = move_toward(velocity.z, movement.z * speed, 18.0 * delta)
        if movement.length_squared() > 0.02:
            rotation.y = lerp_angle(rotation.y, atan2(-movement.x, -movement.z), minf(1.0, 12.0 * delta))
    move_and_slide()
    if global_position.y < -12.0:
        receive_damage(999.0)

func _forward() -> Vector3:
    return -global_transform.basis.z.normalized()

func strike() -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if not _alive or now < _next_strike_at or stamina < Combat.STRIKE_COST:
        return
    stamina -= Combat.STRIKE_COST
    _next_strike_at = now + Combat.STRIKE_COOLDOWN
    _sword.rotation.z = -0.9
    create_tween().tween_property(_sword, "rotation:z", 0.95, 0.12).chain().tween_property(_sword, "rotation:z", 0.0, 0.21)
    for entity in get_tree().get_nodes_in_group("damageable"):
        if entity == self or not is_instance_valid(entity):
            continue
        if not entity.has_method("take_damage"):
            continue
        if not entity is Node3D:
            continue
        var target_node: Node3D = entity as Node3D
        var direction: Vector3 = target_node.global_position - global_position
        direction.y = 0.0
        var distance := direction.length()
        if distance <= Combat.STRIKE_RANGE and distance > 0.01 and _forward().dot(direction / distance) >= 0.16:
            entity.call("take_damage", Combat.STRIKE_DAMAGE, self)
            struck.emit(entity)

func pulse() -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if not _alive or now < _next_pulse_at or stamina < Combat.PULSE_COST:
        return
    stamina -= Combat.PULSE_COST
    _next_pulse_at = now + Combat.PULSE_COOLDOWN
    pulse_used.emit()
    for entity in get_tree().get_nodes_in_group("damageable"):
        if not is_instance_valid(entity) or entity == self or not entity.has_method("take_damage"):
            continue
        if entity is Node3D and (entity as Node3D).global_position.distance_to(global_position) <= Combat.PULSE_RADIUS:
            entity.call("take_damage", Combat.PULSE_DAMAGE * pulse_multiplier, self)

func dodge() -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if not _alive or now < _dodge_until or stamina < Combat.DODGE_COST:
        return
    stamina -= Combat.DODGE_COST
    _dodge_until = now + Combat.DODGE_DURATION
    _invulnerable_until = now + Combat.DODGE_DURATION * 0.72
    _dodge_vector = _forward()

func receive_damage(amount: float) -> void:
    if not _alive or amount <= 0.0:
        return
    if Time.get_ticks_msec() / 1000.0 < _invulnerable_until:
        return
    hp = maxf(0.0, hp - amount)
    if hp <= 0.0:
        _alive = false
        died.emit()

func restore_health(amount: float) -> void:
    if _alive:
        hp = minf(120.0, hp + maxf(0.0, amount))

func restore_from_save(saved_health: float) -> void:
    hp = clampf(saved_health, 1.0, 120.0)
    stamina = 100.0
    _alive = true
    velocity = Vector3.ZERO
    global_position = Vector3(0, 1.15, 0)
