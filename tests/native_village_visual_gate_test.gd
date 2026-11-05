extends SceneTree
## Quality gate for the *actual* Village presentation, not concept art.
## Expected to FAIL while residents still use primitive CapsuleMesh placeholders.
## Run: godot --headless --path . --script res://tests/native_village_visual_gate_test.gd
var checks := 0
var failures := 0

func require(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("VILLAGE VISUAL GATE: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host = load("res://tests/village_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    require(village.residents.size() == 6, "six existing residents must remain present")
    for resident in village.residents:
        var actor: Node3D = resident.get("node")
        var rid := str(resident.get("id", "unknown"))
        require(actor != null, rid + " missing scene actor")
        if actor == null:
            continue
        var mesh_nodes: Array[MeshInstance3D] = []
        var skeletons: Array[Skeleton3D] = []
        _collect(actor, mesh_nodes, skeletons)
        require(not skeletons.is_empty(), rid + " has no actual Skeleton3D")
        require(not mesh_nodes.is_empty(), rid + " has no visual mesh")
        var authored := false
        var skinned := false
        for node in mesh_nodes:
            if node.mesh == null:
                continue
            var mesh: Mesh = node.mesh
            if mesh is CapsuleMesh or mesh is SphereMesh or mesh is BoxMesh or mesh is CylinderMesh or mesh is PrismMesh:
                continue
            authored = true
            if node.skin != null and node.skeleton != NodePath():
                skinned = true
        require(authored, rid + " uses only primitive visuals; authored mesh required")
        require(skinned, rid + " lacks a skinned visual bound to an armature")
    print("VILLAGE VISUAL GATE: %d checks; %d failures (zero required for acceptance)" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _collect(node: Node, meshes: Array[MeshInstance3D], skeletons: Array[Skeleton3D]) -> void:
    if node is MeshInstance3D:
        meshes.append(node)
    if node is Skeleton3D:
        skeletons.append(node)
    for child in node.get_children():
        _collect(child, meshes, skeletons)
