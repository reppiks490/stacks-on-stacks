extends Node3D
## Original modular farmhouse/townhouse art kit.
## Faceted walls, gables, pitched roofs, shutters and porches are drawn from
## authored vertex surfaces, rather than scaled stock boxes.
const WorldCollision = preload("res://scripts/world_collision.gd")
var width: float
var wall_height: float
var depth: float
var variant: int
var wall_color: Color
var roof_color: Color

func build_house(w: float,h: float,walls: Color,roof: Color,style: int=0) -> void:
    width=w
    wall_height=h
    depth=w*0.74
    variant=posmod(style,5)
    wall_color=walls
    roof_color=roof
    var shell:=MeshInstance3D.new()
    shell.name="FacetedMasonryAndTimberEnvelope"
    shell.mesh=_wall_shell()
    shell.material_override=_plaster_material(wall_color)
    add_child(shell)
    WorldCollision.solid_box(shell,Vector3(width,wall_height,depth),"house")
    var roof_node:=MeshInstance3D.new()
    roof_node.name="SlopedHandTiledRoof"
    roof_node.mesh=_roof_mesh()
    roof_node.material_override=_roof_material(roof_color)
    add_child(roof_node)
    # A walkable sloped physics surface over the building's solid wall volume.
    var roof_collision:=StaticBody3D.new()
    roof_collision.name="PitchedRoofPhysics"
    roof_collision.collision_layer=1
    roof_collision.collision_mask=1
    roof_node.add_child(roof_collision)
    var roof_shape:=CollisionShape3D.new()
    roof_shape.shape=roof_node.mesh.create_trimesh_shape()
    roof_collision.add_child(roof_shape)
    roof_collision.add_to_group("everbloom_world_solid")
    _facade_details()
    _porch()
    _chimney()

func _triangle(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
        tint: Color=Color.WHITE) -> void:
    s.set_color(tint)
    s.set_uv(Vector2(0,0))
    s.add_vertex(a)
    s.set_color(tint)
    s.set_uv(Vector2(1,0))
    s.add_vertex(b)
    s.set_color(tint)
    s.set_uv(Vector2(0.5,1))
    s.add_vertex(c)

func _quad(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,
        tint: Color=Color.WHITE) -> void:
    _triangle(s,a,b,c,tint)
    _triangle(s,a,c,d,tint)

func _wall_shell() -> ArrayMesh:
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var hx: float=width*0.5
    var hz: float=depth*0.5
    var H: float=wall_height
    var ridge: float=H+1.75+float(variant%3)*0.25
    var base_tint:=Color.WHITE
    # Four continuous wall elevations, with original timber/stone pattern.
    _quad(s,Vector3(-hx,0,hz),Vector3(hx,0,hz),Vector3(hx,H,hz),Vector3(-hx,H,hz),base_tint)
    _quad(s,Vector3(hx,0,-hz),Vector3(-hx,0,-hz),Vector3(-hx,H,-hz),Vector3(hx,H,-hz),base_tint)
    _quad(s,Vector3(-hx,0,-hz),Vector3(-hx,0,hz),Vector3(-hx,H,hz),Vector3(-hx,H,-hz),base_tint)
    _quad(s,Vector3(hx,0,hz),Vector3(hx,0,-hz),Vector3(hx,H,-hz),Vector3(hx,H,hz),base_tint)
    _triangle(s,Vector3(-hx,H,hz),Vector3(hx,H,hz),Vector3(0,ridge,hz))
    _triangle(s,Vector3(hx,H,-hz),Vector3(-hx,H,-hz),Vector3(0,ridge,-hz))
    s.generate_normals()
    return s.commit()

