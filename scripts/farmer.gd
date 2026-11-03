extends CharacterBody3D
## Original customizable, animated EVERBLOOM farmer assembled from authored geometry.
## Press C to enter the avatar atelier; Tab to choose a category and arrows to vary it.
const PROFILE_PATH := "user://everbloom_avatar.cfg"
const CATEGORIES := ["skin", "face", "hair", "hair_color", "eyes", "outfit", "pants", "build", "headwear", "accessory"]
const LABELS := ["Skin tone", "Face shape", "Hair style", "Hair color", "Eye color", "Outerwear", "Trousers", "Body silhouette", "Headwear", "Accessory"]
const OPTIONS := {
    "skin": 10, "face": 4, "hair": 8, "hair_color": 12, "eyes": 7,
    "outfit": 12, "pants": 10, "build": 5, "headwear": 7, "accessory": 6
}
const SKINS := ["#f8dcc4","#f2c9ab","#dfad8c","#bd8160","#976047","#6f4539","#4b3029","#f1d0b8","#c99777","#ad7360"]
const HAIR_COLORS := ["#292527","#574039","#876345","#bf8d59","#e6c18a","#5d352c","#9c4a35","#d87855","#e4d8b4","#e4d4ee","#405b6b","#8e6999"]
const EYE_COLORS := ["#47352d","#5d7c53","#658da0","#94734e","#78897b","#916c97","#a97557"]
const COATS := ["#4a806f","#c87764","#6284a7","#b09a66","#b65e68","#685a93","#f0d09d","#6d935a","#a17b58","#435a68","#d09f85","#8e5875"]
const TROUSERS := ["#344653","#665044","#797d62","#4d6678","#8f6c62","#363f46","#a08c73","#5b5b71","#7c7668","#464c45"]
var game
var walking_speed: float = 7.0
var coat: MeshInstance3D
var visual_root: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var anim_clock: float = 0.0
var preview_yaw: float = 0.0
var ride_offset: float = 0.0
var profile: Dictionary = {
    "skin": 3, "face": 1, "hair": 2, "hair_color": 2, "eyes": 1,
    "outfit": 0, "pants": 0, "build": 1, "headwear": 0, "accessory": 0
}
var studio_open: bool = false
var selected_category: int = 0
var studio_layer: CanvasLayer
var studio_panel: PanelContainer
var atelier_title: Label
var atelier_details: Label
var atelier_hint: Label
var atelier_swatch: ColorRect
var materials: Dictionary = {}

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

