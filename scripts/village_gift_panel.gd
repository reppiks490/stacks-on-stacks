extends CanvasLayer
## V06: first-party explicit gift choice. Village.act("gift") alone owns
## inventory consumption, friendship, restoration and daily idempotence.
const MIN_TOUCH_TARGET := 44.0
const LABELS := {
    "en": {"open":"Choose a gift [V]", "title":"Offer a thoughtful gift",
        "cancel":"Not now", "favorite":"favorite", "preferred":"preferred",
        "missing":"Walk near a neighbor before choosing a gift.",
        "changed":"That neighbor is no longer close enough.",
        "hint":"Choose an item • 1/2 or D-pad + A • Esc/B to leave",
        "empty":"You have no preferred gifts for this neighbor."},
    "es": {"open":"Elegir regalo [V]", "title":"Ofrecer un regalo",
        "cancel":"Ahora no", "favorite":"favorito", "preferred":"preferido",
        "missing":"Acércate a un vecino antes de elegir un regalo.",
        "changed":"Ese vecino ya no está lo bastante cerca.",
        "hint":"Elige objeto • 1/2 o mando + A • Esc/B para salir",
        "empty":"No tienes regalos preferidos para este vecino."}
}
var village
var opener: Button
var panel: PanelContainer
var title_label: Label
var hint_label: Label
var cancel_button: Button
var feedback_label: Label
var gift_buttons: Array[Button] = []
var gift_ids: Array[String] = []
var active_resident_id: String = ""
var selected_index: int = 0
var paused_before_open: bool = false
var last_result: String = ""
var last_locale: String = ""

func _locale() -> String:
    return "es" if village != null and str(village.dialogue_locale) == "es" else "en"

func _t(key: String) -> String:
    return str(LABELS[_locale()].get(key, LABELS["en"].get(key, key)))

func setup(owner) -> void:
    village = owner
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    var surface := Control.new()
    surface.name = "VillageGiftSurface"
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(surface)
    opener = Button.new()
    opener.name = "OpenGiftChoices"
    opener.anchor_left = 1.0
    opener.anchor_right = 1.0
    opener.offset_left = -200.0
    opener.offset_right = -12.0
    opener.offset_top = 320.0
    opener.offset_bottom = 368.0
    opener.custom_minimum_size.y = MIN_TOUCH_TARGET
    opener.focus_mode = Control.FOCUS_ALL
    opener.pressed.connect(open_gifts)
    surface.add_child(opener)
    feedback_label = Label.new()
    feedback_label.name = "GiftFeedback"
    feedback_label.anchor_left = 1.0
    feedback_label.anchor_right = 1.0
    feedback_label.offset_left = -360.0
    feedback_label.offset_right = -12.0
    feedback_label.offset_top = 370.0
    feedback_label.offset_bottom = 438.0
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.add_child(feedback_label)
    panel = PanelContainer.new()
    panel.name = "VillageGiftChoices"
    panel.anchor_left = 0.2
    panel.anchor_right = 0.8
    panel.anchor_top = 0.2
    panel.anchor_bottom = 0.8
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.15, 0.13, 0.98)
    style.border_color = Color(0.78, 0.81, 0.60)
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
        button.name = "GiftChoice%d" % (index + 1)
        button.custom_minimum_size.y = 56.0
        button.focus_mode = Control.FOCUS_ALL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.pressed.connect(_choose_index.bind(index))
        layout.add_child(button)
        gift_buttons.append(button)
    cancel_button = Button.new()
    cancel_button.name = "CancelGift"
    cancel_button.custom_minimum_size.y = MIN_TOUCH_TARGET
    cancel_button.focus_mode = Control.FOCUS_ALL
    cancel_button.pressed.connect(close_gifts)
    layout.add_child(cancel_button)
    panel.visible = false
    _refresh_locale()

func _blocked() -> bool:
    if village == null or get_tree().paused:
        return true
    if village.social_journal != null and village.social_journal.panel.visible:
        return true
    if village.topic_panel != null and village.topic_panel.panel.visible:
        return true
    var host = village.game
    if host != null and host.get("save_health_panel") != null and host.save_health_panel.is_open:
        return true
    return false

func _process(_delta: float) -> void:
    if opener == null:
        return
    if last_locale != _locale():
        _refresh_locale()
    opener.disabled = _blocked()

func _show_result(message: String) -> String:
    last_result = message
    feedback_label.text = message
    if village != null and village.game != null and village.game.has_method("_show"):
        village.game._show(message)
    return message

func _hero() -> Variant:
    if village == null:
        return null
    var candidate: Variant = village._host_property("hero", null)
    if candidate is Node3D and is_instance_valid(candidate):
        return candidate
    return null

