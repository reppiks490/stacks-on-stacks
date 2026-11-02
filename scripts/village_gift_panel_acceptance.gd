extends SceneTree
## V06: native assembled-game explicit gift choice, two-year persistence,
## invalid selection rejection, modal gates and economy conservation.
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("V06 GIFT FAILED: " + label)

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

func _near(game) -> void:
    game.village.sync_schedule(true)
    game.hero.global_position = game.village.residents[0]["node"].global_position + Vector3(0, 1, 0)

func _run() -> void:
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    var village = game.village
    var ui = village.gift_panel
    _check(ui != null and ui.panel != null, "assembled game constructs real gift UI")
    _check(ui.gift_buttons.size() == 2, "two distinct choice buttons")
    _check(ui.opener.custom_minimum_size.y >= 44.0, "visible touch-sized opener")
    _check(ui.gift_buttons[0].custom_minimum_size.y >= 44.0, "touch-sized item choice")
    _check(ui.gift_buttons[1].focus_mode == Control.FOCUS_ALL, "controller focusable choice")
    _check(not ui.panel.visible, "gift modal starts closed")
    _check(village.residents.size() == 6, "existing residents preserved")
    game.minute_of_day = 600.0
    game.weather = "Clear"
    game.inventory["wild_herb"] = 3
    game.inventory["bluebell"] = 2
    _near(game)
    var gold_before: int = game.gold
    var energy_before: float = game.energy
    var restoration_before: int = game.restoration
    var initial_social: Dictionary = village.save_state()
    var initial_inventory: Dictionary = game.inventory.duplicate(true)

    var invalid: String = village.act("gift", game.hero.global_position, "stone")
    _check("does not accept" in invalid, "unapproved gift explicitly rejected")
    _check(game.inventory == initial_inventory and village.save_state() == initial_social,
            "invalid item cannot debit inventory or create social rewards")
    var unavailable: String = village.act("gift", game.hero.global_position, "milk")
    _check("does not accept" in unavailable, "another resident's favorite rejected")
    _check(game.inventory == initial_inventory, "unapproved gift cannot mint or consume items")

    ui.opener.pressed.emit()
    _check(ui.panel.visible and paused, "pointer/touch opener pauses assembled world")
    _check(ui.active_resident_id == "mira", "real proximity selects Mira")
    _check(ui.gift_ids == ["wild_herb", "bluebell"], "stable authored preferred/favorite order")
    _check("favorite" in ui.gift_buttons[1].text and "2" in ui.gift_buttons[1].text,
            "favorite choice shows authentic available count")
    _check("preferred" in ui.gift_buttons[0].text and "3" in ui.gift_buttons[0].text,
            "alternative gift displays inventory count")
    _check(village.save_state() == initial_social and game.inventory == initial_inventory,
            "opening picker is read-only")
    village.set_dialogue_locale("es")
    ui._refresh_locale()
    _check("favorito" in ui.gift_buttons[1].text and "regalo" in ui.title_label.text,
            "live gift choice labels localize to Spanish")
    _check(game.inventory == initial_inventory, "locale switch cannot consume items")
    village.set_dialogue_locale("en")
    ui._refresh_locale()
    ui.gift_buttons[1].pressed.emit()
    _check(not ui.panel.visible and not paused, "favorite selection closes and unpauses")
    _check("treasured favorite" in ui.last_result.to_lower(), "favorite choice gets specific feedback")
    _check(int(game.inventory["bluebell"]) == 1 and int(game.inventory["wild_herb"]) == 3,
            "only explicitly selected favorite consumed")
    _check(int(village.affection["mira"]) == 18, "favorite grants exactly 18 friendship")
    _check(game.restoration == restoration_before + 2, "one restoration grant")
    _check(int(village.memories["mira"]["gifts"]) == 1, "one authentic gift memory")
    _check(str(village.memories["mira"]["last_gift_item"]) == "bluebell",
            "favorite identity stored in existing memory")
    _check(game.gold == gold_before and is_equal_approx(game.energy, energy_before),
            "gift does not alter money or energy")
    var blocked_inventory: Dictionary = game.inventory.duplicate(true)
    var blocked_social: Dictionary = village.save_state()
    _check("One gift each day" in village.act("gift", game.hero.global_position, "wild_herb"),
            "same-day second gift denied")
    _check(game.inventory == blocked_inventory and village.save_state() == blocked_social,
            "same-day duplicate cannot consume second item or inflate memory")

    game.day = 2
    _near(game)
    ui._input(_key(KEY_V))
    _check(ui.panel.visible and paused, "keyboard V opens gift picker")
    ui._input(_key(KEY_1))
    _check(not ui.panel.visible and not paused, "keyboard 1 selects first item")
    _check(int(game.inventory["wild_herb"]) == 2 and int(game.inventory["bluebell"]) == 1,
            "preferred choice debits only wild herb")
    _check(int(village.affection["mira"]) == 30 and int(village.memories["mira"]["gifts"]) == 2,
            "preferred gift adds 12 friendship and one memory")
    _check(village.memories["mira"]["last_gift_favorite"] == false,
            "preferred versus favorite intent retained")

    game.day = 3
    _near(game)
    var spoken: String = village.act("talk", game.hero.global_position)
    _check("wild_herb" in spoken, "resident recalls selected preferred gift later")
    _check(int(village.memories["mira"]["recalled_gift_epoch"]) == 3,
            "recollection uses monotonic day, not gift day")
    game.save_game(false)
    var saved_inventory: Dictionary = game.inventory.duplicate(true)
    var saved_social: Dictionary = village.save_state()
    var saved_restoration: int = game.restoration
    var saved_gold: int = game.gold
    game.inventory["wild_herb"] = 999
    game.inventory["bluebell"] = 999
    village.affection["mira"] = 0
    game.load_game()
    _check(game.latest_message == "Loaded saved life in the valley.",
            "central save validator admits actual gift history")
    # JSON may decode whole-number values as floats. Compare item quantities,
    # not Variant numeric subtypes, and reject newly minted positive keys.
    var items_conserved: bool = true
    for item in saved_inventory:
        if int(game.inventory.get(item, -1)) != int(saved_inventory[item]):
            items_conserved = false
    for item in game.inventory:
        if not saved_inventory.has(item) and int(game.inventory[item]) != 0:
            items_conserved = false
    _check(items_conserved, "full-game JSON reload restores every item quantity")
    _check(village.save_state() == saved_social, "nested gift history survives assembled reload")
    _check(game.restoration == saved_restoration and game.gold == saved_gold,
            "full-game reload cannot mint money or restoration")
    _check(int(village.memories["mira"]["recalled_gift_epoch"]) == 3,
            "remembered choice and recollection survive reload")

    game.year = 2
    game.season_index = 0
    game.day = 1
    game.minute_of_day = 600.0
    game.weather = "Clear"
    _near(game)
    var year_two_epoch: int = game.day_epoch()
    _check(year_two_epoch == 57, "year-two epoch is 57 in 56-day calendar")
    var before_controller: int = int(game.inventory["bluebell"])
    ui._input(_pad(JOY_BUTTON_DPAD_RIGHT))
    _check(ui.panel.visible and paused, "controller D-pad Right opens picker")
    ui.gift_buttons[1].grab_focus()
    ui._input(_pad(JOY_BUTTON_A))
    _check(not ui.panel.visible and not paused, "controller A confirms focused favorite")
    _check(int(game.inventory["bluebell"]) == before_controller - 1,
            "controller selected favorite rather than stale first option")
    _check(int(village.affection["mira"]) == 52 and int(village.memories["mira"]["gifts"]) == 3,
            "year-two gift is separately earned")
    _check(int(village.memories["mira"]["last_gift_epoch"]) == year_two_epoch,
            "gift memory uses year-two monotonic epoch")
    var before_repeat: Dictionary = game.inventory.duplicate(true)
    ui.open_gifts()
    ui.gift_buttons[0].pressed.emit()
    _check("One gift each day" in ui.last_result, "same-year repeat through button rejected")
    _check(game.inventory == before_repeat, "repeat through button cannot duplicate consumption")

    game.day = 2
    game.inventory["wild_herb"] = 0
    game.inventory["bluebell"] = 0
    _near(game)
    var before_empty_social: Dictionary = village.save_state()
    ui.open_gifts()
    _check(ui.panel.visible and ui.gift_buttons[0].disabled and ui.gift_buttons[1].disabled,
            "empty inventory visibly disables both choices")
    _check("no preferred gifts" in ui.last_result, "empty inventory gives readable feedback")
    ui._input(_pad(JOY_BUTTON_A))
    _check(not ui.panel.visible, "controller confirm on focused cancel exits without gifting")
    _check(village.save_state() == before_empty_social,
            "empty-inventory cancel never creates relationship progress")
    game.inventory["wild_herb"] = 1
    _near(game)
    ui.open_gifts()
    game.hero.global_position = Vector3(500, 1, 500)
    var before_away: Dictionary = village.save_state()
    var before_away_items: Dictionary = game.inventory.duplicate(true)
    ui._choose_index(0)
    _check("no longer close" in ui.last_result, "moving away during modal invalidates choice")
    _check(village.save_state() == before_away and game.inventory == before_away_items,
            "stale proximity cannot debit or reward")
    _near(game)
    village.social_journal.open_journal()
    _check(paused, "social journal holds modal pause")
    ui._input(_pad(JOY_BUTTON_DPAD_RIGHT))
    _check(not ui.panel.visible, "controller gift shortcut cannot hijack journal navigation")
    ui.open_gifts()
    _check(not ui.panel.visible, "gift picker cannot open over social journal")
    village.social_journal.close_journal()
    village.topic_panel.open_topics()
    _check(village.topic_panel.panel.visible, "conversation picker owns separate modal")
    ui.open_gifts()
    _check(not ui.panel.visible, "gift picker cannot open over conversation picker")
    village.topic_panel.close_topics()
    _check(not paused, "modal gates restore original pause state")

    # Existing keyboard G remains backward-compatible and uses original
    # first-preferred automatic selection, never an invented second reward.
    game.day = 3
    game.minute_of_day = 600.0
    _near(game)
    var before_legacy: int = int(game.inventory["wild_herb"])
    game._unhandled_input(_key(KEY_G))
    _check(int(game.inventory["wild_herb"]) == before_legacy - 1,
            "existing G action still performs historical automatic gift")
    _check(int(village.memories["mira"]["gifts"]) == 4,
            "legacy G and explicit choice share authoritative gift counter")
    _check(game.gold == gold_before and is_equal_approx(game.energy, energy_before),
            "all gift input routes conserve gold and energy")
    print("EVERBLOOM V06 GIFT NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
