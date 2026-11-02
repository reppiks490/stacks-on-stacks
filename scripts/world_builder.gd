extends Node3D
## Deterministic, runtime-authored low-poly arena; not streamed/world-partitioned.
signal breakable_created(crystal: Node3D)
signal beacon_created(beacon: Node3D)

const Crystal = preload("res://scripts/resonance_crystal.gd")
const Beacon = preload("res://scripts/faction_beacon.gd")
const REGION_SIZE := 76.0

func construct(seed_number: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_number
    _make_box("The Meridian Floor", Vector3(0, -0.45, 0), Vector3(REGION_SIZE, 0.9, REGION_SIZE), Color(0.085, 0.12, 0.18), true)
    _make_box("North Rampart", Vector3(0, 2, -38), Vector3(78, 4, 2), Color(0.17, 0.20, 0.30), true)
    _make_box("South Rampart", Vector3(0, 2, 38), Vector3(78, 4, 2), Color(0.17, 0.20, 0.30), true)
    _make_box("West Rampart", Vector3(-38, 2, 0), Vector3(2, 4, 78), Color(0.17, 0.20, 0.30), true)
    _make_box("East Rampart", Vector3(38, 2, 0), Vector3(2, 4, 78), Color(0.17, 0.20, 0.30), true)
    for i in range(22):
        var pos := Vector3(rng.randf_range(-32.0, 32.0), 0, rng.randf_range(-32.0, 32.0))
        if pos.length() < 9.0 or pos.distance_to(Vector3(-24, 0, -20)) < 5.0 or pos.distance_to(Vector3(24, 0, -20)) < 5.0:
            continue
        var height := rng.randf_range(1.6, 6.5)
        var size := Vector3(rng.randf_range(1.1, 3.2), height, rng.randf_range(1.1, 3.2))
        _make_box("RuinedColumn_%02d" % i, pos + Vector3(0, height / 2.0, 0), size, Color(0.20, 0.23, 0.31), true)
    for i in range(8):
        var crystal := Crystal.new()
        crystal.name = "ResonanceCrystal_%02d" % i
        crystal.position = Vector3(rng.randf_range(-29.0, 29.0), 1.2, rng.randf_range(-29.0, 29.0))
        if crystal.position.length() < 6.0:
            crystal.position.x += 10.0
        add_child(crystal)
        breakable_created.emit(crystal)
    _spawn_beacon("FAC-01", "The Ember Cartographers", Vector3(-25, 1.6, -21))
    _spawn_beacon("FAC-02", "The Hollow Accord", Vector3(25, 1.6, -21))

func _spawn_beacon(id: String, title: String, at: Vector3) -> void:
    var beacon := Beacon.new()
    beacon.faction_id = id
    beacon.beacon_title = title
    beacon.position = at
    add_child(beacon)
    beacon_created.emit(beacon)

func _make_box(label: String, center: Vector3, size: Vector3, color: Color, solid: bool) -> void:
    var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
    holder.name = label
    holder.position = center
    add_child(holder)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.16
    material.roughness = 0.82
    mesh.material_override = material
    holder.add_child(mesh)
    if solid:
        var shape := CollisionShape3D.new()
        var collision := BoxShape3D.new()
        collision.size = size
        shape.shape = collision
        holder.add_child(shape)
