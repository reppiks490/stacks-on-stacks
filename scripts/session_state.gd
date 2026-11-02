extends RefCounted
## Single local, allowlisted game state. No remote authority or multiplayer.
signal state_changed

const SCHEMA_VERSION := 1
const MAX_FRAGMENTS := 9999
const MAX_KILLS := 9999

var fragments: int = 0
var total_kills: int = 0
var health: float = 120.0
var ember_affinity: int = 0
var hollow_affinity: int = 0
var chosen_faction: String = ""
var world_seed: int = 271828
var quest_completed: bool = false

func collect_fragment(amount: int = 1) -> void:
    fragments = clampi(fragments + maxi(amount, 0), 0, MAX_FRAGMENTS)
    _check_quest()
    state_changed.emit()

func register_enemy_defeat() -> void:
    total_kills = mini(total_kills + 1, MAX_KILLS)
    _check_quest()
    state_changed.emit()

func choose_faction(id: String) -> bool:
    if chosen_faction != "" or not id in ["FAC-01", "FAC-02"]:
        return false
    chosen_faction = id
    if id == "FAC-01":
        ember_affinity = 1
    else:
        hollow_affinity = 1
    _check_quest()
    state_changed.emit()
    return true

func _check_quest() -> void:
    if fragments >= 4 and total_kills >= 3 and chosen_faction != "":
        quest_completed = true

func objective_text() -> String:
    if quest_completed:
        return "MERIDIAN STABILIZED — the next chapter awaits"
    if fragments < 4:
        return "Find resonance fragments: %d / 4" % fragments
    if total_kills < 3:
        return "Defeat Glassbound scavengers: %d / 3" % total_kills
    return "Choose the fate of a beacon (press E nearby)"

func to_save_data() -> Dictionary:
    return {
        "version": SCHEMA_VERSION,
        "fragments": fragments,
        "total_kills": total_kills,
        "health": health,
        "ember_affinity": ember_affinity,
        "hollow_affinity": hollow_affinity,
        "chosen_faction": chosen_faction,
        "world_seed": world_seed,
        "quest_completed": quest_completed,
    }

func from_save_data(data: Dictionary) -> bool:
    if typeof(data.get("version")) != TYPE_FLOAT and typeof(data.get("version")) != TYPE_INT:
        return false
    if int(data.get("version", -1)) != SCHEMA_VERSION:
        return false
    var faction: String = str(data.get("chosen_faction", ""))
    if not faction in ["", "FAC-01", "FAC-02"]:
        return false
    for name in ["fragments", "total_kills", "ember_affinity", "hollow_affinity", "world_seed"]:
        var v: Variant = data.get(name, null)
        if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
            return false
        if float(v) < 0.0 or float(v) > 1000000000.0:
            return false
    var saved_health: Variant = data.get("health", null)
    if typeof(saved_health) != TYPE_INT and typeof(saved_health) != TYPE_FLOAT:
        return false
    if float(saved_health) < 0.0 or float(saved_health) > 120.0:
        return false
    var saved_quest: Variant = data.get("quest_completed", false)
    if typeof(saved_quest) != TYPE_BOOL:
        return false
    var parsed_fragments := int(data["fragments"])
    var parsed_kills := int(data["total_kills"])
    if parsed_fragments > MAX_FRAGMENTS or parsed_kills > MAX_KILLS:
        return false
    fragments = parsed_fragments
    total_kills = parsed_kills
    health = float(saved_health)
    ember_affinity = clampi(int(data["ember_affinity"]), 0, 1)
    hollow_affinity = clampi(int(data["hollow_affinity"]), 0, 1)
    chosen_faction = faction
    world_seed = int(data["world_seed"])
    quest_completed = false
    _check_quest()
    state_changed.emit()
    return true
