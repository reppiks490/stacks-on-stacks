extends Node
## Test-only deterministic contract for the actual Village Node3D implementation.
var year: int = 1
var season_index: int = 0
var day: int = 1
var restoration: int = 0
var inventory: Dictionary = {"wild_herb": 120, "bluebell": 12, "wood": 12, "fish": 12, "milk": 12}
var social_contacts: Dictionary = {}

func day_epoch() -> int:
    return (year - 1) * 56 + season_index * 14 + day

func advance_day() -> void:
    day += 1
    if day > 14:
        day = 1
        season_index = (season_index + 1) % 4
        if season_index == 0:
            year += 1

func consume_item(item: String, count: int) -> bool:
    if count <= 0 or int(inventory.get(item, 0)) < count:
        return false
    inventory[item] = int(inventory[item]) - count
    return true

func add_restoration(points: int) -> void:
    restoration = clampi(restoration + maxi(points, 0), 0, 100)
