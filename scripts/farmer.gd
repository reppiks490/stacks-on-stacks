extends CharacterBody3D
const MovementPhysics = preload("res://scripts/movement_physics.gd")
const SculptedHumanoid = preload("res://scripts/sculpted_humanoid.gd")
## Original customizable, animated EVERBLOOM farmer assembled from authored geometry.
## Press C to enter the avatar atelier; Tab to choose a category and arrows to vary it.
const PROFILE_PATH := "user://everbloom_avatar.cfg"
const CATEGORIES := ["skin","face","jaw","brow","nose","mouth","eyes","eye_size","hair","hair_color","hair_length","outfit","pants","build","height","footwear","headwear","accessory"]
const LABELS := ["Skin tone","Face shape","Jaw structure","Eyebrow shape","Nose shape","Mouth shape","Eye color","Eye size","Hair style","Hair color","Hair length","Outerwear","Trousers","Body silhouette","Height","Boot and shoe style","Headwear","Accessory"]
const OPTIONS := {
    "skin":10,"face":6,"jaw":9,"brow":10,"nose":10,"mouth":10,
    "eyes":7,"eye_size":9,"hair":12,"hair_color":12,"hair_length":10,
    "outfit":12,"pants":10,"build":5,"height":9,"footwear":10,
    "headwear":7,"accessory":6
}
const SKINS := ["#f8dcc4","#f2c9ab","#dfad8c","#bd8160","#976047","#6f4539","#4b3029","#f1d0b8","#c99777","#ad7360"]
const HAIR_COLORS := ["#292527","#574039","#876345","#bf8d59","#e6c18a","#5d352c","#9c4a35","#d87855","#e4d8b4","#e4d4ee","#405b6b","#8e6999"]
const EYE_COLORS := ["#47352d","#5d7c53","#658da0","#94734e","#78897b","#916c97","#a97557"]
const COATS := ["#4a806f","#c87764","#6284a7","#b09a66","#b65e68","#685a93","#f0d09d","#6d935a","#a17b58","#435a68","#d09f85","#8e5875"]
const TROUSERS := ["#344653","#665044","#797d62","#4d6678","#8f6c62","#363f46","#a08c73","#5b5b71","#7c7668","#464c45"]
var game
var walking_speed: float = 7.0
var visual_root: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var anim_clock: float = 0.0
var preview_yaw: float = 0.0
var ride_offset: float = 0.0
var exertion: float = 100.0
var jump_was_pressed: bool = false
var footfall_time: float = 0.0
var profile: Dictionary = {
    "skin":3,"face":1,"jaw":3,"brow":4,"nose":2,"mouth":3,
    "eyes":1,"eye_size":3,"hair":2,"hair_color":2,"hair_length":3,
    "outfit":0,"pants":0,"build":1,"height":4,"footwear":2,
    "headwear":0,"accessory":0
}
var studio_open: bool = false
var selected_category: int = 0
var studio_layer: CanvasLayer
var studio_panel: PanelContainer
var atelier_title: Label
var atelier_details: Label
var atelier_hint: Label
var atelier_swatch: ColorRect

func setup(host) -> void:
    game = host
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.75
    collision.shape = capsule
    collision.position.y = 0.91
    add_child(collision)
    _load_profile()
    _rebuild_avatar()
    _create_studio()

func _color(palette: Array, selection: String) -> Color:
    return Color(str(palette[int(profile.get(selection, 0)) % palette.size()]))

