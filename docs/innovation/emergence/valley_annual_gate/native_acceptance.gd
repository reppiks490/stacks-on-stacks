extends SceneTree
## E18 native negative regression: existing valley daily reward gates must use
## monotonic day_epoch rather than day-of-season. Expected RED until fixed.
const Valley = preload("res://scripts/valley.gd")

class FakeGame:
    extends RefCounted
    var year: int = 1
    var day: int = 1
    var season_index: int = 0
    var energy: float = 100.0
    var items: Dictionary = {}
    var restoration: int = 0
    func day_epoch() -> int:
        return (year - 1) * 56 + season_index * 14 + day
    func spend_energy(amount: float) -> bool:
        if energy < amount:
            return false
        energy -= amount
        return true
    func grant_item(id: String, quantity: int) -> void:
        items[id] = int(items.get(id, 0)) + quantity
    func add_restoration(points: int) -> void:
        restoration += points

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := FakeGame.new()
    var valley := Node3D.new()
    valley.set_script(Valley)
    root.add_child(valley)
    valley.game = game
    valley.forage_locations = [Vector3(1, 0, 1)]
    var first_fish: String = valley.act("fish", valley.lake_center)
    var first_forage: String = valley.act("forage", Vector3(1, 0, 1))
    var before_fish: int = int(game.items.get("fish", 0))
    var before_herbs: int = int(game.items.get("wild_herb", 0))
    game.year = 2
    game.energy = 100.0
    var second_fish: String = valley.act("fish", valley.lake_center)
    var second_forage: String = valley.act("forage", Vector3(1, 0, 1))
    var fish_ok: bool = int(game.items.get("fish", 0)) == before_fish + 1
    var forage_ok: bool = int(game.items.get("wild_herb", 0)) == before_herbs + 2
    print("E18 annual gate: initial fish=", first_fish, " initial forage=", first_forage)
    print("E18 annual gate: next-year fish=", second_fish, " next-year forage=", second_forage)
    print("E18 annual gate: year-two fish accepted=", fish_ok, " forage accepted=", forage_ok)
    valley.queue_free()
    if not fish_ok or not forage_ok:
        push_error("E18 FAIL: valley daily gate reuses day-of-season across years; migrate fishing_day/forage_day to game.day_epoch() with save compatibility.")
        quit(1)
    else:
        print("E18 PASS: cross-year fishing and foraging gates")
        quit(0)
