extends RefCounted
## F14 original isolated pollinator ecology; no authoritative inventory, harvest, or save writes.
## Six habitat nodes influence the existing 6x5 = 30 bed indices.
const BED_COUNT := 30
const SITE_COUNT := 6
const BUDGET := 60
const FOUNDERS := 72
const SITE_X := [0, 2, 5, 0, 3, 5]
const SITE_Y := [0, 0, 0, 4, 4, 4]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const WEATHER := ["Clear", "Rain", "Storm", "Drought"]
const ACTION_COST := {"flower_patch":2, "nesting":3, "corridor":4}
var state: Dictionary = {}

func _init() -> void:
    reset()

func reset() -> void:
    var sites: Array = []
    var bloom: Array = []
    for i in range(BED_COUNT):
        bloom.append(2)
    for i in range(SITE_COUNT):
        sites.append({"flowers":1, "shelter":0, "corridor":false,
            "colony":12, "nectar":18, "last_action_epoch":-1})
    state = {"version":1, "epoch":1, "season":"Spring", "weather":"Clear",
        "bloom":bloom, "sites":sites,
        "ledger":{"budget":BUDGET, "spent":0, "remaining":BUDGET,
            "founders":FOUNDERS, "births":0, "deaths":0, "migrations":0}}

func save_state() -> Dictionary:
    return state.duplicate(true)

func _result(ok: bool, message: String) -> Dictionary:
    return {"ok":ok, "message":message}

func describe_site(index: int) -> String:
    if index < 0 or index >= SITE_COUNT:
        return "Unknown pollinator habitat."
    var site: Dictionary = state["sites"][index]
    return "Habitat %d: %d flower patches, %d nesting shelters, %d pollinators; %d care credits remain." % [
        index + 1, int(site["flowers"]), int(site["shelter"]),
        int(site["colony"]), int(state["ledger"]["remaining"])]

func act(index: int, action: String, epoch: int) -> Dictionary:
    if epoch != int(state["epoch"]) or index < 0 or index >= SITE_COUNT:
        return _result(false, "Habitat action denied: stale day or invalid location.")
    if not ACTION_COST.has(action):
        return _result(false, "Habitat action denied: unknown care action.")
    var site: Dictionary = state["sites"][index]
    if int(site["last_action_epoch"]) == epoch:
        return _result(false, "Habitat already tended today.")
    var cost: int = int(ACTION_COST[action])
    if int(state["ledger"]["remaining"]) < cost:
        return _result(false, "Not enough model care credits; no item was consumed.")
    if action == "flower_patch" and int(site["flowers"]) >= 5:
        return _result(false, "Flower habitat is already fully established.")
    if action == "nesting" and int(site["shelter"]) >= 3:
        return _result(false, "Nesting shelter is already at capacity.")
    if action == "corridor" and bool(site["corridor"]):
        return _result(false, "This habitat corridor already exists.")
    if action == "flower_patch":
        site["flowers"] = int(site["flowers"]) + 1
    elif action == "nesting":
        site["shelter"] = int(site["shelter"]) + 1
    else:
        site["corridor"] = true
    site["last_action_epoch"] = epoch
    state["ledger"]["remaining"] = int(state["ledger"]["remaining"]) - cost
    state["ledger"]["spent"] = int(state["ledger"]["spent"]) + cost
    return _result(true, "Habitat %d: %s completed for %d model care credits." % [
        index + 1, action.replace("_", " "), cost])

func pollination_score(bed_index: int) -> int:
    if bed_index < 0 or bed_index >= BED_COUNT:
        return -1
    if int(state["bloom"][bed_index]) == 0 or state["season"] == "Winter":
        return 0
    if state["weather"] == "Storm":
        return 0
    var x: int = bed_index % 6
    var y: int = int(bed_index / 6)
    var score: int = 0
    for i in range(SITE_COUNT):
        var site: Dictionary = state["sites"][i]
        var radius: int = 2 + (1 if bool(site["corridor"]) else 0)
        var distance: int = absi(x - SITE_X[i]) + absi(y - SITE_Y[i])
        if distance <= radius:
            score += int(int(site["colony"]) * int(site["flowers"]) *
                (radius + 1 - distance) / 8)
    score = mini(100, score * int(state["bloom"][bed_index]) / 2)
    if state["weather"] == "Rain":
        score = int(score / 2)
    if state["weather"] == "Drought":
        score = int(score * 3 / 4)
    return clampi(score, 0, 100)

func preview_yield(bed_index: int, base_yield: int) -> Dictionary:
    var score: int = pollination_score(bed_index)
    if score < 0 or base_yield < 0 or base_yield > 10000:
        return {"ok":false, "message":"Invalid bed or yield; no harvest proposed."}
    var bonus: int = int(base_yield * score / 200)
    return {"ok":true, "base":base_yield, "bonus":bonus,
        "total":base_yield + bonus, "score":score,
        "message":"Projected %d crops (+%d from pollinators); not granted." % [
            base_yield + bonus, bonus]}

func _valid_bloom(raw: Variant) -> bool:
    if not (raw is Array) or raw.size() != BED_COUNT:
        return false
    for level in raw:
        if not _integer(level, 0, 4):
            return false
    return true