func _rebuild_avatar() -> void:
    # Existing profile config continues to drive the new original sculpted
    # anatomy. All previous profile keys are still accepted unchanged.
    if visual_root!=null:
        remove_child(visual_root)
        visual_root.queue_free()
    visual_root=Node3D.new()
    visual_root.name="SculptedCustomizableFarmer"
    add_child(visual_root)
    var sculpt:=Node3D.new()
    sculpt.name="ArticulatedCharacterMesh"
    sculpt.set_script(SculptedHumanoid)
    visual_root.add_child(sculpt)
    var appearance: Dictionary=profile.duplicate(true)
    appearance["skin_tint"]=_color(SKINS,"skin")
    appearance["hair_tint"]=_color(HAIR_COLORS,"hair_color")
    appearance["iris_tint"]=_color(EYE_COLORS,"eyes")
    appearance["coat_tint"]=_color(COATS,"outfit")
    appearance["trousers_tint"]=_color(TROUSERS,"pants")
    appearance["boot_tint"]=Color("#665044")
    sculpt.configure(appearance)
    left_arm=sculpt.left_arm
    right_arm=sculpt.right_arm
    left_leg=sculpt.left_leg
    right_leg=sculpt.right_leg

func _load_profile() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(PROFILE_PATH) != OK:
        return
    for category in CATEGORIES:
        profile[category] = clampi(int(cfg.get_value("avatar",category,profile[category])),0,int(OPTIONS[category])-1)

func _save_profile() -> void:
    var cfg := ConfigFile.new()
    for category in CATEGORIES:
        cfg.set_value("avatar",category,profile[category])
    if cfg.save(PROFILE_PATH) != OK:
        push_warning("EVERBLOOM avatar customization could not be saved.")

