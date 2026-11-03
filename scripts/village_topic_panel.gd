extends CanvasLayer
## V05: optional original topic-choice overlay. Only Village.act("talk") grants
## friendship/restoration and records the authentic spoken line.
const MIN_TOUCH_TARGET := 44.0
const LABELS := {
    "en":{"open":"Ask a neighbor [U]","title":"Choose a conversation","cancel":"Not now",
        "missing":"Walk near a neighbor before asking a question.",
        "changed":"The neighbor is no longer close enough to talk.",
        "hint":"D-pad/↑↓: topics, language, cancel • A/Enter: select • 1–4: topic • C/X: language • Esc/B: leave",
        "work_chapter":"Work memory", "trust_chapter":"Trust memory",
        "chapter_ready":"Ready to discuss", "shift_left":"shift(s) to complete",
        "friendship_left":"friendship points to earn",
        "language":"Español","language_tip":"Switch conversation language (C or controller X)"},
    "es":{"open":"Preguntar [U]","title":"Elige una conversación","cancel":"Ahora no",
        "missing":"Acércate a un vecino antes de hacer una pregunta.",
        "changed":"El vecino ya no está lo bastante cerca para hablar.",
        "hint":"Cruceta/↑↓: temas, idioma, cancelar • A/Intro: elegir • 1–4: tema • C/X: idioma • Esc/B: salir",
        "work_chapter":"Recuerdo del trabajo", "trust_chapter":"Recuerdo de confianza",
        "chapter_ready":"Listo para conversar", "shift_left":"turno(s) por completar",
        "friendship_left":"puntos de amistad por ganar",
        "language":"English","language_tip":"Cambiar idioma de conversación (C o botón X)"}
}
var village
var opener: Button
var panel: PanelContainer
var title_label: Label
var hint_label: Label
var progress_label: Label
var cancel_button: Button
var language_button: Button
var feedback_label: Label
var topic_buttons: Array[Button] = []
var topic_ids: Array[String] = []
var selected_index: int = 0
var active_resident_id: String = ""
var paused_before_open: bool = false
var last_result: String = ""
var last_locale: String = ""

func _locale() -> String:
    return "es" if village != null and str(village.dialogue_locale) == "es" else "en"

func _t(key: String) -> String:
    return str(LABELS[_locale()].get(key, LABELS["en"].get(key, key)))

