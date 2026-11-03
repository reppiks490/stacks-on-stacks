extends Node3D
## Original high-density stylized scenic meshes for EVERBLOOM.
## All geometry and materials are authored in GDScript; no borrowed game assets.
## Each settlement gets its own small bounded dressing pass (no offscreen terrain load).
const FLOWER_SHADES := [
    Color("#e8a3c5"),Color("#f7e2a1"),Color("#c8b0ee"),
    Color("#e9f5db"),Color("#a6d5f0"),Color("#ef9f8f"),Color("#e8d1fb")
]
var flower_material: ShaderMaterial
var stem_material: StandardMaterial3D
var center_material: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var game
var region_name: String=""
var last_season: int=-1

func build_homestead(host) -> void:
    game=host
    region_name="Larkspur"
    rng.seed=2026110317
    _init_materials()
    var beds: Array[Vector3]=[
        Vector3(44,0,35),Vector3(54,0,34),Vector3(42,0,48),
        Vector3(57,0,50),Vector3(-44,0,-38),Vector3(-56,0,-47),
        Vector3(53,0,-44),Vector3(43,0,-54),Vector3(-48,0,45)
    ]
    _plant_flowers(beds,1380,4.2)
    _make_bridge(Vector3(51,0,-19),0.0)
    _make_rose_arch(Vector3(21,0,27),0.0)
    _make_rose_arch(Vector3(-38,0,28),0.5)
    _make_sculpted_lookout(Vector3(-54,0,-14))
    _make_banner(Vector3(13,0,9),Color("#e6a6ba"))
    set_process(true)

func dress_settlement(hub: Dictionary) -> void:
    region_name=str(hub.get("name","Settlement"))
    rng.seed=absi(region_name.hash()*991 + 20261103)
    _init_materials()
    var radius: float=31.0 if str(hub.get("kind","")) in ["Kingdom","Capital","City"] else 24.0
    var gardens: Array[Vector3]=[]
    for i in range(9):
        var angle: float=TAU*float(i)/9.0
        gardens.append(Vector3(cos(angle)*radius,0,sin(angle)*radius))
    _plant_flowers(gardens,630,2.4)
    _make_rose_arch(Vector3(0,0,radius*0.75),0.0)
    _make_banner(Vector3(-radius*0.7,0,-radius*0.4),Color(str(hub.get("color","#b8b4c4"))))
    _make_sculpted_lookout(Vector3(radius*0.68,0,radius*0.63))
    set_process(false)

func _init_materials() -> void:
    if flower_material!=null:
        return
    var shader:=Shader.new()
    shader.code="""
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float season = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
    float grain=hash(floor(UV*57.0));
    float veins=sin(UV.y*51.0+UV.x*16.0)*0.03;
    vec3 color=COLOR.rgb*(0.88+grain*0.19+veins);
    if (season>2.5) color=mix(color,vec3(0.84,0.89,0.96),0.38);
    else if (season>1.5) color=mix(color,vec3(0.85,0.61,0.36),0.21);
    ALBEDO=color;
    ROUGHNESS=0.71+grain*0.13;
    SPECULAR=0.24;
}
"""
    flower_material=ShaderMaterial.new()
    flower_material.shader=shader
    stem_material=StandardMaterial3D.new()
    stem_material.albedo_color=Color.WHITE
    stem_material.vertex_color_use_as_albedo=true
    stem_material.roughness=0.95
    center_material=StandardMaterial3D.new()
    center_material.albedo_color=Color("#ebc66e")
    center_material.roughness=0.67

func _make_petal_mesh() -> ArrayMesh:
    # Five hand-shaped petal faces, each with four triangles and radial UVs.
    var surface:=SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for petal in range(5):
        var a: float=float(petal)*TAU/5.0
        var axis:=Vector3(cos(a),0,sin(a))
        var tangent:=Vector3(-sin(a),0,cos(a))
        var base:=Vector3(0,0.04,0)
        var mid:=axis*0.18+Vector3(0,0.16,0)
        var tip:=axis*0.32+Vector3(0,0.08,0)
        var wing_left:=axis*0.20-tangent*0.15+Vector3(0,0.10,0)
        var wing_right:=axis*0.20+tangent*0.15+Vector3(0,0.10,0)
        _tri(surface,base,wing_left,mid)
        _tri(surface,base,mid,wing_right)
        _tri(surface,wing_left,tip,mid)
        _tri(surface,mid,tip,wing_right)
    surface.generate_normals()
    return surface.commit()

