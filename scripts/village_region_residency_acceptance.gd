extends SceneTree
## Run: godot --headless --path . --script res://scripts/village_region_residency_acceptance.gd
const Region = preload("res://scripts/village_region_residency.gd")
var assertions := 0
var failures := 0

func check(condition: bool, label: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("V17 FAILED: " + label)

func _initialize() -> void:
    check(Region.chunk_for_position(0.0, 0.0) == Vector2i(0, 0), "origin")
    check(Region.chunk_for_position(149.99, 149.99) == Vector2i(0, 0), "first edge")
    check(Region.chunk_for_position(150.0, 150.0) == Vector2i(1, 1), "second chunk")
    check(Region.chunk_for_position(4799.99, 4799.99) == Vector2i(31, 31), "far corner")
    check(Region.chunk_for_position(4800.0, 0.0) == Vector2i(-1, -1), "outside")
    check(Region.chunk_for_position(-1.0, 0.0) == Vector2i(-1, -1), "negative")
    check(Region.neighborhood(Vector2i(16, 16)).size() == 9, "interior 3x3")
    check(Region.neighborhood(Vector2i(0, 0)).size() == 4, "corner clipping")
    check(Region.neighborhood(Vector2i(0, 15)).size() == 6, "edge clipping")
    check(Region.neighborhood(Vector2i(-1, 0)).is_empty(), "invalid center")
    var atlas := []
    for i in range(28):
        atlas.append({"id":"region_%02d" % i, "x":float(i * 150), "z":75.0, "kind":"village"})
    check(Region.validate_destinations(atlas) == "", "28 valid destinations")
    atlas[27]["id"] = atlas[0]["id"]
    check(Region.validate_destinations(atlas) != "", "duplicate atlas ID")
    atlas[27]["id"] = "region_27"
    atlas[27]["x"] = 4800.0
    check(Region.validate_destinations(atlas) != "", "out-of-bounds atlas")
    var residents := [{"id":"a", "x":160.0, "z":160.0}, {"id":"b", "x":4700.0, "z":4700.0}, {"id":"a", "x":160.0, "z":160.0}]
    var nearby := Region.active_residents(residents, Vector2i(1, 1))
    check(nearby.size() == 1, "streamed resident deduplication")
    check(str(nearby[0]["id"]) == "a", "stable resident identity")
    var history := {}
    check(Region.mark_interaction(history, "a", 56), "day 56 admitted")
    check(not Region.mark_interaction(history, "a", 56), "same-day duplicate rejected")
    check(Region.mark_interaction(history, "a", 57), "year rollover admitted")
    check(not Region.mark_interaction(history, "a", 57), "year two duplicate rejected")
    var copy := history.duplicate(true)
    check(not Region.mark_interaction(copy, "a", 57), "reload duplicate rejected")
    print("V17 REGION RESIDENCY: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
