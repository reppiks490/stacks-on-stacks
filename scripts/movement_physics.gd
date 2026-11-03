extends RefCounted
## Reusable movement tuning: accelerative locomotion, braking, gravity and mount handling.
## These are game-feel approximations; they are not a validated biomechanical simulator.
static func planar_acceleration(mounted: bool, on_ground: bool) -> float:
    if not on_ground:
        return 5.5
    return 16.0 if mounted else 22.0

static func braking_drag(mounted: bool, on_ground: bool) -> float:
    if not on_ground:
        return 3.0
    return 14.0 if mounted else 23.0

static func jump_impulse(mounted: bool) -> float:
    return 4.0 if mounted else 6.0

static func max_slope_angle(mounted: bool) -> float:
    return deg_to_rad(35.0 if mounted else 43.0)

static func mount_turn_limit(mounted: bool) -> float:
    return 3.8 if mounted else 8.5

static func gravity_force() -> float:
    return 24.0

static func sprint_multiplier(mounted: bool) -> float:
    return 1.25 if mounted else 1.47

static func stamina_drain(mounted: bool) -> float:
    return 5.5 if mounted else 10.0

static func stamina_recovery() -> float:
    return 7.5
