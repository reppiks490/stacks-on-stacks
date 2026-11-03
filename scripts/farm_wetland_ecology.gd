extends RefCounted
## F15 isolated finite wetland ecology. This model never grants live fish, gold or energy.
## Three habitats are proposals; live valley fishing remains the sole inventory source.
const SITE_COUNT := 3
const FOUNDERS := 72
const BUDGET := 90
const CAPACITY := 50
const SITE_NAMES := ["Glimmer Lake", "Willow Stream", "Reedfen Marsh"]
const SPECIES := ["silverfin", "brookling", "reedperch"]
const MIN_ROD := [1, 1, 2]
const TEMP_MIN := [4, 6, 10]
const TEMP_MAX := [28, 25, 30]
const TEMP_OFFSET := [-1, -3, 2]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const WEATHER := ["Clear", "Rain", "Mist", "Storm", "Drought"]
var state: Dictionary = {}

func _init() -> void:
    reset()

func _temperature(index: int, season: String, weather: String) -> int:
    var baseline: int = [15, 25, 14, 5][SEASONS.find(season)]
    var weather_offset: int = {"Clear":0, "Rain":-2, "Mist":-1,
        "Storm":-3, "Drought":3}[weather]
    return baseline + int(TEMP_OFFSET[index]) + weather_offset

func _season(epoch: int) -> String:
    return SEASONS[int((epoch - 1) / 14) % 4]

func reset() -> void:
    var sites: Array = []
    for i in range(SITE_COUNT):
        sites.append({"population":24, "habitat":60,
            "temperature":_temperature(i, "Spring", "Clear"),
            "last_cast_epoch":-1, "last_steward_epoch":-1})
    state = {"version":1, "epoch":1, "season":"Spring", "weather":"Clear",
        "sites":sites, "ledger":{"founders":FOUNDERS, "births":0, "deaths":0,
        "caught":0, "budget":BUDGET, "spent":0, "remaining":BUDGET}}

func save_state() -> Dictionary:
    return state.duplicate(true)

func _result(ok: bool, message: String) -> Dictionary:
    return {"ok":ok, "message":message}

func describe_site(index: int) -> String:
    if index < 0 or index >= SITE_COUNT:
        return "Unknown wetland fishing site."
    var site: Dictionary = state["sites"][index]
    return "%s: %d %s remain, %d C water, habitat %d/95. Stewardship credits: %d." % [
        SITE_NAMES[index], int(site["population"]), SPECIES[index],
        int(site["temperature"]), int(site["habitat"]),
        int(state["ledger"]["remaining"])]

func forecast(index: int, rod_tier: int) -> Dictionary:
    if index < 0 or index >= SITE_COUNT or rod_tier < 1 or rod_tier > 3:
        return _result(false, "Invalid site or fishing rod.")
    var site: Dictionary = state["sites"][index]
    var temp: int = int(site["temperature"])
    var eligible: bool = rod_tier >= int(MIN_ROD[index]) and (
        temp >= int(TEMP_MIN[index]) and temp <= int(TEMP_MAX[index])) and (
        state["weather"] != "Storm") and not (
        state["season"] == "Winter" and index == 2) and (
        int(site["population"]) >= 3)
    return {"ok":true, "eligible":eligible, "chance_percent":(5 + rod_tier) * 10,
        "energy_quote":6, "message":"%s: %s. %d%% model catch chance; no fish granted." % [
            SITE_NAMES[index], "cast possible" if eligible else "cast unavailable",
            (5 + rod_tier) * 10]}

func cast(index: int, rod_tier: int, epoch: int) -> Dictionary:
    if epoch != int(state["epoch"]):
        return _result(false, "Fishing denied: stale or future calendar day.")
    var forecast_result: Dictionary = forecast(index, rod_tier)
    if not bool(forecast_result["ok"]) or not bool(forecast_result.get("eligible", false)):
        return _result(false, "Fishing denied: rod, season, weather, temperature or stock.")
    var site: Dictionary = state["sites"][index]
    if int(site["last_cast_epoch"]) == epoch:
        return _result(false, "Already cast at this site today.")
    var roll: int = (epoch * 7 + index * 3 + rod_tier * 5) % 10
    var caught: bool = roll < 5 + rod_tier
    site["last_cast_epoch"] = epoch
    if caught:
        site["population"] = int(site["population"]) - 1
        state["ledger"]["caught"] = int(state["ledger"]["caught"]) + 1
    return {"ok":true, "caught":caught, "species":SPECIES[index],
        "energy_quote":6, "proposal_id":"f15:%d:%d" % [epoch, index],
        "message":"%s at %s. Model-only catch; no inventory credited." % [
            "Caught a " + SPECIES[index] if caught else "No bite",
            SITE_NAMES[index]]}

