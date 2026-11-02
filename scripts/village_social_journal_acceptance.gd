extends SceneTree
## V19 native Godot UI + authoritative social-state acceptance.
const SaveService = preload("res://scripts/save_service.gd")
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
    # V19 readable-size controls are real focusable buttons; the tests use
    # synthetic device events, not a claim of physical mobile/controller QA.
    _check(ui.smaller_text_button.focus_mode == Control.FOCUS_ALL
            and ui.larger_text_button.focus_mode == Control.FOCUS_ALL,
            "text scaling buttons support keyboard, gamepad and touch focus")
    _check(ui.smaller_text_button.custom_minimum_size.y >= 44.0
            and ui.larger_text_button.custom_minimum_size.y >= 44.0
            and ui.close_button.custom_minimum_size.y >= 44.0,
            "journal control touch targets have a 44-pixel minimum height")
    var base_card_font: int = ui.cards[0].get_theme_font_size("font_size")
    var base_history_font: int = ui.history_text.get_theme_font_size("normal_font_size")
    _check(ui.text_scale_index == 0 and ui.smaller_text_button.disabled
            and not ui.larger_text_button.disabled, "initial readable-size boundary")
    var initial_page: int = ui.history_page
    ui.larger_text_button.pressed.emit()
    _check(ui.text_scale_index == 1
            and ui.cards[0].get_theme_font_size("font_size") > base_card_font
            and ui.history_text.get_theme_font_size("normal_font_size") > base_history_font,
            "touch/mouse A+ enlarges resident and authentic transcript text")
    _check(ui.selected_index == 0 and ui.history_page == initial_page
            and ui.entries.get_child_count() == 6, "text scale preserves selection, page and cards")
    var grow_pad := InputEventJoypadButton.new()
    grow_pad.pressed = true
    grow_pad.button_index = JOY_BUTTON_Y
    ui._input(grow_pad)
    _check(ui.text_scale_index == 2 and ui.larger_text_button.disabled,
            "controller Y reaches bounded largest readable size")
    ui._input(grow_pad)
    _check(ui.text_scale_index == 2, "controller cannot exceed text size cap")
    var shrink_pad := InputEventJoypadButton.new()
    shrink_pad.pressed = true
    shrink_pad.button_index = JOY_BUTTON_X
    ui._input(shrink_pad)
    _check(ui.text_scale_index == 1, "controller X reduces text size")
    var shrink_key := InputEventKey.new()
    shrink_key.pressed = true
    shrink_key.ctrl_pressed = true
    shrink_key.physical_keycode = KEY_MINUS
    ui._input(shrink_key)
    _check(ui.text_scale_index == 0
            and ui.cards[0].get_theme_font_size("font_size") == base_card_font,
            "Ctrl+- restores original font size without mouse")
    var grow_key := InputEventKey.new()
    grow_key.pressed = true
    grow_key.ctrl_pressed = true
    grow_key.physical_keycode = KEY_EQUAL
    ui._input(grow_key)
    _check(ui.text_scale_index == 1, "Ctrl+= enlarges journal text")
    ui.smaller_text_button.pressed.emit()
    _check(ui.text_scale_index == 0 and ui.smaller_text_button.disabled,
            "A− button returns to bounded minimum")
    ui._layout_for_width(360.0)
    _check(is_equal_approx(ui.panel.anchor_left, 0.02)
            and is_equal_approx(ui.panel.anchor_right, 0.98)
            and ui.history_text.custom_minimum_size.y == 95.0,
            "simulated 360px viewport uses narrow-screen margins and compact history")
    ui._layout_for_width(1280.0)
    _check(is_equal_approx(ui.panel.anchor_left, 0.04)
            and is_equal_approx(ui.panel.anchor_right, 0.96)
            and ui.history_text.custom_minimum_size.y == 125.0,
            "simulated desktop viewport restores normal margins and history")
    _check(village.save_state() == saved_before and host.gold == gold_before
            and host.inventory == inventory_before,
            "accessibility and responsive layout never alter social or economic state")

    _check(ui.cards.size() == 6 and ui.cards[0].focus_mode == Control.FOCUS_ALL, "six focusable neighbor cards")
    _check(ui.selected_index == 0 and "Mira" in ui.selected_label.text, "first neighbor initially selected")
    _check(ui.history_text.focus_mode == Control.FOCUS_ALL and ui.history_text.scroll_active, "history is focusable and scrollable")
    _check(ui.history_earlier_button.focus_mode == Control.FOCUS_ALL and ui.history_later_button.focus_mode == Control.FOCUS_ALL, "history pagination is keyboard and controller focusable")
    _check(ui.history_page_label.text == "Page 1 of 1" and ui.history_earlier_button.disabled and ui.history_later_button.disabled, "two earned lines fit one bounded page")
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
    _check("Ampliar texto" in ui.larger_text_button.tooltip_text
            and "Reducir texto" in ui.smaller_text_button.tooltip_text,
            "Spanish readable-size help remains localized")
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
    # V19 earned-history pagination: twelve genuine records become four pages,
    # defaulting to the newest three. Every route is presentation-only.
    var paged = restored.social_journal
    var state_before_paging: Dictionary = restored.save_state()
    paged.open_journal()
    _check(paged.history_page_label.text == "Page 4 of 4", "journal opens on most recent of four history pages")
    _check("Day %d [en]" % int(final_log[-1]["epoch"]) in paged.history_text.text, "latest earned conversation visible")
    _check("Day %d [en]" % int(final_log[0]["epoch"]) not in paged.history_text.text, "oldest retained line not duplicated on latest page")
    _check(not paged.history_earlier_button.disabled and paged.history_later_button.disabled, "history page bounds update buttons")
    paged.history_earlier_button.pressed.emit()
    _check(paged.history_page_label.text == "Page 3 of 4", "touch/mouse earlier button pages history")
    paged._change_text_scale(1)
    _check(paged.history_page_label.text == "Page 3 of 4"
            and paged.history_page == 2 and paged.selected_index == 0,
            "readable-size change preserves earned-history page and resident")
    paged._change_text_scale(-1)
    var history_left := InputEventKey.new()
    history_left.pressed = true
    history_left.physical_keycode = KEY_LEFT
    paged._input(history_left)
    _check(paged.history_page_label.text == "Page 2 of 4", "keyboard Left pages older dialogue")
    var shoulder_left := InputEventJoypadButton.new()
    shoulder_left.pressed = true
    shoulder_left.button_index = JOY_BUTTON_LEFT_SHOULDER
    paged._input(shoulder_left)
    _check(paged.history_page_label.text == "Page 1 of 4" and paged.history_earlier_button.disabled, "controller left shoulder clamps at oldest page")
    paged._input(shoulder_left)
    _check(paged.history_page_label.text == "Page 1 of 4", "history cannot page before first record")
    var history_right := InputEventKey.new()
    history_right.pressed = true
    history_right.physical_keycode = KEY_RIGHT
    paged._input(history_right)
    _check(paged.history_page_label.text == "Page 2 of 4", "keyboard Right pages newer dialogue")
    var shoulder_right := InputEventJoypadButton.new()
    shoulder_right.pressed = true
    shoulder_right.button_index = JOY_BUTTON_RIGHT_SHOULDER
    paged._input(shoulder_right)
    _check(paged.history_page_label.text == "Page 3 of 4", "controller right shoulder pages newer dialogue")
    paged._toggle_locale()
    _check(paged.history_page_label.text == "Página 3 de 4" and paged.history_earlier_button.text == "Anteriores", "Spanish labels preserve history page")
    paged._select_neighbor(1)
    _check(paged.history_page_label.text == "Página 0 de 0" and paged.history_earlier_button.disabled and paged.history_later_button.disabled, "empty resident has no fabricated pages")
    paged._select_neighbor(0)
    _check(paged.history_page_label.text == "Página 4 de 4", "returning to neighbor defaults to newest history")
    paged._toggle_locale()
    paged.close_journal()
    _check(restored.save_state() == state_before_paging, "history paging and locale never change social state")
    _check(host.gold == gold_before and host.inventory == inventory_before, "history pagination never changes economy")
    var retained_state: Dictionary = restored.save_state()
    var valid_envelope: Dictionary = {
        "schema":1, "year":host.year, "season":host.season_index, "day":host.day,
        "minute":host.minute_of_day, "gold":host.gold, "energy":host.energy,
        "inventory":host.inventory.duplicate(true), "farm":[],
        "village":retained_state.duplicate(true), "animals":{},
        "hero_position":[0.0, 0.0, 0.0]
    }
    _check(SaveService.validate_payload(valid_envelope), "central schema-1 boundary admits authentic bounded transcript")
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
