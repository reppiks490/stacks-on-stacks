extends SceneTree
## Village-owned native runtime acceptance. Deliberately RED until authored NPCs ship.
## Run: godot --headless --path . --script res://tests/native_village_visual_runtime_gate.gd
## No screenshots or FPS claims are inferred from this test.

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        _fail("ordinary launch scene missing")
        return
    var root: Node = packed.instantiate()
    get_root().add_child(root)
    await process_frame
    await physics_frame
    var villages: Array[Node] = get_nodes_in_group("village_visual_gate")
    if villages.is_empty():
        _collect_villages(root, villages)
    if villages.is_empty():
        _fail("no live village domain with residents in ordinary launch")
        return
    var checked := 0
    for village in villages:
        var records: Variant = village.get("residents")
        if not (records is Array):
            continue
        for resident in records:
            if not (resident is Dictionary) or not resident.has("node"):
                continue
            var actor: Node = resident["node"]
            checked += 1
            if not is_instance_valid(actor) or not actor.is_inside_tree():
                _fail("resident absent from live scene")
                return
            var meshes: Array[MeshInstance3D] = []
            _collect_meshes(actor, meshes)
            if meshes.is_empty():
                _fail("resident has no integrated 3D mesh: " + actor.name)
                return
            for mesh_node in meshes:
                if mesh_node.mesh is CapsuleMesh or mesh_node.mesh is SphereMesh or mesh_node.mesh is BoxMesh:
                    _fail("primitive finished NPC mesh: " + actor.name)
                    return
            if _find_skeleton(actor) == null:
                _fail("resident lacks live Skeleton3D rig: " + actor.name)
                return
            if _find_animation_player(actor) == null:
                _fail("resident lacks AnimationPlayer: " + actor.name)
                return
            if not (actor is CharacterBody3D or actor is StaticBody3D):
                _fail("resident lacks collision-aware physics body: " + actor.name)
                return
    if checked == 0:
        _fail("no resident actor instances checked")
        return
    print("PASS village runtime authored rig/collision gate: ", checked, " actors")
    quit(0)

func _collect_villages(node: Node, result: Array[Node]) -> void:
    if node.get_script() != null and str(node.get_script().resource_path).ends_with("/village.gd"):
        result.append(node)
    for child in node.get_children():
        _collect_villages(child, result)

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        result.append(node)
    for child in node.get_children():
        _collect_meshes(child, result)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _fail(message: String) -> void:
    push_error("FAIL village runtime quality gate: " + message)
    quit(1)
