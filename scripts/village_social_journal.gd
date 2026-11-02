extends CanvasLayer
## V19: first-party read-only social recap, derived from authoritative Village state.
## Focusable cards, keyboard/gamepad navigation and bilingual presentation have no save effects.
const HISTORY_PAGE_SIZE := 3
const HISTORY_FILTERS := ["all", "en", "es"]
const TEXT_SCALE_FACTORS := [1.0, 1.25, 1.5]
const MIN_TOUCH_TARGET := 44.0
const LABELS := {
    "en": {
        "open": "Neighbors [L]", "title": "Larkspur • Neighbors & Memories",
        "close": "Close", "hint": "Choose a neighbor • Up/Down or D-pad • Left/Right or shoulders: history",
        "footer": "Memories are earned through conversations, gifts, shifts and celebrations.",
        "selected": "Selected: %s", "friendship": "Friendship",
        "talks": "Conversations", "gifts": "Gifts", "jobs": "Work shifts",
        "festivals": "Festival visits", "last_gift": "Last gift",
        "recollections": "Recollections", "none": "none yet",
        "history": "Conversations remembered", "day": "Day %d",
        "page": "Page %d of %d", "empty_page": "Page 0 of 0",
        "earlier": "Earlier", "later": "Later",
        "filter_all": "All", "filter_en": "English", "filter_es": "Español",
        "filter_tip": "Filter spoken history • F or controller D-pad Left",
        "open_tip": "Open journal: L, controller Back, or tap",
        "close_tip": "Return to the valley: Escape, L or controller Back",
        "locale_tip": "Change journal and conditional dialogue language",
        "smaller_tip": "Smaller text (Ctrl+- or controller X)",
        "larger_tip": "Larger text (Ctrl+= or controller Y)"
    },
    "es": {
        "open": "Vecinos [L]", "title": "Larkspur • Vecinos y recuerdos",
        "close": "Cerrar", "hint": "Elige vecino • Arriba/abajo o mando • Izquierda/derecha: historial",
        "footer": "Los recuerdos nacen de charlas, regalos, trabajos y celebraciones.",
        "selected": "Seleccionado: %s", "friendship": "Amistad",
        "talks": "Conversaciones", "gifts": "Regalos", "jobs": "Turnos",
        "festivals": "Visitas a festivales", "last_gift": "Último regalo",
        "recollections": "Recuerdos", "none": "ninguno",
        "history": "Conversaciones recordadas", "day": "Día %d",
        "page": "Página %d de %d", "empty_page": "Página 0 de 0",
        "earlier": "Anteriores", "later": "Siguientes",
        "filter_all": "Todos", "filter_en": "Inglés", "filter_es": "Español",
        "filter_tip": "Filtrar conversaciones • F o cruceta izquierda",
        "open_tip": "Abrir diario: L, botón Atrás del mando o tocar",
        "close_tip": "Volver al valle: Escape, L o botón Atrás",
        "locale_tip": "Cambiar el idioma del diario y del diálogo condicional",
        "smaller_tip": "Reducir texto (Ctrl+- o botón X del mando)",
        "larger_tip": "Ampliar texto (Ctrl+= o botón Y del mando)"
    }
}
var village
var opener: Button
var panel: PanelContainer
var entries: VBoxContainer
var close_button: Button
var language_button: Button
var smaller_text_button: Button
var larger_text_button: Button
var text_scale_index: int = 0
var title_label: Label
var hint_label: Label
var footer_label: Label
var selected_label: Label
var history_title: Label
var history_filter_button: Button
var history_filter_index: int = 0
var history_page_label: Label
var history_earlier_button: Button
var history_later_button: Button
var history_page: int = 0
var history_text: RichTextLabel
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
    title_label = Label.new()
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(title_label)
    # A separate controls row avoids squeezing the title on narrow touch screens.
    var header := HBoxContainer.new()
    header.name = "JournalHeaderControls"
    layout.add_child(header)
    smaller_text_button = Button.new()
    smaller_text_button.name = "JournalSmallerText"
    smaller_text_button.text = "A−"
    smaller_text_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    smaller_text_button.focus_mode = Control.FOCUS_ALL
    smaller_text_button.pressed.connect(_change_text_scale.bind(-1))
    header.add_child(smaller_text_button)
    larger_text_button = Button.new()
    larger_text_button.name = "JournalLargerText"
    larger_text_button.text = "A+"
    larger_text_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    larger_text_button.focus_mode = Control.FOCUS_ALL
    larger_text_button.pressed.connect(_change_text_scale.bind(1))
    header.add_child(larger_text_button)
    language_button = Button.new()
    language_button.name = "JournalLanguage"
    language_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    language_button.focus_mode = Control.FOCUS_ALL
    language_button.pressed.connect(_toggle_locale)
    header.add_child(language_button)
    close_button = Button.new()
    close_button.name = "CloseSocialJournal"
    close_button.custom_minimum_size.y = MIN_TOUCH_TARGET
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

    var history_heading := HBoxContainer.new()
    history_heading.name = "ConversationHistoryHeading"
    layout.add_child(history_heading)
    history_title = Label.new()
    history_title.name = "ConversationHistoryTitle"
    history_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    history_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    history_heading.add_child(history_title)
    history_filter_button = Button.new()
    history_filter_button.name = "ConversationLanguageFilter"
    history_filter_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    history_filter_button.focus_mode = Control.FOCUS_ALL
    history_filter_button.pressed.connect(_cycle_history_filter)
    history_heading.add_child(history_filter_button)
    var history_controls := HBoxContainer.new()
    history_controls.name = "ConversationPageControls"
    layout.add_child(history_controls)
    history_earlier_button = Button.new()
    history_earlier_button.name = "EarlierConversations"
    history_earlier_button.focus_mode = Control.FOCUS_ALL
    history_earlier_button.pressed.connect(_change_history_page.bind(-1))
    history_controls.add_child(history_earlier_button)
    history_page_label = Label.new()
    history_page_label.name = "ConversationPageStatus"
    history_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    history_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    history_controls.add_child(history_page_label)
    history_later_button = Button.new()
    history_later_button.name = "LaterConversations"
    history_later_button.focus_mode = Control.FOCUS_ALL
    history_later_button.pressed.connect(_change_history_page.bind(1))
    history_controls.add_child(history_later_button)
    history_text = RichTextLabel.new()
    history_text.name = "EarnedConversationHistory"
    history_text.custom_minimum_size.y = 125.0
    history_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    history_text.scroll_active = true
    history_text.selection_enabled = true
    history_text.focus_mode = Control.FOCUS_ALL
    layout.add_child(history_text)

    footer_label = Label.new()
    footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(footer_label)
    panel.visible = false
    get_viewport().size_changed.connect(_update_layout)
    _update_layout()
    _update_labels()
    _apply_text_scale()

