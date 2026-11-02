extends RefCounted
## F02 deterministic per-bed water accounting. Integer units are a gameplay
## abstraction, not physical millimeters or a claimed watershed simulation.
## This service has no hidden mutable state; the farm persists only moisture.
const CAPACITY: int = 100
const DRAINAGE_THRESHOLD: int = 90

static func advance_day(current_moisture: int, rain_units: int, summer: bool, weeds: int) -> Dictionary:
    var before: int = clampi(current_moisture, 0, CAPACITY)
    var rain: int = maxi(0, rain_units)
    var incoming: int = before + rain
    var runoff: int = maxi(0, incoming - CAPACITY)
    var infiltrated: int = mini(CAPACITY, incoming)
    # Saturated topsoil loses a little excess to deeper soil before evaporation.
    var drainage: int = floori(float(maxi(0, infiltrated - DRAINAGE_THRESHOLD)) / 2.0)
    var evap_demand: int = (22 if rain > 0 else (35 if summer else 29)) + clampi(weeds, 0, 5) * 2
    var evaporation: int = mini(infiltrated - drainage, evap_demand)
    var remaining: int = infiltrated - drainage - evaporation
    return {
        "before": before,
        "rain": rain,
        "available_for_growth": infiltrated,
        "runoff": runoff,
        "drainage": drainage,
        "evaporation": evaporation,
        "moisture": remaining,
        "balance_error": before + rain - runoff - drainage - evaporation - remaining
    }