func _nearest(position: Vector3) -> Dictionary:
    var selected: Dictionary = {}
    var distance_limit: float = 4.2
    for resident in village.residents:
        var distance: float = resident["node"].global_position.distance_to(position)
        if distance < distance_limit:
            selected = resident
            distance_limit = distance
    return selected

func _resident() -> Dictionary:
    for resident in village.residents:
        if str(resident["id"]) == active_resident_id:
            return resident
    return {}

func _refresh_locale() -> void:
    last_locale = _locale()
    if opener == null:
        return
    opener.text = _t("open")
    opener.tooltip_text = _t("hint")
    cancel_button.text = _t("cancel")
    hint_label.text = _t("hint")
    title_label.text = _t("title")
    if panel != null and panel.visible:
        _refresh_choices()

func _refresh_choices() -> void:
    var resident: Dictionary = _resident()
    if resident.is_empty():
        return
    title_label.text = "%s: %s" % [_t("title"), str(resident["name"])]
    for index in range(gift_ids.size()):
        var item: String = gift_ids[index]
        var count: int = int(village.game.inventory.get(item, 0))
        var favorite: bool = item == str(resident.get("gift", ""))
        gift_buttons[index].text = "%d. %s (%s; %d)" % [
            index + 1, item, _t("favorite" if favorite else "preferred"), count]
        gift_buttons[index].disabled = count <= 0

func open_gifts() -> void:
    if panel == null or panel.visible or _blocked():
        return
    var hero: Variant = _hero()
    if hero == null:
        _show_result(_t("missing"))
        return
    var resident: Dictionary = _nearest(hero.global_position)
    if resident.is_empty():
        _show_result(_t("missing"))
        return
    active_resident_id = str(resident["id"])
    gift_ids.clear()
    for item in resident["preferences"]:
        if gift_ids.size() < gift_buttons.size():
            gift_ids.append(str(item))
    if gift_ids.is_empty():
        _show_result(_t("empty"))
        return
    for index in range(gift_buttons.size()):
        gift_buttons[index].visible = index < gift_ids.size()
    selected_index = 0
    paused_before_open = get_tree().paused
    get_tree().paused = true
    panel.visible = true
    opener.visible = false
    _refresh_locale()
    var available: bool = false
    for index in range(gift_ids.size()):
        if not gift_buttons[index].disabled:
            gift_buttons[index].grab_focus()
            selected_index = index
            available = true
            break
    if not available:
        cancel_button.grab_focus()
        _show_result(_t("empty"))

func close_gifts() -> void:
    if panel == null or not panel.visible:
        return
    panel.visible = false
    opener.visible = true
    active_resident_id = ""
    gift_ids.clear()
    get_tree().paused = paused_before_open
    opener.grab_focus()

func _choose_index(index: int) -> String:
    if panel == null or not panel.visible or index < 0 or index >= gift_ids.size():
        return ""
    var hero: Variant = _hero()
    if hero == null:
        close_gifts()
        return _show_result(_t("changed"))
    var nearest: Dictionary = _nearest(hero.global_position)
    if nearest.is_empty() or str(nearest["id"]) != active_resident_id:
        close_gifts()
        return _show_result(_t("changed"))
    var item: String = gift_ids[index]
    # Domain revalidates inventory, preference and once/day at transaction time.
    var response: String = village.act("gift", hero.global_position, item)
    close_gifts()
    return _show_result(response)

func _navigate(direction: int) -> void:
    if gift_ids.is_empty():
        return
    selected_index = clampi(selected_index + direction, 0, gift_ids.size() - 1)
    if not gift_buttons[selected_index].disabled:
        gift_buttons[selected_index].grab_focus()

func _activate_focused() -> void:
    if panel == null or not panel.visible:
        return
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused == cancel_button:
        close_gifts()
        return
    for index in range(gift_ids.size()):
        if focused == gift_buttons[index] and not gift_buttons[index].disabled:
            selected_index = index
            _choose_index(index)
            return

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if not event.pressed or event.echo:
            return
        var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if key == KEY_V:
            if panel != null and panel.visible:
                close_gifts()
            else:
                open_gifts()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if key == KEY_ESCAPE:
                close_gifts()
            elif key == KEY_UP:
                _navigate(-1)
            elif key == KEY_DOWN:
                _navigate(1)
            elif key == KEY_ENTER or key == KEY_KP_ENTER:
                _activate_focused()
            elif key == KEY_1 or key == KEY_2:
                _choose_index(key - KEY_1)
            else:
                return
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_DPAD_RIGHT and (panel == null or not panel.visible):
            open_gifts()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible:
            if event.button_index == JOY_BUTTON_B:
                close_gifts()
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