func advance_day(epoch: int, weather: String, season: String, bloom: Array) -> Dictionary:
    if epoch != int(state["epoch"]) + 1 or not WEATHER.has(weather) or (
            not SEASONS.has(season)) or not _valid_bloom(bloom):
        return _result(false, "Pollinator day denied: non-monotonic epoch or invalid ecology.")
    var ledger: Dictionary = state["ledger"]
    var sites: Array = state["sites"]
    for site in sites:
        var flowers: int = int(site["flowers"])
        var colony: int = int(site["colony"])
        var nectar: int = int(site["nectar"])
        if season == "Spring" and epoch % 14 == 1 and flowers < 5:
            flowers += 1
        if weather == "Drought" and epoch % 7 == 0 and flowers > 0:
            flowers -= 1
        nectar = clampi(nectar + flowers * 2 + (2 if weather == "Rain" else 0)
            - int(colony / 12) - (6 if weather == "Storm" else 0)
            - (3 if season == "Winter" else 0), 0, 100)
        var birth: int = 1 if flowers >= 2 and nectar >= 15 and (
            season != "Winter" and weather != "Storm" and colony < 100) else 0
        var death: int = 1 if colony > 0 and (
            (weather == "Storm" and int(site["shelter"]) == 0)
            or (season == "Winter" and nectar < 8)
            or (weather == "Drought" and nectar < 5)) else 0
        site["flowers"] = flowers
        site["nectar"] = nectar
        site["colony"] = colony + birth - death
        ledger["births"] = int(ledger["births"]) + birth
        ledger["deaths"] = int(ledger["deaths"]) + death
    if epoch % 14 == 0 and (season == "Spring" or season == "Autumn"):
        for i in range(SITE_COUNT - 1):
            var origin: Dictionary = sites[i]
            var destination: Dictionary = sites[i + 1]
            if bool(origin["corridor"]) and bool(destination["corridor"]) and (
                    int(origin["colony"]) > 4 and int(destination["colony"]) < 100):
                origin["colony"] = int(origin["colony"]) - 1
                destination["colony"] = int(destination["colony"]) + 1
                ledger["migrations"] = int(ledger["migrations"]) + 1
    state["epoch"] = epoch
    state["season"] = season
    state["weather"] = weather
    state["bloom"] = bloom.duplicate(true)
    return _result(true, "Pollinators advanced one 56-day-calendar day.")

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and floor(number) == number and number >= minimum and number <= maximum

func _decode(raw: Variant) -> Dictionary:
    if not (raw is Dictionary) or raw.size() != 7:
        return {}
    for key in ["version", "epoch", "season", "weather", "bloom", "sites", "ledger"]:
        if not raw.has(key):
            return {}
    if not _integer(raw["version"], 1, 1) or not _integer(raw["epoch"], 1, 100000):
        return {}
    var epoch: int = int(raw["epoch"])
    if not (raw["season"] is String) or not SEASONS.has(raw["season"]) or (
            not (raw["weather"] is String)) or not WEATHER.has(raw["weather"]):
        return {}
    if not _valid_bloom(raw["bloom"]) or not (raw["sites"] is Array) or (
            raw["sites"].size() != SITE_COUNT):
        return {}
    var bloom: Array = []
    for level in raw["bloom"]:
        bloom.append(int(level))
    var sites: Array = []
    var total_colony: int = 0
    for site in raw["sites"]:
        if not (site is Dictionary) or site.size() != 6:
            return {}
        for key in ["flowers", "shelter", "corridor", "colony", "nectar", "last_action_epoch"]:
            if not site.has(key):
                return {}
        if not _integer(site["flowers"], 0, 5) or (
                not _integer(site["shelter"], 0, 3)) or (
                typeof(site["corridor"]) != TYPE_BOOL) or (
                not _integer(site["colony"], 0, 100)) or (
                not _integer(site["nectar"], 0, 100)) or (
                not _integer(site["last_action_epoch"], -1, epoch)):
            return {}
        var normalized: Dictionary = {"flowers":int(site["flowers"]),
            "shelter":int(site["shelter"]), "corridor":bool(site["corridor"]),
            "colony":int(site["colony"]), "nectar":int(site["nectar"]),
            "last_action_epoch":int(site["last_action_epoch"])}
        sites.append(normalized)
        total_colony += int(site["colony"])
    if not (raw["ledger"] is Dictionary) or raw["ledger"].size() != 7:
        return {}
    var ledger: Dictionary = {}
    for key in ["budget", "spent", "remaining", "founders", "births", "deaths", "migrations"]:
        if not raw["ledger"].has(key) or not _integer(raw["ledger"][key], 0, 1000000):
            return {}
        ledger[key] = int(raw["ledger"][key])
    if int(ledger["budget"]) != BUDGET or int(ledger["founders"]) != FOUNDERS or (
            int(ledger["spent"]) + int(ledger["remaining"]) != BUDGET) or (
            FOUNDERS + int(ledger["births"]) - int(ledger["deaths"]) != total_colony):
        return {}
    return {"version":1, "epoch":epoch, "season":str(raw["season"]),
        "weather":str(raw["weather"]), "bloom":bloom, "sites":sites, "ledger":ledger}

func load_state(raw: Variant) -> bool:
    var candidate: Dictionary = _decode(raw)
    if candidate.is_empty():
        return false
    state = candidate
    return true

func load_json(payload: String) -> bool:
    var parser := JSON.new()
    if parser.parse(payload) != OK:
        return false
    return load_state(parser.data)
