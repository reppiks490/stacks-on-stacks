extends CanvasLayer
## V19: first-party read-only social recap, derived from authoritative Village state.
## Focusable cards, keyboard/gamepad navigation and bilingual presentation have no save effects.
const LABELS := {
    "en": {
        "open": "Neighbors [L]", "title": "Larkspur • Neighbors & Memories",
        "close": "Close", "hint": "Choose a neighbor • Up/Down, D-pad, wheel or swipe",
        "footer": "Memories are earned through conversations, gifts, shifts and celebrations.",
        "selected": "Selected: %s", "friendship": "Friendship",
        "talks": "Conversations", "gifts": "Gifts", "jobs": "Work shifts",
        "festivals": "Festival visits", "last_gift": "Last gift",
        "recollections": "Recollections", "none": "none yet",
        "open_tip": "Open journal: L, controller Back, or tap",
        "close_tip": "Return to the valley: Escape, L or controller Back",
        "locale_tip": "Change journal and conditional dialogue language"
    },
    "es": {
        "open": "Vecinos [L]", "title": "Larkspur • Vecinos y recuerdos",
        "close": "Cerrar", "hint": "Elige un vecino • Arriba/abajo, mando, rueda o deslizar",
        "footer": "Los recuerdos nacen de charlas, regalos, trabajos y celebraciones.",
        "selected": "Seleccionado: %s", "friendship": "Amistad",
        "talks": "Conversaciones", "gifts": "Regalos", "jobs": "Turnos",
        "festivals": "Visitas a festivales", "last_gift": "Último regalo",
        "recollections": "Recuerdos", "none": "ninguno",
        "open_tip": "Abrir diario: L, botón Atrás del mando o tocar",
        "close_tip": "Volver al valle: Escape, L o botón Atrás",
        "locale_tip": "Cambiar el idioma del diario y del diálogo condicional"
    }
}
var village
var opener: Button
var panel: PanelContainer
var entries: VBoxContainer
var close_button: Button
var language_button: Button
var title_label: Label
var hint_label: Label
var footer_label: Label
var selected_label: Label
var scroll_area: ScrollContainer
var cards: Array[Button] = []
var selected_index: int = 0
var rendered_text: String = ""
var paused_before_open: bool = false

func _locale() -> String:
    return "es" if village != null and str(village.dialogue_locale) == "es" else "en"

func _t(key: String) -> String:
    return str(LABELS[_locale()].get(key, LABELS["en"].get(key, key)))

func setup(owner) -> void:
    village = owner
    layer = 8
    process_mode = Node.PROCESS_MODE_ALWAYS
    var surface := Control.new()
    surface.name = "SocialJournalSurface"
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(surface)

    opener = Button.new()
    opener.name = "OpenSocialJournal"
    opener.focus_mode = Control.FOCUS_ALL
    opener.anchor_left = 1.0
    opener.anchor_right = 1.0
    opener.offset_left = -200.0
    opener.offset_right = -12.0
    opener.offset_top = 12.0
    opener.offset_bottom = 58.0
    opener.pressed.connect(toggle_journal)
    surface.add_child(opener)

    panel = PanelContainer.new()
    panel.name = "SocialJournalPanel"
    panel.anchor_left = 0.04
    panel.anchor_top = 0.04
    panel.anchor_right = 0.96
    panel.anchor_bottom = 0.96
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.055, 0.11, 0.13, 0.97)
    background.border_color = Color(0.66, 0.81, 0.68)
    background.set_border_width_all(2)
    background.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel", background)
    surface.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 8)
    panel.add_child(layout)
    var header := HBoxContainer.new()
    layout.add_child(header)
    title_label = Label.new()
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_label.add_theme_font_size_override("font_size", 18)
    header.add_child(title_label)
    language_button = Button.new()
    language_button.name = "JournalLanguage"
    language_button.focus_mode = Control.FOCUS_ALL
    language_button.pressed.connect(_toggle_locale)
    header.add_child(language_button)
    close_button = Button.new()
    close_button.name = "CloseSocialJournal"
    close_button.focus_mode = Control.FOCUS_ALL
    close_button.pressed.connect(close_journal)
    header.add_child(close_button)

    hint_label = Label.new()
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(hint_label)
    selected_label = Label.new()
    selected_label.name = "SelectedNeighbor"
    selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(selected_label)

    scroll_area = ScrollContainer.new()
    scroll_area.name = "NeighborRecapScroll"
    scroll_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroll_area)
    entries = VBoxContainer.new()
    entries.name = "NeighborRecapEntries"
    entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    entries.add_theme_constant_override("separation", 10)
    scroll_area.add_child(entries)

    footer_label = Label.new()
    footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(footer_label)
    panel.visible = false
    _update_labels()

