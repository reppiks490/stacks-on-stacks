extends CanvasLayer
## Readable text HUD. Original art pass and remappable controller/touch UI pending.
var game
var header: Label
var controls: Label
var status: Label
var inventory: Label
var festival_line: Label

func setup(host) -> void:
    game = host
    var wash := ColorRect.new()
    wash.color = Color(0.08,0.16,0.16,0.77)
    wash.position = Vector2(12,12)
    wash.size = Vector2(930,185)
    add_child(wash)
    header = _label(Vector2(24,18),18)
    controls = _label(Vector2(24,48),14)
    status = _label(Vector2(24,95),16)
    inventory = _label(Vector2(24,126),14)
    festival_line = _label(Vector2(24,153),13)

func _label(at: Vector2, size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.add_theme_font_size_override("font_size",size)
    label.add_theme_color_override("font_color",Color("#fff3d8"))
    label.add_theme_color_override("font_shadow_color",Color(0.1,0.1,0.1,0.9))
    label.add_theme_constant_override("shadow_offset_x",1)
    label.add_theme_constant_override("shadow_offset_y",1)
    add_child(label)
    return label

func _process(_delta: float) -> void:
    if game == null:
        return
    var hours := int(game.minute_of_day / 60.0)
    var minutes := int(game.minute_of_day) % 60
    header.text = "🌿 EVERBLOOM   %s %d   %02d:%02d   %s   Petals %d   Energy %d   Valley %d%%" % [
        game.season(),game.day,hours,minutes,game.weather,game.gold,int(game.energy),game.restoration]
    controls.text = "WASD Move | E Action | 1-7 Tools | Q Seeds | G Gift | K Job | H Ship | J Fish | T Festival\nR Craft | F Sleep | P/O Save/Load"
    status.text = "%s  •  Seed: %s  •  %s" % [game.TOOLS[game.selected_tool],game.current_seed(),game.latest_message]
    var items: Array[String] = []
    for key in game.inventory:
        if int(game.inventory[key]) > 0:
            items.append("%s:%d" % [str(key),int(game.inventory[key])])
    inventory.text = "Satchel: " + ", ".join(items.slice(0,10))
    if game.festivals != null:
        festival_line.text = game.festivals.status_line()