## Responsive margins and readable history without per-frame layout polling.
func _layout_for_width(width: float) -> void:
    var narrow: bool = width < 600.0
    panel.anchor_left = 0.02 if narrow else 0.04
    panel.anchor_right = 0.98 if narrow else 0.96
    panel.anchor_top = 0.02 if narrow else 0.04
    panel.anchor_bottom = 0.98 if narrow else 0.96
    history_text.custom_minimum_size.y = 95.0 if narrow else 125.0

func _update_layout() -> void:
    _layout_for_width(get_viewport().get_visible_rect().size.x)

func _set_font_size(control: Control, base: int) -> void:
    if control == null:
        return
    var factor: float = float(TEXT_SCALE_FACTORS[text_scale_index])
    var property: String = "normal_font_size" if control is RichTextLabel else "font_size"
    control.add_theme_font_size_override(property, int(round(float(base) * factor)))

func _apply_text_scale() -> void:
    _set_font_size(title_label, 18)
    _set_font_size(selected_label, 16)
    _set_font_size(history_title, 16)
    _set_font_size(history_text, 16)
    _set_font_size(history_page_label, 14)
    _set_font_size(hint_label, 14)
    _set_font_size(footer_label, 14)
    for button in [opener, smaller_text_button, larger_text_button,
            language_button, close_button, history_filter_button,
            history_earlier_button, history_later_button]:
        _set_font_size(button, 16)
    for card in cards:
        _set_font_size(card, 16)
    smaller_text_button.disabled = text_scale_index == 0
    larger_text_button.disabled = text_scale_index == TEXT_SCALE_FACTORS.size() - 1

func _change_text_scale(direction: int) -> void:
    if panel == null or not panel.visible or direction == 0:
        return
    text_scale_index = clampi(text_scale_index + direction, 0, TEXT_SCALE_FACTORS.size() - 1)
    _apply_text_scale()

func _update_labels() -> void:
    opener.text = _t("open")
    opener.tooltip_text = _t("open_tip")
    title_label.text = _t("title")
    close_button.text = _t("close")
    close_button.tooltip_text = _t("close_tip")
    language_button.text = "Español" if _locale() == "en" else "English"
    language_button.tooltip_text = _t("locale_tip")
    smaller_text_button.tooltip_text = _t("smaller_tip")
    larger_text_button.tooltip_text = _t("larger_tip")
    hint_label.text = _t("hint")
    footer_label.text = _t("footer")
    history_title.text = _t("history")
    history_earlier_button.text = _t("earlier")
    history_later_button.text = _t("later")
    history_filter_button.tooltip_text = _t("filter_tip")

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
    _apply_text_scale()

