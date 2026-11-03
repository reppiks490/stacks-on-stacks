extends Node3D
const WorldCollision = preload("res://scripts/world_collision.gd")
const SculptedFoliage = preload("res://scripts/sculpted_foliage.gd")
## EVERBLOOM original procedural scenic art pass.
## No imported or extracted game assets. Deterministic placements; no gameplay state changes.
const SIZE: float = 145.0
const GRASS_COUNT: int = 3400
const FLOWER_COUNT: int = 900
const SHRUB_COUNT: int = 440
var world
var rng := RandomNumberGenerator.new()
var material_cache: Dictionary = {}
var ground_material: ShaderMaterial
var last_season: int = -1
var canopy_mesh: ArrayMesh
var trunk_mesh: ArrayMesh
var rock_mesh: ArrayMesh

func setup(parent_world) -> void:
    world = parent_world
    rng.seed = 20261102
    _meadow()
    _wildflower()
    _orchard()
    _village_details()
    # Architectural overlays retired: the original houses now use the shared
    # authored mesh kit rather than layering two overlapping roof meshes.
    _pond_garden()
    _water_shimmer()
    _edge_woodlands()
    _lanterns()
    set_process(true)

func _process(_delta: float) -> void:
    if world == null or world.game == null or ground_material == null:
        return
    var season: int = world.game.season_index
    if season != last_season:
        last_season = season
        ground_material.set_shader_parameter("season", float(season))

func _material(color: Color, rough: float = 0.89) -> StandardMaterial3D:
    var key := color.to_html() + "_" + str(rough)
    if material_cache.has(key):
        return material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = rough
    material_cache[key] = mat
    return mat

