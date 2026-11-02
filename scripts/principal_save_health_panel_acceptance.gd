extends SceneTree
## P05/P11 native assembled-game test; isolated empty XDG_DATA_HOME only.
const SaveService = preload("res://scripts/save_service.gd")
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    assertions += 1
    if not ok:
        failures += 1
        push_error("PRINCIPAL SAVE UI FAIL: " + reason)

func _write_raw(path: String, value: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(value)
    file.flush()
    var status: Error = file.get_error()
    file.close()
    return status == OK

func _key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.pressed = true
    event.physical_keycode = code
    return event

func _joy(code: JoyButton) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.pressed = true
    event.button_index = code
    return event

func _run() -> void:
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(false, "refuse pre-existing save: " + path)
            quit(1)
            return
    var lock_path: String = ProjectSettings.globalize_path(SaveService.WRITE_LOCK_PATH)
    if DirAccess.dir_exists_absolute(lock_path):
        _check(false, "refuse pre-existing writer lock")
        quit(1)
        return
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    var ui = game.save_health_panel
    _check(ui != null and ui.panel != null, "panel exists in assembled Game")
    _check(ui.layer > game.hud.layer, "modal above HUD")
    _check(ui.title_label.text == "Valley Save Health", "English title visible")
    _check(ui.report_scroll is ScrollContainer, "long report has scroll container")
    _check(ui.report_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
           "touch and wheel can scroll report")
    _check(ui.report_scroll.follow_focus, "focus navigation follows scroll")
    _check(ui.report_scroll.focus_mode == Control.FOCUS_ALL, "scroll report keyboard/gamepad focusable")
    _check(ui.opener.custom_minimum_size.y >= 44.0, "touch opener 44px")
    _check(ui.refresh_button.custom_minimum_size.y >= 44.0, "touch refresh 44px")
    _check(ui.close_button.custom_minimum_size.y >= 44.0, "touch close 44px")
    _check(ui.opener.focus_mode == Control.FOCUS_ALL, "keyboard focusable")
    _check(not ui.is_open and not paused, "initially closed")
    # Exercise actual assembled Village overlay references, not a mock UI.
    # An overlapping modal can steal focus and restore an incorrect pause state.
    var topics = game.village.topic_panel
    _check(topics != null and topics.panel != null, "Village topic modal exists")
    if topics != null and topics.panel != null:
        topics.panel.show()
        _check(ui._blocked(), "visible topic modal blocks Save Health")
        ui._input(_key(KEY_Y))
        _check(not ui.is_open and not paused, "keyboard cannot stack over topics")
        ui.opener.pressed.emit()
        _check(not ui.is_open and not paused, "touch cannot stack over topics")
        topics.panel.hide()
    var journal = game.village.social_journal
    _check(journal != null and journal.panel != null, "Village journal modal exists")
    if journal != null and journal.panel != null:
        journal.panel.show()
        _check(ui._blocked(), "visible social journal blocks Save Health")
        ui._input(_joy(JOY_BUTTON_START))
        _check(not ui.is_open and not paused, "controller cannot stack over journal")
        journal.panel.hide()
    paused = true
    _check(ui._blocked(), "independent paused session blocks modal stacking")
    ui._input(_joy(JOY_BUTTON_START))
    _check(not ui.is_open and paused, "blocked controller does not unpause session")
    paused = false
    _check(not ui._blocked(), "normal unpaused valley permits inspection")
    var initial_gold: int = game.gold
    var initial_items: Dictionary = game.inventory.duplicate(true)
    var initial_epoch: int = game.day_epoch()
    ui._input(_key(KEY_Y))
    _check(ui.is_open and paused, "keyboard Y opens and pauses")
    _check(ui.last_report.get("selected_source") == "none", "empty save explicitly reported")
    _check("No valid save" in ui.report_label.text, "player sees missing-save warning")
    _check("not present" in ui.report_label.text and "none" in ui.report_label.text,
           "empty slots use readable labels")
    # Force genuine report overflow in the assembled scene, rather than
    # mistaking a no-op scroll on a short report for controller coverage.
    var original_report: String = ui.report_label.text
    ui.report_label.text = ("Long recovery diagnostic line.\n").repeat(80)
    await process_frame
    await process_frame
    var scroll_bar: VScrollBar = ui.report_scroll.get_v_scroll_bar()
    _check(scroll_bar.max_value > scroll_bar.page, "long report genuinely overflows")
    ui._input(_key(KEY_PAGEDOWN))
    _check(ui.report_scroll.scroll_vertical > 0, "PageDown scrolls open report")
    var first_scroll: int = ui.report_scroll.scroll_vertical
    ui._input(_joy(JOY_BUTTON_RIGHT_SHOULDER))
    _check(ui.report_scroll.scroll_vertical > first_scroll, "controller RB scrolls farther")
    var second_scroll: int = ui.report_scroll.scroll_vertical
    ui._input(_key(KEY_PAGEUP))
    _check(ui.report_scroll.scroll_vertical < second_scroll, "PageUp scrolls backward")
    ui._input(_joy(JOY_BUTTON_LEFT_SHOULDER))
    _check(ui.report_scroll.scroll_vertical == 0, "controller LB returns to report start")
    ui.refresh_button.pressed.emit()
    _check(ui.last_report.get("selected_source") == "none", "touch refresh read-only")
    _check(ui.report_label.text == original_report, "refresh restores authoritative report after overflow")
    _check(ui.report_scroll.scroll_vertical == 0, "refresh resets scroll position")
    ui._input(_joy(JOY_BUTTON_B))
    _check(not ui.is_open and not paused, "controller B restores pause")
    game.save_game(false)
    _check(FileAccess.file_exists(SaveService.SAVE_PATH), "actual Game creates valid primary")
    game.gold += 7
    game.save_game(false)
    var primary_bytes: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
    var backup_bytes: String = FileAccess.get_file_as_string(SaveService.BACKUP_PATH)
    _check(not primary_bytes.is_empty() and not backup_bytes.is_empty(), "two real save generations")
    ui.opener.pressed.emit()
    _check(ui.is_open and ui.last_report.get("selected_source") == "primary", "touch opens healthy report")
    _check("Primary is readable" in ui.report_label.text, "healthy status visible")
    _check("Primary save: healthy" in ui.report_label.text,
           "healthy primary is translated from diagnostic code")
    game._unhandled_input(_key(KEY_P))
    game.save_game(false)
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == primary_bytes and
           FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == backup_bytes,
           "modal prevents keyboard save and preserves bytes")
    ui.close_button.pressed.emit()
    _check(not ui.is_open and not paused, "touch closes modal")
    _check(_write_raw(SaveService.SAVE_PATH, "{torn"), "inject corrupt primary in isolated profile")
    var damaged_bytes: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
    ui._input(_joy(JOY_BUTTON_START))
    _check(ui.is_open and paused, "controller Start opens modal")
    _check(ui.last_report.get("selected_source") == "backup", "backup selected after torn primary")
    var before_blocked_load: int = game.gold
    game.load_game()
    _check(game.gold == before_blocked_load, "direct load blocked while inspecting")
    _check("older progress" in ui.report_label.text, "backup age uncertainty visible")
    _check("damaged file" in ui.report_label.text and
           "malformed_json" not in ui.report_label.text,
           "corrupt primary shown as readable warning without machine token")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == damaged_bytes and
           FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == backup_bytes,
           "inspection never modifies forensic save bytes")
    _check(DirAccess.make_dir_absolute(lock_path) == OK, "create test-only lock")
    ui.refresh_button.pressed.emit()
    _check(bool(ui.last_report.get("writer_lock_present", false)), "writer lock displayed")
    _check("never delete a lock" in ui.report_label.text, "no unsafe auto-unlock advice")
    _check("Writer lock: present" in ui.report_label.text, "lock status readable")
    _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == damaged_bytes and
           FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == backup_bytes,
           "locked refresh preserves bytes")
    _check(DirAccess.remove_absolute(lock_path) == OK, "remove test-created lock only")
    ui._input(_key(KEY_ESCAPE))
    _check(not ui.is_open and not paused, "Escape restores simulation")
    game.village.set_dialogue_locale("es")
    ui._refresh_locale()
    _check("Estado" in ui.opener.text, "Spanish control text")
    _check("Estado de guardado del valle" == ui.title_label.text,
           "Spanish modal title")
    _check(ui._human_status("invalid_payload") == "datos de guardado inválidos",
           "invalid payload code translated")
    _check(ui._human_status("unreadable") == "no se puede leer el archivo",
           "unreadable status translated")
    _check(ui._human_status("unrecognized_new_code") == "estado desconocido",
           "unknown future code safely translated")
    ui.opener.pressed.emit()
    _check("progreso anterior" in ui.report_label.text, "Spanish recovery explanation")
    _check("archivo dañado" in ui.report_label.text and
           "malformed_json" not in ui.report_label.text,
           "Spanish corruption warning has no raw code")
    _check("Bloqueo de escritura: ausente" in ui.report_label.text,
           "Spanish absent lock label")
    _check("Desplazar informe" in ui.report_label.text, "Spanish controller/keyboard scroll guidance")
    ui.close_button.pressed.emit()
    _check(game.gold == initial_gold + 7 and game.inventory == initial_items and
           game.day_epoch() == initial_epoch, "UI conserves economy, inventory and epoch")
    for path: String in [SaveService.SAVE_PATH, SaveService.BACKUP_PATH, SaveService.TEMP_PATH]:
        if FileAccess.file_exists(path):
            _check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
                   "remove isolated test artifact " + path)
    print("PRINCIPAL SAVE UI: %d assertions, %d failures" % [assertions, failures])
    quit(0 if failures == 0 else 1)
