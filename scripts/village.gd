extends Node3D
## EVERBLOOM original village: seasonal schedules, memory, friendship and civic work.
## The calendar belongs to game.gd. This module never advances it or writes files.
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const LIFE_PATH := "res://data/village_life.json"
const DIALOGUE_LOG_LIMIT := 12
const DIALOGUE_TEXT_LIMIT := 256
var game
var residents: Array = []
var affection: Dictionary = {}
var last_talk: Dictionary = {}
var last_gift: Dictionary = {}
var last_job: Dictionary = {}
var festival_visits: Dictionary = {}
var memories: Dictionary = {}
var life_data: Dictionary = {}
## Presentation-only locale; not a gameplay or economy save field.
var dialogue_locale: String = "en"
## Presentation adapter; authoritative social data stays in this domain.
var social_journal

func setup(host) -> void:
    game = host
    var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/villagers.json"))
    var life: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIFE_PATH))
    if payload is not Dictionary or life is not Dictionary:
        push_error("EVERBLOOM: village resident or routine catalog invalid")
        return
    life_data = life
    for original in payload.get("villagers", []):
        var resident: Dictionary = original.duplicate(true)
        var spot: Array = resident["home"]
        var container := Node3D.new()
        container.name = str(resident["name"])
        container.position = Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
        add_child(container)
        var body := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.38
        mesh.height = 1.7
        body.mesh = mesh
        body.position.y = 0.9
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.html(str(resident["palette"]))
        body.material_override = mat
        container.add_child(body)
        var label := Label3D.new()
        label.text = str(resident["name"]) + " • " + str(resident["role"])
        label.font_size = 36
        label.pixel_size = 0.006
        label.position = Vector3(0, 2.3, 0)
        container.add_child(label)
        resident["node"] = container
        resident["place"] = "home"
        residents.append(resident)
        var rid: String = str(resident["id"])
        affection[rid] = 0
        memories[rid] = _fresh_memory()
    sync_schedule(true)
    social_journal = CanvasLayer.new()
    social_journal.name = "SocialJournal"
    social_journal.set_script(load("res://scripts/village_social_journal.gd"))
    add_child(social_journal)
    social_journal.setup(self)

func _fresh_memory() -> Dictionary:
    return {"talks":0, "gifts":0, "jobs":0, "festivals":0,
            "last_gift_item":"", "last_gift_epoch":-1,
            "last_gift_favorite":false, "recalled_gift_epoch":-1,
            "gift_recollections":0, "dialogue_log":[]}

func _host_property(name: String, fallback: Variant) -> Variant:
    if game == null:
        return fallback
    for property in game.get_property_list():
        if str(property.get("name", "")) == name:
            return game.get(name)
    return fallback

func _minute() -> int:
    return clampi(int(_host_property("minute_of_day", 360.0)), 0, 1439)

func _weather() -> String:
    return str(_host_property("weather", "Clear"))

func _season() -> String:
    return SEASONS[clampi(int(game.season_index), 0, 3)]

func _festival() -> Dictionary:
    for entry in life_data.get("festivals", []):
        if int(entry.get("season", -1)) == int(game.season_index) and int(entry.get("day", -1)) == int(game.day):
            return entry
    return {}

func _active_festival() -> Dictionary:
    var event: Dictionary = _festival()
    if not event.is_empty() and _minute() >= int(event.get("start_minute", 1020)) and _minute() < int(event.get("end_minute", 1320)):
        return event
    return {}

func _profile(rid: String) -> Dictionary:
    var all_profiles: Dictionary = life_data.get("profiles", {})
    return all_profiles.get(rid, {})

func _is_rest_day(profile: Dictionary) -> bool:
    return (game.day_epoch() - 1) % 7 == int(profile.get("rest_day", -1))

func _place_for(resident: Dictionary) -> String:
    var profile: Dictionary = _profile(str(resident["id"]))
    if not _active_festival().is_empty():
        return "village_square"
    var minute: int = _minute()
    if minute < 420 or minute >= 1080:
        return "home"
    if minute < 540:
        return "village_square"
    if minute < 960 and not _is_rest_day(profile):
        if minute >= 720 and minute < 780:
            return "covered_market" if _weather() == "Rain" else "village_square"
        return str(profile.get("workplace", "home"))
    if _weather() == "Rain":
        return str(profile.get("rain_shelter", "home"))
    return str(profile.get("leisure", "village_square"))

func _place_position(resident: Dictionary, place: String) -> Vector3:
    if place == "home":
        var home: Array = resident["home"]
        return Vector3(float(home[0]), float(home[1]), float(home[2]))
    var places: Dictionary = life_data.get("places", {})
    if not places.has(place):
        return _place_position(resident, "home")
    var spot: Array = places[place]
    return Vector3(float(spot[0]), float(spot[1]), float(spot[2]))

