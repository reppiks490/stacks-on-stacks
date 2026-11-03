extends SceneTree
## Native runtime physics acceptance: real ray hits, terrain height, perimeter.
var assertions: int=0
var failures: Array[String]=[]

func _check(condition: bool,description: String) -> void:
    assertions+=1
    if not condition:
        failures.append(description)
        push_error("NATIVE SOLIDITY FAIL: "+description)

func _initialize() -> void:
    call_deferred("_execute")

func _execute() -> void:
    var world:=Node3D.new()
    world.name="NativeSolidWorld"
    root.add_child(world)
    var box:=MeshInstance3D.new()
    box.name="RayTargetHouse"
    var cube:=BoxMesh.new()
    cube.size=Vector3(4.0,3.0,4.0)
    box.mesh=cube
    box.position=Vector3(0.0,1.5,0.0)
    world.add_child(box)
    var WorldCollision=load("res://scripts/world_collision.gd")
    var solid: StaticBody3D=WorldCollision.solid_box(box,Vector3(4.0,3.0,4.0))
    _check(solid.collision_layer==1,"building is in the player collision layer")
    _check(solid.get_child_count()>0,"building has a CollisionShape3D")
    WorldCollision.perimeter_barrier(world,Vector3(10.0,12.0,0.0),Vector3(5,24,12),"Test")
    await physics_frame
    await physics_frame
    var space:=world.get_world_3d().direct_space_state
    var target_query:=PhysicsRayQueryParameters3D.create(Vector3(0,7,0),Vector3(0,-4,0))
    var hit: Dictionary=space.intersect_ray(target_query)
    _check(not hit.is_empty(),"downward ray hits solid farmhouse")
    if not hit.is_empty():
        _check(hit.get("collider") is StaticBody3D,"ray hit collider is a physical StaticBody3D")
    var border_query:=PhysicsRayQueryParameters3D.create(Vector3(4,8,0),Vector3(16,8,0))
    var border: Dictionary=space.intersect_ray(border_query)
    _check(not border.is_empty(),"world perimeter wall blocks a crossing ray")
    var continental:=Node3D.new()
    continental.set_script(load("res://scripts/continental_world.gd"))
    world.add_child(continental)
    _check(absf(continental._terrain_height(0.0,0.0))<0.01,"homestead foundation stays level")
    _check(continental._terrain_height(2394.0,0.0)>60.0,"boundary rises into a sculpted ridge")
    _check(continental._terrain_height(2240.0,0.0)<continental._terrain_height(2394.0,0.0),
        "terrain approaches ridge rather than dropping to nowhere")
    # Real-world verification: build the actual gameplay scene and inspect
    # the farmhouse and mountain bridge collider, not just the factory helper.
    var game_scene: PackedScene=load("res://scenes/main.tscn")
    var gameplay: Node3D=game_scene.instantiate()
    root.add_child(gameplay)
    await physics_frame
    await physics_frame
    var game_space:=gameplay.get_world_3d().direct_space_state
    var homestead_ray:=PhysicsRayQueryParameters3D.create(
        Vector3(-23,2.0,-7),Vector3(-23,2.0,-21))
    var homestead_hit: Dictionary=game_space.intersect_ray(homestead_ray)
    _check(not homestead_hit.is_empty(),"actual homestead farmhouse walls block a ray")
    if not homestead_hit.is_empty():
        var wall: CollisionObject3D=homestead_hit["collider"]
        _check(wall.is_in_group("everbloom_world_solid"),
            "actual farmhouse ray strikes intended structural collision group")
    var walk_probe: KinematicCollision3D=gameplay.hero.move_and_collide(
        Vector3(0,0,-12),true)
    _check(walk_probe!=null,"real player capsule cannot tunnel through farmhouse")
    var bridge_ray:=PhysicsRayQueryParameters3D.create(
        Vector3(51,4,-19),Vector3(51,-2,-19))
    var bridge_hit: Dictionary=game_space.intersect_ray(bridge_ray)
    _check(not bridge_hit.is_empty(),"original walking bridge has physical support")
    if not bridge_hit.is_empty():
        var bridge_body: CollisionObject3D=bridge_hit["collider"]
        _check(bridge_body.is_in_group("everbloom_world_solid"),
            "bridge is a solid structural collider")
    if failures.is_empty():
        print("NATIVE SOLIDITY PASS: %d physics and world assertions" % assertions)
        quit(0)
    else:
        printerr("NATIVE SOLIDITY FAIL: %s" % ", ".join(failures))
        quit(1)
