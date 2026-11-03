extends Node3D
const SculptedHumanoid = preload("res://scripts/sculpted_humanoid.gd")
## EVERBLOOM original village: seasonal schedules, memory, friendship and civic work.
## The calendar belongs to game.gd. This module never advances it or writes files.
## Dialogue history is an optional bounded nested memory; Principal owns strict save admission.
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
## V07: first-party work interaction adapter; Village remains authoritative.
var job_panel
## V05: original optional player-selected conversation topics, presentation only.
var topic_panel
## V06: optional gift-selection UI; item authority remains in _gift().
var gift_panel

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
        var resident_seed: int=absi(str(resident["id"]).hash())
        var render:=Node3D.new()
        render.name="OriginalMeshResident"
        render.set_script(SculptedHumanoid)
        container.add_child(render)
        var resident_tone: Color=Color("#c18d70") if resident_seed%3==0 else (Color("#e5bc9d") if resident_seed%3==1 else Color("#986950"))
        render.configure({
            "skin_tint":resident_tone,
            "coat_tint":Color.html(str(resident["palette"])),
            "trousers_tint":Color("#58645d").lightened(float(resident_seed%4)*0.05),
            "hair_tint":Color("#4c3c36") if resident_seed%2==0 else Color("#926d4f"),
            "iris_tint":Color("#5f806a") if resident_seed%2==0 else Color("#6b83a3"),
            "build":resident_seed%5,
            "height":resident_seed%9,
            "face":resident_seed%6,
            "jaw":resident_seed%9,
            "brow":resident_seed%10,
            "nose":(resident_seed/3)%10,
            "mouth":(resident_seed/7)%10,
            "eye_size":resident_seed%9,
            "hair":resident_seed%12,
            "hair_length":resident_seed%10,
            "outfit":resident_seed%12,
            "footwear":resident_seed%10,
            "headwear":1 if str(resident["role"]).contains("Farm") else 0,
            "accessory":3 if resident_seed%4==0 else 0
        })
        var citizen_body:=AnimatableBody3D.new()
        citizen_body.name="VillageResidentCollision"
        citizen_body.collision_layer=1
        citizen_body.collision_mask=1
        container.add_child(citizen_body)
        var citizen_shape:=CollisionShape3D.new()
        var presence:=CapsuleShape3D.new()
        presence.radius=0.32
        presence.height=1.8
        citizen_shape.shape=presence
        citizen_shape.position.y=0.93
        citizen_body.add_child(citizen_shape)
        var label := Label3D.new()
        label.text = str(resident["name"]) + " • " + str(resident["role"])
        label.font_size = 36
        label.pixel_size = 0.006
        label.position = Vector3(0, 2.88, 0)
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
    # Input-only adapter; paid shifts, calendar gates and resources stay in act("job").
    job_panel = CanvasLayer.new()
    job_panel.name = "VillageJobPanel"
    job_panel.set_script(load("res://scripts/village_job_panel.gd"))
    add_child(job_panel)
    job_panel.setup(self)
    topic_panel = CanvasLayer.new()
    topic_panel.name = "VillageTopicPanel"
    topic_panel.set_script(load("res://scripts/village_topic_panel.gd"))
    add_child(topic_panel)
    topic_panel.setup(self)
    gift_panel = CanvasLayer.new()
    gift_panel.name = "VillageGiftPanel"
    gift_panel.set_script(load("res://scripts/village_gift_panel.gd"))
    add_child(gift_panel)
    gift_panel.setup(self)

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
    # Record the day the resident actually spoke the recollection, not the gift day.
    # Principal save admission requires this chronology to survive JSON reload.
    record["recalled_gift_epoch"] = epoch
    record["gift_recollections"] = mini(1000000, maxi(0, int(record.get("gift_recollections", 0))) + 1)
    memories[rid] = record
    return line % item

func _dialogue(resident: Dictionary, rid: String, epoch: int, topic: String = "") -> String:
    var profile: Dictionary = _profile(rid)
    if not _active_festival().is_empty():
        return str(profile.get("festival_line", "The whole valley is here tonight."))
    if _weather() == "Rain":
        return str(profile.get("rain_line", "The rain sounds lovely on the rooftops."))
    var recollection: String = _gift_memory_dialogue(profile, rid, epoch)
    if not recollection.is_empty():
        return recollection
    # Player-selected topics follow festival, rain and outstanding gift memories.
    # Locked or invalid topic IDs fall through without revealing private chapters.
    if not topic.is_empty():
        var topic_catalog: Dictionary = life_data.get("conversation_topics", {})
        var options: Dictionary = topic_catalog.get(rid, {})
        if options.has(topic):
            var topic_data: Dictionary = options[topic]
            if not _topic_unlocked(rid, topic_data):
                return _dialogue_fallback(resident, rid, profile, epoch)
            var replies: Dictionary = topic_data.get("reply", {})
            var chosen: String = str(replies.get(dialogue_locale, replies.get("en", "")))
            if not chosen.is_empty():
                return chosen
    return _dialogue_fallback(resident, rid, profile, epoch)

