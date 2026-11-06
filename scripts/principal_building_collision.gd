extends Node3D
## Principal-owned temporary physics repair for the ordinary valley launch.
## This does NOT certify the primitive buildings as production art.
## Coordinates match scripts/valley.gd::_farmhouse/_town; remove when
## authored building scenes supply their own collision shapes.
const HOUSES := [
    [Vector3(-23, 0, -14), 7.0],
    [Vector3(-4, 0, -15), 8.0],
    [Vector3(22, 0, 10), 6.0],
    [Vector3(34, 0, 12), 6.0],
    [Vector3(44, 0, 5), 6.0],
    [Vector3(35, 0, -7), 6.0],
]

func _ready() -> void:
    for index in range(HOUSES.size()):
        var entry: Array = HOUSES[index]
        var origin: Vector3 = entry[0]
        var width: float = entry[1]
        var body := StaticBody3D.new()
        body.name = "HouseSolid_%02d" % index
        body.collision_layer = 1
        body.collision_mask = 1
        body.position = origin + Vector3(0, 2.0, 0)
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(width, 4.0, 5.2)
        shape_node.shape = shape
        body.add_child(shape_node)
        add_child(body)
