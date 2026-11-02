extends CanvasLayer
## V05: optional original topic-choice overlay. Only Village.act("talk") grants
## friendship/restoration and records the authentic spoken line.
const MIN_TOUCH_TARGET := 44.0
const LABELS := {
    "en":{"open":"Ask a neighbor [U]","title":"Choose a conversation","cancel":"Not now",
        "missing":"Walk near a neighbor before asking a question.",
        "changed":"The neighbor is no longer close enough to talk.",
        "hint":"Choose a topic • 1/2 or D-pad + A • Esc/B to leave"},
    "es":{"open":"Preguntar [U]","title":"Elige una conversación","cancel":"Ahora no",
        "missing":"Acércate a un vecino antes de hacer una pregunta.",
        "changed":"El vecino ya no está lo bastante cerca para hablar.",
        "hint":"Elige tema • 1/2 o mando + A • Esc/B para salir"}
}
var village
var opener: Button
var panel: PanelContainer
var title_label: Label
var hint_label: Label
var cancel_button: Button
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
    panel.anchor_left = 0.18
    panel.anchor_right = 0.82
    panel.anchor_top = 0.23
    panel.anchor_bottom = 0.77
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.15, 0.16, 0.98)
    style.border_color = Color(0.68, 0.83, 0.68)
    style.set_border_width_all(2)
    style.set_content_margin_all(14)
    panel.add_theme_stylebox_override("panel", style)
    surface.add_child(panel)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    panel.add_child(layout)
    title_label = Label.new()
    title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_label.add_theme_font_size_override("font_size", 21)
    layout.add_child(title_label)
    hint_label = Label.new()
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(hint_label)
    for index in range(2):
        var button := Button.new()
        button.name = "ConversationChoice%d" % (index + 1)
        button.custom_minimum_size.y = 56.0
        button.focus_mode = Control.FOCUS_ALL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.pressed.connect(_choose_index.bind(index))
        layout.add_child(button)
        topic_buttons.append(button)
    cancel_button = Button.new()
    cancel_button.name = "CancelConversation"
    cancel_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    cancel_button.focus_mode = Control.FOCUS_ALL
    cancel_button.pressed.connect(close_topics)
    layout.add_child(cancel_button)
    panel.visible = false
    _refresh_locale()

func _refresh_locale() -> void:
    last_locale = _locale()
    opener.text = _t("open")
    title_label.text = _t("title")
    hint_label.text = _t("hint")
    cancel_button.text = _t("cancel")
    opener.tooltip_text = _t("hint")

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
    if options.size() != 2:
        _show_result(_t("missing"))
        return
    topic_ids.clear()
    _refresh_locale()
    title_label.text = "%s: %s" % [_t("title"), str(selected["name"])]
    for index in range(2):
        topic_ids.append(str(options[index]["id"]))
        topic_buttons[index].text = "%d. %s" % [index + 1, str(options[index]["label"])]
    selected_index = 0
    paused_before_open = get_tree().paused
    get_tree().paused = true
    panel.visible = true
    opener.visible = false
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

func _navigate(direction: int) -> void:
    selected_index = clampi(selected_index + direction, 0, topic_buttons.size() - 1)
    topic_buttons[selected_index].grab_focus()

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
            elif key == KEY_1 or key == KEY_2:
                _choose_index(key - KEY_1)
            elif key == KEY_UP:
                _navigate(-1)
            elif key == KEY_DOWN:
                _navigate(1)
            elif key == KEY_ENTER or key == KEY_KP_ENTER:
                _choose_index(selected_index)
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
            elif event.button_index == JOY_BUTTON_DPAD_UP:
                _navigate(-1)
            elif event.button_index == JOY_BUTTON_DPAD_DOWN:
                _navigate(1)
            elif event.button_index == JOY_BUTTON_A:
                _choose_index(selected_index)
            else:
                return
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if panel != null and panel.visible and get_tree() != null:
        get_tree().paused = paused_before_open
