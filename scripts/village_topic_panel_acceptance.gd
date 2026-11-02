extends SceneTree
## V05: assembled-game, actual Village.act topic-choice routes and persistence.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("V05 TOPIC FAILED: " + label)

func _near(game, index: int) -> void:
    game.village.sync_schedule(true)
    game.hero.global_position = game.village.residents[index]["node"].global_position + Vector3(0, 1, 0)

func _key(code: int) -> InputEventKey:
    var event := InputEventKey.new()
    event.pressed = true
    event.physical_keycode = code
    return event

func _pad(code: int) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.pressed = true
    event.button_index = code
    return event

func _run() -> void:
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    var village = game.village
    var ui = village.topic_panel
    _check(ui != null and ui.panel != null, "actual assembled Game creates optional conversation overlay")
    _check(ui.topic_buttons.size() == 2, "two player-selectable choices")
    _check(ui.opener.custom_minimum_size.y >= 44.0, "touch-capable opener")
    _check(ui.topic_buttons[0].focus_mode == Control.FOCUS_ALL, "keyboard/controller choice focus")
    _check(not ui.panel.visible, "no topic dialogue automatically triggered")
    _check(village.available_topics("missing").is_empty(), "unknown NPC has no fabricated topics")
    var total_topics: int = 0
    for resident in village.residents:
        var rid: String = str(resident["id"])
        var options: Array = village.available_topics(rid)
        _check(options.size() == 2, "two distinct original topics for " + rid)
        total_topics += options.size()
        for option in options:
            var line: String = village._dialogue(resident, rid, game.day_epoch(), str(option["id"]))
            _check(not line.is_empty() and line != str(option["label"]), "authored English response reachable for " + rid)
    _check(total_topics == 12, "twelve authored topics across six original residents")
    village.set_dialogue_locale("es")
    for resident in village.residents:
        var rid: String = str(resident["id"])
        for option in village.available_topics(rid):
            _check(not str(option["label"]).is_empty()
                    and not village._dialogue(resident, rid, game.day_epoch(), str(option["id"])).is_empty(),
                    "Spanish label and reply reachable for " + rid)
    village.set_dialogue_locale("en")

    game.minute_of_day = 600.0
    game.weather = "Clear"
    _near(game, 0)
    var gold_before: int = game.gold
    var energy_before: float = game.energy
    var inventory_before: Dictionary = game.inventory.duplicate(true)
    var restoration_before: int = game.restoration
    var initial: Dictionary = village.save_state()
    ui.opener.pressed.emit()
    _check(ui.panel.visible and paused, "mouse/touch opener pauses the world")
    _check(ui.active_resident_id == "mira", "nearby NPC is selected by actual world distance")
    _check(ui.topic_ids.size() == 2 and "Mira" in ui.title_label.text, "visible NPC-specific choice text")
    _check(village.save_state() == initial and game.gold == gold_before, "opening dialogue menu has no economy/social effects")
    _check(not village.social_journal.panel.visible, "journal initially closed")
    village.social_journal.open_journal()
    _check(not village.social_journal.panel.visible, "second modal cannot steal pause ownership")
    var chosen_id: String = ui.topic_ids[0]
    var expected: String = village._dialogue(village.residents[0], "mira", game.day_epoch(), chosen_id)
    ui.topic_buttons[0].pressed.emit()
    _check(not ui.panel.visible and not paused, "choice closes modal and restores game")
    _check(expected in ui.last_result and game.latest_message == ui.last_result, "authored choice reaches HUD")
    _check(int(village.memories["mira"]["talks"]) == 1, "choice routes through actual once-per-day talk")
    _check(int(village.affection["mira"]) == 4 and game.restoration == restoration_before + 1, "first talk gives only baseline reward")
    _check(game.gold == gold_before and is_equal_approx(game.energy, energy_before)
            and game.inventory == inventory_before, "talk choice cannot mint or spend currency/energy/items")
    var log: Array = village.memories["mira"]["dialogue_log"]
    _check(log.size() == 1 and str(log[0]["text"]) == expected
            and int(log[0]["epoch"]) == game.day_epoch(), "actual chosen line persists as bounded dated transcript")

    ui._input(_key(KEY_U))
    _check(ui.panel.visible, "keyboard U reopens conversation")
    ui._input(_key(KEY_2))
    _check(not ui.panel.visible and not paused, "keyboard 2 selects alternate choice")
    _check(int(village.affection["mira"]) == 4 and int(village.memories["mira"]["talks"]) == 1,
            "same-day second choice never duplicates friendship or talk count")
    _check(village.memories["mira"]["dialogue_log"] == log, "same-day choice does not rewrite historical transcript")
    ui._input(_pad(JOY_BUTTON_RIGHT_STICK))
    _check(ui.panel.visible, "controller right-stick click opens topic menu")
    ui._input(_pad(JOY_BUTTON_DPAD_DOWN))
    _check(ui.selected_index == 1, "controller D-pad selects alternate topic")
    ui._input(_pad(JOY_BUTTON_B))
    _check(not ui.panel.visible and not paused, "controller B cancels without action")
    _check(int(village.affection["mira"]) == 4, "cancel has no friendship reward")
    ui._input(_pad(JOY_BUTTON_RIGHT_STICK))
    ui._input(_pad(JOY_BUTTON_A))
    _check(not ui.panel.visible and int(village.affection["mira"]) == 4,
            "controller A chooses topic without same-day duplication")

    village.social_journal.open_journal()
    _check(paused, "journal remains independently functional")
    ui.open_topics()
    _check(not ui.panel.visible, "topic menu cannot open over journal")
    village.social_journal.close_journal()
    _check(not paused, "journal returns to unpaused world")

    game.year = 2
    game.season_index = 0
    game.day = 1
    game.minute_of_day = 600.0
    game.weather = "Clear"
    village.set_dialogue_locale("es")
    _near(game, 0)
    ui._input(_key(KEY_U))
    _check(ui.panel.visible and "Preguntar" in ui.opener.text, "Spanish topic menu visible in year two")
    ui._input(_key(KEY_1))
    _check("Mira:" in ui.last_result and not ui.panel.visible, "Spanish selected conversation is playable")
    var spanish_log: Array = village.memories["mira"]["dialogue_log"]
    _check(spanish_log.size() == 2 and str(spanish_log[-1]["locale"]) == "es",
            "Spanish chosen line recorded after 56-day rollover")
    _check(int(village.affection["mira"]) == 8 and int(village.memories["mira"]["talks"]) == 2,
            "year-two conversation earns one new legitimate talk reward")
    var before_save: Dictionary = village.save_state()
    var saved_gold: int = game.gold
    game.save_game(false)
    village.memories["mira"]["dialogue_log"].clear()
    village.affection["mira"] = 0
    game.load_game()
    _check(game.latest_message == "Loaded saved life in the valley.", "assembled native save admits selected-topic transcript")
    _check(village.save_state() == before_save, "nested selected-topic memory survives full Game save/load")
    _check(game.gold == saved_gold and game.inventory == inventory_before,
            "save/reload conserves money and items")
    _near(game, 0)
    ui._input(_pad(JOY_BUTTON_RIGHT_STICK))
    ui._input(_pad(JOY_BUTTON_A))
    _check(int(village.affection["mira"]) == 8, "reloaded same-day choice cannot duplicate reward")

    game.hero.global_position = Vector3(500, 1, 500)
    ui.open_topics()
    _check(not ui.panel.visible and "Acércate" in ui.last_result,
            "offsite question rejected with localized feedback")
    _check(game.gold == saved_gold, "offsite rejection conserves money")
    _near(game, 0)
    ui.open_topics()
    game.hero.global_position = Vector3(500, 1, 500)
    var state_before_reach: Dictionary = village.save_state()
    ui._choose_index(0)
    _check(not ui.panel.visible and village.save_state() == state_before_reach,
            "moving out of range before selection cancels without rewards")

    game.year = 3
    game.season_index = 0
    game.day = 7
    game.minute_of_day = 1100.0
    game.weather = "Clear"
    _near(game, 0)
    var festival_line: String = village._dialogue(village.residents[0], "mira", game.day_epoch(), "clinic")
    _check("lantern" in festival_line.to_lower(), "festival context overrides topic without corrupting dialogue")
    game.day = 8
    game.minute_of_day = 600.0
    game.weather = "Rain"
    _near(game, 0)
    var rain_line: String = village._dialogue(village.residents[0], "mira", game.day_epoch(), "clinic")
    _check("rain" in rain_line.to_lower(), "rainy-day conversation priority remains intact")
    _check(not paused, "all input routes leave world pause state restored")
    print("EVERBLOOM V05 TOPIC NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