## View-only filtering. Saved transcripts retain their original locale and order.
func _visible_history(log: Array) -> Array:
    var selected: String = str(HISTORY_FILTERS[history_filter_index])
    if selected == "all":
        return log
    var result: Array = []
    for entry in log:
        if entry is Dictionary and str(entry.get("locale", "")) == selected:
            result.append(entry)
    return result

func _cycle_history_filter() -> void:
    if panel == null or not panel.visible:
        return
    history_filter_index = (history_filter_index + 1) % HISTORY_FILTERS.size()
    history_page = _latest_history_page(selected_index)
    _update_selection_label()

func _latest_history_page(index: int) -> int:
    var records: Array = village.social_recap()
    if index < 0 or index >= records.size():
        return 0
    var log: Array = _visible_history(records[index].get("dialogue_log", []))
    return maxi(0, int((log.size() - 1) / HISTORY_PAGE_SIZE))

func _update_selection_label() -> void:
    if village == null:
        return
    var records: Array = village.social_recap()
    var log: Array = []
    if selected_index >= 0 and selected_index < records.size():
        var selected: Dictionary = records[selected_index]
        selected_label.text = _t("selected") % str(selected["name"])
        log = selected.get("dialogue_log", [])
    else:
        selected_label.text = ""
    log = _visible_history(log)
    var filter_key: String = "filter_" + str(HISTORY_FILTERS[history_filter_index])
    history_filter_button.text = "%s (%d)" % [_t(filter_key), log.size()]
    var last_page: int = maxi(0, int((log.size() - 1) / HISTORY_PAGE_SIZE))
    history_page = clampi(history_page, 0, last_page)
    var lines: Array[String] = []
    var first: int = history_page * HISTORY_PAGE_SIZE
    for index in range(first, mini(log.size(), first + HISTORY_PAGE_SIZE)):
        var entry: Dictionary = log[index]
        lines.append("%s [%s] — %s" % [
            _t("day") % int(entry["epoch"]), str(entry["locale"]), str(entry["text"])])
    history_text.text = "\n\n".join(lines) if not lines.is_empty() else _t("none")
    history_page_label.text = (_t("page") % [history_page + 1, last_page + 1]
            if not log.is_empty() else _t("empty_page"))
    history_earlier_button.disabled = log.is_empty() or history_page == 0
    history_later_button.disabled = log.is_empty() or history_page >= last_page

func _change_history_page(direction: int) -> void:
    if panel == null or not panel.visible or direction == 0:
        return
    history_page = clampi(history_page + direction, 0, _latest_history_page(selected_index))
    _update_selection_label()

func _on_card_focus(index: int) -> void:
    if index < 0 or index >= cards.size():
        return
    if index != selected_index:
        history_page = _latest_history_page(index)
    selected_index = index
    _update_selection_label()
    scroll_area.ensure_control_visible(cards[index])

func _select_neighbor(index: int) -> void:
    if panel == null or not panel.visible or index < 0 or index >= cards.size():
        return
    history_page = _latest_history_page(index)
    selected_index = index
    cards[index].grab_focus()
    _on_card_focus(index)

func _toggle_locale() -> void:
    if village == null:
        return
    var previous: int = selected_index
    var previous_page: int = history_page
    village.set_dialogue_locale("es" if _locale() == "en" else "en")
    refresh()
    _select_neighbor(previous)
    history_page = previous_page
    _update_selection_label()

func open_journal() -> void:
    if panel == null or panel.visible:
        return
    # Two modal overlays must never compete over pause ownership.
    if village != null and village.topic_panel != null and village.topic_panel.panel != null and village.topic_panel.panel.visible:
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
            if event.ctrl_pressed and key == KEY_EQUAL:
                _change_text_scale(1)
            elif event.ctrl_pressed and key == KEY_MINUS:
                _change_text_scale(-1)
            elif key == KEY_F:
                _cycle_history_filter()
            elif key == KEY_ESCAPE:
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
            elif key == KEY_LEFT:
                _change_history_page(-1)
            elif key == KEY_RIGHT:
                _change_history_page(1)
            else:
                return
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_BACK:
            toggle_journal()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if event.button_index == JOY_BUTTON_Y:
                _change_text_scale(1)
            elif event.button_index == JOY_BUTTON_X:
                _change_text_scale(-1)
            elif event.button_index == JOY_BUTTON_B:
                close_journal()
            elif event.button_index == JOY_BUTTON_DPAD_LEFT:
                _cycle_history_filter()
            elif event.button_index == JOY_BUTTON_DPAD_DOWN:
                _navigate(1)
            elif event.button_index == JOY_BUTTON_DPAD_UP:
                _navigate(-1)
            elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
                _change_history_page(-1)
            elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
                _change_history_page(1)
            else:
                return
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if panel != null and panel.visible and get_tree() != null:
        get_tree().paused = paused_before_open
