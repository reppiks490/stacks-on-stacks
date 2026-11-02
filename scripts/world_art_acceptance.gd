extends SceneTree
## Native engine contract for original valley art, seasons and annual action gating.
## Run with Godot 4.7.2 --headless --path . --script res://scripts/world_art_acceptance.gd

class Host extends RefCounted:
    var day: int = 1
    var year: int = 1
    var season_index: int = 0
    var weather: String = "Clear"
    var energy: float = 100.0
    var inventory: Dictionary = {}
    var restoration: int = 0

    func day_epoch() -> int:
        return (year - 1) * 56 + season_index * 14 + day

    func spend_energy(amount: float) -> bool:
        if energy < amount:
            return false
        energy -= amount
        return true

    func grant_item(item: String, quantity: int) -> void:
        inventory[item] = int(inventory.get(item, 0)) + quantity

    func add_restoration(points: int) -> void:
        restoration += points

var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("WORLD ART ACCEPTANCE FAILED: " + message)

func _run() -> void:
    var host := Host.new()
    var valley := preload("res://scripts/valley.gd").new()
    root.add_child(valley)
    valley.setup(host)
    _check(valley.ground_mesh != null, "ground mesh exists")
    _check(valley.lake_surface != null, "lake surface exists")
    _check(valley.flower_instances != null, "batched meadow exists")
    _check(valley.flower_instances.multimesh.instance_count == (180 if OS.has_feature("mobile") else 480), "device-conditional flower instance budget")
    _check(valley.foliage_canopies.size() > 0, "forest canopy nodes exist")
    _check(valley.foliage_canopies.size() == valley.foliage_variants.size(), "foliage palette mapping")
    _check(valley.flower_variants.size() == valley.flower_instances.multimesh.instance_count, "meadow palette mapping")
    _check(valley.last_season == 0, "initial spring palette")
    _check(valley.last_weather == "Clear", "initial clear lake palette")

    var spring_color: Color = valley.ground_mesh.material_override.albedo_color
    host.season_index = 2
    valley._process(0.016)
    _check(valley.last_season == 2, "autumn palette applies without world rebuild")
    _check(valley.ground_mesh.material_override.albedo_color != spring_color, "season changes terrain color")
    var stored_color: Color = valley.flower_instances.multimesh.get_instance_color(0)
    var target_color: Color = valley._flower_color(2, 0)
    print("WORLD ART COLOR DIAGNOSTIC actual=", stored_color, " target=", target_color)
    # MultiMesh instance colors are quantized; compare against 8-bit storage precision.
    _check(absf(stored_color.r - target_color.r) < 0.006 and absf(stored_color.g - target_color.g) < 0.006 and absf(stored_color.b - target_color.b) < 0.006, "autumn blossom instance colors")
    host.weather = "Rain"
    valley._process(0.016)
    _check(valley.last_weather == "Rain", "weather response applies")
    _check(valley.lake_surface.material_override.albedo_color == Color("#4f8296"), "rain darkens lake")

    host.season_index = 0
    host.weather = "Clear"
    valley._process(0.016)
    var lake_point: Vector3 = valley.lake_center
    _check(valley.act("fish", lake_point).contains("+1 fish"), "first cast catches fish")
    _check(int(host.inventory.get("fish", 0)) == 1, "fish credited once")
    _check(valley.act("fish", lake_point).contains("recover"), "same-day fishing blocked")
    host.year = 2
    _check(valley.act("fish", lake_point).contains("+1 fish"), "same season/day in next year is distinct")
    _check(int(host.inventory.get("fish", 0)) == 2, "second-year fish credited")
    _check(valley.act("fish", Vector3.ZERO).contains("Visit"), "distant fishing denied")
    _check(int(host.inventory.get("fish", 0)) == 2, "distant fishing cannot credit fish")

    _check(valley.forage_locations.size() > 0, "forage sites generated")
    if valley.forage_locations.size() > 0:
        var site: Vector3 = valley.forage_locations[0]
        _check(valley.act("forage", site).contains("two aromatic herbs"), "first forage succeeds")
        _check(int(host.inventory.get("wild_herb", 0)) == 2, "forage inventory granted")
        valley.act("forage", site)
        _check(int(host.inventory.get("wild_herb", 0)) == 2, "same-day forage cannot duplicate")
        host.year = 3
        valley.act("forage", site)
        _check(int(host.inventory.get("wild_herb", 0)) == 4, "next-year forage reopens")
    print("EVERBLOOM WORLD ART NATIVE ACCEPTANCE: %d assertions, %d failures" % [assertions, failures])
    quit(1 if failures > 0 else 0)
