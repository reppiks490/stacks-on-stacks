extends Node
## Test-only deterministic game facade for native Godot farming acceptance.
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
var day: int = 1
var year: int = 1
var season_index: int = 0
var gold: int = 400
var energy: float = 100.0
var restoration: int = 0
var care_actions: int = 0
var crops_harvested: int = 0
var selected_seed: int = 0
var seed_order: Array[String] = ["turnip", "carrot", "strawberry", "tomato", "melon", "pumpkin", "winterroot", "bluebell"]
var crop_definitions: Dictionary = {}
var inventory: Dictionary = {
    "turnip_seed":4, "carrot_seed":4, "strawberry_seed":4,
    "tomato_seed":0, "melon_seed":0, "pumpkin_seed":0,
    "winterroot_seed":0, "bluebell_seed":0, "fodder":20,
    "wild_herb":8
}

func configure() -> void:
    var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/crops.json"))
    for crop in payload.get("crops", []):
        crop_definitions[str(crop["id"])] = crop

func current_seed() -> String:
    return seed_order[selected_seed]

func season() -> String:
    return SEASONS[season_index]

func day_epoch() -> int:
    return (year - 1) * 56 + season_index * 14 + day

func advance_day() -> void:
    day += 1
    if day > 14:
        day = 1
        season_index = (season_index + 1) % 4
        if season_index == 0:
            year += 1
    energy = 100.0

func spend_energy(cost: float) -> bool:
    if cost < 0.0 or energy < cost:
        return false
    energy -= cost
    return true

func grant_item(item: String, quantity: int) -> void:
    if quantity > 0:
        inventory[item] = int(inventory.get(item, 0)) + quantity

func consume_item(item: String, quantity: int) -> bool:
    if quantity <= 0 or int(inventory.get(item, 0)) < quantity:
        return false
    inventory[item] = int(inventory[item]) - quantity
    return true

func add_restoration(amount: int) -> void:
    restoration = clampi(restoration + maxi(0, amount), 0, 100)