func setup(owner) -> void:
    village = owner
    layer = 9
    process_mode = Node.PROCESS_MODE_ALWAYS
    var surface := Control.new()
    surface.name = "VillageTopicSurface"
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(surface)
    opener = Button.new()
    opener.name = "OpenVillageTopics"
    opener.anchor_left = 1.0
    opener.anchor_right = 1.0
    opener.offset_left = -200.0
    opener.offset_right = -12.0
    opener.offset_top = 202.0
    opener.offset_bottom = 250.0
    opener.custom_minimum_size.y = MIN_TOUCH_TARGET
    opener.focus_mode = Control.FOCUS_ALL
    opener.pressed.connect(open_topics)
    surface.add_child(opener)
    feedback_label = Label.new()
    feedback_label.name = "VillageTopicFeedback"
    feedback_label.anchor_left = 1.0
    feedback_label.anchor_right = 1.0
    feedback_label.offset_left = -360.0
    feedback_label.offset_right = -12.0
    feedback_label.offset_top = 252.0
    feedback_label.offset_bottom = 315.0
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.add_child(feedback_label)
    panel = PanelContainer.new()
    panel.name = "VillageTopicChoices"
    # Keep the dialogue readable on narrow mobile viewports without turning
    # desktop paragraphs into excessively long lines. Resize is presentation-only.
    panel.anchor_left = 0.08
    panel.anchor_right = 0.92
    panel.anchor_top = 0.08
    panel.anchor_bottom = 0.92
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.15, 0.16, 0.98)
    style.border_color = Color(0.68, 0.83, 0.68)
    style.set_border_width_all(2)
    style.set_content_margin_all(14)
    panel.add_theme_stylebox_override("panel", style)
    surface.add_child(panel)
    surface.resized.connect(_fit_dialogue_panel.bind(surface))
    _fit_dialogue_panel(surface)
    # Village-only presentation treatment: high-contrast authored civic palette,
    # distinct focus ring and generous touch targets; no reward/state changes.
    var focus_style := StyleBoxFlat.new()
    focus_style.bg_color = Color(0.19, 0.30, 0.29, 1.0)
    focus_style.border_color = Color(1.0, 0.85, 0.48, 1.0)
    focus_style.set_border_width_all(3)
    focus_style.set_corner_radius_all(9)
    focus_style.set_content_margin_all(9)
    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color(0.13, 0.23, 0.24, 1.0)
    button_style.border_color = Color(0.48, 0.67, 0.62, 1.0)
    button_style.set_border_width_all(1)
    button_style.set_corner_radius_all(9)
    button_style.set_content_margin_all(9)
    panel.set_meta("village_focus_style", focus_style)
    panel.set_meta("village_button_style", button_style)
    # The chapter tracker must never push choices off a short mobile viewport.
    # Focusable buttons inside ScrollContainer remain keyboard/gamepad reachable.
    var scroll := ScrollContainer.new()
    scroll.name = "ConversationScroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var layout := VBoxContainer.new()
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation", 12)
    scroll.add_child(layout)
    title_label = Label.new()
    title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_label.add_theme_font_size_override("font_size", 21)
    title_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
    layout.add_child(title_label)
    hint_label = Label.new()
    hint_label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.86))
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(hint_label)
    progress_label = Label.new()
    progress_label.name = "EarnedChapterProgress"
    progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    progress_label.add_theme_font_size_override("font_size", 15)
    progress_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.75))
    progress_label.custom_minimum_size.y = 48.0
    layout.add_child(progress_label)
    for index in range(4):
        var button := Button.new()
        button.name = "ConversationChoice%d" % (index + 1)
        button.custom_minimum_size.y = 56.0
        button.focus_mode = Control.FOCUS_ALL
        button.add_theme_stylebox_override("normal", button_style)
        button.add_theme_stylebox_override("focus", focus_style)
        button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.88))
        button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.pressed.connect(_choose_index.bind(index))
        layout.add_child(button)
        topic_buttons.append(button)
    language_button = Button.new()
    language_button.name = "ConversationLanguage"
    language_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    language_button.focus_mode = Control.FOCUS_ALL
    language_button.add_theme_stylebox_override("normal", button_style)
    language_button.add_theme_stylebox_override("focus", focus_style)
    language_button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.88))
    language_button.pressed.connect(_toggle_locale)
    layout.add_child(language_button)
    cancel_button = Button.new()
    cancel_button.name = "CancelConversation"
    cancel_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    cancel_button.focus_mode = Control.FOCUS_ALL
    cancel_button.add_theme_stylebox_override("normal", button_style)
    cancel_button.add_theme_stylebox_override("focus", focus_style)
    cancel_button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.88))
    cancel_button.pressed.connect(close_topics)
    layout.add_child(cancel_button)
    panel.visible = false
    _refresh_locale()

## Constrain the reading column to 760 logical pixels on desktop; preserve
## generous lateral margins and vertical room on phones. No game-state edits.
func _fit_dialogue_panel(surface: Control) -> void:
    if panel == null:
        return
    var width: float = surface.size.x
    if width <= 0.0:
        return
    var inset: float = maxf(12.0, (width - minf(760.0, width * 0.92)) * 0.5)
    panel.anchor_left = 0.0
    panel.anchor_right = 1.0
    panel.offset_left = inset
    panel.offset_right = -inset