func steward(index: int, epoch: int) -> Dictionary:
    if epoch != int(state["epoch"]) or index < 0 or index >= SITE_COUNT:
        return _result(false, "Wetland restoration denied: invalid site or day.")
    var site: Dictionary = state["sites"][index]
    if int(site["last_steward_epoch"]) == epoch:
        return _result(false, "This habitat was restored already today.")
    if int(site["habitat"]) >= 95:
        return _result(false, "Wetland habitat is at its restoration ceiling.")
    if int(state["ledger"]["remaining"]) < 3:
        return _result(false, "Insufficient model stewardship credits.")
    site["habitat"] = mini(95, int(site["habitat"]) + 10)
    site["last_steward_epoch"] = epoch
    state["ledger"]["spent"] = int(state["ledger"]["spent"]) + 3
    state["ledger"]["remaining"] = int(state["ledger"]["remaining"]) - 3
    return _result(true, "%s restored. Recruitment may improve on future days." % [
        SITE_NAMES[index]])

func advance_day(epoch: int, season: String, weather: String) -> Dictionary:
    if epoch != int(state["epoch"]) + 1 or epoch > 100000 or (
            not SEASONS.has(season)) or season != _season(epoch) or (
            not WEATHER.has(weather)):
        return _result(false, "Wetland day denied: non-monotonic epoch or climate.")
    var sites: Array = state["sites"]
    var ledger: Dictionary = state["ledger"]
    for i in range(SITE_COUNT):
        var site: Dictionary = sites[i]
        var habitat: int = int(site["habitat"])
        if weather == "Drought" and epoch % 11 == 0:
            habitat = maxi(0, habitat - 1)
        elif weather == "Rain" and epoch % 14 == 0:
            habitat = mini(95, habitat + 1)
        var temperature: int = _temperature(i, season, weather)
        var population: int = int(site["population"])
        var comfortable: bool = temperature >= int(TEMP_MIN[i]) and (
            temperature <= int(TEMP_MAX[i]))
        var birth: int = 0
        if comfortable and weather != "Storm" and population < CAPACITY and (
                epoch % 7 == 0 or (habitat >= 70 and epoch % 3 == 0)):
            birth = 2 if habitat >= 80 and epoch % 3 == 0 else 1
            birth = mini(birth, CAPACITY - population)
        var death: int = 0
        if population > 0 and (not comfortable or (
                weather == "Drought" and epoch % 5 == 0)):
            death = 1
        site["population"] = population + birth - death
        site["habitat"] = habitat
        site["temperature"] = temperature
        ledger["births"] = int(ledger["births"]) + birth
        ledger["deaths"] = int(ledger["deaths"]) + death
    state["epoch"] = epoch
    state["season"] = season
    state["weather"] = weather
    return _result(true, "Wetland stocks advanced one 56-day-calendar day.")

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and floor(number) == number and (
        number >= minimum and number <= maximum)

func _decode(raw: Variant) -> Dictionary:
    if not (raw is Dictionary) or raw.size() != 6:
        return {}
    for key in ["version", "epoch", "season", "weather", "sites", "ledger"]:
        if not raw.has(key):
            return {}
    if not _integer(raw["version"], 1, 1) or not (
            _integer(raw["epoch"], 1, 100000)):
        return {}
    var epoch: int = int(raw["epoch"])
    if not (raw["season"] is String) or raw["season"] != _season(epoch) or (
            not (raw["weather"] is String)) or not WEATHER.has(raw["weather"]):
        return {}
    if not (raw["sites"] is Array) or raw["sites"].size() != SITE_COUNT:
        return {}
    var sites: Array = []
    var population_total: int = 0
    for i in range(SITE_COUNT):
        var site = raw["sites"][i]
        if not (site is Dictionary) or site.size() != 5:
            return {}
        for key in ["population", "habitat", "temperature", "last_cast_epoch",
                "last_steward_epoch"]:
            if not site.has(key):
                return {}
        if not _integer(site["population"], 0, CAPACITY) or (
                not _integer(site["habitat"], 0, 95)) or (
                not _integer(site["temperature"], -5, 40)) or (
                int(site["temperature"]) != _temperature(i, raw["season"], raw["weather"])) or (
                not _integer(site["last_cast_epoch"], -1, epoch)) or (
                not _integer(site["last_steward_epoch"], -1, epoch)):
            return {}
        var normalized: Dictionary = {
            "population":int(site["population"]), "habitat":int(site["habitat"]),
            "temperature":int(site["temperature"]),
            "last_cast_epoch":int(site["last_cast_epoch"]),
            "last_steward_epoch":int(site["last_steward_epoch"])}
        sites.append(normalized)
        population_total += int(site["population"])
    if not (raw["ledger"] is Dictionary) or raw["ledger"].size() != 7:
        return {}
    var ledger: Dictionary = {}
    for key in ["founders", "births", "deaths", "caught", "budget", "spent", "remaining"]:
        if not raw["ledger"].has(key) or not _integer(raw["ledger"][key], 0, 1000000):
            return {}
        ledger[key] = int(raw["ledger"][key])
    if int(ledger["founders"]) != FOUNDERS or int(ledger["budget"]) != BUDGET or (
            int(ledger["spent"]) + int(ledger["remaining"]) != BUDGET) or (
            FOUNDERS + int(ledger["births"]) - int(ledger["deaths"]) - (
            int(ledger["caught"])) != population_total):
        return {}
    return {"version":1, "epoch":epoch, "season":str(raw["season"]),
        "weather":str(raw["weather"]), "sites":sites, "ledger":ledger}

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
