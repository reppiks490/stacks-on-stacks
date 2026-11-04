extends Node3D
## First-party 4.8 km x 4.8 km continental world: 32x32 cells, 3x3 active at a time.
## Non-destructive to homestead, farming, save schema and existing village.
const CONTINENT_SIDE: float = 4800.0
const CHUNK_SIDE: float = 150.0
const GRID_WIDTH: int = 32
const STREAM_RADIUS: int = 1
const HALF: float = CONTINENT_SIDE * 0.5
const HUBS: Array[Dictionary] = [
    {"name":"Larkspur Homestead", "kind":"Homestead", "x":-15.0, "z":-7.0, "color":"#74ad89"},
    {"name":"Fernwater Village", "kind":"Village", "x":231.0, "z":105.0, "color":"#83bf96"},
    {"name":"Hearthmere Township", "kind":"Town", "x":-287.0, "z":212.0, "color":"#d3a778"},
    {"name":"Briarford Trade City", "kind":"City", "x":431.0, "z":-335.0, "color":"#d9b58b"},
    {"name":"Moonharbor Port", "kind":"Port", "x":315.0, "z":-479.0, "color":"#83bdc5"},
    {"name":"Frostpetal Highlands", "kind":"Highland Village", "x":-468.0, "z":-488.0, "color":"#bccde3"},
    {"name":"Sunspire Kingdom", "kind":"Kingdom", "x":513.0, "z":488.0, "color":"#e9c98b"},
    {"name":"Aurora Crown City", "kind":"Capital", "x":-487.0, "z":451.0, "color":"#c9b3e4"},
    {"name":"Wildflower Hollow", "kind":"Village", "x":1120.0, "z":340.0, "color":"#b3cc91"},
    {"name":"Rosedale Orchards", "kind":"Village", "x":-1300.0, "z":510.0, "color":"#ecacc2"},
    {"name":"Eversong Market Town", "kind":"Town", "x":980.0, "z":-1150.0, "color":"#d9bd9c"},
    {"name":"Shimmerbrook Hamlet", "kind":"Village", "x":-1180.0, "z":-980.0, "color":"#a8cad1"},
    {"name":"Mistveil Sanctuary", "kind":"Highland Village", "x":-1820.0, "z":-650.0, "color":"#b8c0da"},
    {"name":"Starfall Observatory", "kind":"Town", "x":1510.0, "z":1820.0, "color":"#baa9df"},
    {"name":"Kingsreach Citadel", "kind":"Kingdom", "x":2020.0, "z":820.0, "color":"#c8a4a0"},
    {"name":"Emerald Vale Kingdom", "kind":"Kingdom", "x":-1780.0, "z":1690.0, "color":"#a0c897"},
    {"name":"Saffron Dunes Capital", "kind":"Capital", "x":2150.0, "z":-1740.0, "color":"#e4c48d"},
    {"name":"Tideglass Coastal City", "kind":"City", "x":1140.0, "z":-2010.0, "color":"#8bc4c7"},
    {"name":"Silverpine Trade City", "kind":"City", "x":-2140.0, "z":-1800.0, "color":"#9da9bc"},
    {"name":"Moonvine Kingdom", "kind":"Kingdom", "x":-1860.0, "z":-110.0, "color":"#c1a5d5"},
    {"name":"Eldermist Mountain City", "kind":"City", "x":-400.0, "z":2090.0, "color":"#b1c5d9"},
    {"name":"Bellflower Port", "kind":"Port", "x":490.0, "z":2110.0, "color":"#89bcbc"},
    {"name":"Foxglove Crossing", "kind":"Town", "x":-710.0, "z":-1950.0, "color":"#d3abbc"},
    {"name":"Auric Sunfields", "kind":"Village", "x":1630.0, "z":1070.0, "color":"#dec88c"},
    {"name":"Amberroot Borough", "kind":"Town", "x":-950.0, "z":1150.0, "color":"#d3af84"},
    {"name":"Crescent Bay", "kind":"Port", "x":1650.0, "z":-390.0, "color":"#8ac1ca"},
    {"name":"Dragonfly Marsh", "kind":"Village", "x":460.0, "z":-1450.0, "color":"#86afa1"},
    {"name":"Frostlight Royal City", "kind":"City", "x":-2140.0, "z":2120.0, "color":"#bbcde3"}
]
const BIOME_COLORS := [
    ["#718f57","#a7be72"], ["#4e9478","#80bf94"], ["#9cae88","#d5ca96"],
    ["#8b8ba6","#b6b7d2"], ["#c3a27a","#e3cfa1"], ["#679ca8","#8cc3b2"]
]
var game
var chunks: Dictionary = {}
var last_cell := Vector2i(-999,-999)
var society: Node3D
var companions: Node3D
var grass_material: StandardMaterial3D
var bloom_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var terrain_shader: Shader
var _terrain_vertex_origin: Vector3 = Vector3.ZERO
var last_season: int = -1
var panorama: bool = false
var atlas_layer: CanvasLayer
var atlas: PanelContainer
var location_line: Label
var hud_hint: Label
var last_label_update: float = 0.0

