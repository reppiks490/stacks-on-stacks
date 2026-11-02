extends Node3D
## Interactable world object; a choice is not automatically granted on proximity.
signal interaction_requested(beacon: Node3D)
var faction_id: String = "FAC-01"
var beacon_title: String = "Ember Accord"

func _ready() -> void:
    add_to_group("interactables")
    var pole := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.55
    mesh.bottom_radius = 0.9
    mesh.height = 3.2
    pole.mesh = mesh
    var material := StandardMaterial3D.new()
    if faction_id == "FAC-01":
        material.albedo_color = Color(0.95, 0.38, 0.18)
    else:
        material.albedo_color = Color(0.29, 0.39, 0.81)
    material.emission_enabled = true
    material.emission = material.albedo_color * 0.35
    material.emission_energy_multiplier = 0.65
    pole.material_override = material
    add_child(pole)

func interact() -> void:
    interaction_requested.emit(self)