## Rebuild labels by stable topic IDs, never by translated sort order.
## This is presentation-only: no extra talk, rewards or save writes.
func _refresh_locale() -> void:
    last_locale = _locale()
    opener.text = _t("open")
    hint_label.text = _t("hint")
    cancel_button.text = _t("cancel")
    language_button.text = _t("language")
    language_button.tooltip_text = _t("language_tip")
    opener.tooltip_text = _t("hint")
    title_label.text = _t("title")
    if panel == null or not panel.visible or active_resident_id.is_empty():
        return
    for resident in village.residents:
        if str(resident["id"]) == active_resident_id:
            title_label.text = "%s: %s" % [_t("title"), str(resident["name"])]
            break
    var labels_by_id: Dictionary = {}
    for option in village.available_topics(active_resident_id):
        labels_by_id[str(option["id"])] = str(option["label"])
    for index in range(topic_ids.size()):
        if index < topic_buttons.size():
            topic_buttons[index].text = "%d. %s" % [
                index + 1, str(labels_by_id.get(topic_ids[index], topic_ids[index]))]
    _refresh_chapter_progress()

## A readable, localized tracker of real prerequisite deficits, not dialogue
## spoilers or an alternate reward path. No state mutation and no save keys.
func _refresh_chapter_progress() -> void:
    if progress_label == null or village == null or active_resident_id.is_empty():
        return
    var lines := PackedStringArray()
    for chapter in village.chapter_progress(active_resident_id):
        var title: String = _t("work_chapter") if str(chapter["id"]) == "shift_reflection" else _t("trust_chapter")
        if bool(chapter["unlocked"]):
            lines.append("%s: %s" % [title, _t("chapter_ready")])
            continue
        var requirements := PackedStringArray()
        if int(chapter["jobs_remaining"]) > 0:
            requirements.append("%d %s" % [int(chapter["jobs_remaining"]), _t("shift_left")])
        if int(chapter["friendship_remaining"]) > 0:
            requirements.append("%d %s" % [int(chapter["friendship_remaining"]), _t("friendship_left")])
        lines.append("%s: %s" % [title, ", ".join(requirements)])
    progress_label.text = "\n".join(lines)

func _toggle_locale() -> void:
    if village == null or panel == null or not panel.visible:
        return
    village.set_dialogue_locale("es" if _locale() == "en" else "en")
    _refresh_locale()

func _process(_delta: float) -> void:
    if opener == null:
        return
    if last_locale != _locale():
        _refresh_locale()
    opener.disabled = get_tree().paused

func _show_result(message: String) -> String:
    last_result = message
    feedback_label.text = message
    if village != null and village.game != null and village.game.has_method("_show"):
        village.game._show(message)
    return message

func _nearest(position: Vector3) -> Dictionary:
    var selected: Dictionary = {}
    var best_distance: float = 4.2
    for resident in village.residents:
        var actor: Node3D = resident["node"]
        var distance: float = actor.global_position.distance_to(position)
        if distance < best_distance:
            best_distance = distance
            selected = resident
    return selected

func _hero() -> Variant:
    if village == null:
        return null
    var candidate: Variant = village._host_property("hero", null)
    if candidate is Node3D and is_instance_valid(candidate):
        return candidate
    return null

func open_topics() -> void:
    if panel == null or panel.visible or get_tree().paused:
        return
    if village.social_journal != null and village.social_journal.panel.visible:
        return
    var hero: Variant = _hero()
    if hero == null:
        _show_result(_t("missing"))
        return
    var selected: Dictionary = _nearest(hero.global_position)
    if selected.is_empty():
        _show_result(_t("missing"))
        return
    active_resident_id = str(selected["id"])
    var options: Array = village.available_topics(active_resident_id)
    if options.size() < 2 or options.size() > topic_buttons.size():
        _show_result(_t("missing"))
        return
    topic_ids.clear()
    for index in range(topic_buttons.size()):
        var available: bool = index < options.size()
        topic_buttons[index].visible = available
        if available:
            topic_ids.append(str(options[index]["id"]))
    selected_index = 0
    paused_before_open = get_tree().paused
    get_tree().paused = true
    panel.visible = true
    opener.visible = false
    _refresh_locale()
    topic_buttons[0].grab_focus()

