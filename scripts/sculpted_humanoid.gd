extends Node3D
## Hand-authored procedural humanoid mesh kit, not an assortment of stock
## spheres/capsules/boxes. Multi-ring sculpted anatomy, fitted garments,
## faceted hair, contoured eyes and facial features are parameterized for
## both the farmer and frontier NPCs. Original geometry, no borrowed assets.
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var settings: Dictionary={}
var palette: Dictionary={}
var surfaces: Dictionary={}

func configure(preset: Dictionary) -> void:
    settings=preset.duplicate(true)
    for child in get_children():
        remove_child(child)
        child.queue_free()
    palette={
        "skin":_tint("skin_tint",Color("#ce987b")),
        "coat":_tint("coat_tint",Color("#567d7b")),
        "trousers":_tint("trousers_tint",Color("#465563")),
        "hair":_tint("hair_tint",Color("#684a37")),
        "eyes":_tint("iris_tint",Color("#658da0")),
        "boots":_tint("boot_tint",Color("#5a4337")),
        "metal":Color("#d6bb87")
    }
    _sculpt_body()
    _face()
    _hair()
    _fashion()

func _tint(key: String,default_color: Color) -> Color:
    var raw: Variant=settings.get(key,default_color)
    return raw if raw is Color else Color(str(raw))

func _selection(key: String, maximum: int=12) -> int:
    return posmod(int(settings.get(key,0)),maximum)

func _material(color: Color,cloth: bool=false) -> StandardMaterial3D:
    var key: String=color.to_html()+"_"+str(cloth)
    if surfaces.has(key):
        return surfaces[key]
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=0.94 if cloth else 0.78
    m.metallic=0.0
    m.cull_mode=BaseMaterial3D.CULL_DISABLED
    surfaces[key]=m
    return m

func _ring_point(ring: Vector4,theta: float) -> Vector3:
    return Vector3(cos(theta)*ring.y,ring.x,sin(theta)*ring.z+ring.w)

