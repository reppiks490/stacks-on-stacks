extends SceneTree
## V19 native Godot UI + authoritative social-state acceptance.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("VILLAGE JOURNAL FAILED: " + description)

func _run() -> void:
    var host = load("res://scripts/village_life_test_host.gd").new()
    root.add_child(host)
    var village = load("res://scripts/village.gd").new()
    root.add_child(village)
    village.setup(host)
    var ui = village.social_journal
    _check(ui != null and ui is CanvasLayer, "real CanvasLayer adapter exists")
    _check(ui.panel != null and not ui.panel.visible, "journal initially closed")
    _check(ui.opener != null and ui.opener.visible, "visible touch/mouse opener")
    _check(ui.opener.focus_mode == Control.FOCUS_ALL, "opener keyboard/controller focus")
    _check(ui.close_button.focus_mode == Control.FOCUS_ALL, "close control focusable")
    var initial: Array = village.social_recap()
    _check(initial.size() == 6, "all six resident identities represented")
    _check(str(initial[0]["id"]) == "mira" and int(initial[0]["friendship"]) == 0, "initial Mira identity and affection")
    _check(int(initial[0]["talks"]) == 0 and int(initial[0]["jobs"]) == 0, "no fabricated history")
    _check(initial[0]["dialogue_log"].is_empty(), "no invented transcript on a new game")

    host.minute_of_day = 600.0
    village.sync_schedule(true)
    var position: Vector3 = village.residents[0]["node"].global_position
    _check("Earned 24 petals" in village.act("job", position), "real job prerequisite")
    host.inventory["wild_herb"] = 0
    _check("treasured favorite" in village.act("gift", position).to_lower(), "real gift prerequisite")
    var first_talk: String = village.act("talk", position)
    _check("Mira:" in first_talk, "real conversation prerequisite")
    var first_log: Array = village.social_recap()[0]["dialogue_log"]
    _check(first_log.size() == 1 and int(first_log[0]["epoch"]) == host.day_epoch(), "real talk creates one dated transcript")
    _check(str(first_log[0]["text"]) in first_talk and str(first_log[0]["locale"]) == "en", "transcript preserves actually spoken English text")
    var after_first_talk: Dictionary = village.save_state()
    var first_restoration: int = host.restoration
    _check("Mira:" in village.act("talk", position), "same-day repeat remains available")
    _check(village.save_state() == after_first_talk and host.restoration == first_restoration, "same-day repeat neither duplicates transcript nor rewards")
    var after: Array = village.social_recap()
    _check(int(after[0]["jobs"]) == 1 and int(after[0]["gifts"]) == 1 and int(after[0]["talks"]) == 1, "recap reflects earned actions")
    _check(str(after[0]["last_gift_item"]) == "bluebell", "recap reflects actual last gift")
    _check(int(after[0]["friendship"]) == 22, "recap reads authoritative friendship")

    host.day = 7
    host.minute_of_day = 1100.0
    village.sync_schedule(true)
    _check("Seed Lantern Walk" in village.act("talk", Vector3(31, 0, 4)), "real festival visit")
    _check(int(village.social_recap()[0]["festivals"]) == 1, "recap includes festival memory")
    _check(village.social_recap()[0]["dialogue_log"].size() == 2, "festival dialogue is genuinely recorded on its own day")
    var gold_before: int = host.gold
    var inventory_before: Dictionary = host.inventory.duplicate(true)
    var saved_before: Dictionary = village.save_state()

    ui.open_journal()
    _check(ui.panel.visible and not ui.opener.visible, "opening shows journal, hides opener")
    _check(paused, "open journal pauses game calendar and movement")
    _check("Mira" in ui.rendered_text and "bluebell" in ui.rendered_text, "visible recap includes actual person and gift")
    _check("Festival visits: 1" in ui.rendered_text, "visible festival recap")
    _check(ui.entries.get_child_count() == 6, "six scrollable recap sections")

    _check(ui.cards.size() == 6 and ui.cards[0].focus_mode == Control.FOCUS_ALL, "six focusable neighbor cards")
    _check(ui.selected_index == 0 and "Mira" in ui.selected_label.text, "first neighbor initially selected")
    _check(ui.history_text.focus_mode == Control.FOCUS_ALL and ui.history_text.scroll_active, "history is focusable and scrollable")
    _check("Day 1 [en]" in ui.history_text.text and "Day 7 [en]" in ui.history_text.text, "actual two-day Mira dialogue is visible")
    var down := InputEventKey.new()
    down.pressed = true
    down.physical_keycode = KEY_DOWN
    ui._input(down)
    _check(ui.selected_index == 1 and "Rowan" in ui.selected_label.text, "keyboard Down selects next neighbor")
    _check(ui.history_text.text == "none yet", "unspoken Rowan dialogue is not invented")
    var up := InputEventKey.new()
    up.pressed = true
    up.physical_keycode = KEY_UP
    ui._input(up)
    _check(ui.selected_index == 0, "keyboard Up selects previous neighbor")
    var dpad_down := InputEventJoypadButton.new()
    dpad_down.pressed = true
    dpad_down.button_index = JOY_BUTTON_DPAD_DOWN
    ui._input(dpad_down)
    _check(ui.selected_index == 1, "controller D-pad Down selects neighbor")
    var dpad_up := InputEventJoypadButton.new()
    dpad_up.pressed = true
    dpad_up.button_index = JOY_BUTTON_DPAD_UP
    ui._input(dpad_up)
    _check(ui.selected_index == 0, "controller D-pad Up selects neighbor")
    var end_key := InputEventKey.new()
    end_key.pressed = true
    end_key.physical_keycode = KEY_END
    ui._input(end_key)
    _check(ui.selected_index == 5 and "Soren" in ui.selected_label.text, "keyboard End reaches final neighbor")
    ui._input(down)
    _check(ui.selected_index == 5, "navigation clamps without wrapping")
    ui._toggle_locale()
    _check(village.dialogue_locale == "es", "journal exposes existing Spanish dialogue presentation API")
    _check("Amistad:" in ui.rendered_text and "Visitas a festivales: 1" in ui.rendered_text, "Spanish recap translates earned state")
    _check("Soren" in ui.selected_label.text and ui.selected_index == 5, "language change preserves selection")
    _check(ui.language_button.text == "English" and ui.close_button.text == "Cerrar", "Spanish controls are visible")
    ui._select_neighbor(0)
    _check(ui.history_title.text == "Conversaciones recordadas" and "Día 1 [en]" in ui.history_text.text, "Spanish UI labels preserve historical language provenance")
    ui._select_neighbor(5)
    ui._toggle_locale()
    _check(village.dialogue_locale == "en" and "Festival visits: 1" in ui.rendered_text, "English can be restored without reload")
    _check(ui.entries.get_child_count() == 6, "repeated locale refresh does not accumulate stale cards")
    _check(village.save_state() == saved_before, "navigation and language changes leave social save state untouched")

    _check(village.save_state() == saved_before, "opening UI never changes saved social state")
    _check(host.gold == gold_before and host.inventory == inventory_before, "opening UI cannot mint or spend goods")
    ui.close_journal()
    _check(not paused and not ui.panel.visible and ui.opener.visible, "closing resumes game")

    paused = true
    ui.open_journal()
    _check(paused and ui.panel.visible, "journal opens while an external system has already paused")
    ui.close_journal()
    _check(paused, "closing restores prior paused state rather than always unpausing")
    paused = false


    var keyboard := InputEventKey.new()
    keyboard.pressed = true
    keyboard.physical_keycode = KEY_L
    ui._input(keyboard)
    _check(paused and ui.panel.visible, "L opens without mouse")
    ui._input(keyboard)
    _check(not paused and not ui.panel.visible, "L closes without mouse")
    var controller := InputEventJoypadButton.new()
    controller.pressed = true
    controller.button_index = JOY_BUTTON_BACK
    ui._input(controller)
    _check(paused and ui.panel.visible, "controller Back opens without mouse")
    ui._input(controller)
    _check(not paused and not ui.panel.visible, "controller Back closes without mouse")

    var saved: Variant = JSON.parse_string(JSON.stringify(village.save_state()))
    _check(saved is Dictionary, "native JSON snapshot")
    host.year = 2
    host.season_index = 0
    host.day = 1
    host.minute_of_day = 600.0
    var restored = load("res://scripts/village.gd").new()
    root.add_child(restored)
    restored.setup(host)
    if saved is Dictionary:
        restored.load_state(saved)
    var restored_recap: Array = restored.social_recap()
    _check(restored_recap == village.social_recap(), "year-two save reload preserves recap exactly")
    restored.social_journal.open_journal()
    _check("bluebell" in restored.social_journal.rendered_text, "gift memory survives new process-style Village instance")
    _check("Festival visits: 1" in restored.social_journal.rendered_text, "festival memory survives year rollover")
    _check("Day 1 [en]" in restored.social_journal.history_text.text, "authentic transcript survives 56-day year rollover")
    _check(host.gold == gold_before and host.inventory == inventory_before, "reload recap has zero economy effects")
    restored.social_journal.close_journal()
    _check(not paused, "journal leaves scene unpaused")

    # Deterministic bounded retention: 15 more unique calendar days must
    # retain only the 12 most recent genuine lines without reward replay.
    for index in range(15):
        host.advance_day()
        restored.next_day()
        var near_mira: Vector3 = restored.residents[0]["node"].global_position
        var line: String = restored.act("talk", near_mira)
        _check("Mira:" in line, "later talk remains player-visible on day %d" % index)
        var log: Array = restored.social_recap()[0]["dialogue_log"]
        _check(log.size() <= 12, "transcript bounded to twelve entries on day %d" % index)
    var final_log: Array = restored.social_recap()[0]["dialogue_log"]
    _check(final_log.size() == 12 and int(final_log[0]["epoch"]) > 7, "oldest entries evicted after cap, latest retained")
    _check(int(final_log[-1]["epoch"]) == host.day_epoch(), "newest transcript matches monotonic calendar")
    var retained_state: Dictionary = restored.save_state()
    var legacy_state: Dictionary = retained_state.duplicate(true)
    for rid in legacy_state["memories"]:
        legacy_state["memories"][rid].erase("dialogue_log")
    var legacy = load("res://scripts/village.gd").new()
    root.add_child(legacy)
    legacy.setup(host)
    legacy.load_state(legacy_state)
    _check(legacy.social_recap()[0]["dialogue_log"].is_empty(), "old schema-1 memories load with empty authentic history")
    var reloaded = load("res://scripts/village.gd").new()
    root.add_child(reloaded)
    reloaded.setup(host)
    var roundtrip: Variant = JSON.parse_string(JSON.stringify(retained_state))
    if roundtrip is Dictionary:
        reloaded.load_state(roundtrip)
    _check(reloaded.social_recap()[0]["dialogue_log"] == final_log, "bounded transcript roundtrips through native JSON reload")
    _check(host.gold == gold_before and host.inventory == inventory_before, "transcript replay never creates money or items")
    print("EVERBLOOM VILLAGE JOURNAL NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
