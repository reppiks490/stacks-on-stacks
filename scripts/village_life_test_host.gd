extends Node
## Deterministic test facade; actual village.gd and JSON data run in Godot.
var year: int = 1
var season_index: int = 0
var day: int = 1
var minute_of_day: float = 360.0
var weather: String = "Clear"
var gold: int = 380
var energy: float = 100.0
var restoration: int = 0
var social_contacts: Dictionary = {}
var inventory: Dictionary = {"wild_herb":8, "bluebell":8, "wood":8, "fish":8, "milk":8}

func day_epoch() -> int:
    return (year - 1) * 56 + season_index * 14 + day

func advance_day() -> void:
    day += 1
    if day > 14:
        day = 1
        season_index = (season_index + 1) % 4
        if season_index == 0:
            year += 1
    minute_of_day = 360.0
    energy = 100.0

func consume_item(item: String, count: int) -> bool:
    if count <= 0 or int(inventory.get(item, 0)) < count:
        return false
    inventory[item] = int(inventory[item]) - count
    return true

func spend_energy(cost: float) -> bool:
    if cost <= 0.0 or energy < cost:
        return false
    energy -= cost
    return true

func add_restoration(points: int) -> void:
    restoration = clampi(restoration + maxi(0, points), 0, 100)
