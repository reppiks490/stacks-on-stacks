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
    _check(ui.topic_buttons.size() == 4, "four reusable player-selectable choice controls")
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
    _check(ui.panel.get_node("ConversationScroll") is ScrollContainer,
            "scrollable topic menu preserves focus access on short screens")
    var initial_chapters: Array = village.chapter_progress("mira")
    _check(initial_chapters.size() == 2 and not bool(initial_chapters[0]["unlocked"])
            and not bool(initial_chapters[1]["unlocked"]),
            "both earned chapters initially locked without revealing their replies")
    _check(int(initial_chapters[0]["jobs_remaining"]) == 1
            and int(initial_chapters[1]["friendship_remaining"]) == 80,
            "tracker reports actual paid-shift and friendship deficits")
    _check("1 shift(s)" in ui.progress_label.text
            and "80 friendship points" in ui.progress_label.text,
            "English player-visible tracker explains both unlock requirements")
    _check(ui.topic_ids.size() == 2 and "Mira" in ui.title_label.text, "visible NPC-specific choice text")
    _check(ui.language_button.custom_minimum_size.y >= 44.0
            and ui.language_button.focus_mode == Control.FOCUS_ALL,
            "live language control is touch-sized and controller-focusable")
    var stable_topic_ids: Array[String] = ui.topic_ids.duplicate()
    var english_choice: String = ui.topic_buttons[0].text
    ui.language_button.pressed.emit()
    _check(village.dialogue_locale == "es" and "Elige" in ui.title_label.text
            and "Mira" in ui.title_label.text and ui.language_button.text == "English",
            "touch/mouse language button localizes active NPC menu")
    _check(ui.topic_ids == stable_topic_ids and ui.topic_buttons[0].text != english_choice
            and "Preguntar" in ui.topic_buttons[0].text,
            "Spanish choices translate without reordering stable topic IDs")
    _check("turno(s)" in ui.progress_label.text
            and "puntos de amistad" in ui.progress_label.text,
            "chapter tracker translates into Spanish without changing progress")
    _check(ui.panel.visible and paused and village.save_state() == initial
            and game.gold == gold_before and game.inventory == inventory_before,
            "language switch conserves paused game and all authoritative social/economic state")
    ui._input(_key(KEY_C))
    _check(village.dialogue_locale == "en" and ui.topic_buttons[0].text == english_choice
            and ui.topic_ids == stable_topic_ids and paused,
            "keyboard C restores English in place without losing selected topic")
    _check(village.save_state() == initial and game.gold == gold_before, "opening dialogue menu has no economy/social effects")
    # V19: a keyboard/controller confirm must activate the *focused* widget,
    # not the last selected topic index. This is essential for Tab navigation.
    ui.language_button.grab_focus()
    ui._input(_key(KEY_ENTER))
    _check(ui.panel.visible and paused and village.dialogue_locale == "es"
            and ui.language_button.text == "English",
            "keyboard Enter activates focused language control without talking")
    ui._input(_pad(JOY_BUTTON_A))
    _check(ui.panel.visible and paused and village.dialogue_locale == "en",
            "controller A activates focused language control without talking")
    _check(village.save_state() == initial and game.gold == gold_before
            and game.inventory == inventory_before and game.restoration == restoration_before,
            "focused language confirmations cannot mint friendship or resources")
    ui.cancel_button.grab_focus()
    ui._input(_key(KEY_ENTER))
    _check(not ui.panel.visible and not paused,
            "keyboard Enter on focused cancel closes menu rather than talking")
    _check(village.save_state() == initial and game.gold == gold_before,
            "focused keyboard cancel conserves all authoritative state")
    ui.open_topics()
    _check(ui.panel.visible and paused, "conversation reopens after focused cancel")
    ui.cancel_button.grab_focus()
    ui._input(_pad(JOY_BUTTON_A))
    _check(not ui.panel.visible and not paused,
            "controller A on focused cancel closes without selecting a topic")
    _check(village.save_state() == initial and game.gold == gold_before,
            "focused controller cancel cannot create a conversation reward")
    ui.open_topics()
    _check(ui.panel.visible and paused, "conversation reopens after controller cancel")
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
    var alternate_id: String = ui.topic_ids[1]
    var alternate_line: String = village._dialogue(village.residents[0], "mira", game.day_epoch(), alternate_id)
    ui.topic_buttons[1].grab_focus()
    ui._input(_key(KEY_ENTER))
    _check(not ui.panel.visible and not paused and alternate_line in ui.last_result,
            "keyboard Enter follows focused second topic, not stale selected index")
    ui._input(_key(KEY_U))
    _check(ui.panel.visible, "keyboard U reopens after focused topic activation")
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
    # SaveService may normalize absent zero-valued inventory keys. Compare
    # actual item quantities and reject newly minted positive items instead
    # of demanding identical dictionary key sets.
    var inventory_conserved: bool = true
    for item in inventory_before:
        if int(game.inventory.get(item, 0)) != int(inventory_before[item]):
            inventory_conserved = false
    for item in game.inventory:
        if not inventory_before.has(item) and int(game.inventory[item]) != 0:
            inventory_conserved = false
    _check(game.gold == saved_gold and inventory_conserved,
            "save/reload conserves money and every item quantity")
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
    # V05/V14: real work unlocks a new, optional chapter without a new save key.
    game.year = 4
    game.season_index = 0
    game.day = 1
    game.minute_of_day = 600.0
    game.weather = "Clear"
    village.set_dialogue_locale("en")
    _near(game, 0)
    var authored_shift: String = str(village.life_data["conversation_topics"]["mira"]["shift_reflection"]["reply"]["en"])
    _check(village.available_topics("mira").size() == 2, "earned chapters are hidden before prerequisites")
    _check(village._dialogue(village.residents[0], "mira", game.day_epoch(), "shift_reflection") != authored_shift,
            "direct locked topic ID cannot bypass social prerequisites")
    var before_shift_gold: int = game.gold
    var before_shift_energy: float = game.energy
    var work_reply: String = village.act("job", game.hero.global_position)
    _check("Earned 24 petals" in work_reply and game.gold == before_shift_gold + 24
            and is_equal_approx(game.energy, before_shift_energy - 12.0),
            "real paid work unlocks the shift chapter through authoritative settlement")
    _check(village.available_topics("mira").size() == 3, "one earned work chapter unlocked, trust remains gated")
    var after_work: Array = village.chapter_progress("mira")
    _check(bool(after_work[0]["unlocked"]) and int(after_work[0]["jobs_remaining"]) == 0
            and not bool(after_work[1]["unlocked"]),
            "legitimate paid shift immediately satisfies only the work chapter")
    ui.open_topics()
    _check(ui.panel.visible and ui.topic_ids.size() == 3
            and ui.topic_buttons[2].visible and not ui.topic_buttons[3].visible,
            "third visible choice appears only when actually earned")
    _check("Work memory: Ready to discuss" in ui.progress_label.text
            and "Trust memory:" in ui.progress_label.text,
            "live chapter tracker shows earned work while preserving locked trust")
    var earned_topic_ids: Array[String] = ui.topic_ids.duplicate()
    ui._input(_pad(JOY_BUTTON_X))
    _check(village.dialogue_locale == "es" and "plántulas" in ui.topic_buttons[2].text
            and ui.topic_ids == earned_topic_ids and paused,
            "controller X localizes unlocked earned chapter without altering IDs")
    ui._input(_pad(JOY_BUTTON_X))
    _check(village.dialogue_locale == "en" and "seedlings" in ui.topic_buttons[2].text
            and ui.topic_ids == earned_topic_ids and paused,
            "controller X roundtrip restores earned chapter and menu focus")
    ui._input(_key(KEY_3))
    _check(not ui.panel.visible and authored_shift in ui.last_result,
            "keyboard 3 plays original earned shift chapter")
    _check(int(village.memories["mira"]["talks"]) == 3,
            "year-four earned chapter uses exactly one legitimate new daily talk")
    var talk_before_trust: int = int(village.memories["mira"]["talks"])
    village.affection["mira"] = 80
    var authored_trust: String = str(village.life_data["conversation_topics"]["mira"]["trusted_memory"]["reply"]["en"])
    _check(village.available_topics("mira").size() == 4, "earned trust unlocks fourth original topic")
    _check(village.chapter_progress("mira").all(func(chapter): return bool(chapter["unlocked"])),
            "both earned chapter prerequisites are satisfied at 80 friendship")
    ui.open_topics()
    _check(ui.topic_ids.size() == 4 and ui.topic_buttons[3].visible,
            "fourth choice visible and focusable after friendship threshold")
    _check("Trust memory: Ready to discuss" in ui.progress_label.text,
            "player receives clear confirmation of trust chapter unlock")
    ui._input(_key(KEY_4))
    _check(authored_trust in ui.last_result and not ui.panel.visible,
            "keyboard 4 plays earned trust story")
    _check(int(village.memories["mira"]["talks"]) == talk_before_trust,
            "multiple same-day story choices never multiply social rewards")

    # All twelve earned chapters have distinct, localized content and predicates.
    var earned_count: int = 0
    for resident in village.residents:
        var rid: String = str(resident["id"])
        village.affection[rid] = maxi(80, int(village.affection[rid]))
        var record: Dictionary = village.memories[rid]
        record["jobs"] = maxi(1, int(record.get("jobs", 0)))
        village.memories[rid] = record
        var options: Array = village.available_topics(rid)
        _check(options.size() == 4, "both earned chapters reachable for " + rid)
        for topic_id in ["shift_reflection", "trusted_memory"]:
            var source: Dictionary = village.life_data["conversation_topics"][rid][topic_id]
            _check(village._dialogue(resident, rid, game.day_epoch(), topic_id) == str(source["reply"]["en"]),
                    "original English earned chapter reachable for " + rid + ":" + topic_id)
            earned_count += 1
    _check(earned_count == 12, "twelve distinct new conditional NPC chapters")
    village.set_dialogue_locale("es")
    for resident in village.residents:
        var rid: String = str(resident["id"])
        for topic_id in ["shift_reflection", "trusted_memory"]:
            var source: Dictionary = village.life_data["conversation_topics"][rid][topic_id]
            _check(village._dialogue(resident, rid, game.day_epoch(), topic_id) == str(source["reply"]["es"]),
                    "original Spanish earned chapter reachable for " + rid + ":" + topic_id)
    village.set_dialogue_locale("en")
    var earned_snapshot: Dictionary = village.save_state()
    var gold_at_save: int = game.gold
    game.save_game(false)
    village.affection["mira"] = 0
    village.memories["mira"]["jobs"] = 0
    game.load_game()
    _check(game.latest_message == "Loaded saved life in the valley." and village.save_state() == earned_snapshot,
            "all earned chapters restore from real assembled Game save without new save fields")
    _check(game.gold == gold_at_save and village.available_topics("mira").size() == 4,
            "save/load conserves money and restored chapter availability")
    _check(village.chapter_progress("mira").all(func(chapter): return bool(chapter["unlocked"])),
            "chapter tracker reconstructs both unlocks from actual reloaded memory")

    game.year = 5
    game.season_index = 0
    game.day = 1
    game.minute_of_day = 600.0
    game.weather = "Clear"
    _near(game, 0)
    var year_five_gold: int = game.gold
    var first_new_year_shift: String = village.act("job", game.hero.global_position)
    var duplicate_new_year_shift: String = village.act("job", game.hero.global_position)
    _check("Earned 24 petals" in first_new_year_shift and game.gold == year_five_gold + 24,
            "year-five monotonic epoch allows a new legitimate paid shift")
    _check("already helped" in duplicate_new_year_shift and game.gold == year_five_gold + 24,
            "same-day repeat shift cannot duplicate wages after year rollover")
    _check(village.available_topics("mira").size() == 4 and not paused,
            "earned chapters persist into year five without breaking modal pause")

    _check(not paused, "all input routes leave world pause state restored")
    print("EVERBLOOM V05 TOPIC NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
