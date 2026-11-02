extends SceneTree
## Principal native save-boundary regression. Only run on an isolated CI runner.
## Unlike text-only tests, this executes the real Godot GDScript validator.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, context: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("PRINCIPAL SAVE VALIDATION FAIL: " + context)

func _run() -> void:
    var base: Dictionary = {
        "schema": 1, "year": 2, "day": 14, "season": 3,
        "minute": 900.0, "gold": 125, "energy": 85.0,
        "weather": "Clear", "restoration": 7,
        "crops_harvested": 1, "care_actions": 0,
        "inventory": {"turnip": 3, "fodder": 0},
        "farm": [], "village": {"affection": {}, "talked": {}, "gifted": {}},
        "animals": {"hen": {"last_care": -1}}, "hero_position": [0.0, 1.0, 0.0]
    }
    _check(SaveService.validate_payload(base), "valid schema-1 snapshot rejected")
    var legacy: Dictionary = base.duplicate(true)
    legacy.erase("year")
    _check(SaveService.validate_payload(legacy), "pre-year schema-1 compatibility lost")
    var bad: Dictionary = base.duplicate(true)
    bad["schema"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional schema was accepted")
    bad = base.duplicate(true)
    bad["year"] = 0
    _check(not SaveService.validate_payload(bad), "year zero was accepted")
    bad = base.duplicate(true)
    bad["day"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional day was accepted")
    bad = base.duplicate(true)
    bad["season"] = 4
    _check(not SaveService.validate_payload(bad), "impossible season accepted")
    bad = base.duplicate(true)
    bad["minute"] = INF
    _check(not SaveService.validate_payload(bad), "infinite minute accepted")
    bad = base.duplicate(true)
    bad["energy"] = NAN
    _check(not SaveService.validate_payload(bad), "NaN energy accepted")
    bad = base.duplicate(true)
    bad["energy"] = 110
    _check(not SaveService.validate_payload(bad), "overfilled energy accepted")
    bad = base.duplicate(true)
    bad["gold"] = -25
    _check(not SaveService.validate_payload(bad), "negative currency accepted")
    bad = base.duplicate(true)
    bad["gold"] = 4.75
    _check(not SaveService.validate_payload(bad), "fractional currency accepted")
    bad = base.duplicate(true)
    bad["inventory"]["turnip"] = -1
    _check(not SaveService.validate_payload(bad), "negative inventory accepted")
    bad = base.duplicate(true)
    bad["inventory"]["turnip"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional inventory accepted")
    bad = base.duplicate(true)
    bad["restoration"] = 101
    _check(not SaveService.validate_payload(bad), "restoration above 100 accepted")
    bad = base.duplicate(true)
    bad["hero_position"][0] = INF
    _check(not SaveService.validate_payload(bad), "infinite player coordinate accepted")
    bad = base.duplicate(true)
    bad["farm"] = [null]
    _check(not SaveService.validate_payload(bad), "malformed farm record accepted")
    bad = base.duplicate(true)
    bad["animals"]["hen"] = "not an animal state"
    _check(not SaveService.validate_payload(bad), "malformed animal state accepted")
    bad = base.duplicate(true)
    bad["inventory"]["turnip"] = 9007199254740992.0
    _check(not SaveService.validate_payload(bad), "integer precision overflow accepted")
    bad = base.duplicate(true)
    bad["village"]["talked"] = "tampered social state"
    _check(not SaveService.validate_payload(bad), "malformed daily social map accepted")
    bad = base.duplicate(true)
    bad["farm"] = [{"age": 1.5}]
    _check(not SaveService.validate_payload(bad), "fractional soil age accepted")
    bad = base.duplicate(true)
    bad["animals"]["hen"]["health"] = "impossible health"
    _check(not SaveService.validate_payload(bad), "invalid animal health accepted")
    bad = base.duplicate(true)
    bad["animals"]["hen"]["last_care"] = -5
    _check(not SaveService.validate_payload(bad), "impossible animal epoch accepted")
    bad = base.duplicate(true)
    bad["social_contacts"] = {"mira": "not a boolean"}
    _check(not SaveService.validate_payload(bad), "invalid social contact flag accepted")
    # Ecology + village-life contracts introduced after the original 24 fixtures.
    var integrated: Dictionary = base.duplicate(true)
    integrated["animals"]["__paddocks__"] = [
        {"forage": 7}, {"forage": 4}, {"forage": 1}]
    integrated["animals"]["hen"]["compost_counter"] = 2
    integrated["village"]["worked"] = {"mira": 56}
    integrated["village"]["festivals"] = {"2:seed_lantern_walk": true}
    integrated["village"]["memories"] = {
        "mira": {"talks": 5, "gifts": 1, "jobs": 1, "festivals": 1,
                 "last_gift_item": "wild_herb", "last_gift_epoch": 56,
                 "last_gift_favorite": true, "recalled_gift_epoch": 56,
                 "gift_recollections": 1}}
    _check(SaveService.validate_payload(integrated),
           "valid ecology + village-life state was rejected")
    bad = integrated.duplicate(true)
    bad["animals"]["__paddocks__"] = {"forage": 7}
    _check(not SaveService.validate_payload(bad), "paddock array shape accepted as dict")
    bad = integrated.duplicate(true)
    bad["animals"]["__paddocks__"][0]["forage"] = -1
    _check(not SaveService.validate_payload(bad), "negative grazing capacity accepted")
    bad = integrated.duplicate(true)
    bad["animals"]["hen"]["compost_counter"] = "full"
    _check(not SaveService.validate_payload(bad), "malformed compost counter accepted")
    bad = integrated.duplicate(true)
    bad["village"]["worked"]["mira"] = "last year"
    _check(not SaveService.validate_payload(bad), "malformed job epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["festivals"]["2:seed_lantern_walk"] = 123
    _check(not SaveService.validate_payload(bad), "invalid festival attendance accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["jobs"] = "unbounded"
    _check(not SaveService.validate_payload(bad), "malformed employment memory accepted")

    # P04/P05: festival rewards are a separate nested domain snapshot.
    # Old schema-1 saves may omit it; present snapshots must be lossless.
    var festival_state: Dictionary = integrated.duplicate(true)
    festival_state["festivals"] = {"schema": 1, "awarded": [
        "1:spring_seed_exchange", "2:summer_lantern_making"]}
    _check(SaveService.validate_payload(festival_state),
           "valid multi-year festival awards rejected")
    bad = festival_state.duplicate(true)
    bad["festivals"] = []
    _check(not SaveService.validate_payload(bad), "festival array accepted as domain")
    bad = festival_state.duplicate(true)
    bad["festivals"].erase("schema")
    _check(not SaveService.validate_payload(bad), "missing festival schema accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["schema"] = 2
    _check(not SaveService.validate_payload(bad), "future festival schema accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = "not an award list"
    _check(not SaveService.validate_payload(bad), "string festival awards accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = [17]
    _check(not SaveService.validate_payload(bad), "numeric festival award accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"].append("1:spring_seed_exchange")
    _check(not SaveService.validate_payload(bad), "duplicate festival award accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["3:spring_seed_exchange"]
    _check(not SaveService.validate_payload(bad), "future-year festival award accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["0:spring_seed_exchange"]
    _check(not SaveService.validate_payload(bad), "year-zero festival award accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["01:spring_seed_exchange"]
    _check(not SaveService.validate_payload(bad), "noncanonical festival year accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["2:"]
    _check(not SaveService.validate_payload(bad), "empty festival event ID accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["2:summer:lantern"]
    _check(not SaveService.validate_payload(bad), "extra festival key separator accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["2:../unsafe"]
    _check(not SaveService.validate_payload(bad), "unsafe festival event ID accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = ["2:invented_festival"]
    _check(not SaveService.validate_payload(bad), "unknown festival award ID accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["forged_field"] = true
    _check(not SaveService.validate_payload(bad), "unknown festival state field accepted")
    bad = festival_state.duplicate(true)
    bad["festivals"]["awarded"] = []
    bad["festivals"]["awarded"].resize(5001)
    _check(not SaveService.validate_payload(bad), "unbounded festival awards accepted")

    # New optional Village recollection fields must reject tampering rather
    # than being silently converted/clamped by Village.load_state().
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["last_gift_favorite"] = 1
    _check(not SaveService.validate_payload(bad), "numeric favorite flag accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["last_gift_favorite"] = "yes"
    _check(not SaveService.validate_payload(bad), "string favorite flag accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["recalled_gift_epoch"] = "56"
    _check(not SaveService.validate_payload(bad), "string recall epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["recalled_gift_epoch"] = 56.5
    _check(not SaveService.validate_payload(bad), "fractional recall epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["recalled_gift_epoch"] = -2
    _check(not SaveService.validate_payload(bad), "negative invalid recall epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["recalled_gift_epoch"] = 113
    _check(not SaveService.validate_payload(bad), "future recall epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"].erase("last_gift_epoch")
    _check(not SaveService.validate_payload(bad), "recollection without gift accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["recalled_gift_epoch"] = 55
    _check(not SaveService.validate_payload(bad), "recollection before gift accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["gift_recollections"] = -1
    _check(not SaveService.validate_payload(bad), "negative recollection count accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["gift_recollections"] = 1.5
    _check(not SaveService.validate_payload(bad), "fractional recollection count accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["gift_recollections"] = 1000001
    _check(not SaveService.validate_payload(bad), "unbounded recollection count accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["gift_recollections"] = "many"
    _check(not SaveService.validate_payload(bad), "string recollection count accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["last_gift_epoch"] = 113
    _check(not SaveService.validate_payload(bad), "future last-gift epoch accepted")
    bad = integrated.duplicate(true)
    bad["village"]["memories"]["mira"]["last_gift_item"] = 7
    _check(not SaveService.validate_payload(bad), "numeric gift item accepted")

    # P04/P05: optional V19 earned dialogue must be admitted losslessly or
    # rejected atomically. Year one epoch 56 precedes year two epoch 57.
    var dialogue_fixture: Dictionary = integrated.duplicate(true)
    dialogue_fixture["village"]["memories"]["mira"]["dialogue_log"] = [
        {"epoch": 56, "locale": "en", "text": "Welcome to the valley."},
        {"epoch": 57, "locale": "es", "text": "Buenos dias, vecino."}]
    _check(SaveService.validate_payload(dialogue_fixture),
           "valid two-year bilingual dialogue history rejected")
    var dialogue_legacy: Dictionary = dialogue_fixture.duplicate(true)
    dialogue_legacy["village"]["memories"]["mira"].erase("dialogue_log")
    _check(SaveService.validate_payload(dialogue_legacy),
           "legacy village memory without dialogue log rejected")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"] = "not a history"
    _check(not SaveService.validate_payload(bad), "string dialogue history accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"] = [null]
    _check(not SaveService.validate_payload(bad), "null dialogue entry accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][0]["epoch"] = "56"
    _check(not SaveService.validate_payload(bad), "string dialogue epoch accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][0]["epoch"] = 56.5
    _check(not SaveService.validate_payload(bad), "fractional dialogue epoch accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["epoch"] = 113
    _check(not SaveService.validate_payload(bad), "future dialogue epoch accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][0]["epoch"] = 0
    _check(not SaveService.validate_payload(bad), "zero dialogue epoch accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["epoch"] = 56
    _check(not SaveService.validate_payload(bad), "duplicate dialogue epoch accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][0]["epoch"] = 58
    _check(not SaveService.validate_payload(bad), "descending dialogue epochs accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["locale"] = "fr"
    _check(not SaveService.validate_payload(bad), "unknown dialogue locale accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["locale"] = 1
    _check(not SaveService.validate_payload(bad), "numeric dialogue locale accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["text"] = ""
    _check(not SaveService.validate_payload(bad), "empty dialogue text accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["text"] = 9
    _check(not SaveService.validate_payload(bad), "numeric dialogue text accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["text"] = "x".repeat(257)
    _check(not SaveService.validate_payload(bad), "oversized dialogue text accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1].erase("text")
    _check(not SaveService.validate_payload(bad), "missing dialogue text accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["unowned"] = true
    _check(not SaveService.validate_payload(bad), "extra dialogue entry field accepted")
    bad = dialogue_fixture.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"] = []
    for epoch in range(1, 14):
        bad["village"]["memories"]["mira"]["dialogue_log"].append(
            {"epoch": epoch, "locale": "en", "text": "Recorded line"})
    _check(not SaveService.validate_payload(bad), "overlong dialogue history accepted")
    var dialogue_boundary: Dictionary = dialogue_fixture.duplicate(true)
    dialogue_boundary["village"]["memories"]["mira"]["dialogue_log"][1]["text"] = "x".repeat(256)
    _check(SaveService.validate_payload(dialogue_boundary),
           "exactly 256-character dialogue text rejected")

    # P02/P04/P05: all once-per-day ledgers must fit the *saved* 56-day
    # monotonic epoch. Domain loaders previously clamped future values,
    # silently altering otherwise accepted snapshots.
    var rollover: Dictionary = base.duplicate(true)
    rollover["year"] = 1
    rollover["season"] = 3
    rollover["day"] = 14 # epoch 56
    rollover["farm"] = [{"last_harvest_epoch": 56}]
    rollover["animals"]["hen"]["last_care"] = 56
    rollover["village"]["talked"] = {"mira": 56}
    rollover["village"]["gifted"] = {"mira": 56}
    rollover["village"]["worked"] = {"mira": 56}
    _check(SaveService.validate_payload(rollover), "last day of year one epoch 56 rejected")
    var next_year: Dictionary = rollover.duplicate(true)
    next_year["year"] = 2
    next_year["season"] = 0
    next_year["day"] = 1 # epoch 57; prior year's actions remain valid
    _check(SaveService.validate_payload(next_year), "year-two epoch 57 rejected")
    for domain_key: String in ["talked", "gifted", "worked"]:
        bad = next_year.duplicate(true)
        bad["village"][domain_key]["mira"] = 58
        _check(not SaveService.validate_payload(bad),
               "future year-two village %s epoch accepted" % domain_key)
    bad = next_year.duplicate(true)
    bad["farm"][0]["last_harvest_epoch"] = 58
    _check(not SaveService.validate_payload(bad), "future farm harvest epoch accepted")
    bad = next_year.duplicate(true)
    bad["animals"]["hen"]["last_care"] = 58
    _check(not SaveService.validate_payload(bad), "future livestock care epoch accepted")
    bad = next_year.duplicate(true)
    bad["village"]["worked"]["mira"] = 56.5
    _check(not SaveService.validate_payload(bad), "fractional job epoch accepted")
    bad = next_year.duplicate(true)
    bad["farm"][0]["last_harvest_epoch"] = -2
    _check(not SaveService.validate_payload(bad), "invalid negative harvest epoch accepted")
    bad = next_year.duplicate(true)
    bad["year"] = SaveService.MAX_SAFE_YEAR + 1
    _check(not SaveService.validate_payload(bad), "year allowing inexact day epoch accepted")
    bad = next_year.duplicate(true)
    bad["year"] = SaveService.MAX_SAFE_YEAR
    _check(SaveService.validate_payload(bad), "last exact-safe 56-day year rejected")
    bad = next_year.duplicate(true)
    bad["year"] = 1
    bad["season"] = 0
    bad["day"] = 1
    _check(not SaveService.validate_payload(bad),
           "year-one snapshot accepted year-two daily-action history")

    # This is the actual assembled Game coordinator and its real domain saves,
    # running on a disposable CI user:// filesystem; never a live player's slot.
    for file_path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH,
                             SaveService.TEMP_PATH]:
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
    var session = load("res://scripts/game.gd").new()
    root.add_child(session)
    _check(InputMap.has_action("job"), "principal K job action not installed")
    var job_key_mapped: bool = false
    for evt in InputMap.action_get_events("job"):
        if evt is InputEventKey and evt.physical_keycode == KEY_K:
            job_key_mapped = true
    _check(job_key_mapped, "K key not mapped to part-time jobs")
    session.year = 3
    session.season_index = 1
    session.day = 12
    session.gold = 901
    session.inventory["turnip"] = 17
    session.village.memories["mira"]["talks"] = 9
    session.village.memories["mira"]["last_gift_item"] = "wild_herb"
    session.village.memories["mira"]["last_gift_epoch"] = 130
    session.village.memories["mira"]["last_gift_favorite"] = true
    session.village.memories["mira"]["recalled_gift_epoch"] = 130
    session.village.memories["mira"]["gift_recollections"] = 2
    var earned_lines: Array = [
        {"epoch": 129, "locale": "en", "text": "Good morning, neighbor."},
        {"epoch": 130, "locale": "es", "text": "La cosecha prospera."}]
    session.village.memories["mira"]["dialogue_log"] = earned_lines.duplicate(true)
    session.animals.paddocks[0]["forage"] = 5
    session.festivals.awarded["3:spring_seed_exchange"] = true
    session.save_game(false)
    _check(FileAccess.file_exists(SaveService.SAVE_PATH),
           "assembled gameplay failed to create a valid save")
    var saved: Dictionary = SaveService.read_payload()
    _check(int(saved.get("year", -1)) == 3, "assembled year did not persist")
    _check(saved.get("animals", {}).get("__paddocks__", []).size() == 3,
           "assembled grazing state did not persist")
    _check(saved.get("village", {}).get("memories", {}).has("mira"),
           "assembled village memory did not persist")
    _check(saved.get("village", {}).get("memories", {}).get("mira", {}).get("dialogue_log", []) == earned_lines,
           "assembled earned dialogue missing or changed in saved JSON")
    _check(saved.get("festivals", {}).get("awarded", []).has("3:spring_seed_exchange"),
           "assembled festival award missing from saved snapshot")
    # Invalid in-memory payload must not replace the last valid on-disk
    # snapshot or mutate the assembled player's state.
    var saved_bytes: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
    bad = saved.duplicate(true)
    bad["village"]["memories"]["mira"]["dialogue_log"][1]["epoch"] = session.day_epoch() + 1
    _check(not SaveService.write_payload(bad), "future assembled dialogue history written")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == saved_bytes,
           "invalid dialogue history modified authoritative save bytes")
    _check(session.gold == 901 and int(session.inventory.get("turnip", -1)) == 17,
           "rejected dialogue save mutated live currency or inventory")
    bad = saved.duplicate(true)
    bad["village"]["memories"]["mira"]["last_gift_favorite"] = "tampered"
    _check(not SaveService.write_payload(bad), "invalid assembled gift memory written")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == saved_bytes,
           "invalid gift memory modified authoritative save bytes")
    _check(session.gold == 901, "rejected save mutated active game currency")
    bad = saved.duplicate(true)
    bad["festivals"]["awarded"] = ["4:spring_seed_exchange"]
    _check(not SaveService.write_payload(bad), "future-year assembled festival award written")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == saved_bytes,
           "invalid festival awards modified authoritative save bytes")
    # Refuse invalid future daily-action state without touching authoritative
    # saved bytes or the live game; unlike fixture-only tests this is a real
    # assembled 30-bed + village + livestock snapshot.
    bad = saved.duplicate(true)
    bad["farm"][0]["last_harvest_epoch"] = session.day_epoch() + 1
    _check(not SaveService.write_payload(bad), "future assembled harvest written")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == saved_bytes,
           "future harvest rejection modified saved bytes")
    bad = saved.duplicate(true)
    bad["village"]["talked"]["mira"] = session.day_epoch() + 1
    _check(not SaveService.write_payload(bad), "future assembled social action written")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == saved_bytes,
           "future social rejection modified saved bytes")
    session.gold = 0
    session.inventory["turnip"] = 0
    session.year = 1
    session.day = 1
    session.animals.paddocks[0]["forage"] = 0
    session.village.memories["mira"]["talks"] = 0
    session.village.memories["mira"]["dialogue_log"] = []
    session.festivals.awarded.clear()
    session.village.memories["mira"]["last_gift_favorite"] = false
    session.village.memories["mira"]["recalled_gift_epoch"] = -1
    session.village.memories["mira"]["gift_recollections"] = 0
    session.load_game()
    _check(session.gold == 901, "assembled game currency failed to restore")
    _check(int(session.inventory["turnip"]) == 17,
           "assembled game inventory failed to restore")
    _check(session.year == 3 and session.season_index == 1 and session.day == 12,
           "assembled calendar failed to restore")
    _check(int(session.animals.paddocks[0]["forage"]) == 5,
           "assembled paddock failed to restore")
    _check(int(session.village.memories["mira"]["talks"]) == 9,
           "assembled village memory failed to restore")
    _check(session.village.memories["mira"]["dialogue_log"] == earned_lines,
           "assembled earned bilingual dialogue failed to roundtrip exactly")
    _check(session.village.memories["mira"]["last_gift_favorite"] == true
           and int(session.village.memories["mira"]["recalled_gift_epoch"]) == 130
           and int(session.village.memories["mira"]["gift_recollections"]) == 2,
           "assembled gift recollection failed to roundtrip exactly")
    _check(session.festivals.awarded.has("3:spring_seed_exchange"),
           "assembled festival award failed to roundtrip without duplication")
    _check(session.festivals.awarded.size() == 1,
           "assembled festival award count changed after reload")
    # P02/P04: every accepted schema-1 minute must survive the assembled
    # Game -> SaveService -> Game roundtrip, including historical off-hours.
    # Freeze rendering ticks here; gameplay auto-sleep at 22:00 is a separate
    # state transition and must not silently rewrite a loaded snapshot.
    session.set_process(false)
    for sample in [0.0, 359.5, 360.0, 1319.0, 1320.0, 1440.0]:
        var clock_sample: float = float(sample)
        session.minute_of_day = clock_sample
        session.save_game(false)
        var clock_payload: Dictionary = SaveService.read_payload()
        _check(clock_payload.get("minute", -1.0) == clock_sample,
               "assembled clock was not persisted at %s" % str(clock_sample))
        session.minute_of_day = 700.0
        session.load_game()
        _check(session.minute_of_day == clock_sample,
               "accepted schema-1 clock was clamped during load at %s" % str(clock_sample))
        _check(session.gold == 901 and int(session.inventory.get("turnip", -1)) == 17,
               "clock roundtrip changed assembled money or inventory")
    var clock_bytes: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
    for invalid_minute in [-0.01, 1440.01, INF]:
        var bad_clock: Dictionary = SaveService.read_payload().duplicate(true)
        bad_clock["minute"] = invalid_minute
        _check(not SaveService.validate_payload(bad_clock),
               "invalid schema-1 minute accepted: %s" % str(invalid_minute))
        _check(not SaveService.write_payload(bad_clock),
               "invalid schema-1 minute written: %s" % str(invalid_minute))
        _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == clock_bytes,
               "invalid clock write mutated authoritative save bytes")
    # A loaded late-night clock advances exactly one day on its next tick;
    # the rollover persists as an ordinary assembled game save.
    var before_bedtime_epoch: int = session.day_epoch()
    session.minute_of_day = 1440.0
    session._process(0.0)
    _check(session.day_epoch() == before_bedtime_epoch + 1,
           "late-night loaded clock did not advance exactly one day")
    _check(session.minute_of_day == 360.0,
           "late-night rollover did not reset clock to 06:00")
    var slept_payload: Dictionary = SaveService.read_payload()
    _check(int(slept_payload.get("year", -1)) == session.year
           and int(slept_payload.get("season", -1)) == session.season_index
           and int(slept_payload.get("day", -1)) == session.day
           and slept_payload.get("minute", -1.0) == 360.0,
           "late-night rollover did not persist authoritative calendar")
    session._process(0.0)
    _check(session.day_epoch() == before_bedtime_epoch + 1,
           "late-night rollover applied twice")
    _check(SaveService.validate_payload(base), "mutating deep duplicates corrupted valid fixture")
    print("PRINCIPAL SAVE VALIDATION: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