func setup(host) -> void:
    game = host
    _make_materials()
    society = Node3D.new()
    society.name = "FrontierResidentsAndMarkets"
    society.set_script(load("res://scripts/frontier_society.gd"))
    add_child(society)
    society.setup(game,self)
    companions = Node3D.new()
    companions.name = "MountsPetsAndWildlife"
    companions.set_script(load("res://scripts/wild_companions.gd"))
    add_child(companions)
    companions.setup(game,self)
    var exploration := Node3D.new()
    exploration.name = "ContinentalExploration"
    exploration.set_script(load("res://scripts/exploration_system.gd"))
    add_child(exploration)
    exploration.setup(game,self)
    _create_atlas()
    # Install the starting 3x3 terrain and physics before the first movement tick.
    # Otherwise the hero can fall while waiting for _physics_process streaming.
    if game.hero != null:
        last_cell = _cell_of(Vector2(game.hero.global_position.x, game.hero.global_position.z))
        _stream_neighborhood(last_cell)
    set_physics_process(true)

func _make_materials() -> void:
    grass_material = StandardMaterial3D.new()
    grass_material.albedo_color = Color.WHITE
    grass_material.vertex_color_use_as_albedo = true
    grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    grass_material.roughness = 0.95
    bloom_material = StandardMaterial3D.new()
    bloom_material.albedo_color = Color.WHITE
    bloom_material.vertex_color_use_as_albedo = true
    bloom_material.roughness = 0.73
    stone_material = StandardMaterial3D.new()
    stone_material.albedo_color = Color.WHITE
    stone_material.vertex_color_use_as_albedo = true
    stone_material.roughness = 0.98
    terrain_shader = Shader.new()
    terrain_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform vec3 base_a = vec3(0.35,0.53,0.3);
