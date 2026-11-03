extends Node3D
## First-party wild mounts and pets. Local optional configuration, no save schema changes.
const PROFILE_PATH := "user://everbloom_companions.cfg"
const HORSES: Array[Dictionary] = [
    {"id":"chestnut_comet","name":"Comet","x":-31.0,"z":24.0,"tint":"#9c6650"},
    {"id":"silver_mist","name":"Mist","x":112.0,"z":125.0,"tint":"#b6bcc7"},
    {"id":"willow_fawn","name":"Willow","x":242.0,"z":144.0,"tint":"#bd9474"},
    {"id":"sunfire","name":"Sunfire","x":402.0,"z":-313.0,"tint":"#d4a36d"},
    {"id":"moonstep","name":"Moonstep","x":-465.0,"z":452.0,"tint":"#9a8fbc"},
    {"id":"winterwind","name":"Winterwind","x":-486.0,"z":-483.0,"tint":"#d4d7dc"},
    {"id":"harbor_rider","name":"Harbor","x":307.0,"z":-469.0,"tint":"#7f6e64"},
    {"id":"kingdom_dawn","name":"Dawn","x":516.0,"z":483.0,"tint":"#d7b27d"}
]
const PETS: Array[Dictionary] = [
    {"id":"poppy_dog","name":"Poppy","x":-13.0,"z":17.0,"tint":"#dbb184"},
    {"id":"miso_cat","name":"Miso","x":-4.0,"z":-10.0,"tint":"#b6b1a4"},
    {"id":"pebble_fox","name":"Pebble","x":35.0,"z":25.0,"tint":"#c87e5c"},
    {"id":"fern_dog","name":"Fern","x":220.0,"z":101.0,"tint":"#80695d"},
    {"id":"luna_cat","name":"Luna","x":-295.0,"z":208.0,"tint":"#9686a1"},
    {"id":"starlight_fox","name":"Star","x":-493.0,"z":442.0,"tint":"#d2bec4"},
    {"id":"saffron_dog","name":"Saffron","x":514.0,"z":495.0,"tint":"#be9d70"}
]
var game
var world
var animals: Dictionary={}
var tamed_mounts: Dictionary={}
var tamed_pets: Dictionary={}
var active_mount: String=""
var active_pet: String=""
var is_mounted: bool=false
var elapsed: float=0.0

func setup(host,continent) -> void:
    game=host
    world=continent
    _load()
    _make_animals()
    set_process(true)

func _material(tint: Color) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=tint
    m.roughness=0.9
    return m

func _shape(parent: Node3D,name: String,point: Vector3,size: Vector3,tint: Color) -> MeshInstance3D:
    var piece:=MeshInstance3D.new()
    piece.name=name
    var ball:=SphereMesh.new()
    ball.radius=0.5
    ball.height=1.0
    ball.radial_segments=12
    ball.rings=8
    piece.mesh=ball
    piece.position=point
    piece.scale=size
    piece.material_override=_material(tint)
    parent.add_child(piece)
    return piece

func _make_animals() -> void:
    for source in HORSES:
        _make_animal(source,true)
    for source in PETS:
        _make_animal(source,false)

func _make_animal(source: Dictionary,is_horse: bool) -> void:
    var animal:=Node3D.new()
    var id:=str(source["id"])
    animal.name="Companion_"+id
    animal.position=Vector3(float(source["x"]),0.0,float(source["z"]))
    add_child(animal)
    var tint:=Color(str(source["tint"]))
    var scale_factor:=1.0 if is_horse else 0.54
    _shape(animal,"Body",Vector3(0,1.15,0),Vector3(1.1,1.05,1.85)*scale_factor,tint)
    _shape(animal,"Neck",Vector3(0,1.56,0.63)*scale_factor,Vector3(0.58,1.08,0.70)*scale_factor,tint.lightened(0.06))
    _shape(animal,"Head",Vector3(0,1.83,1.02)*scale_factor,Vector3(0.65,0.70,0.75)*scale_factor,tint.lightened(0.12))
    _shape(animal,"Muzzle",Vector3(0,1.66,1.38)*scale_factor,Vector3(0.46,0.32,0.38)*scale_factor,tint.lightened(0.22))
    for side in [-1,1]:
        for front in [-1,1]:
            _shape(animal,"Leg_%d_%d" % [side,front],
                Vector3(float(side)*0.35,0.47,float(front)*0.61)*scale_factor,
                Vector3(0.28,0.91,0.29)*scale_factor,tint.darkened(0.13))
        _shape(animal,"Ear_%d" % side,
            Vector3(float(side)*0.22,2.29,0.9)*scale_factor,
            Vector3(0.19,0.40,0.17)*scale_factor,tint.darkened(0.09))
        _shape(animal,"Eye_%d" % side,
            Vector3(float(side)*0.30,1.87,1.28)*scale_factor,
            Vector3(0.105,0.105,0.08)*scale_factor,Color("#312c2a"))
    _shape(animal,"Tail",Vector3(0,1.21,-1.0)*scale_factor,
        Vector3(0.25,0.65,0.65)*scale_factor,tint.darkened(0.28))
    if is_horse:
        _shape(animal,"Mane",Vector3(0,1.91,0.52),Vector3(0.3,0.95,0.9),tint.darkened(0.27))
        _shape(animal,"Saddle",Vector3(0,1.69,-0.13),Vector3(0.99,0.16,0.92),Color("#765b48"))
    else:
        _shape(animal,"Collar",Vector3(0,1.45,0.34)*scale_factor,
            Vector3(0.61,0.19,0.59)*scale_factor,Color("#d6b276"))
    var nametag:=Label3D.new()
    nametag.text=str(source["name"])+"  •  "+("MOUNT" if is_horse else "PET")
    nametag.position=Vector3(0,3.1 if is_horse else 1.8,0)
    nametag.font_size=40
    nametag.pixel_size=0.003
    nametag.modulate=Color("#fff1d5")
    animal.add_child(nametag)
    animals[id]={
        "node":animal,"origin":animal.position,"name":str(source["name"]),
        "mount":is_horse,"offset":float(id.length())*0.7
    }