func _update_labels() -> void:
    opener.text = _t("open")
    opener.tooltip_text = _t("open_tip")
    title_label.text = _t("title")
    close_button.text = _t("close")
    close_button.tooltip_text = _t("close_tip")
    language_button.text = "Español" if _locale() == "en" else "English"
    language_button.tooltip_text = _t("locale_tip")
    hint_label.text = _t("hint")
    footer_label.text = _t("footer")

func _card_text(record: Dictionary) -> String:
    var last_gift: String = str(record["last_gift_item"])
    if last_gift.is_empty():
        last_gift = _t("none")
    return "%s — %s\n%s: %d (%s)\n%s: %d  •  %s: %d  •  %s: %d  •  %s: %d\n%s: %s  •  %s: %d" % [
        record["name"], record["role"], _t("friendship"), record["friendship"], record["tier"],
        _t("talks"), record["talks"], _t("gifts"), record["gifts"],
        _t("jobs"), record["jobs"], _t("festivals"), record["festivals"],
        _t("last_gift"), last_gift, _t("recollections"), record["gift_recollections"]]

func refresh() -> void:
    if village == null or entries == null:
        return
    for child in entries.get_children():
        entries.remove_child(child)
        child.queue_free()
    cards.clear()
    _update_labels()
    var lines: Array[String] = []
    var records: Array = village.social_recap()
    for index in range(records.size()):
        var record: Dictionary = records[index]
        var line: String = _card_text(record)
        lines.append(line)
        var card := Button.new()
        card.name = "Neighbor_%s" % str(record["id"])
        card.text = line
        card.alignment = HORIZONTAL_ALIGNMENT_LEFT
        card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        card.custom_minimum_size.y = 160.0
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.focus_mode = Control.FOCUS_ALL
        card.pressed.connect(_select_neighbor.bind(index))
        card.focus_entered.connect(_on_card_focus.bind(index))
        entries.add_child(card)
        cards.append(card)
    rendered_text = "\n\n".join(lines)
    selected_index = clampi(selected_index, 0, maxi(0, cards.size() - 1))
    _update_selection_label()

func _update_selection_label() -> void:
    if village == null:
        return
    var records: Array = village.social_recap()
    if selected_index >= 0 and selected_index < records.size():
        selected_label.text = _t("selected") % str(records[selected_index]["name"])
    else:
        selected_label.text = ""

func _on_card_focus(index: int) -> void:
    if index < 0 or index >= cards.size():
        return
    selected_index = index
    _update_selection_label()
    scroll_area.ensure_control_visible(cards[index])

func _select_neighbor(index: int) -> void:
    if panel == null or not panel.visible or index < 0 or index >= cards.size():
        return
    selected_index = index
    cards[index].grab_focus()
    _on_card_focus(index)

func _toggle_locale() -> void:
    if village == null:
        return
    var previous: int = selected_index
    village.set_dialogue_locale("es" if _locale() == "en" else "en")
    refresh()
    _select_neighbor(previous)

func open_journal() -> void:
    if panel == null or panel.visible:
        return
    refresh()
    paused_before_open = get_tree().paused
    get_tree().paused = true
    panel.visible = true
    opener.visible = false
    _select_neighbor(0)

func close_journal() -> void:
    if panel == null or not panel.visible:
        return
    panel.visible = false
    opener.visible = true
    get_tree().paused = paused_before_open
    opener.grab_focus()

func toggle_journal() -> void:
    if panel != null and panel.visible:
        close_journal()
    else:
        open_journal()

func _navigate(direction: int) -> void:
    if panel != null and panel.visible and not cards.is_empty():
        _select_neighbor(clampi(selected_index + direction, 0, cards.size() - 1))

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if not event.pressed or event.echo:
            return
        var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if key == KEY_L:
            toggle_journal()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if key == KEY_ESCAPE:
                close_journal()
            elif key == KEY_DOWN:
                _navigate(1)
            elif key == KEY_UP:
                _navigate(-1)
            elif key == KEY_PAGEDOWN:
                _navigate(3)
            elif key == KEY_PAGEUP:
                _navigate(-3)
            elif key == KEY_HOME:
                _select_neighbor(0)
            elif key == KEY_END:
                _select_neighbor(cards.size() - 1)
            else:
                return
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_BACK:
            toggle_journal()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if event.button_index == JOY_BUTTON_B:
                close_journal()
            elif event.button_index == JOY_BUTTON_DPAD_DOWN:
                _navigate(1)
            elif event.button_index == JOY_BUTTON_DPAD_UP:
                _navigate(-1)
            else:
                return
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if panel != null and panel.visible and get_tree() != null:
        get_tree().paused = paused_before_open
