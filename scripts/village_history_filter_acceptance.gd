extends SceneTree
## V19: assembled Godot game; filter only authentic saved conversations.
## Input events are synthetic. No physical device or frame-time claim.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("V19 HISTORY FILTER FAILED: " + label)

func _talk(game, year: int, day: int, locale: String) -> String:
    game.year = year
    game.season_index = 0
    game.day = day
    game.minute_of_day = 600.0
    game.weather = "Clear"
    game.village.set_dialogue_locale(locale)
    game.village.sync_schedule(true)
    game.hero.global_position = game.village.residents[0]["node"].global_position + Vector3(0, 1, 0)
    return game.village.act("talk", game.hero.global_position)

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
    var ui = village.social_journal
    _check(ui != null and ui.history_filter_button != null, "assembled game exposes history language filter")
    _check(ui.history_filter_button.focus_mode == Control.FOCUS_ALL
            and ui.history_filter_button.custom_minimum_size.y >= 44.0,
            "filter is focusable with 44-pixel touch target")
    _check(ui.history_filter_index == 0, "default filter shows all historical languages")
    _check(ui.HISTORY_FILTERS.size() == 3, "three bounded filter modes")

    # Twelve genuine player conversations, six in each original language,
    # spanning the 56-day-year boundary; no test-injected dialogue entries.
    for year in [1, 2]:
        for day in range(1, 7):
            var locale: String = "en" if day % 2 == 1 else "es"
            _check("Mira:" in _talk(game, year, day, locale),
                    "real player conversation year %d day %d" % [year, day])
    var actual: Array = village.social_recap()[0]["dialogue_log"]
    _check(actual.size() == 12 and int(actual[0]["epoch"]) == 1
            and int(actual[-1]["epoch"]) == 62,
            "twelve genuine bounded transcripts span year rollover")
    # The last authentic talk was in Spanish; select English UI independently
    # before asserting English presentation labels. Do not rewrite transcripts.
    village.set_dialogue_locale("en")
    var before_save: Dictionary = village.save_state()
    game.save_game(false)
    village.memories["mira"]["dialogue_log"].clear()
    game.load_game()
    _check(game.latest_message == "Loaded saved life in the valley.",
            "actual assembled-game save reload succeeds")
    _check(village.save_state() == before_save,
            "full save roundtrip preserves every nested village field")
    var baseline: Dictionary = village.save_state()
    var gold: int = game.gold
    var energy: float = game.energy
    var restoration: int = game.restoration
    var inventory: Dictionary = game.inventory.duplicate(true)

    ui.open_journal()
    _check(ui.panel.visible and paused, "journal pauses game before filtering")
    _check(ui.history_filter_button.text == "All (12)"
            and ui.history_page_label.text == "Page 4 of 4",
            "unfiltered journal preserves established newest-page behavior")
    _check("Day 62 [es]" in ui.history_text.text,
            "latest genuine conversation appears without filtering")

    ui.history_filter_button.pressed.emit()
    _check(ui.history_filter_index == 1
            and ui.history_filter_button.text == "English (6)",
            "mouse/touch filter selects only English records")
    _check(ui.history_page_label.text == "Page 2 of 2"
            and "Day 61 [en]" in ui.history_text.text
            and "[es]" not in ui.history_text.text,
            "English history is paginated and excludes Spanish lines")
    ui.history_earlier_button.pressed.emit()
    _check(ui.history_page_label.text == "Page 1 of 2"
            and "Day 1 [en]" in ui.history_text.text,
            "filtered earlier page shows original first English line")
    ui._input(_key(KEY_F))
    _check(ui.history_filter_index == 2
            and ui.history_filter_button.text == "Español (6)"
            and "Day 62 [es]" in ui.history_text.text
            and "[en]" not in ui.history_text.text,
            "keyboard F selects Spanish-only latest page")
    ui._input(_pad(JOY_BUTTON_DPAD_LEFT))
    _check(ui.history_filter_index == 0
            and ui.history_filter_button.text == "All (12)"
            and ui.history_page_label.text == "Page 4 of 4",
            "controller D-pad Left cycles back to full history")
    ui.history_filter_button.pressed.emit()
    ui._toggle_locale()
    _check(village.dialogue_locale == "es"
            and ui.history_filter_index == 1
            and ui.history_filter_button.text == "Inglés (6)"
            and ui.history_page_label.text == "Página 2 de 2",
            "switching interface locale preserves provenance filter and pagination")
    ui._select_neighbor(1)
    _check(ui.history_page_label.text == "Página 0 de 0"
            and ui.history_text.text == "ninguno"
            and ui.history_filter_button.text == "Inglés (0)",
            "resident with no conversations has no invented filtered history")
    ui._select_neighbor(0)
    _check(ui.history_page_label.text == "Página 2 de 2",
            "returning to resident selects latest matching history")
    ui._layout_for_width(360.0)
    _check(is_equal_approx(ui.panel.anchor_left, 0.02) and ui.history_filter_button.custom_minimum_size.y >= 44.0,
            "narrow simulated viewport retains filter control")
    ui._change_text_scale(1)
    _check(ui.text_scale_index == 1 and ui.history_filter_index == 1,
            "text scaling preserves active language filter")
    ui.close_journal()
    _check(not paused and not ui.panel.visible, "journal closes and restores gameplay pause")
    var closed_filter: int = ui.history_filter_index
    ui._cycle_history_filter()
    _check(ui.history_filter_index == closed_filter,
            "closed journal cannot change filter through direct shortcut")
    _check(village.save_state() == baseline,
            "filter, locale, resident selection and pagination never mutate Village")
    _check(game.gold == gold and is_equal_approx(game.energy, energy)
            and game.restoration == restoration and game.inventory == inventory,
            "all filter input routes conserve money, energy, restoration and items")
    print("EVERBLOOM V19 HISTORY FILTER NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