func _box(at: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = at
    instance.material_override = _material(color)
    parent.add_child(instance)
    if size.y>=0.65 and size.x>=0.13 and size.z>=0.13:
        WorldCollision.solid_box(instance,size)
    return instance

func _ellipsoid(at: Vector3, scale: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 12
    mesh.rings = 7
    instance.mesh = mesh
    instance.position = at
    instance.scale = scale
    instance.material_override = _material(color)
    parent.add_child(instance)
    return instance

func _pole(at: Vector3, height: float, radius: float, color: Color) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = radius * 0.8
    mesh.height = height
    mesh.radial_segments = 8
    instance.mesh = mesh
    instance.position = at + Vector3(0, height * 0.5, 0)
    instance.material_override = _material(color)
    add_child(instance)
    if height>=1.0 and radius>=0.15:
        WorldCollision.solid_box(instance,Vector3(radius*1.5,height,radius*1.5),"tree_or_post")
    return instance

func _meadow() -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(SIZE, SIZE)
    plane.subdivide_width = 8
    plane.subdivide_depth = 8
    var surface := MeshInstance3D.new()
    surface.name = "SeasonalPainterlyMeadow"
    surface.mesh = plane
    surface.position.y = 0.009
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform float season = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1.0,0.0)), f.x),
               mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0,1.0)), f.x), f.y);
}
void fragment() {
    vec2 p = UV * 145.0;
    float patch = noise2(p * 0.105);
    float fleck = noise2(p * 2.2);
    float moor = noise2(p * 0.034);
    vec3 spring = mix(vec3(0.22,0.44,0.26), vec3(0.46,0.63,0.32), patch);
    vec3 summer = mix(vec3(0.16,0.40,0.23), vec3(0.36,0.58,0.22), patch);
    vec3 autumn = mix(vec3(0.41,0.37,0.19), vec3(0.64,0.51,0.26), patch);
    vec3 winter = mix(vec3(0.65,0.75,0.75), vec3(0.84,0.88,0.84), patch);
    vec3 color = spring;
    if (season > 2.5) { color = winter; }
    else if (season > 1.5) { color = autumn; }
    else if (season > 0.5) { color = summer; }
    color *= 0.91 + fleck * 0.13 + moor * 0.09;
    ALBEDO = color;
    ROUGHNESS = 0.96;
}
"""
    ground_material = ShaderMaterial.new()
    ground_material.shader = shader
    surface.material_override = ground_material
    add_child(surface)
    _scatter_grass()

func _is_open(x: float, z: float) -> bool:
    if absf(x) > 69.0 or absf(z) > 69.0:
        return false
    if absf(z) < 3.6 and x > -34.0 and x < 44.0:
        return false
    if absf(x - 28.0) < 4.0 and z > -26.0 and z < 14.0:
        return false
    if absf(x + 15.0) < 4.0 and z > -7.0 and z < 30.0:
        return false
    if Vector2(x + 15.0, z + 3.0).length() < 19.0:
        return false
    if Vector2(x - 30.0, z - 5.0).length() < 21.0:
        return false
    if Vector2(x - 27.0, z + 28.0).length() < 11.0:
        return false
    return true

func _scatter_grass() -> void:
    var grass := MultiMesh.new()
    grass.transform_format = MultiMesh.TRANSFORM_3D
    grass.use_colors = true
    var blade := QuadMesh.new()
    blade.size = Vector2(0.6, 0.7)
    grass.mesh = blade
    grass.instance_count = GRASS_COUNT
    var leaves := StandardMaterial3D.new()
    leaves.albedo_color = Color.WHITE
    leaves.vertex_color_use_as_albedo = true
    leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
    leaves.roughness = 0.98
    for i in range(GRASS_COUNT):
        var x := rng.randf_range(-68.0,68.0)
        var z := rng.randf_range(-68.0,68.0)
        if not _is_open(x,z):
            x = rng.randf_range(-62.0,-36.0)
            z = rng.randf_range(18.0,55.0)
        var h := rng.randf_range(0.30,0.86)
        var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU))
        basis = basis.scaled(Vector3(rng.randf_range(0.45,0.94),h,1.0))
        grass.set_instance_transform(i,Transform3D(basis,Vector3(x,h*0.34,z)))
        grass.set_instance_color(i,Color("#547c48") if i%4==0 else (Color("#88a65c") if i%3==0 else Color("#6e994e")))
    var patch := MultiMeshInstance3D.new()
    patch.name = "WindMeadowGrass"
    patch.multimesh = grass
    patch.material_override = leaves
    patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    patch.custom_aabb = AABB(Vector3(-72,-1,-72),Vector3(144,5,144))
    add_child(patch)

func _wildflower() -> void:
    var blossom := SphereMesh.new()
    blossom.radius = 0.12
    blossom.height = 0.20
    blossom.radial_segments = 7
    blossom.rings = 4
    var flowers := MultiMesh.new()
    flowers.transform_format = MultiMesh.TRANSFORM_3D
    flowers.use_colors = true
    flowers.mesh = blossom
    flowers.instance_count = FLOWER_COUNT
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.84
    var palette := [Color("#f8d6da"),Color("#ffe4a1"),Color("#b8b4ea"),Color("#f4efe0"),Color("#e88a9b"),Color("#aed9f1")]
    for i in range(FLOWER_COUNT):
        var x := rng.randf_range(-65.0,65.0)
        var z := rng.randf_range(-65.0,65.0)
        if not _is_open(x,z):
            x = rng.randf_range(-61.0,-34.0)
            z = rng.randf_range(18.0,62.0)
        var scale_value := rng.randf_range(0.6,1.5)
        flowers.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ONE*scale_value),Vector3(x,0.26*scale_value,z)))
        flowers.set_instance_color(i,palette[i%palette.size()])
    var node := MultiMeshInstance3D.new()
    node.name = "PollinatorWildflowerCarpets"
    node.multimesh = flowers
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.custom_aabb = AABB(Vector3(-72,-1,-72),Vector3(144,5,144))
    add_child(node)
    var bushmesh := SphereMesh.new()
    bushmesh.radius = 0.5
    bushmesh.height = 1.0
    bushmesh.radial_segments = 10
    bushmesh.rings = 6
    var bushes := MultiMesh.new()
    bushes.transform_format = MultiMesh.TRANSFORM_3D
    bushes.use_colors = true
    bushes.mesh = bushmesh
    bushes.instance_count = SHRUB_COUNT
    for i in range(SHRUB_COUNT):
        var x := rng.randf_range(-64.0,64.0)
        var z := rng.randf_range(-64.0,64.0)
        if not _is_open(x,z):
            x = rng.randf_range(-61.0,-35.0)
            z = rng.randf_range(21.0,62.0)
        var size_factor := rng.randf_range(0.5,1.4)
        bushes.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(1.5,0.68,1.1)*size_factor),Vector3(x,0.32*size_factor,z)))
        bushes.set_instance_color(i,Color("#426f42") if i%3==0 else Color("#739a58"))
    var hedge := MultiMeshInstance3D.new()
    hedge.name = "LayeredWildShrubUnderstory"
    hedge.multimesh = bushes
    hedge.material_override = mat
    hedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    hedge.custom_aabb = AABB(Vector3(-72,-1,-72),Vector3(144,5,144))
    add_child(hedge)

func _flower_cluster(center: Vector3, spread: float, count: int) -> void:
    var shades := [Color("#e59bb2"),Color("#fff0b9"),Color("#b7b5ec"),Color("#fff7eb")]
    for i in range(count):
        var offset := Vector3(rng.randf_range(-spread,spread),0.0,rng.randf_range(-spread,spread))
        var at: Vector3 = center + offset
        _pole(at,0.18,0.032,Color("#67925c"))
        _ellipsoid(at+Vector3(0,0.23,0),Vector3(0.25,0.20,0.25),shades[i%shades.size()])

func _tree(at: Vector3, scale_factor: float, blossom: bool = false) -> void:
    if canopy_mesh==null:
        canopy_mesh=SculptedFoliage.make_canopy_mesh()
        trunk_mesh=SculptedFoliage.make_trunk_mesh()
        rock_mesh=SculptedFoliage.make_rock_mesh()
    var trunk:=MeshInstance3D.new()
    trunk.name="SculptedOrchardTimber"
    trunk.mesh=trunk_mesh
    trunk.position=at+Vector3(0,1.15*scale_factor,0)
    trunk.scale=Vector3(0.6,2.3,0.6)*scale_factor
    trunk.material_override=_material(Color("#72513d"))
    add_child(trunk)
    WorldCollision.solid_box(trunk,Vector3.ONE,"orchard_trunk")
    var crown:=MeshInstance3D.new()
    crown.name="BotanicalBlossomAndLeafCanopy"
    crown.mesh=canopy_mesh
    crown.position=at+Vector3(0,3.03*scale_factor,0)
    crown.scale=Vector3(3.7,3.9,3.5)*scale_factor
    crown.material_override=_material(Color("#e8aec5") if blossom else Color("#608653"))
    add_child(crown)

func _orchard() -> void:
    var origin := Vector3(-47,0,15)
    _box(origin+Vector3(0,0.05,0),Vector3(25,0.09,25),Color("#8ca65e"))
    for row in range(3):
        for col in range(3):
            _tree(Vector3(-56+col*8,0,7+row*8),0.92,((row+col)%3)==0)
    for lane in range(3):
        _box(Vector3(-52+lane*8,0.065,15),Vector3(0.8,0.06,22),Color("#b99a6d"))
    for i in range(14):
        var at := Vector3(-58.0+i*1.7,0,28.0)
        _pole(at,0.7,0.09,Color("#b38e6c"))
        if i%3==0:
            _flower_cluster(at,0.6,2)
    _box(Vector3(-47,1.0,31),Vector3(5,0.18,0.3),Color("#876648"))
    _box(Vector3(-47,2.9,31),Vector3(5.6,0.24,0.45),Color("#b78169"))
    for side in [-1,1]:
        _pole(Vector3(-47+float(side)*2.5,0,31),3.1,0.13,Color("#876648"))

func _village_details() -> void:
    # Market square: two garden kiosks, benches, urns and a small focal fountain.
    var square := Vector3(31,0,0)
    var stone := Color("#c8bb9b")
    for i in range(15):
        var angle: float = float(i)*TAU/15.0
        _ellipsoid(square+Vector3(cos(angle)*4.5,0.12,sin(angle)*4.5),Vector3(1.1,0.23,0.75),stone)
    _ellipsoid(square+Vector3(0,0.29,0),Vector3(3.0,0.6,3.0),Color("#e1d3b6"))
    _ellipsoid(square+Vector3(0,0.52,0),Vector3(2.2,0.17,2.2),Color("#89b7b7"))
    _pole(square+Vector3(0,0.45,0),1.8,0.19,Color("#ded4bd"))
    _ellipsoid(square+Vector3(0,2.48,0),Vector3(0.65,0.65,0.65),Color("#e3d8bd"))
    _ellipsoid(square+Vector3(0,2.85,0),Vector3(0.35,0.52,0.35),Color("#b5d6d7"))
    for side in [-1,1]:
        var origin := Vector3(20+float(side)*10,0,18)
        _box(origin+Vector3(0,0.85,0),Vector3(4.3,0.18,2.8),Color("#8c684c"))
        for j in [-1,1]:
            _pole(origin+Vector3(float(j)*1.8,0,-0.9),2.4,0.11,Color("#725241"))
            _pole(origin+Vector3(float(j)*1.8,0,0.9),2.4,0.11,Color("#725241"))
        var canopy := _box(origin+Vector3(0,2.55,0),Vector3(5,0.23,3.2),Color("#c97c67") if side==1 else Color("#83a57e"))
        canopy.rotation.z = 0.08*float(side)
        _flower_cluster(origin+Vector3(0,0.1,1.5),1.7,12)
    for i in range(4):
        var x := 14.0 + float(i)*13.0
        _box(Vector3(x,0.35,-3.5),Vector3(3.4,0.18,0.9),Color("#997558"))
        _box(Vector3(x,1.0,-4.0),Vector3(3.4,1.2,0.16),Color("#997558"))
        _flower_cluster(Vector3(x,0,-5.0),0.8,6)
    for i in range(6):
        var z := -3.0 + float(i)*4.3
        _ellipsoid(Vector3(12.0,0.35,z),Vector3(1.4,0.7,1.0),Color("#4e7f5e"))
        _flower_cluster(Vector3(12.0,0,z),0.7,5)

func _pond_garden() -> void:
    var lake := Vector3(27,0,-28)
    for i in range(56):
        var a: float = float(i)*TAU/56.0
        var r: float = 8.8+sin(a*9.0)*0.4
        _ellipsoid(lake+Vector3(cos(a)*r,0.16,sin(a)*r),Vector3(0.8,0.4,0.55),Color("#a6aaa1") if i%3 else Color("#d7c9ad"))
    for i in range(31):
        var a: float = rng.randf_range(0.0,TAU)
        var r: float = rng.randf_range(1.5,7.6)
        var at := lake+Vector3(cos(a)*r,0.15,sin(a)*r)
        _ellipsoid(at,Vector3(0.75,0.055,0.65),Color("#679b72"))
        if i%4==0:
            _ellipsoid(at+Vector3(0,0.15,0),Vector3(0.28,0.2,0.3),Color("#eed0da"))
    _box(Vector3(18.0,0.28,-24.0),Vector3(2.8,0.3,8.0),Color("#ac8864"))
    for i in range(5):
        _box(Vector3(18,0.44,-27.0+float(i)*1.5),Vector3(3.2,0.08,0.13),Color("#dbc3a0"))
    _tree(Vector3(11,0,-29),1.08,true)
    _tree(Vector3(42,0,-34),1.25,false)
    _flower_cluster(Vector3(14,0,-20),2.7,30)

func _edge_woodlands() -> void:
    for i in range(64):
        var x := rng.randf_range(-64.0,64.0)
        var z := rng.randf_range(-64.0,64.0)
        if not _is_open(x,z):
            continue
        if Vector2(x+47.0,z-15.0).length()<17.0:
            continue
        if i%3==0:
            _tree(Vector3(x,0,z),rng.randf_range(0.65,1.2),i%7==0)
        else:
            if canopy_mesh==null:
                canopy_mesh=SculptedFoliage.make_canopy_mesh()
            var shrub:=MeshInstance3D.new()
            shrub.name="HandShapedWoodlandShrub"
            shrub.mesh=canopy_mesh
            shrub.position=Vector3(x,0.7,z)
            shrub.scale=Vector3(1.9,1.3,1.7)
            shrub.material_override=_material(Color("#59814b") if i%2==0 else Color("#8b9d61"))
            add_child(shrub)
    for i in range(90):
        var x := rng.randf_range(-67.0,67.0)
        var z := rng.randf_range(-67.0,67.0)
        if _is_open(x,z):
            if rock_mesh==null:
                rock_mesh=SculptedFoliage.make_rock_mesh()
            var stone:=MeshInstance3D.new()
            stone.name="IrregularWoodlandStone"
            stone.mesh=rock_mesh
            stone.position=Vector3(x,0.12,z)
            stone.scale=Vector3(rng.randf_range(0.35,0.9),0.28,rng.randf_range(0.35,0.8))
            stone.material_override=_material(Color("#b4aa94"))
            add_child(stone)


func _cottage_facades() -> void:
    # Handmade shingled facades and gabled roofs over the former simple block homes.
    var homes := [
        [Vector3(-23,0,-14),7.0,Color("#ab6b66"),Color("#f6dfb5")],
        [Vector3(-4,0,-15),8.0,Color("#776b63"),Color("#dfd7ac")],
        [Vector3(22,0,10),6.0,Color("#9b6978"),Color("#e7bda5")],
        [Vector3(34,0,12),6.0,Color("#578480"),Color("#c9d9b3")],
        [Vector3(44,0,5),6.0,Color("#9e7463"),Color("#e0cea7")],
        [Vector3(35,0,-7),6.0,Color("#696e91"),Color("#c8c3da")]
    ]
    for item in homes:
        _finish_cottage(item[0],float(item[1]),item[2],item[3])

func _finish_cottage(at: Vector3, width: float, roof_tint: Color, trim: Color) -> void:
    var timber := Color("#705544")
    var eave: float = width*0.69
    var rise: float = 2.05
    var roof_mesh := SurfaceTool.new()
    roof_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a := at+Vector3(-eave,4.08,-3.18)
    var b := at+Vector3(-eave,4.08,3.18)
    var c := at+Vector3(0,4.08+rise,-3.18)
    var d := at+Vector3(0,4.08+rise,3.18)
    var e := at+Vector3(eave,4.08,-3.18)
    var g := at+Vector3(eave,4.08,3.18)
    _roof_quad(roof_mesh,a,b,c,d)
    _roof_quad(roof_mesh,c,d,e,g)
    roof_mesh.generate_normals()
    var roof := MeshInstance3D.new()
    roof.name = "HandShingledGableRoof"
    roof.mesh = roof_mesh.commit()
    var finish := _material(roof_tint)
    finish.cull_mode = BaseMaterial3D.CULL_DISABLED
    roof.material_override = finish
    add_child(roof)
    _box(at+Vector3(0,6.16,0),Vector3(0.23,0.23,6.6),roof_tint.darkened(0.22))
    for side in [-1,1]:
        var side_x: float = float(side)*width*0.5
        for z in [-2.4,2.4]:
            _box(at+Vector3(side_x,2.05,z),Vector3(0.16,4.1,0.18),timber)
        for x_factor in [0.16,0.31,0.46,0.60]:
            var dx: float = float(side)*width*x_factor
            var local_y := 6.13-(absf(dx)/eave)*rise
            for iz in range(7):
                var tile := _box(at+Vector3(dx,local_y+0.055,-2.6+float(iz)*0.84),
                    Vector3(width*0.17,0.06,0.72),
                    roof_tint.lightened(0.12) if (iz+int(x_factor*10))%2==0 else roof_tint.darkened(0.12))
                tile.rotation.z = atan2(-float(side)*rise,eave)
    # Windows, mullions, shutters and front flower boxes.
    for side in [-1,1]:
        var wx: float = float(side)*width*0.29
        _box(at+Vector3(wx,2.45,2.73),Vector3(1.25,1.46,0.16),timber)
        _box(at+Vector3(wx,2.47,2.83),Vector3(0.96,1.15,0.11),Color("#f4d9a7"))
        _box(at+Vector3(wx,2.47,2.9),Vector3(0.09,1.2,0.08),trim)
        _box(at+Vector3(wx,2.47,2.9),Vector3(1.02,0.09,0.08),trim)
        for shutter_side in [-1,1]:
            _box(at+Vector3(wx+float(shutter_side)*0.69,2.45,2.77),Vector3(0.25,1.44,0.13),roof_tint.darkened(0.22))
        _box(at+Vector3(wx,1.68,2.85),Vector3(1.45,0.23,0.42),timber)
        for flower in range(4):
            _ellipsoid(at+Vector3(wx-0.5+float(flower)*0.33,1.92,2.93),Vector3(0.3,0.35,0.31),
                Color("#e7afba") if flower%2==0 else Color("#e9d88d"))
    _box(at+Vector3(0,1.56,2.77),Vector3(1.35,3.1,0.20),Color("#835d48"))
    _box(at+Vector3(0,3.18,2.8),Vector3(1.76,0.18,0.38),trim)
    _ellipsoid(at+Vector3(0.43,1.49,2.91),Vector3(0.09,0.09,0.1),Color("#e4c888"))
    _box(at+Vector3(0,0.11,3.34),Vector3(2.15,0.16,1.08),Color("#cfbd9d"))
    # Chimney: chimney pot plus two decorative brick courses.
    _box(at+Vector3(width*0.26,5.95,-1.0),Vector3(0.76,2.0,0.7),Color("#b97e68"))
    _box(at+Vector3(width*0.26,7.0,-1.0),Vector3(1.02,0.20,0.94),Color("#79605d"))
    for y in [5.4,5.8,6.2,6.6]:
        _box(at+Vector3(width*0.26,float(y),-0.63),Vector3(0.8,0.06,0.03),Color("#e2b296"))

func _roof_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    # Two triangles per roof slope with UVs reserved for a future licensed texture atlas.
    surface.set_uv(Vector2(0,0))
    surface.add_vertex(a)
    surface.set_uv(Vector2(0,1))
    surface.add_vertex(b)
    surface.set_uv(Vector2(1,0))
    surface.add_vertex(c)
    surface.set_uv(Vector2(1,0))
    surface.add_vertex(c)
    surface.set_uv(Vector2(0,1))
    surface.add_vertex(b)
    surface.set_uv(Vector2(1,1))
    surface.add_vertex(d)

func _water_shimmer() -> void:
    # Recolor only the existing lake disk. No alteration to fishing collisions or game state.
    var lake := Vector3(27,0.075,-28)
    for child in world.get_children():
        if child is MeshInstance3D and child.position.distance_to(lake)<0.12 and child.mesh is CylinderMesh:
            var mat := ShaderMaterial.new()
            var shader := Shader.new()
            shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley;
void fragment() {
    float ripple = sin(UV.x * 52.0 + TIME * 1.6) * sin(UV.y * 39.0 - TIME * 0.9);
    float soft = sin(UV.x*18.0 + UV.y*20.0 + TIME*0.5);
    vec3 shallow = vec3(0.24, 0.58, 0.62);
    vec3 deep = vec3(0.10, 0.36, 0.48);
    ALBEDO = mix(deep,shallow,clamp(0.45 + ripple*0.13 + soft*0.18,0.0,1.0));
    ROUGHNESS = 0.26;
    METALLIC = 0.06;
}
"""
            mat.shader = shader
            child.material_override = mat
            break

func _lanterns() -> void:
    for at in [Vector3(-21,0,-3),Vector3(-3,0,3),Vector3(12,0,3),Vector3(21,0,-7),Vector3(35,0,19),Vector3(17,0,-20)]:
        _pole(at,3.0,0.12,Color("#51483d"))
        _box(at+Vector3(0,3.0,0),Vector3(0.58,0.85,0.58),Color("#f8d89e"))
        _box(at+Vector3(0,3.56,0),Vector3(0.92,0.14,0.92),Color("#6c5143"))
        var light := OmniLight3D.new()
        light.position = at+Vector3(0,3.0,0)
        light.light_color = Color("#ffe2a6")
        light.light_energy = 0.36
        light.omni_range = 5.5
        light.shadow_enabled = false
        add_child(light)
