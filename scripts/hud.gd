extends CanvasLayer
## Unstyled, readable proof-of-play interface. Full accessibility pass pending.
signal faction_chosen(faction_id: String)

var _hp: Label
var _stamina: Label
var _quest: Label
var _status: Label
var _faction: Label
var _dialog: PanelContainer
var _faction_id: String = ""
var _last_status_until: float = 0.0

func _ready() -> void:
    var panel := PanelContainer.new()
    panel.offset_left = 18.0
    panel.offset_top = 16.0
    panel.offset_right = 475.0
    panel.offset_bottom = 194.0
    add_child(panel)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 7)
    panel.add_child(vbox)
    var title := Label.new()
    title.text = "SABLESTAR  /  THE BROKEN MERIDIAN"
    vbox.add_child(title)
    _hp = Label.new()
    vbox.add_child(_hp)
    _stamina = Label.new()
    vbox.add_child(_stamina)
    _quest = Label.new()
    _quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vbox.add_child(_quest)
    _faction = Label.new()
    vbox.add_child(_faction)
    _status = Label.new()
    vbox.add_child(_status)

    var control := Label.new()
    control.text = "WASD move  •  Mouse look  •  LMB strike  •  F pulse  •  Ctrl dodge  •  E interact  •  F5/F9 save/load"
    control.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    control.offset_top = -54.0
    control.offset_bottom = -13.0
    control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(control)

    _dialog = PanelContainer.new()
    _dialog.set_anchors_preset(Control.PRESET_CENTER)
    _dialog.position = Vector2(420, 230)
    _dialog.custom_minimum_size = Vector2(410, 180)
    _dialog.visible = false
    add_child(_dialog)
    var choices := VBoxContainer.new()
    choices.add_theme_constant_override("separation", 10)
    _dialog.add_child(choices)
    var prompt := Label.new()
    prompt.text = "A CHOICE THAT CANNOT BE REVOKED"
    choices.add_child(prompt)
    var ember := Button.new()
    ember.text = "[1] Empower the Ember Cartographers"
    ember.pressed.connect(func() -> void: _submit("FAC-01"))
    choices.add_child(ember)
    var hollow := Button.new()
    hollow.text = "[2] Empower the Hollow Accord"
    hollow.pressed.connect(func() -> void: _submit("FAC-02"))
    choices.add_child(hollow)
    var cancel := Button.new()
    cancel.text = "[Esc] Leave the beacon"
    cancel.pressed.connect(close_choice)
    choices.add_child(cancel)

func update_stats(hp: float, stamina: float, session) -> void:
    _hp.text = "VITALITY   %03d / 120" % int(hp)
    _stamina.text = "RESONANCE STAMINA   %03d / 100    FRAGMENTS %d" % [int(stamina), session.fragments]
    _quest.text = "OBJECTIVE   " + session.objective_text()
    _faction.text = "ALLEGIANCE   " + (session.chosen_faction if session.chosen_faction != "" else "UNBOUND")
    if Time.get_ticks_msec() / 1000.0 > _last_status_until:
        _status.text = ""

func notify(message: String, seconds: float = 3.5) -> void:
    _status.text = message
    _last_status_until = Time.get_ticks_msec() / 1000.0 + seconds

func open_choice() -> void:
    _dialog.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_choice() -> void:
    _dialog.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func choice_is_open() -> bool:
    return _dialog.visible

func _submit(id: String) -> void:
    _faction_id = id
    faction_chosen.emit(id)
    close_choice()

func _unhandled_input(event: InputEvent) -> void:
    if not _dialog.visible or not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_1:
        _submit("FAC-01")
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_2:
        _submit("FAC-02")
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE:
        close_choice()
        get_viewport().set_input_as_handled()
