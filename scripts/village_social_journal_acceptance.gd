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

    host.minute_of_day = 600.0
    village.sync_schedule(true)
    var position: Vector3 = village.residents[0]["node"].global_position
    _check("Earned 24 petals" in village.act("job", position), "real job prerequisite")
    host.inventory["wild_herb"] = 0
    _check("treasured favorite" in village.act("gift", position).to_lower(), "real gift prerequisite")
    _check("Mira:" in village.act("talk", position), "real conversation prerequisite")
    var after: Array = village.social_recap()
    _check(int(after[0]["jobs"]) == 1 and int(after[0]["gifts"]) == 1 and int(after[0]["talks"]) == 1, "recap reflects earned actions")
    _check(str(after[0]["last_gift_item"]) == "bluebell", "recap reflects actual last gift")
    _check(int(after[0]["friendship"]) == 22, "recap reads authoritative friendship")

    host.day = 7
    host.minute_of_day = 1100.0
    village.sync_schedule(true)
    _check("Seed Lantern Walk" in village.act("talk", Vector3(31, 0, 4)), "real festival visit")
    _check(int(village.social_recap()[0]["festivals"]) == 1, "recap includes festival memory")
    var gold_before: int = host.gold
    var inventory_before: Dictionary = host.inventory.duplicate(true)
    var saved_before: Dictionary = village.save_state()

    ui.open_journal()
    _check(ui.panel.visible and not ui.opener.visible, "opening shows journal, hides opener")
    _check(paused, "open journal pauses game calendar and movement")
    _check("Mira" in ui.rendered_text and "bluebell" in ui.rendered_text, "visible recap includes actual person and gift")
    _check("Festival visits: 1" in ui.rendered_text, "visible festival recap")
    _check(ui.entries.get_child_count() == 6, "six scrollable recap sections")
    _check(village.save_state() == saved_before, "opening UI never changes saved social state")
    _check(host.gold == gold_before and host.inventory == inventory_before, "opening UI cannot mint or spend goods")
    ui.close_journal()
    _check(not paused and not ui.panel.visible and ui.opener.visible, "closing resumes game")

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
    _check(host.gold == gold_before and host.inventory == inventory_before, "reload recap has zero economy effects")
    restored.social_journal.close_journal()
    _check(not paused, "journal leaves scene unpaused")
    print("EVERBLOOM VILLAGE JOURNAL NATIVE: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