func sync_schedule(snap: bool = false, delta: float = 0.0) -> void:
    if game == null:
        return
    for resident in residents:
        var place: String = _place_for(resident)
        var target: Vector3 = _place_position(resident, place)
        var actor: Node3D = resident["node"]
        if snap:
            actor.position = target
        elif delta > 0.0:
            actor.position = actor.position.move_toward(target, 2.4 * delta)
        resident["place"] = place

func _process(delta: float) -> void:
    if game != null and not residents.is_empty():
        sync_schedule(false, delta)

func _friendship_tier(points: int) -> String:
    var tier: String = "acquaintance"
    for row in life_data.get("friendship_tiers", []):
        if points >= int(row.get("at", 0)):
            tier = str(row.get("name", tier))
    return tier

## Recollection is a one-time dialogue response, not a second friendship reward.
## A gift given today can only be reflected on a later monotonic calendar day.
func _gift_memory_dialogue(profile: Dictionary, rid: String, epoch: int) -> String:
    var record: Dictionary = memories.get(rid, _fresh_memory())
    var gifted_epoch: int = int(record.get("last_gift_epoch", -1))
    if gifted_epoch < 0 or gifted_epoch >= epoch:
        return ""
    if int(record.get("recalled_gift_epoch", -1)) >= gifted_epoch:
        return ""
    var item: String = str(record.get("last_gift_item", ""))
    if item.is_empty():
        return ""
    var line_key: String = "gift_memory_favorite" if bool(record.get("last_gift_favorite", false)) else "gift_memory_preferred"
    var line: String = str(profile.get(line_key, ""))
    if line.is_empty():
        return ""
    record["recalled_gift_epoch"] = gifted_epoch
    record["gift_recollections"] = mini(1000000, maxi(0, int(record.get("gift_recollections", 0))) + 1)
    memories[rid] = record
    return line % item

func _dialogue(resident: Dictionary, rid: String, epoch: int) -> String:
    var profile: Dictionary = _profile(rid)
    if not _active_festival().is_empty():
        return str(profile.get("festival_line", "The whole valley is here tonight."))
    if _weather() == "Rain":
        return str(profile.get("rain_line", "The rain sounds lovely on the rooftops."))
    var recollection: String = _gift_memory_dialogue(profile, rid, epoch)
    if not recollection.is_empty():
        return recollection
    var contextual: String = _conditional_dialogue(resident, profile, rid)
    if not contextual.is_empty():
        return contextual
    if int(affection.get(rid, 0)) >= 220:
        return str(profile.get("bond_line", "I'm glad you came by."))
    if str(resident.get("place", "")) == str(profile.get("workplace", "")):
        return str(profile.get("work_line", "There is always something worth tending."))
    var seasonal: Dictionary = profile.get("seasonal_lines", {})
    if seasonal.has(_season()):
        return str(seasonal[_season()])
    var lines: Array = resident.get("dialogue", ["It's good to see you."])
    return str(lines[epoch % maxi(1, lines.size())])

## V05: authored predicate branches, ordered most specific first.
## Reads existing persisted memory/affection; never mutates rewards or save shape.
func set_dialogue_locale(code: String) -> void:
    dialogue_locale = code if code in ["en", "es"] else "en"

func _conditional_dialogue(resident: Dictionary, profile: Dictionary, rid: String) -> String:
    var catalog: Dictionary = life_data.get("dialogue_branches", {})
    var branches: Array = catalog.get(rid, [])
    var memory: Dictionary = memories.get(rid, _fresh_memory())
    for branch in branches:
        if not (branch is Dictionary):
            continue
        var predicate: Dictionary = branch.get("when", {})
        if int(memory.get("jobs", 0)) < int(predicate.get("min_jobs", 0)):
            continue
        if int(affection.get(rid, 0)) < int(predicate.get("min_affection", 0)):
            continue
        if bool(predicate.get("at_work", false)) and str(resident.get("place", "")) != str(profile.get("workplace", "")):
            continue
        var lines: Dictionary = branch.get("text", {})
        var result: String = str(lines.get(dialogue_locale, lines.get("en", "")))
        if not result.is_empty():
            return result
    return ""

## Store only actual spoken lines, one per resident per monotonic day.
## The capped log is a memory artifact, not a reward or second talk action.
func _record_dialogue(rid: String, epoch: int, line: String) -> void:
    if line.is_empty():
        return
    var record: Dictionary = memories.get(rid, _fresh_memory())
    var history: Array = record.get("dialogue_log", []).duplicate(true)
    for entry in history:
        if entry is Dictionary and int(entry.get("epoch", -1)) == epoch:
            return
    history.append({"epoch":epoch, "locale":dialogue_locale,
                    "text":line.substr(0, DIALOGUE_TEXT_LIMIT)})
    while history.size() > DIALOGUE_LOG_LIMIT:
        history.pop_front()
    record["dialogue_log"] = history
    memories[rid] = record

