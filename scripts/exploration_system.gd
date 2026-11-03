extends Node3D
## Persistent world exploration journal for the streamed continent.
## Separate ConfigFile keeps exploration progress independent of schema-1 farm saves.
const PROFILE_PATH := "user://everbloom_exploration.cfg"
const CHECK_INTERVAL := 0.45
const DISCOVERY_RADIUS := 58.0
const BIOME_NAMES := [
    "Larkspur Meadows","Fernwater Woodlands","Amber Prairie",
    "Frostpetal Highlands","Saffron Uplands","Tideglass Coast"
]
var game
var world
var visited_hubs: Dictionary={}
var visited_biomes: Dictionary={}
var elapsed: float=0.0
var journal_layer: CanvasLayer
var panel: PanelContainer
var title: Label
var body: Label
var hint: Label
var open: bool=false
var last_hub: String=""
var last_biome: int=-1

func setup(host,continent) -> void:
    game=host
    world=continent
    _load()
    _make_journal()
    set_process(true)

func _process(delta: float) -> void:
    if game==null or game.hero==null or world==null:
        return
    elapsed+=delta
    if elapsed<CHECK_INTERVAL:
        return
    elapsed=0.0
    _discover_nearby()
    if open:
        _refresh()

func _discover_nearby() -> void:
    var pos: Vector3=game.hero.global_position
    var biome: int=world._biome(pos.x,pos.z)
    if biome!=last_biome:
        last_biome=biome
        var biome_id:=str(biome)
        if not visited_biomes.has(biome_id):
            visited_biomes[biome_id]=game.day_epoch()
            if _save():
                game.gold+=8
                game.add_restoration(1)
                game._show("Discovered region: %s • +8 petals • +1 restoration" % BIOME_NAMES[biome])
            else:
                visited_biomes.erase(biome_id)
                game._show("Discovery journal could not be saved; no reward was granted.")
    var nearest_name: String=""
    var nearest_distance: float=INF
    for hub in world.HUBS:
        var dx: float=pos.x-float(hub["x"])
        var dz: float=pos.z-float(hub["z"])
        var d: float=sqrt(dx*dx+dz*dz)
        if d<nearest_distance:
            nearest_distance=d
            nearest_name=str(hub["name"])
        if d<=DISCOVERY_RADIUS and not visited_hubs.has(str(hub["name"])):
            visited_hubs[str(hub["name"])]={
                "day_epoch":game.day_epoch(),
                "kind":str(hub["kind"]),
                "x":float(hub["x"]),
                "z":float(hub["z"])
            }
            if _save():
                game.gold+=12
                game.add_restoration(1)
                last_hub=str(hub["name"])
                game._show("First arrival: %s • +12 petals • journal updated" % last_hub)
            else:
                visited_hubs.erase(str(hub["name"]))
                game._show("Settlement journal could not be saved; no reward was granted.")
    if nearest_name!=last_hub and nearest_distance<DISCOVERY_RADIUS*1.8:
        last_hub=nearest_name

func _load() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load(PROFILE_PATH)!=OK:
        return
    var hubs: Variant=cfg.get_value("exploration","visited_hubs",{})
    var biomes: Variant=cfg.get_value("exploration","visited_biomes",{})
    if hubs is Dictionary:
        visited_hubs=hubs
    if biomes is Dictionary:
        visited_biomes=biomes

func _save() -> bool:
    var cfg:=ConfigFile.new()
    cfg.set_value("exploration","visited_hubs",visited_hubs)
    cfg.set_value("exploration","visited_biomes",visited_biomes)
    var result: Error=cfg.save(PROFILE_PATH)
    if result!=OK:
        push_warning("EVERBLOOM exploration journal could not be saved: %d" % result)
        return false
    return true

func _make_journal() -> void:
    journal_layer=CanvasLayer.new()
    journal_layer.name="ExplorerJournalUI"
    journal_layer.layer=13
    add_child(journal_layer)
    panel=PanelContainer.new()
    panel.position=Vector2(28,180)
    panel.custom_minimum_size=Vector2(520,0)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(0.045,0.10,0.12,0.96)
    style.border_color=Color("#d2b781")
    style.set_border_width_all(2)
    style.set_corner_radius_all(15)
    style.content_margin_left=18
    style.content_margin_right=18
    style.content_margin_top=16
    style.content_margin_bottom=16
    panel.add_theme_stylebox_override("panel",style)
    journal_layer.add_child(panel)
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",8)
    panel.add_child(column)
    title=Label.new()
    title.add_theme_font_size_override("font_size",21)
    title.add_theme_color_override("font_color",Color("#f2d49c"))
    column.add_child(title)
    body=Label.new()
    body.custom_minimum_size=Vector2(480,210)
    body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size",14)
    body.add_theme_color_override("font_color",Color("#e7efe4"))
    column.add_child(body)
    hint=Label.new()
    hint.text="L closes journal • discover settlements and biomes by reaching them"
    hint.add_theme_font_size_override("font_size",12)
    hint.add_theme_color_override("font_color",Color("#a8c0ae"))
    column.add_child(hint)
    panel.hide()
    _refresh()

func _refresh() -> void:
    if title==null:
        return
    title.text="EXPLORER'S JOURNAL   %d / %d settlements" % [visited_hubs.size(),world.HUBS.size()]
    var lines: Array[String]=[]
    lines.append("REGIONS DISCOVERED: %d / %d" % [visited_biomes.size(),BIOME_NAMES.size()])
    if not last_hub.is_empty():
        lines.append("NEAREST / RECENT: %s" % last_hub)
    lines.append("")
    lines.append("SETTLEMENT LOG")
    var names: Array=visited_hubs.keys()
    names.sort()
    if names.is_empty():
        lines.append("No settlements recorded yet. Leave Larkspur and follow the atlas.")
    else:
        for name in names.slice(0,12):
            var entry: Dictionary=visited_hubs[name]
            lines.append("• %s — %s" % [str(name),str(entry.get("kind","Settlement"))])
        if names.size()>12:
            lines.append("…and %d more discoveries" % (names.size()-12))
    body.text="\n".join(lines)

func _toggle_journal() -> void:
    open=not open
    panel.visible=open
    if open:
        _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if game!=null and game.hero!=null and game.hero.studio_open:
        return
    if event.keycode==KEY_L:
        _toggle_journal()
        get_viewport().set_input_as_handled()
