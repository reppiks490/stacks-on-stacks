extends RefCounted
## Sculpted vegetation and natural stone for the 4.8 km continent.
## Shared low-poly authored meshes: leaf clusters are shaped blades, not
## spheres. Deterministic vertex colors and no third-party source assets.
static func _tri(t: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
    t.set_color(color)
    t.set_uv(Vector2(0,0))
    t.add_vertex(a)
    t.set_color(color)
    t.set_uv(Vector2(1,0))
    t.add_vertex(b)
    t.set_color(color)
    t.set_uv(Vector2(0.5,1))
    t.add_vertex(c)

static func make_canopy_mesh() -> ArrayMesh:
    var rng:=RandomNumberGenerator.new()
    rng.seed=2026110209
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tint_a:=Color("#e7f2d5")
    var tint_b:=Color("#94b389")
    # Forty-eight ribbons across six nested bough layers, with strongly
    # asymmetrical pointed leaves for legible silhouettes at distance.
    for tier in range(7):
        var tier_y: float=-0.35+float(tier)*0.116
        var tier_radius: float=0.42*(1.0-0.08*float(tier))
        for i in range(18):
            var a: float=TAU*(float(i)+float(tier%2)*0.5)/18.0
            var root: Vector3=Vector3(cos(a)*tier_radius*0.45,tier_y,sin(a)*tier_radius*0.45)
            var reach: float=rng.randf_range(0.19,0.39)*maxf(0.45,1.0-float(tier)*0.065)
            var direction:=Vector3(cos(a),rng.randf_range(0.15,0.58),sin(a)).normalized()
            var tip: Vector3=root+direction*reach
            var midpoint: Vector3=root+direction*reach*0.55
            var across:=Vector3(-sin(a),0.0,cos(a))*rng.randf_range(0.065,0.12)
            var sheen: float=rng.randf_range(0.2,0.72)
            var tint: Color=tint_a.lerp(tint_b,sheen)
            _tri(s,root,midpoint-across,tip,tint)
            _tri(s,root,tip,midpoint+across,tint.lightened(0.05))
            _tri(s,tip,midpoint-across,root,tint)
            _tri(s,tip,root,midpoint+across,tint.lightened(0.05))
    s.generate_normals()
    return s.commit()

static func make_trunk_mesh() -> ArrayMesh:
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segments: int=10
    for level in range(2):
        var y0: float=-0.5+float(level)*0.5
        var y1: float=y0+0.5
        var r0: float=0.5-float(level)*0.11
        var r1: float=r0-0.11
        for i in range(segments):
            var a: float=float(i)*TAU/float(segments)
            var b: float=float(i+1)*TAU/float(segments)
            var d: float=0.91+0.09*sin(float(i)*2.4+float(level))
            var e: float=0.91+0.09*sin(float(i+1)*2.4+float(level))
            var p0:=Vector3(cos(a)*r0*d,y0,sin(a)*r0*d)
            var p1:=Vector3(cos(b)*r0*e,y0,sin(b)*r0*e)
            var p2:=Vector3(cos(a)*r1*d,y1,sin(a)*r1*d)
            var p3:=Vector3(cos(b)*r1*e,y1,sin(b)*r1*e)
            var bark:=Color("#a78a67") if i%3 else Color("#78674e")
            _tri(s,p0,p2,p1,bark)
            _tri(s,p1,p2,p3,bark.lightened(0.06))
    s.generate_normals()
    return s.commit()

static func make_rock_mesh() -> ArrayMesh:
    var s:=SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segments: int=9
    var layers: Array[Vector3]=[
        Vector3(-0.50,0.37,0.35),
        Vector3(-0.15,0.53,0.48),
        Vector3(0.22,0.45,0.43),
        Vector3(0.45,0.16,0.19)
    ]
    for j in range(layers.size()-1):
        var low: Vector3=layers[j]
        var high: Vector3=layers[j+1]
        for i in range(segments):
            var theta: float=TAU*float(i)/float(segments)
            var theta_next: float=TAU*float(i+1)/float(segments)
            var waviness: float=1.0+0.12*sin(float(i)*2.3)
            var next_wave: float=1.0+0.12*sin(float(i+1)*2.3)
            var a:=Vector3(cos(theta)*low.y*waviness,low.x,sin(theta)*low.z*waviness)
            var b:=Vector3(cos(theta_next)*low.y*next_wave,low.x,sin(theta_next)*low.z*next_wave)
            var c:=Vector3(cos(theta)*high.y*waviness,high.x,sin(theta)*high.z*waviness)
            var d:=Vector3(cos(theta_next)*high.y*next_wave,high.x,sin(theta_next)*high.z*next_wave)
            var shade:=Color("#bcc1b8") if i%3 else Color("#8c968d")
            _tri(s,a,c,b,shade)
            _tri(s,b,c,d,shade.lightened(0.05))
    s.generate_normals()
    return s.commit()