func _material(color: Color) -> StandardMaterial3D:
    var key := color.to_html()
    if materials.has(key):
        return materials[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.81
    materials[key] = mat
    return mat

func _body_part(name: String, at: Vector3, dimensions: Vector3, tint: Color, parent: Node3D) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 16
    mesh.rings = 10
    node.mesh = mesh
    node.position = at
    node.scale = dimensions
    node.material_override = _material(tint)
    parent.add_child(node)
    return node

func _cube(name: String, at: Vector3, dimensions: Vector3, tint: Color, parent: Node3D) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    node.mesh = mesh
    node.position = at
    node.material_override = _material(tint)
    parent.add_child(node)
    return node

func _rebuild_avatar() -> void:
    if visual_root != null:
        remove_child(visual_root)
        visual_root.queue_free()
    visual_root = Node3D.new()
    visual_root.name = "CustomizableFarmer"
    add_child(visual_root)
    var body_type: int = int(profile["build"])
    var widths := [0.78,0.91,1.0,1.13,1.25]
    visual_root.scale = Vector3(widths[body_type],1.0,1.0)
    var skin := _color(SKINS,"skin")
    var hair := _color(HAIR_COLORS,"hair_color")
    var iris := _color(EYE_COLORS,"eyes")
    var cloth := _color(COATS,"outfit")
    var trousers := _color(TROUSERS,"pants")
    var darker := cloth.darkened(0.32)
    var lighter := cloth.lightened(0.2)
    _body_part("BootLeft",Vector3(-0.20,0.13,0.09),Vector3(0.30,0.27,0.47),Color("#664b3f"),visual_root)
    _body_part("BootRight",Vector3(0.20,0.13,0.09),Vector3(0.30,0.27,0.47),Color("#664b3f"),visual_root)
    left_leg = Node3D.new()
    left_leg.name = "LeftLegAnimationPivot"
    left_leg.position = Vector3(-0.20,0.90,0)
    visual_root.add_child(left_leg)
    right_leg = Node3D.new()
    right_leg.name = "RightLegAnimationPivot"
    right_leg.position = Vector3(0.20,0.90,0)
    visual_root.add_child(right_leg)
    _body_part("TrouserLeft",Vector3(0,-0.39,0),Vector3(0.34,0.78,0.36),trousers,left_leg)
    _body_part("TrouserRight",Vector3(0,-0.39,0),Vector3(0.34,0.78,0.36),trousers,right_leg)
    _body_part("TunicHem",Vector3(0,0.91,0),Vector3(0.92,0.38,0.55),darker,visual_root)
    coat = _body_part("TailoredJacket",Vector3(0,1.31,0),Vector3(0.91,0.91,0.58),cloth,visual_root)
    _body_part("Collar",Vector3(0,1.72,0),Vector3(0.72,0.24,0.62),lighter,visual_root)
    _cube("FrontSeam",Vector3(0,1.34,0.293),Vector3(0.045,0.72,0.03),darker,visual_root)
    for i in range(3):
        _body_part("Button"+str(i),Vector3(0,1.52-float(i)*0.24,0.315),Vector3(0.065,0.065,0.035),Color("#e5c48c"),visual_root)
    _cube("LeatherBelt",Vector3(0,0.99,0.0),Vector3(0.94,0.14,0.59),Color("#6c503f"),visual_root)
    _cube("BrassBuckle",Vector3(0,0.99,0.32),Vector3(0.16,0.12,0.05),Color("#d1b279"),visual_root)
    left_arm = Node3D.new()
    left_arm.position = Vector3(-0.48,1.59,0)
    visual_root.add_child(left_arm)
    right_arm = Node3D.new()
    right_arm.position = Vector3(0.48,1.59,0)
    visual_root.add_child(right_arm)
    _body_part("LeftSleeve",Vector3(0,-0.38,0),Vector3(0.32,0.76,0.38),cloth,left_arm)
    _body_part("RightSleeve",Vector3(0,-0.38,0),Vector3(0.32,0.76,0.38),cloth,right_arm)
    _body_part("LeftCuff",Vector3(0,-0.72,0),Vector3(0.34,0.16,0.39),lighter,left_arm)
    _body_part("RightCuff",Vector3(0,-0.72,0),Vector3(0.34,0.16,0.39),lighter,right_arm)
    _body_part("LeftHand",Vector3(0,-0.86,0),Vector3(0.20,0.22,0.21),skin,left_arm)
    _body_part("RightHand",Vector3(0,-0.86,0),Vector3(0.20,0.22,0.21),skin,right_arm)
    _body_part("Neck",Vector3(0,1.77,0),Vector3(0.24,0.28,0.24),skin,visual_root)
    var face_type: int = int(profile["face"])
    var face_widths := [0.61,0.65,0.71,0.66]
    var head := _body_part("Head",Vector3(0,2.08,0.03),Vector3(face_widths[face_type],0.75,0.60),skin,visual_root)
    head.rotation.z = 0.03
    _body_part("LeftEar",Vector3(-0.33,2.08,0),Vector3(0.14,0.24,0.12),skin,visual_root)
    _body_part("RightEar",Vector3(0.33,2.08,0),Vector3(0.14,0.24,0.12),skin,visual_root)
    for side in [-1,1]:
        var px: float = float(side)*0.145
        _body_part("EyeWhite"+str(side),Vector3(px,2.13,0.321),Vector3(0.13,0.12,0.075),Color("#fbf6e9"),visual_root)
        _body_part("Iris"+str(side),Vector3(px,2.13,0.372),Vector3(0.069,0.083,0.038),iris,visual_root)
        _body_part("Pupil"+str(side),Vector3(px,2.13,0.392),Vector3(0.030,0.052,0.015),Color("#182329"),visual_root)
        _body_part("Brow"+str(side),Vector3(px,2.27,0.296),Vector3(0.18,0.046,0.07),hair.darkened(0.25),visual_root)
        _body_part("Cheek"+str(side),Vector3(px*1.55,1.99,0.291),Vector3(0.12,0.06,0.035),skin.lightened(0.045),visual_root)
    _body_part("Nose",Vector3(0,2.04,0.354),Vector3(0.095,0.12,0.13),skin.lightened(0.05),visual_root)
    _body_part("Smile",Vector3(0,1.914,0.32),Vector3(0.19,0.035,0.03),Color("#a56a67"),visual_root)
    _style_hair(hair)
    _headwear()
    _accessories()

func _style_hair(tint: Color) -> void:
    var style: int = int(profile["hair"])
    _body_part("HairCrown",Vector3(0,2.41,-0.01),Vector3(0.70,0.32,0.65),tint,visual_root)
    if style == 0:
        _body_part("PixieSweep",Vector3(-0.15,2.42,0.21),Vector3(0.37,0.22,0.34),tint,visual_root)
    elif style == 1:
        for side in [-1,1]:
            _body_part("Bob"+str(side),Vector3(float(side)*0.32,2.05,0.0),Vector3(0.20,0.62,0.46),tint,visual_root)
    elif style == 2:
        for i in range(5):
            _body_part("Windswept"+str(i),Vector3(-0.27+float(i)*0.14,2.46,0.26),Vector3(0.17,0.23,0.3),tint.lightened(0.025*float(i)),visual_root)
    elif style == 3:
        for side in [-1,1]:
            _body_part("BraidedRoot"+str(side),Vector3(float(side)*0.33,1.96,-0.10),Vector3(0.22,0.72,0.26),tint,visual_root)
            _body_part("BraidTail"+str(side),Vector3(float(side)*0.34,1.57,-0.1),Vector3(0.16,0.36,0.19),tint.darkened(0.08),visual_root)
    elif style == 4:
        _body_part("ArtistBun",Vector3(0,2.59,-0.3),Vector3(0.47,0.44,0.41),tint,visual_root)
        _body_part("SideFringe",Vector3(-0.17,2.29,0.29),Vector3(0.35,0.21,0.18),tint,visual_root)
    elif style == 5:
        for side in [-1,1]:
            _body_part("LongLocks"+str(side),Vector3(float(side)*0.35,1.91,-0.08),Vector3(0.25,0.92,0.41),tint,visual_root)
    elif style == 6:
        for i in range(12):
            var a: float = float(i)*TAU/12.0
            _body_part("NaturalCurls"+str(i),Vector3(cos(a)*0.32,2.39+sin(a*2.1)*0.10,sin(a)*0.28),Vector3(0.30,0.28,0.28),tint,visual_root)
    else:
        _body_part("TopKnot",Vector3(0,2.67,-0.11),Vector3(0.35,0.43,0.35),tint,visual_root)
        _body_part("SidePart",Vector3(0.22,2.35,0.25),Vector3(0.28,0.19,0.24),tint,visual_root)

func _headwear() -> void:
    var index: int = int(profile["headwear"])
    if index == 0:
        return
    var tint := Color("#c9a573")
    if index == 2:
        tint = Color("#4f7687")
    elif index == 3:
        tint = Color("#a35f76")
    elif index == 4:
        tint = Color("#6e876b")
    elif index == 5:
        tint = Color("#e6c596")
    elif index == 6:
        tint = Color("#6d5a8a")
    _body_part("HatCrown",Vector3(0,2.64,0),Vector3(0.59,0.36,0.57),tint,visual_root)
    if index in [1,2,5,6]:
        _body_part("WideHatBrim",Vector3(0,2.49,0),Vector3(1.03,0.09,0.92),tint.darkened(0.08),visual_root)
    elif index == 3:
        _body_part("BeretTilt",Vector3(-0.12,2.73,0),Vector3(0.77,0.18,0.67),tint,visual_root)
    else:
        for i in range(6):
            var a := TAU*float(i)/6.0
            _body_part("BlossomCrown"+str(i),Vector3(cos(a)*0.32,2.54,sin(a)*0.29),Vector3(0.19,0.18,0.19),Color("#f2bdd0"),visual_root)

func _accessories() -> void:
    var index: int = int(profile["accessory"])
    if index == 1:
        for side in [-1,1]:
            _body_part("GlassesRim"+str(side),Vector3(float(side)*0.15,2.12,0.41),Vector3(0.20,0.15,0.04),Color("#c3a978"),visual_root)
        _cube("NoseBridge",Vector3(0,2.14,0.42),Vector3(0.09,0.025,0.04),Color("#c3a978"),visual_root)
    elif index == 2:
        for side in [-1,1]:
            _body_part("Earring"+str(side),Vector3(float(side)*0.36,1.97,0.07),Vector3(0.09,0.15,0.07),Color("#edc87e"),visual_root)
    elif index == 3:
        _body_part("RibbonNecktie",Vector3(0,1.68,0.31),Vector3(0.52,0.16,0.19),Color("#d98f83"),visual_root)
    elif index == 4:
        _body_part("Scarf",Vector3(0,1.7,0.0),Vector3(0.79,0.23,0.69),Color("#e8c19b"),visual_root)
        _body_part("ScarfTail",Vector3(0.30,1.41,0.33),Vector3(0.19,0.53,0.15),Color("#e8c19b"),visual_root)
    elif index == 5:
        _body_part("CanvasBag",Vector3(-0.46,1.04,-0.1),Vector3(0.35,0.58,0.51),Color("#bb9974"),visual_root)
        _cube("BagClasp",Vector3(-0.61,1.07,0.18),Vector3(0.12,0.12,0.08),Color("#d8c68d"),visual_root)

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
    var direction := Vector3(axis.x,0.0,axis.y)
    velocity.x = direction.x * walking_speed
    velocity.z = direction.z * walking_speed
    if not is_on_floor():
        velocity.y -= 22.0*delta
    else:
        velocity.y = 0.0
    move_and_slide()
    if direction.length() > 0.05:
        rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1.0,delta*9.0))
    anim_clock += delta * (9.0 if direction.length()>0.05 else 2.0)
    var stride := sin(anim_clock)*0.42 if direction.length()>0.05 else 0.0
    if left_arm != null and right_arm != null:
        left_arm.rotation.x = -stride
        right_arm.rotation.x = stride
    if left_leg != null and right_leg != null:
        left_leg.rotation.x = stride*0.7
        right_leg.rotation.x = -stride*0.7
    if visual_root != null:
        visual_root.position.y = sin(anim_clock*0.5)*0.025 + ride_offset
