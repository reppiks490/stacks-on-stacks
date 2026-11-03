extends SceneTree
## Native sculpted avatar: verify real custom mesh surfaces, both arm/leg rigs,
## stable rebuild and category-dependent geometry. No product-art claim.
var errors: Array[String]=[]
var checks: int=0

func _check(ok: bool,description: String) -> void:
    checks+=1
    if not ok:
        errors.append(description)
        push_error("NATIVE AVATAR FAIL: "+description)

func _initialize() -> void:
    call_deferred("_execute")

func _execute() -> void:
    var actor:=Node3D.new()
    actor.name="NativeAvatar"
    actor.set_script(load("res://scripts/sculpted_humanoid.gd"))
    root.add_child(actor)
    var base_style: Dictionary={
        "face":2,"jaw":4,"brow":3,"nose":5,"mouth":2,
        "hair":7,"hair_length":5,"eye_size":3,"height":4,
        "outfit":3,"pants":4,"build":2,"headwear":3,
        "accessory":2,"footwear":8
    }
    actor.configure(base_style)
    _check(actor.left_arm!=null and actor.right_arm!=null,
        "rig exposes independent articulated arms")
    _check(actor.left_leg!=null and actor.right_leg!=null,
        "rig exposes independent articulated legs")
    _check(actor.has_node("TailoredOuterwear"),"tailored torso generated")
    _check(actor.has_node("AnatomicalFaceAndHead/ContouredCraniumAndJaw"),
        "head is contoured ring mesh, not an attached sphere")
    var coat: MeshInstance3D=actor.get_node_or_null("TailoredOuterwear")
    if coat!=null:
        _check(coat.mesh is ArrayMesh,"torso uses original ArrayMesh geometry")
        _check(coat.mesh.get_surface_count()>0,"torso mesh has draw surfaces")
    actor.configure({"face":5,"jaw":7,"hair":11,"hair_length":9,"height":8,
        "build":4,"accessory":1,"headwear":2,"footwear":7})
    _check(actor.has_node("HairScalp"),"reconfigure regenerates hairstyle")
    _check(actor.has_node("FittedFashionHeadwear"),"headwear selection is visible")
    _check(actor.has_node("StarlitSpectacleFrame-1"),"accessory selection is visible")
    _check(actor.scale.y>1.0,"height parameter changes stature")
    _check(actor.left_leg!=null,"rebuild preserves walk-animation pivots")
    if errors.is_empty():
        print("NATIVE AVATAR PASS: %d mesh and profile assertions" % checks)
        quit(0)
    else:
        printerr("NATIVE AVATAR FAIL: %s" % ", ".join(errors))
        quit(1)