func _record_memory(rid: String, field: String) -> void:
    var record: Dictionary = memories.get(rid, _fresh_memory())
    record[field] = maxi(0, int(record.get(field, 0))) + 1
    memories[rid] = record

func _gift(resident: Dictionary, rid: String, epoch: int) -> String:
    if int(last_gift.get(rid, -1)) == epoch:
        return "%s smiles. One gift each day is enough." % resident["name"]
    var found: String = ""
    for gift in resident["preferences"]:
        if int(game.inventory.get(gift, 0)) > 0:
            found = str(gift)
            break
    if found == "":
        return "Bring %s a thoughtful local gift." % resident["name"]
    if not game.consume_item(found, 1):
        return "No suitable gift in your pouch."
    last_gift[rid] = epoch
    var favorite: bool = found == str(resident.get("gift", ""))
    var gain: int = 18 if favorite else 12
    affection[rid] = clampi(int(affection.get(rid, 0)) + gain, 0, 1000)
    var memory: Dictionary = memories.get(rid, _fresh_memory())
    memory["last_gift_item"] = found
    memory["last_gift_epoch"] = epoch
    memory["last_gift_favorite"] = favorite
    memories[rid] = memory
    _record_memory(rid, "gifts")
    game.add_restoration(2)
    return "%s loved your gift of %s. %s Friendship blossoms." % [
        resident["name"], found, "A treasured favorite!" if favorite else "A thoughtful choice."]

func _job(resident: Dictionary, rid: String, epoch: int) -> String:
    var profile: Dictionary = _profile(rid)
    var rules: Dictionary = life_data.get("jobs", {})
    if int(last_job.get(rid, -1)) == epoch:
        return "%s thanks you. You already helped here today." % resident["name"]
    var minute: int = _minute()
    var on_shift: bool = minute >= int(rules.get("start_minute", 540)) and minute < int(rules.get("end_minute", 960))
    var at_break: bool = minute >= int(rules.get("break_start", 720)) and minute < int(rules.get("break_end", 780))
    if not on_shift or at_break or _is_rest_day(profile) or not _active_festival().is_empty():
        return "%s has no work shift available right now." % resident["name"]
    if str(resident.get("place", "")) != str(profile.get("workplace", "")):
        return "Find %s at their workplace to lend a hand." % resident["name"]
    var cost: float = float(rules.get("energy_cost", 12))
    if not game.has_method("spend_energy") or not game.spend_energy(cost):
        return "You need more energy before taking on village work."
    var pay: int = maxi(0, int(rules.get("reward_petals", 24)))
    game.gold += pay
    game.add_restoration(int(rules.get("restoration", 1)))
    last_job[rid] = epoch
    _record_memory(rid, "jobs")
    return "Helped %s with %s. Earned %d petals." % [
        resident["name"], str(profile.get("job_task", "community repairs")), pay]

func act(action: String, position: Vector3) -> String:
    var selected: Dictionary = {}
    var best_distance: float = 4.2
    for resident in residents:
        var distance: float = resident["node"].global_position.distance_to(position)
        if distance < best_distance:
            best_distance = distance
            selected = resident
    if selected.is_empty():
        return "Visit a resident of Larkspur Village."
    var rid: String = str(selected["id"])
    var epoch: int = game.day_epoch()
    if action == "gift":
        return _gift(selected, rid, epoch)
    if action == "job":
        return _job(selected, rid, epoch)
    if action != "talk":
        return "Spend time talking, gifting, or helping your neighbors."
    if int(last_talk.get(rid, -1)) != epoch:
        last_talk[rid] = epoch
        affection[rid] = clampi(int(affection.get(rid, 0)) + 4, 0, 1000)
        game.social_contacts[rid] = true
        game.add_restoration(1)
        _record_memory(rid, "talks")
    var festival: Dictionary = _active_festival()
    var celebration: String = ""
    if not festival.is_empty():
        var event_key: String = "%d:%s" % [int(game.year), str(festival["id"])]
        if not festival_visits.has(event_key):
            festival_visits[event_key] = true
            affection[rid] = clampi(int(affection.get(rid, 0)) + 8, 0, 1000)
            game.add_restoration(3)
            _record_memory(rid, "festivals")
            celebration = " You joined %s. %s" % [
                str(festival["name"]), str(festival["narration"])]
    var points: int = int(affection.get(rid, 0))
    var spoken: String = _dialogue(selected, rid, epoch)
    _record_dialogue(rid, epoch, spoken)
    return "%s: “%s” (friendship %d — %s)%s" % [
        selected["name"], spoken, points,
        _friendship_tier(points), celebration]

func next_day() -> void:
    sync_schedule(true)