func _roof_mesh() -> ArrayMesh:
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var hx: float=width*0.5+0.64
    var hz: float=depth*0.5+0.58
    var ridge: float=wall_height+1.78+float(variant%3)*0.25
    var eave: float=wall_height-0.02
    # Two continuous gabled roof planes with a generous expressive overhang.
    _quad(s,Vector3(-hx,eave,-hz),Vector3(0,ridge,-hz),
        Vector3(0,ridge,hz),Vector3(-hx,eave,hz))
    _quad(s,Vector3(0,ridge,-hz),Vector3(hx,eave,-hz),
        Vector3(hx,eave,hz),Vector3(0,ridge,hz))
    # Architectural roof edge trim is integrated into this source mesh.
    for side in [-1.0,1.0]:
        var x: float=float(side)*hx
        _quad(s,Vector3(x,eave-0.17,-hz),Vector3(x,eave-0.17,hz),
            Vector3(x,eave,hz),Vector3(x,eave,-hz))
    s.generate_normals()
    return s.commit()

func _plaster_material(color: Color) -> ShaderMaterial:
    var shader:=Shader.new()
    shader.code="""
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform vec4 pigment : source_color;
float h(vec2 p){ return fract(sin(dot(p,vec2(12.989,78.233)))*43758.545); }
void fragment(){
    float flecks=h(floor(UV*vec2(95.0,83.0)));
    float wash=sin(UV.x*29.0+cos(UV.y*47.0))*0.025;
    ALBEDO=pigment.rgb*(0.92+0.10*flecks+wash);
    ROUGHNESS=0.9;
    SPECULAR=0.17;
}"""
    var mat:=ShaderMaterial.new()
    mat.shader=shader
    mat.set_shader_parameter("pigment",color)
    return mat

func _roof_material(color: Color) -> ShaderMaterial:
    var shader:=Shader.new()
    shader.code="""
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform vec4 pigment : source_color;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.545);}
void fragment(){
    vec2 tiles=UV*vec2(11.0,17.0);
    tiles.x+=mod(floor(tiles.y),2.0)*0.5;
    float joint=max(step(0.935,fract(tiles.x)),step(0.94,fract(tiles.y)));
    float mottled=h(floor(tiles));
    ALBEDO=pigment.rgb*mix(0.83+mottled*0.24,0.56,joint);
    ROUGHNESS=0.82;
    SPECULAR=0.16;
}"""
    var mat:=ShaderMaterial.new()
    mat.shader=shader
    mat.set_shader_parameter("pigment",color)
    return mat

func _facade_details() -> void:
    # Window glass, shutters, wooden support beams, trim, and a central door
    # share one vertex-color mesh to keep a settlement's draw calls bounded.
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var hx: float=width*0.5
    var hz: float=depth*0.5
    var ivory:=Color("#f3e3ca")
    var wood:=roof_color.darkened(0.34)
    var glass:=Color("#9ac3ca")
    var front: float=hz+0.024
    var plank: float=front+0.012
    var window_count: int=2 if width<6.4 else 3
    for i in range(window_count):
        var x: float=-hx*0.72+float(i)*hx*1.44/maxf(1.0,float(window_count-1))
        if absf(x)<0.72:
            continue
        var bottom: float=wall_height*0.39
        var top: float=bottom+1.10
        _quad(s,Vector3(x-0.46,bottom,front),Vector3(x+0.46,bottom,front),
            Vector3(x+0.46,top,front),Vector3(x-0.46,top,front),glass)
        _quad(s,Vector3(x-0.49,bottom-0.1,plank),Vector3(x+0.49,bottom-0.1,plank),
            Vector3(x+0.49,bottom,plank),Vector3(x-0.49,bottom,plank),ivory)
        _quad(s,Vector3(x-0.035,bottom,plank),Vector3(x+0.035,bottom,plank),
            Vector3(x+0.035,top,plank),Vector3(x-0.035,top,plank),ivory)
        _quad(s,Vector3(x-0.46,bottom+(top-bottom)*0.47,plank),
            Vector3(x+0.46,bottom+(top-bottom)*0.47,plank),
            Vector3(x+0.46,bottom+(top-bottom)*0.53,plank),
            Vector3(x-0.46,bottom+(top-bottom)*0.53,plank),ivory)
        # Angled shutters improve silhouettes without repeated stock cuboids.
        for side in [-1.0,1.0]:
            var sx: float=x+float(side)*0.63
            _quad(s,Vector3(sx-0.16,bottom,front),
                Vector3(sx+0.16,bottom,front),
                Vector3(sx+0.22,top,front),
                Vector3(sx-0.22,top,front),wood)
    var door_width: float=1.24
    _quad(s,Vector3(-door_width*0.5,0,plank),Vector3(door_width*0.5,0,plank),
        Vector3(door_width*0.5,2.28,plank),Vector3(-door_width*0.5,2.28,plank),wood)
    _quad(s,Vector3(-0.56,2.28,plank),Vector3(0.56,2.28,plank),
        Vector3(0.56,2.42,plank),Vector3(-0.56,2.42,plank),ivory)
    for x in [-hx*0.89,hx*0.89]:
        _quad(s,Vector3(x-0.065,0,front),Vector3(x+0.065,0,front),
            Vector3(x+0.065,wall_height,front),Vector3(x-0.065,wall_height,front),wood)
    s.generate_normals()
    var mesh:=MeshInstance3D.new()
    mesh.name="HandPaintedWindowAndFacadeSystem"
    mesh.mesh=s.commit()
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=Color.WHITE
    mat.vertex_color_use_as_albedo=true
    mat.roughness=0.73
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mesh.material_override=mat
    add_child(mesh)