func _tri(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
    surface.set_uv(Vector2(0,0))
    surface.add_vertex(a)
    surface.set_uv(Vector2(0,1))
    surface.add_vertex(b)
    surface.set_uv(Vector2(1,1))
    surface.add_vertex(c)

func _plant_flowers(centers: Array[Vector3],count: int,radius: float) -> void:
    var petals:=MultiMesh.new()
    petals.transform_format=MultiMesh.TRANSFORM_3D
    petals.use_colors=true
    petals.mesh=_make_petal_mesh()
    petals.instance_count=count
    var stems:=MultiMesh.new()
    stems.transform_format=MultiMesh.TRANSFORM_3D
    stems.use_colors=true
    var stalk_mesh:=CylinderMesh.new()
    stalk_mesh.top_radius=0.025
    stalk_mesh.bottom_radius=0.039
    stalk_mesh.height=0.58
    stalk_mesh.radial_segments=5
    stems.mesh=stalk_mesh
    stems.instance_count=count
    var pollen:=MultiMesh.new()
    pollen.transform_format=MultiMesh.TRANSFORM_3D
    var seed_mesh:=SphereMesh.new()
    seed_mesh.radius=0.06
    seed_mesh.height=0.09
    seed_mesh.radial_segments=7
    seed_mesh.rings=5
    pollen.mesh=seed_mesh
    pollen.instance_count=count
    for i in range(count):
        var center: Vector3=centers[i%centers.size()]
        var angle: float=rng.randf_range(0.0,TAU)
        var distance: float=sqrt(rng.randf())*radius
        var pos:=center+Vector3(cos(angle)*distance,0,sin(angle)*distance)
        var size_factor:=rng.randf_range(0.75,1.58)
        var stalk_height: float=0.38*size_factor
        var yaw: float=rng.randf_range(0,TAU)
        petals.set_instance_transform(i,Transform3D(
            Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size_factor),
            pos+Vector3(0,stalk_height,0)))
        petals.set_instance_color(i,FLOWER_SHADES[i%FLOWER_SHADES.size()])
        stems.set_instance_transform(i,Transform3D(
            Basis().scaled(Vector3(0.95,size_factor,0.95)),
            pos+Vector3(0,0.29*size_factor,0)))
        stems.set_instance_color(i,Color("#60975c") if i%3 else Color("#8cab66"))
        pollen.set_instance_transform(i,Transform3D(
            Basis().scaled(Vector3.ONE*size_factor),
            pos+Vector3(0,stalk_height+0.09*size_factor,0)))
    _multimesh("HandShapedWildflowerPetals",petals,flower_material)
    _multimesh("FlowerStalks",stems,stem_material)
    _multimesh("FlowerPollen",pollen,center_material)

func _multimesh(title: String,mesh: MultiMesh,material: Material) -> void:
    var model:=MultiMeshInstance3D.new()
    model.name=title
    model.multimesh=mesh
    model.material_override=material
    model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    model.custom_aabb=AABB(Vector3(-80,-2,-80),Vector3(160,15,160))
    add_child(model)

func _material(tint: Color,wood: bool=false) -> ShaderMaterial:
    var shader:=Shader.new()
    shader.code="""
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.7,0.6,0.5,1.0);
uniform float fibers=0.0;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
    float grain=hash21(floor(UV*vec2(38.0,17.0)));
    float bands=sin(UV.y*91.0+sin(UV.x*19.0)*2.0)*fibers;
    ALBEDO=tint.rgb*(0.84+grain*0.24+bands*0.11);
    ROUGHNESS=0.78+grain*0.17;
    SPECULAR=0.15;
}
"""
    var mat:=ShaderMaterial.new()
    mat.shader=shader
    mat.set_shader_parameter("tint",tint)
    mat.set_shader_parameter("fibers",1.0 if wood else 0.0)
    return mat

func _box(at: Vector3,dimensions: Vector3,tint: Color,wood: bool=false) -> MeshInstance3D:
    var model:=MeshInstance3D.new()
    var mesh:=BoxMesh.new()
    mesh.size=dimensions
    model.mesh=mesh
    model.position=at
    model.material_override=_material(tint,wood)
    add_child(model)
    return model

func _cylinder(at: Vector3,dimensions: Vector3,tint: Color) -> MeshInstance3D:
    var model:=MeshInstance3D.new()
    var mesh:=CylinderMesh.new()
    mesh.bottom_radius=0.5
    mesh.top_radius=0.42
    mesh.height=1.0
    mesh.radial_segments=12
    model.mesh=mesh
    model.position=at
    model.scale=dimensions
    model.material_override=_material(tint,true)
    add_child(model)
    return model