func _create_studio() -> void:
    studio_layer = CanvasLayer.new()
    studio_layer.name = "CharacterCustomizationAtelier"
    studio_layer.layer = 10
    add_child(studio_layer)
    studio_panel = PanelContainer.new()
    studio_panel.position = Vector2(18,130)
    studio_panel.custom_minimum_size = Vector2(380,0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.065,0.14,0.16,0.94)
    style.border_color = Color("#c3a879")
    style.set_border_width_all(2)
    style.set_corner_radius_all(15)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 18
    style.content_margin_bottom = 18
    studio_panel.add_theme_stylebox_override("panel",style)
    studio_layer.add_child(studio_panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",11)
    studio_panel.add_child(column)
    atelier_title = Label.new()
    atelier_title.add_theme_font_size_override("font_size",22)
    atelier_title.add_theme_color_override("font_color",Color("#f4dfaa"))
    column.add_child(atelier_title)
    atelier_details = Label.new()
    atelier_details.add_theme_font_size_override("font_size",17)
    atelier_details.add_theme_color_override("font_color",Color("#fff5e3"))
    column.add_child(atelier_details)
    atelier_swatch = ColorRect.new()
    atelier_swatch.custom_minimum_size = Vector2(100,12)
    atelier_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(atelier_swatch)
    atelier_hint = Label.new()
    atelier_hint.text = "TAB: category    LEFT / RIGHT: change\nA / D: rotate preview    C or ESC: close"
    atelier_hint.add_theme_font_size_override("font_size",13)
    atelier_hint.add_theme_color_override("font_color",Color("#c9d5c3"))
    column.add_child(atelier_hint)
    studio_panel.hide()
    _refresh_studio()

func _refresh_studio() -> void:
    if atelier_title == null:
        return
    var key: String = CATEGORIES[selected_category]
    atelier_title.text = "THE EVERBLOOM ATELIER"
    atelier_details.text = "%s  (%d / %d)\nStyle %d  ◀   ▶" % [
        LABELS[selected_category],selected_category+1,CATEGORIES.size(),int(profile[key])+1]
    if key == "skin":
        atelier_swatch.color = _color(SKINS,key)
    elif key == "hair_color":
        atelier_swatch.color = _color(HAIR_COLORS,key)
    elif key == "eyes":
        atelier_swatch.color = _color(EYE_COLORS,key)
    elif key == "outfit":
        atelier_swatch.color = _color(COATS,key)
    elif key == "pants":
        atelier_swatch.color = _color(TROUSERS,key)
    else:
        atelier_swatch.color = Color("#b69a78")

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if not event.pressed or event.echo:
        return
    if event.keycode == KEY_C:
        studio_open = not studio_open
        studio_panel.visible = studio_open
        get_viewport().set_input_as_handled()
        return
    if not studio_open:
        return
    if event.keycode == KEY_ESCAPE:
        studio_open = false
        studio_panel.hide()
    elif event.keycode == KEY_TAB:
        selected_category = (selected_category+1) % CATEGORIES.size()
        _refresh_studio()
    elif event.keycode == KEY_A or event.keycode == KEY_D:
        preview_yaw += 0.25 if event.keycode == KEY_D else -0.25
        visual_root.rotation.y = preview_yaw
    elif event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
        var key: String = CATEGORIES[selected_category]
        var step: int = 1 if event.keycode == KEY_RIGHT else -1
        profile[key] = posmod(int(profile[key])+step,int(OPTIONS[key]))
        _rebuild_avatar()
        _save_profile()
        _refresh_studio()
    else:
        return
    get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if game == null or game.camera == null:
        return
    if studio_open:
        var focus := global_position + Vector3(2.6,2.8,4.2)
        game.camera.global_position = game.camera.global_position.lerp(focus,minf(1.0,delta*4.0))
        game.camera.look_at(global_position+Vector3(0,1.35,0),Vector3.UP)
        game.camera.fov = lerpf(game.camera.fov,43.0,minf(1.0,delta*4.0))
    else:
        game.camera.fov = lerpf(game.camera.fov,56.0,minf(1.0,delta*3.0))
        if visual_root != null:
            visual_root.rotation.y = lerp_angle(visual_root.rotation.y,0.0,minf(1.0,delta*5.0))

func _physics_process(delta: float) -> void:
    var axis := Vector2.ZERO
    if not studio_open:
        axis = Input.get_vector("move_left","move_right","move_up","move_down")
    var mounted: bool = ride_offset > 0.02
    var ground: bool = is_on_floor()
    var requested_sprint: bool = Input.is_key_pressed(KEY_SHIFT) and not studio_open
    var sprint: bool = requested_sprint and exertion > 5.0 and axis.length() > 0.10
    var target_speed: float = walking_speed * (MovementPhysics.sprint_multiplier(mounted) if sprint else 1.0)
    var desired: Vector2 = axis.normalized() * target_speed
    var planar: Vector2 = Vector2(velocity.x, velocity.z)
    var accel: float = MovementPhysics.planar_acceleration(mounted, ground)
    var drag: float = MovementPhysics.braking_drag(mounted, ground)
    planar = planar.move_toward(desired, (drag if axis.length() < 0.05 else accel) * delta)
    velocity.x = planar.x
    velocity.z = planar.y
    if sprint:
        exertion = maxf(0.0, exertion - MovementPhysics.stamina_drain(mounted) * delta)
    else:
        exertion = minf(100.0, exertion + MovementPhysics.stamina_recovery() * delta)
    var jump_pressed: bool = Input.is_key_pressed(KEY_SPACE) and not studio_open
    floor_snap_length = 0.24
    floor_max_angle = MovementPhysics.max_slope_angle(mounted)
    if ground:
        if jump_pressed and not jump_was_pressed and not studio_open:
            velocity.y = MovementPhysics.jump_impulse(mounted)
        elif velocity.y < 0.0:
            velocity.y = -0.3
    else:
        velocity.y = maxf(velocity.y - MovementPhysics.gravity_force() * delta, -36.0)
    jump_was_pressed = jump_pressed
    move_and_slide()
    var walking: bool = Vector2(velocity.x, velocity.z).length() > 0.12
    if walking:
        rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z),
            minf(1.0, delta * MovementPhysics.mount_turn_limit(mounted)))
    footfall_time += delta * (10.5 if sprint else (7.0 if walking else 1.6))
    anim_clock = footfall_time
    var stride: float = sin(anim_clock) * (0.45 if walking else 0.0)
    if left_arm != null and right_arm != null:
        left_arm.rotation.x = -stride
        right_arm.rotation.x = stride
    if left_leg != null and right_leg != null:
        left_leg.rotation.x = stride * 0.68
        right_leg.rotation.x = -stride * 0.68
    if visual_root != null:
        visual_root.position.y = sin(anim_clock * 0.5) * (0.042 if walking else 0.015) + ride_offset