func _porch() -> void:
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var base: float=depth*0.5+0.9
    var tone:=Color("#b79772")
    var light:=Color("#d2bea2")
    for layer in range(3):
        var front_z: float=base+float(layer)*0.47
        var y: float=0.33-float(layer)*0.11
        _quad(s,Vector3(-1.4,y,front_z-0.23),Vector3(1.4,y,front_z-0.23),
            Vector3(1.4,y,front_z+0.23),Vector3(-1.4,y,front_z+0.23),tone)
        _quad(s,Vector3(-1.4,0,front_z+0.23),Vector3(1.4,0,front_z+0.23),
            Vector3(1.4,y,front_z+0.23),Vector3(-1.4,y,front_z+0.23),light)
    s.generate_normals()
    var step:=MeshInstance3D.new()
    step.name="LayeredStoneAndWoodEntry"
    step.mesh=s.commit()
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=Color("#bea180")
    mat.roughness=0.88
    mat.vertex_color_use_as_albedo=true
    step.material_override=mat
    add_child(step)
    # Doorstep is traversable but solid; separate ramp sized to the visible steps.
    var step_body:=WorldCollision.solid_box(step,Vector3(2.7,0.35,1.8),"entry_steps")
    step_body.position=Vector3(0,0.20,depth*0.5+1.2)

func _chimney() -> void:
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var x: float=width*0.29
    var z: float=-depth*0.22
    var low: float=wall_height+0.45
    var high: float=wall_height+3.10
    var a: float=0.42
    for side in range(4):
        var theta: float=float(side)*TAU/4.0+PI*0.25
        var next: float=float(side+1)*TAU/4.0+PI*0.25
        _quad(s,
            Vector3(x+cos(theta)*a,low,z+sin(theta)*a),
            Vector3(x+cos(next)*a,low,z+sin(next)*a),
            Vector3(x+cos(next)*a,high,z+sin(next)*a),
            Vector3(x+cos(theta)*a,high,z+sin(theta)*a))
    s.generate_normals()
    var node:=MeshInstance3D.new()
    node.name="HandCarvedChimney"
    node.mesh=s.commit()
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=Color("#b88c7f")
    mat.roughness=0.93
    node.material_override=mat
    add_child(node)
    var chimney_body:=WorldCollision.solid_box(node,Vector3(a*1.7,high-low,a*1.7),"chimney")
    chimney_body.position=Vector3(x,(low+high)*0.5,z)
