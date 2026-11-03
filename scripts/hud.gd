extends CanvasLayer
## Original restrained HUD: vital info in two compact ribbons instead of a full-screen banner.
var game
var header: Label
var stats: Label
var status: Label
var inventory: Label
var festival_line: Label
var controls: Label
var tool_line: Label
var energy: ProgressBar
var restoration: ProgressBar
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var help_panel: PanelContainer
var help_open: bool = false

func setup(host) -> void:
    game = host
    top_panel = _panel(Vector2(15,12),Vector2(640,122))
    var top_box := VBoxContainer.new()
    top_box.add_theme_constant_override("separation",4)
    top_panel.add_child(top_box)
    header = _label(21,Color("#f9dfa6"))
    top_box.add_child(header)
    stats = _label(13,Color("#e7f0df"))
    top_box.add_child(stats)
    var meters := HBoxContainer.new()
    meters.add_theme_constant_override("separation",12)
    top_box.add_child(meters)
    var energy_section := VBoxContainer.new()
    energy_section.custom_minimum_size = Vector2(240,0)
    meters.add_child(energy_section)
    var energy_label := _label(12,Color("#e3dbc3"))
    energy_label.text = "ENERGY"
    energy_section.add_child(energy_label)
    energy = _progress(Color("#8cc79a"),100)
    energy_section.add_child(energy)
    var valley_section := VBoxContainer.new()
    valley_section.custom_minimum_size = Vector2(240,0)
    meters.add_child(valley_section)
    var valley_label := _label(12,Color("#e3dbc3"))
    valley_label.text = "VALLEY RESTORATION"
    valley_section.add_child(valley_label)
    restoration = _progress(Color("#e3be79"),100)
    valley_section.add_child(restoration)
    bottom_panel = _panel(Vector2(15,0),Vector2(685,99))
    var bottom_box := VBoxContainer.new()
    bottom_box.add_theme_constant_override("separation",4)
    bottom_panel.add_child(bottom_box)
    tool_line = _label(15,Color("#f5dea4"))
    bottom_box.add_child(tool_line)
    status = _label(13,Color("#f6f6eb"))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size = Vector2(630,32)
    bottom_box.add_child(status)
    inventory = _label(12,Color("#b8d4c3"))
    bottom_box.add_child(inventory)
    festival_line = _label(12,Color("#d8cdae"))
    bottom_box.add_child(festival_line)
    help_panel = _panel(Vector2(15,150),Vector2(575,0))
    var guide := VBoxContainer.new()
    guide.add_theme_constant_override("separation",6)
    help_panel.add_child(guide)
    var help_title := _label(19,Color("#f9dfa6"))
    help_title.text = "VALLEY FIELD GUIDE"
    guide.add_child(help_title)
    controls = _label(14,Color("#f1eedd"))
    controls.text = "WASD  Walk     E  Interact     1–7  Tools     Q  Seeds\nG  Gift     K  Job     H  Ship     J  Fish     T  Festival\nR  Craft     F  Rest     P / O  Save / Load\nC  Character Atelier     Y  Save Health     F1  Help"
    guide.add_child(controls)
    help_panel.hide()
    set_process(true)

func _panel(at: Vector2, size: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.position = at
    panel.custom_minimum_size = size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.045,0.13,0.14,0.84)
    style.border_color = Color(0.68,0.58,0.38,0.85)
    style.set_border_width_all(1)
    style.set_corner_radius_all(13)
    style.content_margin_left = 15
    style.content_margin_right = 15
    style.content_margin_top = 11
    style.content_margin_bottom = 11
    style.shadow_color = Color(0.02,0.04,0.04,0.32)
    style.shadow_size = 8
    panel.add_theme_stylebox_override("panel",style)
    add_child(panel)
    return panel

func _label(size: int, tint: Color) -> Label:
    var item := Label.new()
    item.add_theme_font_size_override("font_size",size)
    item.add_theme_color_override("font_color",tint)
    item.add_theme_color_override("font_shadow_color",Color(0.02,0.05,0.06,0.8))
    item.add_theme_constant_override("shadow_offset_x",1)
    item.add_theme_constant_override("shadow_offset_y",1)
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return item

func _progress(color: Color, maximum: float) -> ProgressBar:
    var item := ProgressBar.new()
    item.max_value = maximum
    item.value = maximum
    item.show_percentage = false
    item.custom_minimum_size = Vector2(232,9)
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var track := StyleBoxFlat.new()
    track.bg_color = Color(0.16,0.24,0.23,0.94)
    track.set_corner_radius_all(5)
    item.add_theme_stylebox_override("background",track)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.set_corner_radius_all(5)
    item.add_theme_stylebox_override("fill",fill)
    return item

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
        help_open = not help_open
        help_panel.visible = help_open
        get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
    if game == null:
        return
    var viewport_height: float = get_viewport().get_visible_rect().size.y
    bottom_panel.position.y = maxf(185.0,viewport_height-114.0)
    var hours := int(game.minute_of_day / 60.0)
    var minutes := int(game.minute_of_day) % 60
    header.text = "✦  EVERBLOOM   /   THE LIVING VALLEY"
    stats.text = "%s · Day %d   |   %02d:%02d   |   %s   |   %d Petals   |   F1 Guide" % [
        game.season(),game.day,hours,minutes,game.weather,game.gold]
    energy.value = game.energy
    restoration.value = game.restoration
    tool_line.text = "TOOL  %d/7  %s     •     SEED  %s     •     C  Customize" % [
        game.selected_tool+1,game.TOOLS[game.selected_tool].to_upper(),game.current_seed()]
    status.text = game.latest_message
    var items: Array[String] = []
    for key in game.inventory:
        if int(game.inventory[key]) > 0:
            items.append("%s ×%d" % [str(key),int(game.inventory[key])])
    inventory.text = "SATCHEL   " + "   /   ".join(items.slice(0,7))
    if game.festivals != null:
        festival_line.text = game.festivals.status_line()
