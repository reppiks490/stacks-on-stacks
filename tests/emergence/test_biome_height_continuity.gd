extends SceneTree
## Native negative regression: biome transitions must not produce terrain cliffs.
## Run: godot --headless --path . --script res://tests/emergence/test_biome_height_continuity.gd
## Isolated test: intentionally fails against discontinuous biome multiplier.
const WORLD = preload("res://scripts/continental_world.gd")
const EPS := 0.001
const MAX_STEP := 0.10

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world = WORLD.new()
    root.add_child(world)
    var failures: Array[String] = []
    # x=90 switches biome 0 -> 1; z=285 switches biome 0 -> 2.
    # x=-325,z<-260 switches biome 0 -> 3.
    # x=350,z>200 switches biome 1 -> 4.
    # z=-390,x>120 switches biome 1 -> 5.
    var crossings: Array[Dictionary] = [
        {"label":"east grassland", "a":Vector2(90.0-EPS,150.0), "b":Vector2(90.0+EPS,150.0)},
        {"label":"northern highland", "a":Vector2(0.0,285.0-EPS), "b":Vector2(0.0,285.0+EPS)},
        {"label":"western ridge", "a":Vector2(-325.0+EPS,-300.0), "b":Vector2(-325.0-EPS,-300.0)},
        {"label":"eastern upland", "a":Vector2(350.0-EPS,250.0), "b":Vector2(350.0+EPS,250.0)},
        {"label":"coastal transition", "a":Vector2(200.0,-390.0+EPS), "b":Vector2(200.0,-390.0-EPS)}
    ]
    for crossing in crossings:
        var a: Vector2 = crossing["a"]
        var b: Vector2 = crossing["b"]
        var ha: float = world._terrain_height(a.x,a.y)
        var hb: float = world._terrain_height(b.x,b.y)
        if not is_finite(ha) or not is_finite(hb):
            failures.append("%s: nonfinite terrain" % crossing["label"])
        elif absf(ha-hb) > MAX_STEP:
            failures.append("%s: %.4f m discontinuity" % [crossing["label"],absf(ha-hb)])
    world.queue_free()
    if failures.is_empty():
        print("PASS: 5 biome-boundary terrain height continuity checks")
        quit(0)
    else:
        for failure in failures:
            push_error("FAIL: "+failure)
        quit(1)