## V19: deterministic, read-only recap. No transcript is fabricated or stored.
## Save/load already preserves every underlying count and gift memory.
func social_recap() -> Array:
    var result: Array = []
    for resident in residents:
        var rid: String = str(resident["id"])
        var record: Dictionary = memories.get(rid, _fresh_memory())
        var points: int = int(affection.get(rid, 0))
        result.append({
            "id":rid, "name":str(resident["name"]), "role":str(resident["role"]),
            "friendship":points, "tier":_friendship_tier(points),
            "talks":int(record.get("talks", 0)),
            "gifts":int(record.get("gifts", 0)),
            "jobs":int(record.get("jobs", 0)),
            "festivals":int(record.get("festivals", 0)),
            "last_gift_item":str(record.get("last_gift_item", "")),
            "gift_recollections":int(record.get("gift_recollections", 0)),
            "dialogue_log":record.get("dialogue_log", []).duplicate(true)
        })
    return result

func save_state() -> Dictionary:
    return {"affection":affection.duplicate(true), "talked":last_talk.duplicate(true),
            "gifted":last_gift.duplicate(true), "worked":last_job.duplicate(true),
            "festivals":festival_visits.duplicate(true), "memories":memories.duplicate(true)}

func load_state(state: Dictionary) -> void:
    var loaded: Variant = state.get("affection", {})
    var talk: Variant = state.get("talked", {})
    var gifts: Variant = state.get("gifted", {})
    var worked: Variant = state.get("worked", {})
    var saved_memories: Variant = state.get("memories", {})
    if loaded is Dictionary:
        for rid in affection:
            if loaded.has(rid):
                affection[rid] = clampi(int(loaded[rid]), 0, 1000)
    last_talk.clear()
    last_gift.clear()
    last_job.clear()
    for rid in affection:
        if talk is Dictionary and talk.has(rid):
            last_talk[rid] = clampi(int(talk[rid]), -1, game.day_epoch())
        if gifts is Dictionary and gifts.has(rid):
            last_gift[rid] = clampi(int(gifts[rid]), -1, game.day_epoch())
        if worked is Dictionary and worked.has(rid):
            last_job[rid] = clampi(int(worked[rid]), -1, game.day_epoch())
        var record: Dictionary = _fresh_memory()
        if saved_memories is Dictionary and saved_memories.get(rid, null) is Dictionary:
            var incoming: Dictionary = saved_memories[rid]
            for field in ["talks", "gifts", "jobs", "festivals"]:
                record[field] = clampi(int(incoming.get(field, 0)), 0, 1000000)
            record["last_gift_item"] = str(incoming.get("last_gift_item", ""))
            record["last_gift_epoch"] = clampi(int(incoming.get("last_gift_epoch", -1)), -1, game.day_epoch())
            # Old schema-1 saves have no favorite flag: infer it from the
            # original resident catalog instead of changing their gift history.
            var favorite_item: String = ""
            for resident in residents:
                if str(resident["id"]) == str(rid):
                    favorite_item = str(resident.get("gift", ""))
                    break
            var inferred_favorite: bool = not favorite_item.is_empty() and record["last_gift_item"] == favorite_item
            var saved_favorite: Variant = incoming.get("last_gift_favorite", inferred_favorite)
            record["last_gift_favorite"] = saved_favorite if typeof(saved_favorite) == TYPE_BOOL else inferred_favorite
            record["recalled_gift_epoch"] = clampi(int(incoming.get("recalled_gift_epoch", -1)), -1, int(record["last_gift_epoch"]))
            record["gift_recollections"] = clampi(int(incoming.get("gift_recollections", 0)), 0, 1000000)
            # Optional historical dialogue log. Reject malformed or future-dated
            # entries rather than inventing conversation history on old saves.
            var raw_history: Variant = incoming.get("dialogue_log", [])
            if raw_history is Array:
                var clean_history: Array = []
                var previous_epoch: int = 0
                for raw in raw_history.slice(maxi(0, raw_history.size() - DIALOGUE_LOG_LIMIT)):
                    if not (raw is Dictionary):
                        continue
                    var day: int = int(raw.get("epoch", -1))
                    var line: String = str(raw.get("text", ""))
                    var locale: String = str(raw.get("locale", ""))
                    if day <= previous_epoch or day > game.day_epoch() or line.is_empty() or line.length() > DIALOGUE_TEXT_LIMIT or not locale in ["en", "es"]:
                        continue
                    clean_history.append({"epoch":day, "locale":locale, "text":line})
                    previous_epoch = day
                record["dialogue_log"] = clean_history
        memories[rid] = record
    festival_visits.clear()
    var visits: Variant = state.get("festivals", {})
    if visits is Dictionary:
        for key in visits:
            if visits[key] == true and str(key).length() <= 80:
                festival_visits[str(key)] = true
    sync_schedule(true)
