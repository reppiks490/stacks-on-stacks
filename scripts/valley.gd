extends Node3D
const WorldCollision = preload("res://scripts/world_collision.gd")
## Procedural valley shell of exclusively original primitive shapes.
var game
var material_cache: Dictionary = {}
var forage_locations: Array[Vector3] = []
var forage_day: int = -1
var fishing_day: int = -1
var lake_center := Vector3(27.0, 0.0, -28.0)

func setup(host) -> void:
    game = host
    _land()
    _paths()
    _farmhouse()
    _town()
    _lake()
    _woods()
    _hills()
    _wayfinding()
    var art := Node3D.new()
    art.name = "EverBloomLivingArt"
    art.set_script(load("res://scripts/visual_environment.gd"))
    add_child(art)
    art.setup(self)
    var scenery := Node3D.new()
    scenery.name = "OriginalHomesteadArt"
    scenery.set_script(load("res://scripts/premium_scenery.gd"))
    add_child(scenery)
    scenery.build_homestead(game)
    var continent := Node3D.new()
    continent.name = "EverbloomContinentalFrontier"
    continent.set_script(load("res://scripts/continental_world.gd"))
    add_child(continent)
    continent.setup(game)

func material(tint: Color) -> StandardMaterial3D:
    var key := tint.to_html()
    if material_cache.has(key):
        return material_cache[key]
    var result := StandardMaterial3D.new()
    result.albedo_color = tint
    result.roughness = 0.86
    material_cache[key] = result
    return result

func box(at: Vector3, extent: Vector3, tint: Color, parent: Node3D = self) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = extent
    mesh_instance.mesh = mesh
    mesh_instance.position = at
    mesh_instance.material_override = material(tint)
    parent.add_child(mesh_instance)
    # All substantial structural boxes get the same physical volume as the visible model.
    if extent.y >= 0.55 and extent.x >= 0.12 and extent.z >= 0.12:
        WorldCollision.solid_box(mesh_instance,extent)
    return mesh_instance

func sphere(at: Vector3, radius: float, tint: Color, parent: Node3D = self) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 8
    mesh_instance.mesh = mesh
    mesh_instance.position = at
    mesh_instance.material_override = material(tint)
    parent.add_child(mesh_instance)
    return mesh_instance

func _land() -> void:
    box(Vector3(0, -0.5, 0), Vector3(145, 1, 145), Color("#a0bb82"))
    var body := StaticBody3D.new()
    add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(145, 1, 145)
    collider.shape = shape
    collider.position.y = -0.5
    body.add_child(collider)

func _paths() -> void:
    box(Vector3(7, 0.015, 0), Vector3(65, 0.03, 3.0), Color("#d9c7a4"))
    box(Vector3(28, 0.02, -11), Vector3(3.0, 0.035, 27), Color("#d9c7a4"))
    box(Vector3(-15, 0.02, 14), Vector3(3.0, 0.035, 40), Color("#d9c7a4"))

func _house(at: Vector3, walls: Color, roof: Color, width: float = 6.0) -> void:
    # Single original architectural surface-kit replaces box + wedge primitives.
    var home:=Node3D.new()
    home.name="AuthoredLarkspurHouse"
    home.position=at
    home.set_script(load("res://scripts/sculpted_architecture.gd"))
    add_child(home)
    var style: int=posmod(int(round(at.x*3.0+at.z*7.0)),5)
    home.build_house(width,4.0,walls,roof,style)

func _farmhouse() -> void:
    _house(Vector3(-23, 0, -14), Color("#f0e5ca"), Color("#ba7662"), 7.0)
    _house(Vector3(-4, 0, -15), Color("#b6b48e"), Color("#846a53"), 8.0)
    for idx in range(5):
        box(Vector3(-17 + idx * 2.4, 0.55, 10), Vector3(0.22, 1.1, 0.25), Color("#88694a"))
        box(Vector3(-17 + idx * 2.4, 0.55, 18), Vector3(0.22, 1.1, 0.25), Color("#88694a"))
    box(Vector3(-5, 0.62, -5), Vector3(2.4, 1.24, 1.8), Color("#98724b"))