func _tri(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
    surface.set_uv(Vector2(0,0))
    surface.add_vertex(a)
    surface.set_uv(Vector2(1,0))
    surface.add_vertex(b)
    surface.set_uv(Vector2(0.5,1))
    surface.add_vertex(c)

func _ring_mesh(rings: Array,segments: int=14) -> ArrayMesh:
    # Vector4 rings: y, half-width, half-depth, longitudinal center offset.
    # Paired longitudinal loops create contoured silhouettes and garments.
    var t:=SurfaceTool.new()
    t.begin(Mesh.PRIMITIVE_TRIANGLES)
    for layer in range(rings.size()-1):
        var ring_a: Vector4=rings[layer]
        var ring_b: Vector4=rings[layer+1]
        for i in range(segments):
            var a: float=float(i)*TAU/float(segments)
            var b: float=float(i+1)*TAU/float(segments)
            var low_left:=_ring_point(ring_a,a)
            var low_right:=_ring_point(ring_a,b)
            var high_left:=_ring_point(ring_b,a)
            var high_right:=_ring_point(ring_b,b)
            _tri(t,low_left,high_left,low_right)
            _tri(t,low_right,high_left,high_right)
    var first: Vector4=rings[0]
    var last: Vector4=rings[rings.size()-1]
    for i in range(segments):
        var angle_a:=float(i)*TAU/float(segments)
        var angle_b:=float(i+1)*TAU/float(segments)
        _tri(t,Vector3(0,first.x,first.w),_ring_point(first,angle_b),_ring_point(first,angle_a))
        _tri(t,Vector3(0,last.x,last.w),_ring_point(last,angle_a),_ring_point(last,angle_b))
    t.generate_normals()
    return t.commit()

func _part(parent: Node3D,name: String,rings: Array,color: Color,cloth: bool=true) -> MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    item.mesh=_ring_mesh(rings)
    item.material_override=_material(color,cloth)
    parent.add_child(item)
    return item

func _disc(parent: Node3D,name: String,at: Vector3,size: Vector2,
        tint: Color,sides: int=12,rotation_z: float=0.0) -> MeshInstance3D:
    # Thin frontal mesh, not an eye sphere. Slightly dished for expression.
    var t:=SurfaceTool.new()
    t.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(sides):
        var a:=float(i)*TAU/float(sides)
        var b:=float(i+1)*TAU/float(sides)
        var p1:=Vector3(cos(a)*size.x,sin(a)*size.y,-0.006)
        var p2:=Vector3(cos(b)*size.x,sin(b)*size.y,-0.006)
        _tri(t,Vector3(0,0,0.01),p1,p2)
    t.generate_normals()
    var obj:=MeshInstance3D.new()
    obj.name=name
    obj.mesh=t.commit()
    obj.position=at
    obj.rotation.z=rotation_z
    obj.material_override=_material(tint)
    parent.add_child(obj)
    return obj

func _sculpt_body() -> void:
    var bulk: float=[0.82,0.92,1.0,1.11,1.24][_selection("build",5)]
    var height_factor: float=0.91+float(_selection("height",9))*0.022
    scale=Vector3(bulk,height_factor,0.97)
    var skin: Color=palette["skin"]
    var coat: Color=palette["coat"]
    var trousers: Color=palette["trousers"]
    var boots: Color=palette["boots"]
    var outfit: int=_selection("outfit",12)
    var body_width: float=0.40+(float(outfit%3)-1.0)*0.016
    _part(self,"TailoredOuterwear",[
        Vector4(0.83,0.37,0.29,0.0),
        Vector4(1.01,0.40,0.31,0.0),
        Vector4(1.31,body_width,0.26,0.0),
        Vector4(1.55,0.46,0.27,0.0),
        Vector4(1.71,0.28,0.22,0.0),
        Vector4(1.76,0.16,0.17,0.0)
    ],coat)
    _part(self,"LayeredJacketHem",[
        Vector4(0.77,0.43,0.30,0.015),
        Vector4(0.84,0.45,0.30,0.0),
        Vector4(1.01,0.37,0.28,0.0)
    ],coat.darkened(0.12))
    _part(self,"TailoredCollar",[
        Vector4(1.66,0.22,0.21,0.0),
        Vector4(1.78,0.20,0.19,0.0),
        Vector4(1.87,0.13,0.15,0.0)
    ],coat.lightened(0.22))
    _part(self,"AnatomicalNeck",[
        Vector4(1.75,0.13,0.12,0.0),
        Vector4(1.85,0.125,0.11,0.0),
        Vector4(1.96,0.14,0.13,0.0)
    ],skin,false)
    for side in [-1,1]:
        var x: float=float(side)
        var leg_pivot:=Node3D.new()
        leg_pivot.name="LeftLegRig" if side<0 else "RightLegRig"
        leg_pivot.position=Vector3(x*0.205,0.92,0)
        add_child(leg_pivot)
        if side<0:
            left_leg=leg_pivot
        else:
            right_leg=leg_pivot
        _part(leg_pivot,"TailoredTrouserLeg",[
            Vector4(-0.80,0.126,0.137,0),
            Vector4(-0.62,0.14,0.15,0),
            Vector4(-0.43,0.145,0.159,0),
            Vector4(-0.19,0.166,0.171,0),
            Vector4(0.00,0.193,0.187,0)
        ],trousers)
        _part(leg_pivot,"StructuredBoot",[
            Vector4(-0.91,0.16,0.27,0.12),
            Vector4(-0.865,0.18,0.28,0.10),
            Vector4(-0.77,0.151,0.19,0.037),
            Vector4(-0.57,0.131,0.142,0)
        ],boots)
        var arm_pivot:=Node3D.new()
        arm_pivot.name="LeftShoulderRig" if side<0 else "RightShoulderRig"
        arm_pivot.position=Vector3(x*0.465,1.59,0)
        add_child(arm_pivot)
        if side<0:
            left_arm=arm_pivot
        else:
            right_arm=arm_pivot
        _part(arm_pivot,"SeamedSleeve",[
            Vector4(-0.70,0.121,0.13,0.02),
            Vector4(-0.51,0.138,0.139,0),
            Vector4(-0.30,0.155,0.162,0),
            Vector4(-0.07,0.19,0.19,0),
            Vector4(0.12,0.16,0.16,0)
        ],coat.darkened(0.04))
        _part(arm_pivot,"EmbroideredCuff",[
            Vector4(-0.77,0.119,0.124,0.02),
            Vector4(-0.67,0.133,0.138,0.02)
        ],coat.lightened(0.26))
        _part(arm_pivot,"HandAndFingers",[
            Vector4(-0.99,0.074,0.10,0.03),
            Vector4(-0.91,0.111,0.12,0.025),
            Vector4(-0.78,0.102,0.109,0.02)
        ],skin,false)
    # Material panels and stitched details are thin, not spherical studs.
    for i in range(4):
        _disc(self,"Fastener_%d" % i,Vector3(0,1.53-float(i)*0.17,0.284),
            Vector2(0.031,0.033),palette["metal"],8)

func _face() -> void:
    var skin: Color=palette["skin"]
    var hair: Color=palette["hair"]
    var eyes: Color=palette["eyes"]
    var width: float=[0.88,0.95,1.0,1.05,1.12,1.18][_selection("face",6)]
    var jaw: float=0.72+float(_selection("jaw",9))*0.055
    var head:=Node3D.new()
    head.name="AnatomicalFaceAndHead"
    add_child(head)
    _part(head,"ContouredCraniumAndJaw",[
        Vector4(1.78,0.125*width*jaw,0.155,0.004),
        Vector4(1.86,0.222*width*jaw,0.245,0.008),
        Vector4(2.03,0.314*width,0.290,0.0),
        Vector4(2.22,0.342*width,0.295,-0.008),
        Vector4(2.40,0.288*width,0.26,-0.02),
        Vector4(2.47,0.115*width,0.14,-0.035)
    ],skin,false)
    # Ears and jaw contours are built as lofted anatomical meshes.
    for side in [-1,1]:
        var x: float=float(side)
        var ear:=_part(head,"Ear_%d" % side,[
            Vector4(1.94,0.060,0.086,0),
            Vector4(2.08,0.075,0.09,0),
            Vector4(2.19,0.048,0.064,0)
        ],skin.darkened(0.035),false)
        ear.position.x=x*0.326*width
        var eye_size: float=0.78+0.075*float(_selection("eye_size",9))
        var bx: float=x*0.156*width
        _disc(head,"Sclera_%d" % side,Vector3(bx,2.145,0.297),
            Vector2(0.086*eye_size,0.049*eye_size),Color("#f5efe7"),16,x*0.045)
        _disc(head,"Iris_%d" % side,Vector3(bx,2.145,0.311),
            Vector2(0.044*eye_size,0.047*eye_size),eyes,14)
        _disc(head,"Pupil_%d" % side,Vector3(bx,2.144,0.326),
            Vector2(0.022*eye_size,0.032*eye_size),Color("#20242b"),14)
        _disc(head,"Catchlight_%d" % side,Vector3(bx-0.012,2.160,0.340),
            Vector2(0.009,0.012),Color("#fff5e8"),9)
        var brow_style: int=_selection("brow",10)
        _disc(head,"ExpressiveBrow_%d" % side,
            Vector3(bx,2.257+float(brow_style%3)*0.008,0.291),
            Vector2(0.112,0.019+float(brow_style/4)*0.004),
            hair.darkened(0.18),12,x*(float(brow_style%5)-2.0)*0.055)
        # Cheekbone highlight is applied as a subtle face marking.
        _disc(head,"CheekContour_%d" % side,Vector3(x*0.235,1.996,0.244),
            Vector2(0.060,0.029),skin.lightened(0.04),12)
    var nose: int=_selection("nose",10)
    _part(head,"SculptedNoseBridge",[
        Vector4(2.012,0.064+0.003*float(nose),0.059,0.327+float(nose)*0.003),
        Vector4(2.067,0.055,0.040,0.330),
        Vector4(2.135,0.032,0.026,0.299)
    ],skin.lightened(0.018),false)
    var mouth: int=_selection("mouth",10)
    _disc(head,"LipLine",Vector3(0,1.924+float(mouth%4)*0.006,0.284),
        Vector2(0.092+float(mouth%3)*0.011,0.018),Color("#ac6a68"),16)
    _disc(head,"LowerLip",Vector3(0,1.909+float(mouth%4)*0.006,0.281),
        Vector2(0.071,0.012),skin.darkened(0.095),16)

func _hair() -> void:
    var hair: Color=palette["hair"]
    var style: int=_selection("hair",12)
    var length: int=_selection("hair_length",10)
    # Scalp geometry is a fitted shell with an intentionally irregular hairline.
    _part(self,"HairScalp",[
        Vector4(2.324,0.312,0.254,-0.029),
        Vector4(2.421,0.32,0.272,-0.035),
        Vector4(2.495,0.265,0.235,-0.043),
        Vector4(2.566,0.12,0.12,-0.04)
    ],hair,false)
    var bangs: int=4+style%5
    for i in range(bangs):
        var fraction: float=float(i)/maxf(1.0,float(bangs-1))
        var x: float=-0.30+fraction*0.59
        var hair_tip: float=2.29-float(style%4)*0.026+float(i%3)*0.022
        var tuft:=_part(self,"SculptedFringe_%02d" % i,[
            Vector4(hair_tip,0.026,0.047,0.305),
            Vector4(2.40,0.066,0.080,0.285),
            Vector4(2.515,0.065,0.075,0.21)
        ],hair.lightened(float(i%3)*0.022),false)
        tuft.position.x=x
        tuft.rotation.z=0.10*(float(style%5)-2.0)
    if style in [1,3,5,7,9,11] or length>=4:
        var extension: float=0.10+float(length)*0.075
        for side in [-1,1]:
            var lock:=_part(self,"LayeredSideLocks_%d" % side,[
                Vector4(2.04-extension,0.07,0.10,-0.024),
                Vector4(2.20,0.105,0.134,-0.028),
                Vector4(2.39,0.128,0.14,-0.026)
            ],hair.darkened(0.04),false)
            lock.position.x=float(side)*0.320
    if style in [2,4,6,8,10] or length>6:
        var pony:=_part(self,"WovenPonytail",[
            Vector4(1.69-float(length)*0.042,0.044,0.060,-0.36),
            Vector4(2.11,0.125,0.11,-0.37),
            Vector4(2.38,0.16,0.13,-0.27)
        ],hair.darkened(0.07),false)
        pony.rotation.z=0.12

func _fashion() -> void:
    var hat: int=_selection("headwear",7)
    var accessory: int=_selection("accessory",6)
    var footwear: int=_selection("footwear",10)
    var coats: Color=palette["coat"]
    if hat!=0:
        var hat_color: Color=Color.from_hsv(float(hat*31+28)/360.0,0.32,0.67)
        _part(self,"FittedFashionHeadwear",[
            Vector4(2.48,0.25,0.24,-0.04),
            Vector4(2.62,0.325,0.30,-0.04),
            Vector4(2.74,0.23,0.235,-0.04),
            Vector4(2.78,0.14,0.13,-0.04)
        ],hat_color)
        if hat in [1,2,5,6]:
            _part(self,"WideBrim",[
                Vector4(2.53,0.51,0.45,-0.01),
                Vector4(2.57,0.48,0.45,-0.01)
            ],hat_color.darkened(0.12))
    if accessory==1:
        for side in [-1,1]:
            _disc(self,"StarlitSpectacleFrame%d" % side,
                Vector3(float(side)*0.154,2.145,0.333),Vector2(0.106,0.070),
                Color("#c3ad86"),20)
            _disc(self,"Lens%d" % side,Vector3(float(side)*0.154,2.145,0.338),
                Vector2(0.089,0.053),Color("#aec7c8"),20)
    elif accessory==2:
        for side in [-1,1]:
            _disc(self,"FashionEarring%d" % side,Vector3(float(side)*0.350,1.952,0.068),
                Vector2(0.035,0.054),Color("#e6cc8b"),10)
    elif accessory in [3,4]:
        _part(self,"TailoredFestivalScarf",[
            Vector4(1.67,0.36,0.31,0),
            Vector4(1.76,0.40,0.32,0),
            Vector4(1.84,0.27,0.23,0)
        ],Color("#df9d9a") if accessory==3 else Color("#eac799"))
    elif accessory==5:
        _part(self,"ExplorerSatchel",[
            Vector4(0.82,0.17,0.22,-0.13),
            Vector4(1.10,0.24,0.22,-0.12),
            Vector4(1.32,0.13,0.14,-0.12)
        ],Color("#bb956e"))
    if footwear>=5:
        # Optional legging detail is an extra tapered cloth wrap, no boxes.
        for leg in [left_leg,right_leg]:
            _part(leg,"BootFashionTrim",[
                Vector4(-0.64,0.157,0.157,0),
                Vector4(-0.57,0.169,0.171,0)
            ],coats.lightened(0.19))