func _nearest(is_horse: bool) -> String:
    if game==null or game.hero==null:
        return ""
    var distance:=5.0 if is_horse else 3.4
    var nearest: String=""
    for id in animals:
        var data: Dictionary=animals[id]
        if bool(data["mount"])!=is_horse:
            continue
        var animal: Node3D=data["node"]
        var d:=animal.global_position.distance_to(game.hero.global_position)
        if d<distance:
            distance=d
            nearest=str(id)
    return nearest

func _tame(mount_id: String) -> bool:
    if mount_id.is_empty() or not animals.has(mount_id):
        return false
    if not game.consume_item("fodder",2):
        game._show("Bring 2 fodder to befriend a wild mount.")
        return false
    tamed_mounts[mount_id]=true
    active_mount=mount_id
    _save()
    game._show("You bonded with %s! Press N to ride or dismount." % str(animals[mount_id]["name"]))
    return true

func _mount() -> void:
    if game==null or game.hero==null:
        return
    if is_mounted:
        is_mounted=false
        game.hero.walking_speed=7.0
        game.hero.ride_offset=0.0
        if animals.has(active_mount):
            var mount: Node3D=animals[active_mount]["node"]
            mount.position=game.hero.global_position+Vector3(1.6,0,0)
        game._show("Dismounted. Your companion stays nearby.")
        return
    var nearby:=_nearest(true)
    if not nearby.is_empty():
        if not tamed_mounts.has(nearby) and not _tame(nearby):
            return
        active_mount=nearby
    elif active_mount.is_empty() or not tamed_mounts.has(active_mount):
        game._show("Find a horse, deer, or other mount and press N nearby with 2 fodder.")
        return
    is_mounted=true
    game.hero.walking_speed=13.5
    game.hero.ride_offset=1.13
    _save()
    game._show("Riding %s — faster continental travel!" % str(animals[active_mount]["name"]))

func _pet() -> void:
    if game==null or game.hero==null:
        return
    var nearby:=_nearest(false)
    if not nearby.is_empty():
        if not tamed_pets.has(nearby):
            if not game.consume_item("wild_herb",1) and not game.consume_item("fodder",1):
                game._show("Offer 1 wild herb or fodder to befriend a pet.")
                return
            tamed_pets[nearby]=true
        active_pet=nearby
        _save()
        game._show("%s is your companion! They will follow you across the world." % str(animals[nearby]["name"]))
    elif not active_pet.is_empty():
        active_pet=""
        _save()
        game._show("Your pet will rest until you call them again.")
    else:
        game._show("Approach a friendly animal and press B to adopt a pet.")

func _process(delta: float) -> void:
    if game==null or game.hero==null:
        return
    elapsed+=delta
    for id in animals:
        var data: Dictionary=animals[id]
        var node: Node3D=data["node"]
        if not is_instance_valid(node):
            continue
        var origin: Vector3=data["origin"]
        if is_mounted and str(id)==active_mount:
            node.global_position=game.hero.global_position+Vector3(0,-0.02,0)
            node.rotation.y=game.hero.rotation.y
            continue
        if str(id)==active_pet and tamed_pets.has(id):
            var target: Vector3 = game.hero.global_position + Vector3(-1.2,0,1.4)
            node.global_position=node.global_position.lerp(target,minf(1.0,delta*3.2))
            node.rotation.y=lerp_angle(node.rotation.y,game.hero.rotation.y,minf(1.0,delta*4.0))
            continue
        if str(id)==active_mount and tamed_mounts.has(id):
            var spot: Vector3 = game.hero.global_position + Vector3(2.2,0,2.3)
            if node.global_position.distance_to(spot)>6.0:
                node.global_position=node.global_position.lerp(spot,minf(1.0,delta*2.0))
            continue
        node.position=origin+Vector3(sin(elapsed*0.35+float(data["offset"]))*0.80,0,
            cos(elapsed*0.27+float(data["offset"]))*0.7)

func _save() -> void:
    var cfg:=ConfigFile.new()
    cfg.set_value("companions","mounts",tamed_mounts)
    cfg.set_value("companions","pets",tamed_pets)
    cfg.set_value("companions","mount",active_mount)
    cfg.set_value("companions","pet",active_pet)
    if cfg.save(PROFILE_PATH)!=OK:
        push_warning("Could not persist companion roster.")

func _load() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load(PROFILE_PATH)!=OK:
        return
    var mounts: Variant=cfg.get_value("companions","mounts",{})
    var pets: Variant=cfg.get_value("companions","pets",{})
    if mounts is Dictionary:
        tamed_mounts=mounts
    if pets is Dictionary:
        tamed_pets=pets
    active_mount=str(cfg.get_value("companions","mount",""))
    active_pet=str(cfg.get_value("companions","pet",""))

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if game!=null and game.hero!=null and game.hero.studio_open:
        return
    if event.keycode==KEY_N:
        _mount()
        get_viewport().set_input_as_handled()
    elif event.keycode==KEY_B:
        _pet()
        get_viewport().set_input_as_handled()