func _town() -> void:
    _house(Vector3(22,0,10), Color("#d8a88c"), Color("#8f627d"))
    _house(Vector3(34,0,12), Color("#b9ceb1"), Color("#60989b"))
    _house(Vector3(44,0,5), Color("#e3d0a7"), Color("#a27660"))
    _house(Vector3(35,0,-7), Color("#b3aec9"), Color("#6c768c"))
    sphere(Vector3(30,2.3,0), 1.4, Color("#e9ce89"))
    box(Vector3(30,0.65,0),Vector3(0.9,1.3,0.9),Color("#a89575"))
    for i in range(10):
        var angle = float(i) * TAU / 10.0
        sphere(Vector3(30 + cos(angle)*6.0,0.2, sin(angle)*6.0),0.22,Color("#e9b9b8"))

func _lake() -> void:
    var circle := CylinderMesh.new()
    circle.top_radius = 8.5
    circle.bottom_radius = 8.5
    circle.height = 0.06
    circle.radial_segments = 40
    var lake := MeshInstance3D.new()
    lake.mesh = circle
    lake.position = lake_center + Vector3(0, 0.075, 0)
    lake.material_override = material(Color("#68aac5"))
    add_child(lake)
    for i in range(8):
        var a: float = float(i) * TAU / 8.0
        sphere(lake_center + Vector3(cos(a)*9.4,0.4,sin(a)*9.4),0.5,Color("#d6d8bd"))

func _woods() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261101
    for i in range(85):
        var x: float = rng.randf_range(-60.0, 56.0)
        var z: float = rng.randf_range(-58.0, 56.0)
        if Vector2(x+15,z).length() < 23.0 or Vector2(x-30,z).length() < 21.0 or Vector2(x-27,z+28).length() < 17.0:
            continue
        _tree(Vector3(x,0,z), rng.randf_range(0.75,1.3), i)
        if i % 5 == 0:
            forage_locations.append(Vector3(x+1.0,0,z+1.0))
    for i in range(90):
        var x: float = rng.randf_range(-55,54)
        var z: float = rng.randf_range(-55,54)
        if Vector2(x+15,z).length() < 15.0 or Vector2(x-30,z).length() < 12.0:
            continue
        sphere(Vector3(x,0.2,z), rng.randf_range(0.11,0.25), Color("#f0c8d5") if i%3==0 else Color("#f5e6a8"))

func _tree(at: Vector3, scale: float, index: int) -> void:
    box(at+Vector3(0,1.2*scale,0),Vector3(0.55*scale,2.6*scale,0.55*scale),Color("#785e43"))
    var leaf := Color("#75a36e") if index%3 else Color("#98b87a")
    sphere(at+Vector3(0,3.0*scale,0),1.55*scale,leaf)
    sphere(at+Vector3(-0.8*scale,2.7*scale,0),1.1*scale,leaf.lightened(0.1))

func _hills() -> void:
    for i in range(9):
        var x = -52 + i * 13
        sphere(Vector3(float(x),-1.2,67.0),13.0, Color("#83a190"))
    for i in range(8):
        var z = -55 + i * 15
        sphere(Vector3(-68.0,-1.4,float(z)),12.5,Color("#849e80"))

func _wayfinding() -> void:
    for data in [
        ["HOME",Vector3(-15,0.2,5)],["LARKSPUR",Vector3(19,0.2,0)],
        ["GLIMMER LAKE",Vector3(27,0.2,-16)],["HIGH HILL",Vector3(0,0.2,22)]
    ]:
        box(data[1] + Vector3(0, 0.8, 0),Vector3(0.22,1.6,0.22),Color("#886c4c"))
        var sign := Label3D.new()
        sign.text = data[0]
        sign.font_size = 45
        sign.pixel_size = 0.005
        sign.position = data[1] + Vector3(0,2,0)
        sign.modulate = Color("#624a3a")
        add_child(sign)

func act(mode: String, position: Vector3) -> String:
    if mode == "fish":
        if position.distance_to(lake_center) > 12.0:
            return "Visit Glimmer Lake to fish."
        if fishing_day == game.day:
            return "The fishing spot needs time to recover."
        if not game.spend_energy(8.0):
            return "You are too tired to cast the line."
        fishing_day = game.day
        game.grant_item("fish", 1)
        return "A silverfin fish tugs your line! +1 fish"
    for point in forage_locations:
        if position.distance_to(point) < 3.5 and forage_day != game.day:
            if not game.spend_energy(3.0):
                return "You need rest before gathering more herbs."
            game.grant_item("wild_herb", 2)
            forage_day = game.day
            game.add_restoration(1)
            return "You gathered two aromatic herbs from the forest."
    return "Explore the groves and search among the flowers."
