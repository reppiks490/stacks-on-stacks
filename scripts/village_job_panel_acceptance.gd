extends SceneTree
## Native assembled-Game V07 acceptance: same shift through touch/click signal,
## controller X and Principal's keyboard K; exact once/day and save recovery.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("V07 WORK UI FAILED: " + label)

func _at_mira(game) -> void:
    game.village.sync_schedule(true)
    game.hero.global_position = game.village.residents[0]["node"].global_position + Vector3(0, 1, 0)

func _run() -> void:
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    var village = game.village
    var ui = village.job_panel
    _check(ui != null and ui.work_button != null, "work action created in assembled Godot Game")
    _check(ui.work_button.custom_minimum_size.y >= 44.0, "touch target at least 44 px")
    _check(ui.work_button.focus_mode == Control.FOCUS_ALL, "button focusable without mouse")
    _check("K" in ui.work_button.text, "visible existing keyboard shortcut")
    _check(village.social_journal.layer > ui.layer, "modal journal is above work action")
    _check(ui.last_result.is_empty(), "no fabricated work history on startup")

    game.minute_of_day = 600.0
    game.weather = "Clear"
    _at_mira(game)
    var before_gold: int = game.gold
    var before_energy: float = game.energy
    var before_restoration: int = game.restoration
    var before_inventory: Dictionary = game.inventory.duplicate(true)
    # Button signal is the same path a real pointer/touch activation uses.
    ui.work_button.pressed.emit()
    _check("Helped Mira" in ui.last_result and "Earned 24 petals" in ui.last_result,
            "on-screen action reports actual paid shift")
    _check(game.latest_message == ui.last_result, "HUD receives identical action feedback")
    _check(game.gold == before_gold + 24, "button pays one authoritative shift")
    _check(is_equal_approx(game.energy, before_energy - 12.0), "button charges 12 energy once")
    _check(game.restoration == before_restoration + 1, "one restoration point credited")
    _check(int(village.memories["mira"]["jobs"]) == 1, "work memory persisted in Village")
    _check(game.inventory == before_inventory, "work action cannot mint inventory")
    ui.work_button.pressed.emit()
    _check("already helped" in ui.last_result, "same-day duplicate button rejected")
    _check(game.gold == before_gold + 24 and is_equal_approx(game.energy, before_energy - 12.0),
            "duplicate button cannot mint money or spend energy")
    _check(int(village.memories["mira"]["jobs"]) == 1, "duplicate does not inflate job history")

    village.social_journal.open_journal()
    var blocked_gold: int = game.gold
    var blocked_energy: float = game.energy
    _check(get_tree().paused, "journal pauses game")
    _check(ui._perform_job().is_empty(), "work blocked while modal journal is open")
    _check(game.gold == blocked_gold and is_equal_approx(game.energy, blocked_energy),
            "modal cannot bypass payment or energy gates")
    village.social_journal.close_journal()
    _check(not get_tree().paused, "closing journal restores game pause state")

    game.year = 2
    game.season_index = 0
    game.day = 1
    game.minute_of_day = 600.0
    game.weather = "Clear"
    _at_mira(game)
    var controller := InputEventJoypadButton.new()
    controller.pressed = true
    controller.button_index = JOY_BUTTON_X
    var before_controller: int = game.gold
    ui._input(controller)
    _check(game.gold == before_controller + 24, "controller X pays one year-two shift")
    _check(int(village.memories["mira"]["jobs"]) == 2, "year rollover preserves separate work day")
    ui._input(controller)
    _check(game.gold == before_controller + 24, "controller X cannot repeat same-year shift")

    game.save_game(false)
    var saved_gold: int = game.gold
    var saved_energy: float = game.energy
    var saved_jobs: Dictionary = village.save_state()
    game.gold = 0
    game.energy = 0.0
    village.last_job.clear()
    game.load_game()
    _check(game.latest_message == "Loaded saved life in the valley.", "assembled save accepted and reloaded")
    _check(game.gold == saved_gold and is_equal_approx(game.energy, saved_energy),
            "full-game save roundtrip conserves money and energy")
    _check(village.save_state() == saved_jobs, "nested Village job history survives assembled reload")
    _at_mira(game)
    ui.work_button.pressed.emit()
    _check("already helped" in ui.last_result and game.gold == saved_gold,
            "reloaded same-day button cannot duplicate payout")

    game.day = 8
    game.minute_of_day = 600.0
    _at_mira(game)
    var key := InputEventKey.new()
    key.pressed = true
    key.physical_keycode = KEY_K
    var before_key: int = game.gold
    game._unhandled_input(key)
    _check(game.gold == before_key + 24, "Principal K route retains identical shift payout")
    _check(int(village.memories["mira"]["jobs"]) == 3, "keyboard shift counted once")

    game.day = 9
    game.minute_of_day = 600.0
    game.energy = 0.0
    _at_mira(game)
    var before_empty: int = game.gold
    ui._perform_job()
    _check("more energy" in ui.last_result, "exhausted player receives visible rejection")
    _check(game.gold == before_empty, "no pay when energy is insufficient")
    game.energy = 100.0
    game.hero.global_position = Vector3(500, 1, 500)
    ui._perform_job()
    _check("Visit a resident" in ui.last_result, "offsite player receives proximity feedback")
    _check(game.gold == before_empty, "offsite action cannot mint money")

    game.day = 3 # Mira's original weekly rest day (epoch 115).
    game.minute_of_day = 600.0
    _at_mira(game)
    ui._perform_job()
    _check("no work shift" in ui.last_result, "rest-day shifts rejected")
    _check(game.gold == before_empty, "rest-day denial conserves currency")
    game.day = 4
    game.minute_of_day = 750.0
    _at_mira(game)
    ui._perform_job()
    _check("no work shift" in ui.last_result, "lunch break shifts rejected")
    _check(game.gold == before_empty, "lunch denial conserves currency")

    village.set_dialogue_locale("es")
    ui._refresh_locale()
    _check("Ayudar" in ui.work_button.text, "work button follows journal locale selection")
    _check("mando" in ui.work_button.tooltip_text, "controller help localized in Spanish")
    _check(game.inventory == before_inventory, "all three input routes preserve inventory")
    print("EVERBLOOM V07 WORK UI NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