func _make_bridge(at: Vector3,angle: float) -> void:
    var bridge:=Node3D.new()
    bridge.name="LarkspurOrnateFootbridge"
    bridge.position=at
    bridge.rotation.y=angle
    add_child(bridge)
    for plank in range(19):
        var z: float=(float(plank)-9.0)*0.61
        var rise: float=0.38+0.8*(1.0-pow(z/6.1,2.0))
        var deck:=MeshInstance3D.new()
        var mesh:=BoxMesh.new()
        mesh.size=Vector3(3.15,0.15,0.52)
        deck.mesh=mesh
        deck.position=Vector3(0,rise,z)
        deck.material_override=_material(Color("#b99774"),true)
        bridge.add_child(deck)
    for side in [-1,1]:
        for i in range(7):
            var z: float=float(i)*1.75-5.25
            var post:=MeshInstance3D.new()
            var mesh:=CylinderMesh.new()
            mesh.top_radius=0.10
            mesh.bottom_radius=0.14
            mesh.height=1.9
            post.mesh=mesh
            post.position=Vector3(float(side)*1.44,1.12,z)
            post.material_override=_material(Color("#78604b"),true)
            bridge.add_child(post)
            var cap:=MeshInstance3D.new()
            var capmesh:=SphereMesh.new()
            capmesh.radius=0.17
            capmesh.height=0.30
            cap.mesh=capmesh
            cap.position=post.position+Vector3(0,1.03,0)
            cap.material_override=_material(Color("#e2c49a"))
            bridge.add_child(cap)

func _make_rose_arch(at: Vector3,rotation: float) -> void:
    var arch:=Node3D.new()
    arch.position=at
    arch.rotation.y=rotation
    arch.name="FloweredGardenArch"
    add_child(arch)
    var wood:=_material(Color("#8b6a52"),true)
    for side in [-1,1]:
        var post:=MeshInstance3D.new()
        var mesh:=CylinderMesh.new()
        mesh.bottom_radius=0.12
        mesh.top_radius=0.1
        mesh.height=3.8
        post.mesh=mesh
        post.position=Vector3(float(side)*1.7,1.9,0)
        post.material_override=wood
        arch.add_child(post)
    var beam:=MeshInstance3D.new()
    var box:=BoxMesh.new()
    box.size=Vector3(4.1,0.24,0.49)
    beam.mesh=box
    beam.position=Vector3(0,3.95,0)
    beam.material_override=wood
    arch.add_child(beam)
    for petal in range(19):
        var x: float=-1.65+float(petal)*0.183
        var blossom:=MeshInstance3D.new()
        blossom.mesh=_make_petal_mesh()
        blossom.position=Vector3(x,4.2+sin(x*3.3)*0.13,0.09)
        blossom.rotation=Vector3(0,0.0,float(petal)*0.31)
        blossom.scale=Vector3.ONE*rng.randf_range(0.65,1.25)
        blossom.material_override=_material(FLOWER_SHADES[petal%FLOWER_SHADES.size()])
        arch.add_child(blossom)

func _make_sculpted_lookout(at: Vector3) -> void:
    # A freestanding gazebo landmark, not just a waypoint label.
    _cylinder(at+Vector3(0,0.30,0),Vector3(9.0,0.56,9.0),Color("#b9b0a1"))
    for i in range(8):
        var angle: float=float(i)*TAU/8.0
        var offset:=Vector3(cos(angle)*3.4,0,sin(angle)*3.4)
        _cylinder(at+offset+Vector3(0,2.0,0),Vector3(0.37,3.7,0.37),Color("#b5a087"))
        _cylinder(at+offset+Vector3(0,4.22,0),Vector3(0.70,0.42,0.70),Color("#d2b894"))
    var roof:=MeshInstance3D.new()
    var mesh:=CylinderMesh.new()
    mesh.bottom_radius=4.8
    mesh.top_radius=0.0
    mesh.height=2.4
    mesh.radial_segments=8
    roof.mesh=mesh
    roof.position=at+Vector3(0,5.45,0)
    roof.material_override=_material(Color("#b77b77"),true)
    add_child(roof)
    _cylinder(at+Vector3(0,6.95,0),Vector3(0.70,0.6,0.70),Color("#f2d7aa"))

func _make_banner(at: Vector3,tint: Color) -> void:
    _cylinder(at+Vector3(0,3.0,0),Vector3(0.16,6.0,0.16),Color("#725544"))
    _box(at+Vector3(0.8,5.35,0),Vector3(1.55,0.12,0.13),Color("#bda077"),true)
    var cloth:=MeshInstance3D.new()
    var mesh:=PrismMesh.new()
    mesh.size=Vector3(1.35,1.95,0.09)
    cloth.mesh=mesh
    cloth.position=at+Vector3(0.79,4.28,0)
    cloth.material_override=_material(tint)
    add_child(cloth)

func _process(_delta: float) -> void:
    if game!=null and game.season_index!=last_season and flower_material!=null:
        last_season=game.season_index
        flower_material.set_shader_parameter("season",float(last_season))
