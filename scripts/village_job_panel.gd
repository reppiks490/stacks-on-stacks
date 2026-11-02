extends CanvasLayer
## V07: accessible on-screen and controller route to the EXISTING authoritative
## Village paid-shift verb. No independent reward, schedule or save state.
const MIN_TOUCH_TARGET := 44.0
const LABELS := {
    "en": {
        "button": "Help at work [K]",
        "tip": "Near a working neighbor: tap, click, press K or controller X.",
        "missing": "Walk near a neighbor at their workplace to offer help."
    },
    "es": {
        "button": "Ayudar [K]",
        "tip": "Junto a un vecino trabajando: toca, haz clic, pulsa K o X en el mando.",
        "missing": "Acércate a un vecino en su lugar de trabajo para ayudar."
    }
}
var village
var work_button: Button
var feedback_label: Label
var last_result: String = ""
var _last_locale: String = ""

func setup(owner) -> void:
    village = owner
    layer = 7 # Below the modal social journal (layer 8).
    process_mode = Node.PROCESS_MODE_ALWAYS
    var surface := Control.new()
    surface.name = "VillageWorkSurface"
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(surface)

    work_button = Button.new()
    work_button.name = "VillageWorkAction"
    work_button.anchor_left = 1.0
    work_button.anchor_right = 1.0
    work_button.offset_left = -200.0
    work_button.offset_right = -12.0
    work_button.offset_top = 70.0
    work_button.offset_bottom = 118.0
    work_button.custom_minimum_size.y = 48.0
    work_button.focus_mode = Control.FOCUS_ALL
    work_button.pressed.connect(_perform_job)
    surface.add_child(work_button)

    feedback_label = Label.new()
    feedback_label.name = "VillageWorkFeedback"
    feedback_label.anchor_left = 1.0
    feedback_label.anchor_right = 1.0
    feedback_label.offset_left = -360.0
    feedback_label.offset_right = -12.0
    feedback_label.offset_top = 120.0
    feedback_label.offset_bottom = 190.0
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_label.add_theme_font_size_override("font_size", 14)
    surface.add_child(feedback_label)
    _refresh_locale()

func _locale() -> String:
    return "es" if village != null and str(village.dialogue_locale) == "es" else "en"

func _refresh_locale() -> void:
    _last_locale = _locale()
    work_button.text = str(LABELS[_last_locale]["button"])
    work_button.tooltip_text = str(LABELS[_last_locale]["tip"])

func _blocked() -> bool:
    if get_tree().paused:
        return true
    if village == null:
        return true
    if village.social_journal != null and village.social_journal.panel != null:
        return village.social_journal.panel.visible
    return false

func _process(_delta: float) -> void:
    if work_button == null:
        return
    if _last_locale != _locale():
        _refresh_locale()
    var blocked: bool = _blocked()
    if work_button.disabled != blocked:
        work_button.disabled = blocked

func _display_result(message: String) -> String:
    last_result = message
    feedback_label.text = message
    if village != null and village.game != null and village.game.has_method("_show"):
        village.game._show(message)
    return message

func _perform_job() -> String:
    # Modal/paused interactions must never charge energy or grant currency.
    if _blocked():
        return ""
    var hero: Variant = village._host_property("hero", null)
    if not (hero is Node3D) or not is_instance_valid(hero):
        return _display_result(str(LABELS[_locale()]["missing"]))
    # Exactly one authority: same nearest-resident, clock, energy, pay and
    # monotonic-epoch checks as the existing keyboard K route.
    return _display_result(village.act("job", hero.global_position))

func _input(event: InputEvent) -> void:
    # Controller X is a shortcut when the journal is closed; it cannot bypass
    # the modal pause gate. Focused buttons also support standard UI accept.
    if event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_X and not _blocked():
            _perform_job()
            get_viewport().set_input_as_handled()