uniform vec3 base_b = vec3(0.59,0.71,0.4);
uniform float season = 0.0;
float hash21(vec2 x) { return fract(sin(dot(x,vec2(127.1,311.7)))*43758.5453); }
float noise21(vec2 x) {
    vec2 i=floor(x); vec2 f=fract(x);
    f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),
               mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
    float macro = noise21(UV*11.0);
    float soil = noise21(UV*58.0);
    float flecks = noise21(UV*205.0);
    vec3 base = mix(base_a, base_b, macro*0.72+soil*0.28);
    if (season>2.5) base=mix(base, vec3(0.82,0.86,0.87),0.79);
    else if (season>1.5) base=mix(base,vec3(0.71,0.47,0.23),0.30);
    ALBEDO=base*(0.91+flecks*0.17);
    ROUGHNESS=0.97;
}
"""

func _physics_process(delta: float) -> void:
    if game == null or game.hero == null:
        return
    var pos: Vector3 = game.hero.global_position
    if absf(pos.x)>HALF-3.0 or absf(pos.z)>HALF-3.0:
        game.hero.global_position.x=clampf(pos.x,-HALF+3.0,HALF-3.0)
        game.hero.global_position.z=clampf(pos.z,-HALF+3.0,HALF-3.0)
        game.hero.velocity=Vector3.ZERO
    var cell := _cell_of(Vector2(game.hero.global_position.x,game.hero.global_position.z))
    if cell!=last_cell:
        last_cell=cell
        _stream_neighborhood(cell)
    if game.season_index!=last_season:
        last_season=game.season_index
        for chunk in chunks.values():
            var ground: MeshInstance3D=chunk.get_node_or_null("BiomeTerrain")
            if ground!=null and ground.material_override is ShaderMaterial:
                ground.material_override.set_shader_parameter("season",float(last_season))
    if panorama and game.camera!=null:
        var destination: Vector3=game.hero.global_position+Vector3(110,125,125)
        game.camera.global_position=game.camera.global_position.lerp(destination,minf(1.0,delta*3.5))
        game.camera.look_at(game.hero.global_position+Vector3(0,5,0),Vector3.UP)
        game.camera.fov=72.0
        game.camera.far=850.0
    last_label_update+=delta
    if last_label_update>0.3 and hud_hint!=null:
        last_label_update=0.0
        var nearest := _closest_hub(game.hero.global_position)
        hud_hint.text="%s  •  M ATLAS  •  V PANORAMA  •  U TALK/TRADE  •  N MOUNT  •  B PET" % str(nearest.get("name","Wilds"))

func _cell_of(point: Vector2) -> Vector2i:
    return Vector2i(clampi(int(floor((point.x+HALF)/CHUNK_SIDE)),0,GRID_WIDTH-1),
        clampi(int(floor((point.y+HALF)/CHUNK_SIDE)),0,GRID_WIDTH-1))

func _stream_neighborhood(center: Vector2i) -> void:
    var required: Dictionary={}
    for dx in range(-STREAM_RADIUS,STREAM_RADIUS+1):
        for dz in range(-STREAM_RADIUS,STREAM_RADIUS+1):
            var cx: int=center.x+dx
            var cz: int=center.y+dz
            if cx<0 or cz<0 or cx>=GRID_WIDTH or cz>=GRID_WIDTH:
                continue
            var key := Vector2i(cx,cz)
            required[key]=true
            if not chunks.has(key):
                chunks[key]=_make_chunk(key)
    for key in chunks.keys():
        if not required.has(key):
            _unload_chunk(key)

func _unload_chunk(key: Vector2i) -> void:
    if not chunks.has(key):
        return
    society.release_chunk(key)
    var chunk: Node3D=chunks[key]
    chunks.erase(key)
    chunk.queue_free()

func _biome(x: float,z: float) -> int:
    if z < -390.0 and x>120.0:
        return 5
    if x < -325.0 and z < -260.0:
        return 3
    if x > 350.0 and z > 200.0:
        return 4
    if z > 285.0:
        return 2
    if x>90.0:
        return 1
    return 0

func _terrain_height(x: float,z: float) -> float:
    # Continuous world-space height function: adjacent chunks share edge vertices.
    # Gentle home and settlement plateaus preserve interactive flat foundations.
    if absf(x)<76.0 and absf(z)<76.0:
        return 0.0
    var waves: float = sin(x*0.0065+0.4)*cos(z*0.0084)*6.5
    waves += sin(x*0.016+z*0.004)*2.4 + cos(z*0.0142)*1.6
    var biome: int=_biome(x,z)
    var relief: float=1.45 if biome==3 else (1.25 if biome in [2,4] else 1.0)
    var plateau: float=1.0
    for hub in HUBS:
        var distance: float=Vector2(x-float(hub["x"]),z-float(hub["z"])).length()
        var fade: float=clampf((distance-51.0)/44.0,0.0,1.0)
        plateau=minf(plateau,fade*fade*(3.0-2.0*fade))
    var home_dist: float=maxf(absf(x),absf(z))
    var home_fade: float=clampf((home_dist-75.0)/32.0,0.0,1.0)
    plateau=minf(plateau,home_fade*home_fade*(3.0-2.0*home_fade))
    return waves*relief*plateau

func _terrain_mesh(origin: Vector3) -> ArrayMesh:
    # Sculpt 150m chunks with 24 subdivisions; generate normals and a matching
    # StaticBody trimesh. 3x3 nearby chunks bound runtime memory and collision.
    const STEPS: int=24
    _terrain_vertex_origin = origin
    var surface:=SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_smooth_group(0)
    var step: float=CHUNK_SIDE/float(STEPS)
    for iz in range(STEPS):
        for ix in range(STEPS):
            var x0: float=-CHUNK_SIDE*0.5+float(ix)*step
            var z0: float=-CHUNK_SIDE*0.5+float(iz)*step
            var x1: float=x0+step
            var z1: float=z0+step
            var a:=Vector3(x0,_terrain_height(origin.x+x0,origin.z+z0),z0)
            var b:=Vector3(x0,_terrain_height(origin.x+x0,origin.z+z1),z1)
            var d:=Vector3(x1,_terrain_height(origin.x+x1,origin.z+z0),z0)
            var e:=Vector3(x1,_terrain_height(origin.x+x1,origin.z+z1),z1)
            _terrain_vertex(surface,a,Vector2(float(ix)/STEPS,float(iz)/STEPS))
            _terrain_vertex(surface,b,Vector2(float(ix)/STEPS,float(iz+1)/STEPS))
            _terrain_vertex(surface,d,Vector2(float(ix+1)/STEPS,float(iz)/STEPS))
            _terrain_vertex(surface,d,Vector2(float(ix+1)/STEPS,float(iz)/STEPS))
            _terrain_vertex(surface,b,Vector2(float(ix)/STEPS,float(iz+1)/STEPS))
            _terrain_vertex(surface,e,Vector2(float(ix+1)/STEPS,float(iz+1)/STEPS))
    surface.index()
    # Normals are derived from the same world-space height function on BOTH
    # sides of a chunk border, avoiding discontinuous lighting at tile seams.
    return surface.commit()

func _terrain_vertex(surface: SurfaceTool,at: Vector3,uv: Vector2) -> void:
    surface.set_uv(uv)
    var wx: float = _terrain_vertex_origin.x + at.x
    var wz: float = _terrain_vertex_origin.z + at.z
    var spacing: float = CHUNK_SIDE / 24.0
    var slope_x: float = (_terrain_height(wx + spacing, wz) - _terrain_height(wx - spacing, wz)) / (2.0 * spacing)
    var slope_z: float = (_terrain_height(wx, wz + spacing) - _terrain_height(wx, wz - spacing)) / (2.0 * spacing)
    surface.set_normal(Vector3(-slope_x, 1.0, -slope_z).normalized())
    surface.add_vertex(at)

func _make_chunk(key: Vector2i) -> Node3D:
    var origin := Vector3(-HALF+(float(key.x)+0.5)*CHUNK_SIDE,0.0,
        -HALF+(float(key.y)+0.5)*CHUNK_SIDE)
    var chunk := Node3D.new()
    chunk.name="Continent_%02d_%02d" % [key.x,key.y]
    chunk.position=origin
    add_child(chunk)
    var biome: int=_biome(origin.x,origin.z)
    var ground := MeshInstance3D.new()
    ground.name="BiomeTerrain"
    var mesh: ArrayMesh = _terrain_mesh(origin)
    ground.mesh=mesh
    ground.position.y=0.0
    var mat := ShaderMaterial.new()
    mat.shader=terrain_shader
    mat.set_shader_parameter("base_a",Color(BIOME_COLORS[biome][0]))
    mat.set_shader_parameter("base_b",Color(BIOME_COLORS[biome][1]))
    mat.set_shader_parameter("season",float(game.season_index))
    ground.material_override=mat
    ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    chunk.add_child(ground)
    var body := StaticBody3D.new()
    chunk.add_child(body)
    var collision := CollisionShape3D.new()
    collision.shape=mesh.create_trimesh_shape()
    collision.position.y=0.0
    body.add_child(collision)
    _install_outer_boundary(chunk, key)
    var rng:=RandomNumberGenerator.new()
    rng.seed=abs(key.x*16777619+key.y*1234567+20261103)
    _flora(chunk,origin,biome,rng)
    _rocks(chunk,origin,biome,rng)
    for hub in HUBS:
        if str(hub["kind"])=="Homestead":
            continue
        var loc:=Vector2(float(hub["x"]),float(hub["z"]))
        if _cell_of(loc)==key:
            _make_settlement(chunk,hub,rng)
    society.spawn_for_chunk(chunk,key,origin)
    return chunk

# Real physics containment at the outermost streamed cells. These barriers exist
# only in loaded edge chunks, never across internal chunk transitions.
# A 3 m tall collider is deliberately taller than the local terrain relief.
func _install_outer_boundary(chunk: Node3D, key: Vector2i) -> void:
    var thickness: float = 2.0
    var wall_height: float = 80.0
    var sides: Array[Dictionary] = []
    if key.x == 0:
        sides.append({"at":Vector3(-CHUNK_SIDE*0.5, 0, 0), "size":Vector3(thickness, wall_height, CHUNK_SIDE+thickness)})
    if key.x == GRID_WIDTH-1:
        sides.append({"at":Vector3(CHUNK_SIDE*0.5, 0, 0), "size":Vector3(thickness, wall_height, CHUNK_SIDE+thickness)})
    if key.y == 0:
        sides.append({"at":Vector3(0, 0, -CHUNK_SIDE*0.5), "size":Vector3(CHUNK_SIDE+thickness, wall_height, thickness)})
    if key.y == GRID_WIDTH-1:
        sides.append({"at":Vector3(0, 0, CHUNK_SIDE*0.5), "size":Vector3(CHUNK_SIDE+thickness, wall_height, thickness)})
    for side in sides:
        var boundary := StaticBody3D.new()
        boundary.name = "PhysicalWorldBoundary"
        boundary.collision_layer = 1
        boundary.collision_mask = 1
        chunk.add_child(boundary)
        var shape := BoxShape3D.new()
        shape.size = side["size"]
        var collider := CollisionShape3D.new()
        collider.shape = shape
        collider.position = side["at"]
        boundary.add_child(collider)

func _safe_scatter(x: float,z: float) -> bool:
    return not (absf(x)<76.0 and absf(z)<76.0)

func _sample_chunk(rng: RandomNumberGenerator, origin: Vector3) -> Vector3:
    for attempt in range(18):
        var pos:=origin+Vector3(rng.randf_range(-70.5,70.5),0,rng.randf_range(-70.5,70.5))
        if _safe_scatter(pos.x,pos.z):
            pos.y=_terrain_height(pos.x,pos.z)
            return pos
    var fallback: Vector3=origin+Vector3(-70,0,-70)
    fallback.y=_terrain_height(fallback.x,fallback.z)
    return fallback

func _flora(chunk: Node3D,origin: Vector3,biome: int,rng: RandomNumberGenerator) -> void:
    var count:=660 if biome!=3 else 330
    var blade_mesh:=QuadMesh.new()
    blade_mesh.size=Vector2(0.48,0.70)
    var grass:=MultiMesh.new()
    grass.transform_format=MultiMesh.TRANSFORM_3D
    grass.use_colors=true
    grass.mesh=blade_mesh
    grass.instance_count=count
    for i in range(count):
        var spot:=_sample_chunk(rng,origin)-origin
        var h:=rng.randf_range(0.45,1.3)
        var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(rng.randf_range(0.65,1.4),h,1.0))
        grass.set_instance_transform(i,Transform3D(basis,spot+Vector3(0,h*0.30,0)))
        var shade: Color=Color("#83b968") if biome!=3 else Color("#b7b7ba")
        if i%3==0: shade=Color("#4c8255") if biome!=3 else Color("#91a5b1")
        if i%11==0: shade=Color("#d9c16a")
        grass.set_instance_color(i,shade)
    _multimesh_node(chunk,"SweepingGrass",grass,grass_material)
    var petals:=MultiMesh.new()
    var flower_mesh:=SphereMesh.new()
    flower_mesh.radius=0.13
    flower_mesh.height=0.20
    flower_mesh.radial_segments=7
    flower_mesh.rings=4
    petals.transform_format=MultiMesh.TRANSFORM_3D
    petals.use_colors=true
    petals.mesh=flower_mesh
    petals.instance_count=240
    var colors: Array[Color]=[Color("#e7b8d2"),Color("#f6d79c"),
        Color("#c3b5ed"),Color("#eff2d8"),Color("#b0d8ed")]
    for i in range(petals.instance_count):
        var spot:=_sample_chunk(rng,origin)-origin
        var scale_value:=rng.randf_range(0.65,1.55)
        petals.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ONE*scale_value),
            spot+Vector3(0,0.24*scale_value,0)))
        petals.set_instance_color(i,colors[(i+biome)%colors.size()])
    _multimesh_node(chunk,"FieldFlowers",petals,bloom_material)
    _tree_grove(chunk,origin,biome,rng)

func _multimesh_node(parent: Node3D,label: String,mesh: MultiMesh,material: Material) -> void:
    var instance:=MultiMeshInstance3D.new()
    instance.name=label
    instance.multimesh=mesh
    instance.material_override=material
    instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.custom_aabb=AABB(Vector3(-76,-2,-76),Vector3(152,15,152))
    parent.add_child(instance)

func _tree_grove(chunk: Node3D,origin: Vector3,biome: int,rng: RandomNumberGenerator) -> void:
    var stem_mesh:=CylinderMesh.new()
    stem_mesh.top_radius=0.18
    stem_mesh.bottom_radius=0.38
    stem_mesh.height=3.2
    stem_mesh.radial_segments=7
    var crown_mesh:=SphereMesh.new()
    crown_mesh.radius=0.5
    crown_mesh.height=1.0
    crown_mesh.radial_segments=10
    crown_mesh.rings=6
    var count:=62 if biome in [0,1,2] else 26
    var stems:=MultiMesh.new()
    stems.transform_format=MultiMesh.TRANSFORM_3D
    stems.use_colors=true
    stems.mesh=stem_mesh
    stems.instance_count=count
    var crowns:=MultiMesh.new()
    crowns.transform_format=MultiMesh.TRANSFORM_3D
    crowns.use_colors=true
    crowns.mesh=crown_mesh
    crowns.instance_count=count*2
    for i in range(count):
        var at:=_sample_chunk(rng,origin)-origin
        var size_factor:=rng.randf_range(0.85,1.75)
        var yaw:=rng.randf_range(0,TAU)
        stems.set_instance_transform(i,Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size_factor),
            at+Vector3(0,1.5*size_factor,0)))
        stems.set_instance_color(i,Color("#75614a"))
        var leaf_color:=Color("#54885a")
        if biome==3: leaf_color=Color("#79929e")
        if biome==4: leaf_color=Color("#81965d")
        if i%7==0: leaf_color=Color("#edb6cf")
        crowns.set_instance_transform(2*i,Transform3D(Basis().scaled(
            Vector3(4.2,3.9,4.0)*size_factor),at+Vector3(0,4.05*size_factor,0)))
        crowns.set_instance_color(2*i,leaf_color)
        crowns.set_instance_transform(2*i+1,Transform3D(Basis().scaled(
            Vector3(2.9,2.9,3.5)*size_factor),at+Vector3(-0.7,3.55,0.5)*size_factor))
        crowns.set_instance_color(2*i+1,leaf_color.lightened(0.14))
    var timber:=StandardMaterial3D.new()
    timber.vertex_color_use_as_albedo=true
    timber.albedo_color=Color.WHITE
    timber.roughness=0.92
    _multimesh_node(chunk,"GroveTimber",stems,timber)
    _multimesh_node(chunk,"GroveCanopies",crowns,bloom_material)

func _rocks(chunk: Node3D,origin: Vector3,biome: int,rng: RandomNumberGenerator) -> void:
    var stones:=MultiMesh.new()
    var rock:=SphereMesh.new()
    rock.radius=0.5
    rock.height=1.0
    rock.radial_segments=7
    rock.rings=4
    stones.transform_format=MultiMesh.TRANSFORM_3D
    stones.use_colors=true
    stones.mesh=rock
    stones.instance_count=55
    for i in range(stones.instance_count):
        var spot:=_sample_chunk(rng,origin)-origin
        var size_factor:=rng.randf_range(0.3,1.7)
        stones.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(
            Vector3(size_factor,0.35*size_factor,size_factor*0.82)),spot+Vector3(0,0.15*size_factor,0)))
        stones.set_instance_color(i,Color("#a5aaa1") if biome!=4 else Color("#d1b99a"))
    _multimesh_node(chunk,"TrailBoulders",stones,stone_material)

func _mat(tint: Color) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=tint
    m.roughness=0.85
    return m

func _box(root: Node3D,position: Vector3,size: Vector3,tint: Color) -> MeshInstance3D:
    var obj:=MeshInstance3D.new()
    var box:=BoxMesh.new()
    box.size=size
    obj.mesh=box
    obj.position=position
    obj.material_override=_mat(tint)
    root.add_child(obj)
    return obj

func _ball(root: Node3D,position: Vector3,size: Vector3,tint: Color) -> MeshInstance3D:
    var obj:=MeshInstance3D.new()
    var sphere:=SphereMesh.new()
    sphere.radius=0.5
    sphere.height=1.0
    sphere.radial_segments=12
    sphere.rings=8
    obj.mesh=sphere
    obj.position=position
    obj.scale=size
    obj.material_override=_mat(tint)
    root.add_child(obj)
    return obj

func _make_settlement(chunk: Node3D,hub: Dictionary,rng: RandomNumberGenerator) -> void:
    var district:=Node3D.new()
    district.name=str(hub["name"]).replace(" ","")
    district.position=Vector3(float(hub["x"]),0,float(hub["z"]))-chunk.position
    chunk.add_child(district)
    var theme:=Color(str(hub["color"]))
    var kind:=str(hub["kind"])
    var radius:=36.0 if kind in ["Capital","Kingdom","City"] else 23.0
    _box(district,Vector3(0,0.018,0),Vector3(radius*2.0,0.06,radius*1.6),Color("#c5b599"))
    _box(district,Vector3(0,0.065,0),Vector3(5,0.08,radius*1.6),Color("#e6cfab"))
    _box(district,Vector3(0,0.07,0),Vector3(radius*2,0.075,4),Color("#e6cfab"))
    var homes:=16 if kind in ["Capital","Kingdom","City"] else 8
    for i in range(homes):
        var a: float=(float(i)/float(homes))*TAU
        var r: float=12.0+float(i%3)*5.5
        var at:=Vector3(cos(a)*r,0,sin(a)*r)
        var height:=rng.randf_range(3.8,6.3)
        var width:=rng.randf_range(4.3,7.5)
        var walls:=Color("#f1ddbe") if i%3==0 else (Color("#ced6b8") if i%3==1 else Color("#d6b8ad"))
        _settlement_house(district,at,width,height,walls,theme.darkened(0.12))
    for gate in [-1,1]:
        var gx:=float(gate)*radius*0.86
        _box(district,Vector3(gx,2.2,0),Vector3(2.8,4.4,2.8),theme.darkened(0.22))
        _box(district,Vector3(gx,4.6,0),Vector3(3.4,0.55,3.4),Color("#f1dcc1"))
    # A unique monumental landmark per settlement, not merely a region label.
    if kind in ["Kingdom","Capital"]:
        _box(district,Vector3(0,6,-radius*0.4),Vector3(12,12,10),Color("#dbd7c9"))
        for dx in [-1,1]:
            for dz in [-1,1]:
                _box(district,Vector3(float(dx)*6,8.5,-radius*0.4+float(dz)*5),Vector3(2.6,17,2.6),theme.darkened(0.2))
                _ball(district,Vector3(float(dx)*6,17.5,-radius*0.4+float(dz)*5),Vector3(3,3,3),theme)
    elif kind=="Port":
        _box(district,Vector3(0,2.1,-radius*0.4),Vector3(22,0.4,8),Color("#b99875"))
        for i in range(4):
            _box(district,Vector3(-7+float(i)*4.7,0.8,-radius*0.4),Vector3(0.45,1.7,0.5),Color("#816a53"))
        _box(district,Vector3(12,6,-8),Vector3(3,12,3),Color("#f0e3d4"))
        _ball(district,Vector3(12,12,-8),Vector3(3.7,2.2,3.7),Color("#dbd6a3"))
    else:
        _ball(district,Vector3(0,0.45,0),Vector3(6,0.7,6),Color("#e4d6bc"))
        _ball(district,Vector3(0,0.55,0),Vector3(4.5,0.17,4.5),Color("#91b7bf"))
        _box(district,Vector3(0,1.45,0),Vector3(0.65,2.3,0.65),Color("#c2b69a"))
    for i in range(14):
        var angle:=TAU*float(i)/14.0
        var r:=radius*0.68
        var p:=Vector3(cos(angle)*r,0.3,sin(angle)*r)
        _ball(district,p,Vector3(1.7,0.65,1.6),Color("#69936a"))
        _ball(district,p+Vector3(0,0.55,0),Vector3(0.6,0.55,0.6),
            Color("#e9adc5") if i%2==0 else Color("#f5d99d"))
    var placard:=Label3D.new()
    placard.text=str(hub["name"]).to_upper()+"   ✦   "+kind
    placard.font_size=72
    placard.pixel_size=0.004
    placard.position=Vector3(0,6,radius*0.43)
    placard.modulate=Color("#fff0d1")
    district.add_child(placard)
    _market_stalls(district,theme)
    var scenic_dressing := Node3D.new()
    scenic_dressing.name = "TownArtAndGardens"
    scenic_dressing.set_script(load("res://scripts/premium_scenery.gd"))
    district.add_child(scenic_dressing)
    scenic_dressing.dress_settlement(hub)

func _settlement_house(root: Node3D,at: Vector3,width: float,height: float,walls: Color,roof_color: Color) -> void:
    _box(root,at+Vector3(0,height*0.5,0),Vector3(width,height,width*0.74),walls)
    var roof:=CylinderMesh.new()
    roof.top_radius=0.0
    roof.bottom_radius=width*0.72
    roof.height=2.5
    roof.radial_segments=4
    var r:=MeshInstance3D.new()
    r.mesh=roof
    r.position=at+Vector3(0,height+0.78,0)
    r.rotation.y=PI*0.25
    r.material_override=_mat(roof_color)
    root.add_child(r)
    for dx in [-1,1]:
        var x:=float(dx)*width*0.27
        _box(root,at+Vector3(x,height*0.65,width*0.39),Vector3(1.0,1.1,0.13),Color("#a6d0d5"))
        _box(root,at+Vector3(x,height*0.65,width*0.47),Vector3(0.07,1.1,0.05),Color("#f8e6cb"))
        _box(root,at+Vector3(x,height*0.65,width*0.47),Vector3(1.0,0.07,0.05),Color("#f8e6cb"))
        _box(root,at+Vector3(x,height*0.35,width*0.39),Vector3(1.4,0.25,0.5),Color("#96775c"))
        _ball(root,at+Vector3(x,height*0.40,width*0.53),Vector3(1.0,0.35,0.4),Color("#dcb4bf"))
    _box(root,at+Vector3(0,1.18,width*0.4),Vector3(1.3,2.3,0.16),Color("#a2785f"))
    _box(root,at+Vector3(0,0.12,width*0.70),Vector3(1.9,0.20,1.8),Color("#cbb69c"))

func _market_stalls(root: Node3D,theme: Color) -> void:
    for side in [-1,1]:
        var center:=Vector3(float(side)*8.5,0,9.5)
        _box(root,center+Vector3(0,0.9,0),Vector3(4.0,0.18,2.7),Color("#876b4d"))
        for x in [-1,1]:
            for z in [-1,1]:
                _box(root,center+Vector3(float(x)*1.7,1.7,float(z)*1.1),
                    Vector3(0.14,3.4,0.13),Color("#775644"))
        _box(root,center+Vector3(0,3.38,0),Vector3(4.8,0.20,3.3),theme)
        for item in range(6):
            _ball(root,center+Vector3(-1.2+float(item%3)*1.1,1.17,-0.6+float(item/3)*1.2),
                Vector3(0.58,0.6,0.58),
                Color("#deab84") if item%2==0 else Color("#9abf76"))

func _closest_hub(player: Vector3) -> Dictionary:
    var best: Dictionary=HUBS[0]
    var distance:=INF
    for hub in HUBS:
        var delta:=Vector2(player.x-float(hub["x"]),player.z-float(hub["z"]))
        var d:=delta.length_squared()
        if d<distance:
            distance=d
            best=hub
    return best

func _make_panorama() -> void:
    panorama=not panorama
    if game!=null:
        game._show("Panorama lookout: %s" % ("ON — press V to return" if panorama else "OFF"))

func _create_atlas() -> void:
    atlas_layer=CanvasLayer.new()
    atlas_layer.name="ContinentalAtlasUI"
    atlas_layer.layer=11
    add_child(atlas_layer)
    atlas=PanelContainer.new()
    atlas.position=Vector2(35,42)
    atlas.custom_minimum_size=Vector2(520,0)
    var bg:=StyleBoxFlat.new()
    bg.bg_color=Color(0.06,0.12,0.14,0.96)
    bg.border_color=Color("#e1c596")
    bg.set_border_width_all(2)
    bg.set_corner_radius_all(18)
    bg.content_margin_top=16
    bg.content_margin_bottom=16
    bg.content_margin_left=18
    bg.content_margin_right=18
    atlas.add_theme_stylebox_override("panel",bg)
    atlas_layer.add_child(atlas)
    var scroll:=ScrollContainer.new()
    scroll.custom_minimum_size=Vector2(500,380)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    atlas.add_child(scroll)
    var list:=VBoxContainer.new()
    list.add_theme_constant_override("separation",3)
    scroll.add_child(list)
    location_line=Label.new()
    location_line.text="✦  EVERBLOOM CONTINENTAL ATLAS  ✦"
    location_line.add_theme_font_size_override("font_size",21)
    location_line.add_theme_color_override("font_color",Color("#f7dba8"))
    list.add_child(location_line)
    var guide:=Label.new()
    guide.text="4,800 × 4,800 world   •   ~1,096× original ground area\nChoose a destination to take a waystone trail; M to close."
    guide.add_theme_font_size_override("font_size",13)
    guide.add_theme_color_override("font_color",Color("#b7d2c0"))
    list.add_child(guide)
    for i in range(HUBS.size()):
        var destination: Dictionary=HUBS[i]
        var option:=Button.new()
        option.text="%s  ·  %s" % [str(destination["name"]),str(destination["kind"])]
        option.add_theme_font_size_override("font_size",16)
        option.custom_minimum_size=Vector2(470,35)
        option.pressed.connect(_travel.bind(i))
        list.add_child(option)
    atlas.hide()
    hud_hint=Label.new()
    hud_hint.position=Vector2(680,17)
    hud_hint.add_theme_font_size_override("font_size",12)
    hud_hint.add_theme_color_override("font_color",Color("#fff0d1"))
    hud_hint.add_theme_color_override("font_shadow_color",Color("#20312e"))
    hud_hint.add_theme_constant_override("shadow_offset_x",1)
    hud_hint.add_theme_constant_override("shadow_offset_y",1)
    atlas_layer.add_child(hud_hint)

func _travel(index: int) -> void:
    if game==null or game.hero==null or index<0 or index>=HUBS.size():
        return
    var hub: Dictionary=HUBS[index]
    game.hero.global_position=Vector3(float(hub["x"]),1.05,float(hub["z"])+6.0)
    game.hero.velocity=Vector3.ZERO
    last_cell=Vector2i(-999,-999)
    _stream_neighborhood(_cell_of(Vector2(game.hero.global_position.x,game.hero.global_position.z)))
    last_cell=_cell_of(Vector2(game.hero.global_position.x,game.hero.global_position.z))
    atlas.hide()
    game._show("Waystone reached: %s. Explore the square, markets and local residents." % str(hub["name"]))

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if game!=null and game.hero!=null and game.hero.studio_open:
        return
    if event.keycode==KEY_M:
        atlas.visible=not atlas.visible
        get_viewport().set_input_as_handled()
    elif event.keycode==KEY_V:
        _make_panorama()
        get_viewport().set_input_as_handled()
