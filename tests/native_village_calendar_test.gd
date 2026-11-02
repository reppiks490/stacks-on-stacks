extends SceneTree
## Real Godot engine test of Village's talk/gift admission across multiple years.
## An ordinary 120-frame smoke never exercises these input paths.
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("VILLAGE ACCEPTANCE FAILED: " + label)

func _run() -> void:
    var host = load("res://tests/village_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    _check(village.residents.size() == 6, "six distinct inhabitants loaded")
    _check(host.day_epoch() == 1, "first day epoch")
    var mira: Dictionary = village.residents[0]
    var position: Vector3 = mira["node"].global_position
    var identity: String = str(mira["id"])
    _check(identity == "mira", "Mira has canonical original id")
    var start_inventory: int = int(host.inventory["wild_herb"])
    _check("Mira:" in village.act("talk", position), "dialogue accessible")
    _check(int(village.affection[identity]) == 4, "one social reward")
    _check(int(host.social_contacts.size()) == 1, "social contacts persisted")
    _check("Mira:" in village.act("talk", position), "repeat chat shown")
    _check(int(village.affection[identity]) == 4, "repeat chat does not duplicate affection")
    _check("loved your gift" in village.act("gift", position), "first gift accepted")
    _check(int(village.affection[identity]) == 16, "gift awards 12 affection")
    _check(int(host.inventory["wild_herb"]) == start_inventory - 1, "gift spends exactly one herb")
    _check("One gift each day" in village.act("gift", position), "duplicate gift rejected")
    _check(int(host.inventory["wild_herb"]) == start_inventory - 1, "duplicate gift costs no inventory")
    _check(int(host.restoration) == 3, "once-only restoration for chat and gift")

    # Calendar must always advance, including all four seasons and the year boundary.
    var old_epoch: int = host.day_epoch()
    for i in range(56):
        host.advance_day()
        _check(host.day_epoch() == old_epoch + i + 1, "monotonic epoch step %d" % i)
    _check(host.year == 2 and host.season_index == 0 and host.day == 1,
           "returned to Spring Day 1 in second year")
    var affection_before: int = int(village.affection[identity])
    var herb_before: int = int(host.inventory["wild_herb"])
    _check("Mira:" in village.act("talk", position), "second-year dialogue available")
    _check(int(village.affection[identity]) == affection_before + 4,
           "second-year conversation grants once")
    _check("loved your gift" in village.act("gift", position),
           "second-year same-calendar-date gift accepted")
    _check(int(host.inventory["wild_herb"]) == herb_before - 1,
           "year-two gift spent one herb")
    _check("One gift each day" in village.act("gift", position),
           "year-two duplicate denied")
    _check(int(host.inventory["wild_herb"]) == herb_before - 1,
           "year-two duplicate spends nothing")
    _check(int(village.affection[identity]) == affection_before + 16,
           "year-two no reward duplication")

    # Genuine JSON roundtrip approximates on-disk dictionary serialization.
    var snapshot: Variant = JSON.parse_string(JSON.stringify(village.save_state()))
    _check(snapshot is Dictionary, "snapshot roundtrip decodes")
    var next_village = load("res://scripts/village.gd").new()
    root.add_child(next_village)
    next_village.setup(host)
    if snapshot is Dictionary:
        next_village.load_state(snapshot)
    _check(int(next_village.affection[identity]) == int(village.affection[identity]),
           "friendship survives save/load")
    var no_more_gifts: int = int(host.inventory["wild_herb"])
    _check("One gift each day" in next_village.act("gift", position),
           "loading same day cannot reset gift cap")
    _check(int(host.inventory["wild_herb"]) == no_more_gifts,
           "save reload cannot duplicate item spending")

    # New day restores permission for this resident only, without resetting affinity.
    host.advance_day()
    _check("loved your gift" in next_village.act("gift", position),
           "year-two next-day gift permitted")
    _check(int(host.inventory["wild_herb"]) == no_more_gifts - 1,
           "next-day gift single debit")

    print("EVERBLOOM VILLAGE NATIVE ACCEPTANCE: %d assertions, %d failures" % [
          assertions, failures])
    quit(0 if failures == 0 else 1)