func close_topics() -> void:
    if panel == null or not panel.visible:
        return
    panel.visible = false
    opener.visible = true
    active_resident_id = ""
    topic_ids.clear()
    get_tree().paused = paused_before_open
    opener.grab_focus()

func _choose_index(index: int) -> String:
    if panel == null or not panel.visible or index < 0 or index >= topic_ids.size():
        return ""
    var hero: Variant = _hero()
    if hero == null:
        close_topics()
        return _show_result(_t("changed"))
    var nearest: Dictionary = _nearest(hero.global_position)
    if nearest.is_empty() or str(nearest["id"]) != active_resident_id:
        close_topics()
        return _show_result(_t("changed"))
    # One authority for once-per-day talk rewards, festivals and transcripts.
    var response: String = village.act("talk", hero.global_position, topic_ids[index])
    close_topics()
    return _show_result(response)

## Navigate every visible, enabled modal action, not only conversation topics.
## This keeps Language and Cancel reachable without Tab or a pointer. Hidden
## locked chapters and disabled controls cannot trap controller focus.
func _navigate(direction: int) -> void:
    if panel == null or not panel.visible:
        return
    var controls: Array[Button] = []
    for index in range(topic_ids.size()):
        if topic_buttons[index].visible and not topic_buttons[index].disabled:
            controls.append(topic_buttons[index])
    if language_button.visible and not language_button.disabled:
        controls.append(language_button)
    if cancel_button.visible and not cancel_button.disabled:
        controls.append(cancel_button)
    if controls.is_empty():
        return
    var focused: Control = get_viewport().gui_get_focus_owner()
    var current_index: int = controls.find(focused)
    if current_index < 0:
        current_index = 0 if direction >= 0 else controls.size() - 1
    else:
        current_index = clampi(current_index + direction, 0, controls.size() - 1)
    var target: Button = controls[current_index]
    target.grab_focus()
    for index in range(topic_ids.size()):
        if topic_buttons[index] == target:
            selected_index = index
            break

## V19: Tab, Shift-Tab and pointer focus can select a different control than
## the last D-pad index. Activate that real focused control, never silently
## turn a language/cancel request into a paid or rewarded conversation.
func _activate_focused() -> void:
    if panel == null or not panel.visible:
        return
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused == language_button:
        _toggle_locale()
        return
    if focused == cancel_button:
        close_topics()
        return
    for index in range(topic_ids.size()):
        if focused == topic_buttons[index]:
            selected_index = index
            _choose_index(index)
            return
    # Never interpret absent/foreign focus as consent to a rewarded talk.
    # The player must focus an actual modal action before confirming.
    return

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if not event.pressed or event.echo:
            return
        var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if key == KEY_U:
            if panel != null and panel.visible:
                close_topics()
            else:
                open_topics()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if key == KEY_ESCAPE:
                close_topics()
            elif key == KEY_C:
                _toggle_locale()
            elif key >= KEY_1 and key <= KEY_4:
                _choose_index(key - KEY_1)
            elif key == KEY_UP:
                _navigate(-1)
            elif key == KEY_DOWN:
                _navigate(1)
            elif key == KEY_ENTER or key == KEY_KP_ENTER:
                _activate_focused()
            else:
                return
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_RIGHT_STICK:
            if panel != null and panel.visible:
                close_topics()
            else:
                open_topics()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if event.button_index == JOY_BUTTON_B:
                close_topics()
            elif event.button_index == JOY_BUTTON_X:
                _toggle_locale()
            elif event.button_index == JOY_BUTTON_DPAD_UP:
                _navigate(-1)
            elif event.button_index == JOY_BUTTON_DPAD_DOWN:
                _navigate(1)
            elif event.button_index == JOY_BUTTON_A:
                _activate_focused()
            else:
                return
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if panel != null and panel.visible and get_tree() != null:
        get_tree().paused = paused_before_open
