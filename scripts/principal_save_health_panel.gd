extends CanvasLayer
## Read-only player presentation of SaveService diagnostics. No write or recovery APIs.
const SaveService = preload("res://scripts/save_service.gd")
var game
var opener: Button
var panel: PanelContainer
var report_label: Label
var refresh_button: Button
var close_button: Button
var last_report: Dictionary = {}
var is_open: bool = false
var paused_before_open: bool = false
var locale: String = "en"

func _t(en: String, es: String) -> String:
    return es if locale == "es" else en

func setup(owner) -> void:
    game = owner
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    var surface := Control.new()
    surface.name = "SaveHealthSurface"
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(surface)
    opener = Button.new()
    opener.name = "OpenSaveHealth"
    opener.anchor_left = 1.0
    opener.anchor_right = 1.0
    opener.offset_left = -200.0
    opener.offset_right = -12.0
    opener.offset_top = 200.0
    opener.offset_bottom = 248.0
    opener.custom_minimum_size.y = 48.0
    opener.focus_mode = Control.FOCUS_ALL
    opener.pressed.connect(toggle_panel)
    surface.add_child(opener)
    panel = PanelContainer.new()
    panel.name = "SaveHealthPanel"
    panel.anchor_left = 0.10
    panel.anchor_top = 0.15
    panel.anchor_right = 0.90
    panel.anchor_bottom = 0.85
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.11, 0.13, 0.97)
    style.border_color = Color(0.66, 0.81, 0.68)
    style.set_border_width_all(2)
    style.set_content_margin_all(16)
    panel.add_theme_stylebox_override("panel", style)
    surface.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    var title := Label.new()
    title.name = "SaveHealthTitle"
    title.text = "Valley Save Health"
    title.add_theme_font_size_override("font_size", 24)
    column.add_child(title)
    report_label = Label.new()
    report_label.name = "SaveHealthReport"
    report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    report_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(report_label)
    var row := HBoxContainer.new()
    column.add_child(row)
    refresh_button = Button.new()
    refresh_button.name = "RefreshSaveHealth"
    refresh_button.custom_minimum_size.y = 44.0
    refresh_button.focus_mode = Control.FOCUS_ALL
    refresh_button.pressed.connect(refresh_report)
    row.add_child(refresh_button)
    close_button = Button.new()
    close_button.name = "CloseSaveHealth"
    close_button.custom_minimum_size.y = 44.0
    close_button.focus_mode = Control.FOCUS_ALL
    close_button.pressed.connect(close_panel)
    row.add_child(close_button)
    panel.hide()
    _refresh_locale()

func _refresh_locale() -> void:
    locale = "es" if game != null and game.village != null and str(game.village.dialogue_locale) == "es" else "en"
    opener.text = _t("Save Health [Y]", "Estado de guardado [Y]")
    refresh_button.text = _t("Refresh inspection", "Actualizar inspección")
    close_button.text = _t("Return to valley", "Volver al valle")
    if not last_report.is_empty():
        report_label.text = _format_report(last_report)

func _format_report(report: Dictionary) -> String:
    var lines: Array[String] = []
    lines.append(_t("Primary save: ", "Guardado principal: ") + str(report.get("primary_status", "unknown")))
    lines.append(_t("Recovery backup: ", "Copia de recuperación: ") + str(report.get("backup_status", "unknown")))
    lines.append(_t("Interrupted temporary: ", "Archivo temporal: ") + str(report.get("temp_status", "unknown")))
    lines.append(_t("Load source: ", "Fuente de carga: ") + str(report.get("selected_source", "none")))
    lines.append(_t("Writer lock: ", "Bloqueo de escritura: ") + str(report.get("writer_lock_present", false)))
    lines.append(_t("Preserved corrupt files: ", "Archivos dañados conservados: ") + "%d / %d" % [
        int(report.get("quarantine_occupied", 0)), int(report.get("quarantine_capacity", 0))]
    if bool(report.get("writer_lock_present", false)):
        lines.append(_t("Saving blocked. Close other instances; never delete a lock while a writer may be active.",
                        "Guardado bloqueado. Cierra otras instancias; nunca borres un bloqueo activo."))
    match str(report.get("selected_source", "none")):
        "primary":
            lines.append(_t("Primary is readable; power-loss durability is not guaranteed.",
                            "El guardado principal es legible; no se garantiza resistencia a cortes de energía."))
        "backup":
            lines.append(_t("Backup available; loading may restore older progress. Inspect before saving.",
                            "Copia disponible; puede recuperar progreso anterior. Inspecciona antes de guardar."))
        _:
            lines.append(_t("No valid save. Loading cannot recover progress; current session is untouched.",
                            "No hay guardado válido. La sesión actual permanece intacta."))
    if str(report.get("temp_status", "missing")) != "missing":
        lines.append(_t("Temporary file is NOT an authoritative save.",
                        "El archivo temporal NO es un guardado autorizado."))
    return "\n".join(lines)

func refresh_report() -> void:
    last_report = SaveService.inspect_save_health()
    report_label.text = _format_report(last_report)

func _blocked() -> bool:
    if game == null or game.village == null:
        return true
    var journal = game.village.social_journal
    return journal != null and journal.panel != null and journal.panel.visible

func open_panel() -> void:
    if is_open or _blocked():
        return
    paused_before_open = get_tree().paused
    refresh_report()
    panel.show()
    is_open = true
    opener.disabled = true
    get_tree().paused = true
    close_button.grab_focus()

func close_panel() -> void:
    if not is_open:
        return
    panel.hide()
    is_open = false
    get_tree().paused = paused_before_open
    opener.disabled = _blocked()
    opener.grab_focus()

func toggle_panel() -> void:
    if is_open:
        close_panel()
    else:
        open_panel()

func _process(_delta: float) -> void:
    if opener == null:
        return
    var desired: String = "es" if game != null and game.village != null and str(game.village.dialogue_locale) == "es" else "en"
    if desired != locale:
        _refresh_locale()
    opener.disabled = is_open or _blocked()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.is_echo():
        if event.physical_keycode == KEY_Y:
            toggle_panel()
            get_viewport().set_input_as_handled()
        elif event.physical_keycode == KEY_ESCAPE and is_open:
            close_panel()
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_START:
            toggle_panel()
            get_viewport().set_input_as_handled()
        elif event.button_index == JOY_BUTTON_B and is_open:
            close_panel()
            get_viewport().set_input_as_handled()
