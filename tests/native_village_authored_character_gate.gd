extends SceneTree
## Quality gate: run against the real village presentation, never a mock render.
## Expected to FAIL while the shipped residents use CapsuleMesh.
const VillageScript = preload("res://scripts/village.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var village := Node3D.new()
    village.set_script(VillageScript)
    root.add_child(village)
    var host := Node.new()
    host.set_script(GDScript.new())
    # Setup requires the live game calendar and economy; use the actual
    # main scene rather than a mock host to exercise ordinary integration.
    village.queue_free()
    host.queue_free()
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("QUALITY FAIL: ordinary main scene cannot load")
        quit(1)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    await physics_frame
    var village_nodes := get_nodes_in_group("everbloom_village")
    # The existing Village node may not be grouped; find it by script path.
    var candidates: Array[Node] = []
    _find_villages(game, candidates)
    if candidates.is_empty():
        push_error("QUALITY FAIL: no Village presentation in ordinary launch")
        quit(1)
        return
    var found: int = 0
    var failed: int = 0
    for domain in candidates:
        for resident in domain.residents:
            found += 1
            var actor: Node3D = resident.get("node")
            if actor == null:
                failed += 1
                continue
            var mesh_nodes: Array[MeshInstance3D] = []
            _find_meshes(actor, mesh_nodes)
            var authored := false
            var animated := false
            for part in mesh_nodes:
                if part.mesh is ArrayMesh or part.mesh is ImporterMesh:
                    authored = true
            animated = _has_animation(actor)
            if not authored or not animated:
                failed += 1
                print("QUALITY FAIL NPC ", resident.get("id", "?"),
                    ": authored_mesh=", authored, " animation=", animated)
    if found == 0 or failed > 0:
        push_error("QUALITY FAIL: %d/%d residents lack authored animated presentation" % [failed, found])
        quit(1)
    else:
        print("QUALITY PASS: %d residents have authored mesh and animation nodes" % found)
        quit(0)

func _find_villages(node: Node, result: Array[Node]) -> void:
    if node.get_script() == VillageScript:
        result.append(node)
    for child in node.get_children():
        _find_villages(child, result)

func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        result.append(node)
    for child in node.get_children():
        _find_meshes(child, result)

func _has_animation(node: Node) -> bool:
    if node is AnimationPlayer and node.get_animation_list().size() > 0:
        return true
    if node is AnimationTree and node.anim_player != NodePath(""):
        return true
    for child in node.get_children():
        if _has_animation(child):
            return true
    return false