func _dialogue_fallback(resident: Dictionary, rid: String, profile: Dictionary, epoch: int) -> String:
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

## V06: explicit choice and legacy automatic gifts share one authoritative
## monotonic-day gate, inventory debit, reward and persisted memory path.
func _gift(resident: Dictionary, rid: String, epoch: int, requested_item: String = "") -> String:
    if int(last_gift.get(rid, -1)) == epoch:
        return "%s smiles. One gift each day is enough." % resident["name"]
    var found: String = ""
    if not requested_item.is_empty():
        # Explicit player choice must be a resident-approved item. Do not
        # silently substitute another gift or debit inventory on rejection.
        if not resident["preferences"].has(requested_item):
            return "%s does not accept that gift." % resident["name"]
        if int(game.inventory.get(requested_item, 0)) <= 0:
            return "You do not have %s to give." % requested_item
        found = requested_item
    else:
        # Preserve the historical G-key automatic gift route unchanged.
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
    # A new gift is pending even when it follows an earlier recollection today.
    # Preserve the lifetime count, but clear the latest-gift recollection marker.
    memory["recalled_gift_epoch"] = -1
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
    # V02/V07: the schedule label is the *destination*, not proof of arrival.
    # Never pay a shift while the resident is still walking from home or lunch.
    # This admission guard does not replace pathfinding or movement ownership.
    # Compare in world space so translated Village scene roots remain correct.
    var worksite: Vector3 = to_global(_place_position(resident, str(profile.get("workplace", "home"))))
    var worker: Node3D = resident["node"]
    if worker.global_position.distance_to(worksite) > 1.0:
        return "%s is still on their way to work. Meet them at the workplace." % resident["name"]
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

## Read-only, deterministic topic menu. No new save keys or side effects.
func _topic_unlocked(rid: String, entry: Dictionary) -> bool:
    var requirements: Dictionary = entry.get("requires", {})
    if int(memories.get(rid, _fresh_memory()).get("jobs", 0)) < int(requirements.get("min_jobs", 0)):
        return false
    if int(affection.get(rid, 0)) < int(requirements.get("min_affection", 0)):
        return false
    return true

## Stable base topics first, earned chapters second. No new save fields.
func available_topics(rid: String) -> Array:
    var catalog: Dictionary = life_data.get("conversation_topics", {})
    var options: Dictionary = catalog.get(rid, {})
    var keys: Array = options.keys()
    keys.sort()
    var result: Array = []
    for phase in range(2):
        for key in keys:
            var entry: Dictionary = options[key]
            var gated: bool = entry.has("requires")
            if gated != (phase == 1) or not _topic_unlocked(rid, entry):
                continue
            var labels: Dictionary = entry.get("label", {})
            var label: String = str(labels.get(dialogue_locale, labels.get("en", "")))
            if not label.is_empty():
                result.append({"id":str(key), "label":label})
    return result

## V05/V19: read-only, data-driven progress toward existing earned chapters.
## Never expose a locked reply or mutate relationship/economy/save state.
## Recomputed from the same persisted job and friendship prerequisites as
## _topic_unlocked(), so save/load and 56-day year rollover need no new keys.
func chapter_progress(rid: String) -> Array:
    var catalog: Dictionary = life_data.get("conversation_topics", {})
    var options: Dictionary = catalog.get(rid, {})
    var keys: Array = options.keys()
    keys.sort()
    var result: Array = []
    var memory: Dictionary = memories.get(rid, _fresh_memory())
    for key in keys:
        var entry: Dictionary = options[key]
        if not entry.has("requires"):
            continue
        var requirements: Dictionary = entry.get("requires", {})
        var jobs_remaining: int = maxi(0, int(requirements.get("min_jobs", 0)) - int(memory.get("jobs", 0)))
        var friendship_remaining: int = maxi(0, int(requirements.get("min_affection", 0)) - int(affection.get(rid, 0)))
        result.append({"id":str(key), "unlocked":_topic_unlocked(rid, entry),
            "jobs_remaining":jobs_remaining, "friendship_remaining":friendship_remaining})
    return result

func act(action: String, position: Vector3, topic: String = "") -> String:
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
        return _gift(selected, rid, epoch, topic)
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
    var spoken: String = _dialogue(selected, rid, epoch, topic)
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
            # Recollection can occur days or years AFTER the gift. Never clamp
            # its actual conversation epoch to the earlier gift epoch.
            record["recalled_gift_epoch"] = clampi(int(incoming.get("recalled_gift_epoch", -1)), -1, game.day_epoch())
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
