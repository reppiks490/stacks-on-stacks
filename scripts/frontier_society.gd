extends Node3D
## Runtime frontier society. Existing Larkspur villagers and core save stay authoritative.
## Distinct settlement NPCs use their own optional profile: no schema-1 save migration.
const PROFILE_PATH := "user://everbloom_frontier_social.cfg"
const GIVEN := ["Ayla","Cassian","Mira","Bryn","Orin","Elodie","Kael","Nessa","Iris","Rowan","Sera","Theo","Veda","Lucan","Celeste","Tarin","Lumi","Alden"]
const FAMILY := ["Willow","Riversong","Silverleaf","Suncrest","Wildrose","Thistledown","Pine","Ashbourne","Meadowmere","Moonglen","Dewfall","Fairwind"]
const ROLES := ["Florist","Baker","Blacksmith","Naturalist","Seamstress","Cartographer","Herbalist","Gardener","Librarian","Fisher","Ranger","Merchant","Musician","Carpenter","Storyteller","Stablekeeper"]
const GIFTS := ["wild_herb","wood","stone","fodder"]
const FASHION := [
    {"name":"Orchard Straw Hat","price":45,"field":"headwear","value":1},
    {"name":"Starlit Spectacles","price":95,"field":"accessory","value":1},
    {"name":"Festival Pearl Earrings","price":85,"field":"accessory","value":2},
    {"name":"Wildrose Ribbon","price":70,"field":"accessory","value":3},
    {"name":"Golden Hour Scarf","price":120,"field":"accessory","value":4},
    {"name":"Wayfarer Satchel","price":135,"field":"accessory","value":5},
    {"name":"Blossom Crown","price":90,"field":"headwear","value":4},
    {"name":"Royal Velvet Beret","price":160,"field":"headwear","value":3}
]
var game
var continent
var active: Dictionary = {}
var memory: Dictionary = {}
var collected: Dictionary = {}
var panel_layer: CanvasLayer
var panel: PanelContainer
var title: Label
var body: Label
var fair: Label
var selected_id: String = ""
var market_index: int = 0
var drift_clock: float = 0.0

func setup(host,world) -> void:
    game=host
    continent=world
    _load()
    _create_panel()
    set_process(true)

func spawn_for_chunk(parent: Node3D,key: Vector2i,origin: Vector3) -> void:
    var list: Array=[]
    for hub in continent.HUBS:
        if str(hub["kind"])=="Homestead" or continent._cell_of(Vector2(float(hub["x"]),float(hub["z"])))!=key:
            continue
        var kind:=str(hub["kind"])
        var people:=16 if kind in ["Capital","Kingdom","City"] else (11 if kind in ["Town","Port"] else 8)
        for i in range(people):
            var a:=float(i)*TAU/float(people)
            var radius:=10.0+float(i%4)*5.0
            var world_at:=Vector3(float(hub["x"])+cos(a)*radius,0,float(hub["z"])+sin(a)*radius)
            list.append(_make_resident(parent,key,origin,world_at,str(hub["name"]),i))
    # A pair of roaming merchants or travelers on each loaded world tile.
    for i in range(2):
        var at:=origin+Vector3(-38.0+float(i)*60.0,0,30.0-float(i)*55.0)
        if not continent._safe_scatter(at.x,at.z):
            continue
        list.append(_make_resident(parent,key,origin,at,"Wayfaring Trails",key.x*13+key.y*7+i))
    active[key]=list

func _make_resident(parent: Node3D,key: Vector2i,origin: Vector3,world_at: Vector3,
        home: String,index: int) -> Dictionary:
    var name_index:=posmod(index*7+home.length(),GIVEN.size())
    var family_index:=posmod(index*5+home.length(),FAMILY.size())
    var role_index:=posmod(index*3+home.length(),ROLES.size())
    var resident_id: String=home.replace(" ","_")+"_"+str(index)
    var actor:=Node3D.new()
    actor.name="Resident_"+resident_id
    actor.position=world_at-origin
    parent.add_child(actor)
    var coat:=Color.from_hsv(float(posmod(index*37+home.length()*13,360))/360.0,0.42,0.70)
    var skin:=Color("#e3ac89") if index%3==0 else (Color("#a57159") if index%3==1 else Color("#efd0b4"))
    _body(actor,Vector3(0,1.02,0),Vector3(0.74,1.15,0.56),coat)
    _body(actor,Vector3(0,1.91,0),Vector3(0.57,0.62,0.56),skin)
    _body(actor,Vector3(0,2.24,-0.12),Vector3(0.64,0.23,0.55),Color("#60443d") if index%2==0 else Color("#b17e54"))
    for side in [-1,1]:
        _body(actor,Vector3(float(side)*0.42,1.20,0),Vector3(0.24,0.91,0.30),coat.darkened(0.11))
        _body(actor,Vector3(float(side)*0.2,0.45,0),Vector3(0.26,0.78,0.34),Color("#4d5960"))
        _body(actor,Vector3(float(side)*0.13,1.97,0.279),Vector3(0.085,0.08,0.04),Color("#243b39"))
    var badge:=Label3D.new()
    badge.text=GIVEN[name_index]+" "+FAMILY[family_index]+"\n"+ROLES[role_index]
    badge.position=Vector3(0,2.75,0)
    badge.font_size=46
    badge.pixel_size=0.003
    badge.modulate=Color("#fff3df")
    actor.add_child(badge)
    return {
        "id":resident_id,"name":GIVEN[name_index]+" "+FAMILY[family_index],
        "role":ROLES[role_index],"home":home,"node":actor,"base":actor.position,
        "sway":float(index)*0.37,"key":key
    }

func _body(parent: Node3D,at: Vector3,dimensions: Vector3,tint: Color) -> void:
    var obj:=MeshInstance3D.new()
    var mesh:=SphereMesh.new()
    mesh.radius=0.5
    mesh.height=1.0
    mesh.radial_segments=12
    mesh.rings=8
    obj.mesh=mesh
    obj.position=at
    obj.scale=dimensions
    var material:=StandardMaterial3D.new()
    material.albedo_color=tint
    material.roughness=0.88
    obj.material_override=material
    parent.add_child(obj)

func release_chunk(key: Vector2i) -> void:
    if not active.has(key):
        return
    for resident in active[key]:
        if str(resident["id"])==selected_id:
            selected_id=""
            panel.hide()
    active.erase(key)

func _process(delta: float) -> void:
    if game==null or game.hero==null:
        return
    drift_clock+=delta
    for list in active.values():
        for resident in list:
            var node: Node3D=resident["node"]
            if not is_instance_valid(node):
                continue
            var base: Vector3=resident["base"]
            var sway: float=resident["sway"]
            var hour: float=game.minute_of_day/60.0
            var duty: float=1.0 if hour>=9.0 and hour<18.0 else 0.25
            node.position=base+Vector3(sin(drift_clock*0.21+sway)*1.35*duty,0,
                cos(drift_clock*0.18+sway)*1.25*duty)
            node.rotation.y=sin(drift_clock*0.22+sway)*0.5

func _nearest() -> Dictionary:
    var nearest: Dictionary={}
    var distance: float=4.5
    if game==null or game.hero==null:
        return nearest
    for list in active.values():
        for resident in list:
            var actor: Node3D=resident["node"]
            if not is_instance_valid(actor):
                continue
            var d: float=actor.global_position.distance_to(game.hero.global_position)
            if d<distance:
                distance=d
                nearest=resident
    return nearest

func _selected() -> Dictionary:
    for list in active.values():
        for resident in list:
            if str(resident["id"])==selected_id:
                return resident
    return {}

func _interact() -> void:
    var person:=_nearest()
    if person.is_empty():
        if game!=null:
            game._show("Approach a frontier resident or flea-market stall before pressing U.")
        return
    selected_id=str(person["id"])
    panel.show()
    _talk()

func _record(id: String) -> Dictionary:
    if not memory.has(id):
        memory[id]={"affection":0,"last_help":-1,"last_gift":-1,"visits":0}
    return memory[id]

func _talk() -> void:
    var person:=_selected()
    if person.is_empty():
        panel.hide()
        return
    var entry:=_record(selected_id)
    entry["visits"]=int(entry.get("visits",0))+1
    memory[selected_id]=entry
    title.text="%s   •   %s" % [str(person["name"]),str(person["role"])]
    var messages: Array[String]=[
        "Every trail tells a different story in %s. Have you found a wildflower grove?" % str(person["home"]),
        "The best crafting ideas arrive after an early morning walk. Ask around the market!",
        "The valley changes with every season. Keep an eye out for rare seeds and local festivals.",
        "Our traders visit neighboring kingdoms. The flea market has fashions you can wear.",
        "This settlement has its own rhythm: markets by day, lantern gatherings at night."
    ]
    var index: int=posmod(int(game.day)+selected_id.length()+int(entry["visits"]),messages.size())
    body.text=messages[index]+"\n\nFriendship: %d  •  Visits: %d" % [int(entry.get("affection",0)),int(entry["visits"])]
    _refresh_fair()
    _save()

func _quest() -> void:
    var person:=_selected()
    if person.is_empty():
        return
    var entry:=_record(selected_id)
    var epoch: int=game.day_epoch()
    if int(entry.get("last_help",-1))==epoch:
        body.text="You already helped %s today. Visit again tomorrow!" % str(person["name"])
        return
    var material: String=GIFTS[posmod(selected_id.length()+int(game.day),GIFTS.size())]
    var needed: int=1+(selected_id.length()%2)
    if int(game.inventory.get(material,0))<needed:
        body.text="%s needs %d × %s for the local workshop. Gather supplies and return; daily reward: 45 petals." % [
            str(person["name"]),needed,material]
        return
    if game.consume_item(material,needed):
        entry["last_help"]=epoch
        entry["affection"]=int(entry.get("affection",0))+4
        game.gold+=45
        game.add_restoration(1)
        memory[selected_id]=entry
        body.text="Commission completed! +45 petals, +4 friendship, +1 restoration. Thank you!"
        _save()

func _gift() -> void:
    var person:=_selected()
    if person.is_empty():
        return
    var entry:=_record(selected_id)
    var epoch: int=game.day_epoch()
    if int(entry.get("last_gift",-1))==epoch:
        body.text="You already shared a gift with %s today." % str(person["name"])
        return
    if game.consume_item("wild_herb",1) or game.consume_item("fodder",1):
        entry["last_gift"]=epoch
        entry["affection"]=int(entry.get("affection",0))+3
        memory[selected_id]=entry
        body.text="%s loves your thoughtful gift. Friendship +3!" % str(person["name"])
        _save()
    else:
        body.text="Bring wild herbs or fodder to give %s a small handcrafted gift." % str(person["name"])

func _flea_open() -> bool:
    return game!=null and posmod(game.day_epoch(),7) in [1,4,6]

func _refresh_fair() -> void:
    if fair==null or game==null:
        return
    var day: int=game.day_epoch()
    if _flea_open():
        fair.text="✦  FLEA MARKET OPEN TODAY   •   artisans and fashion"
    elif day%14==8:
        fair.text="✦  HARVEST EXCHANGE DAY   •   local deliveries"
    elif day%14==12:
        fair.text="✦  LANTERN PARADE TONIGHT"
    else:
        fair.text="✦  Market exchange returns on scheduled days."

func _trade() -> void:
    if game==null:
        return
    var item: Dictionary=FASHION[market_index]
    title.text="ARTISAN FASHION • %s" % str(item["name"])
    body.text="Handmade %s\nPrice: %d petals\nYour purse: %d petals\nBrowse to switch styles; choose Purchase to equip." % [
        str(item["name"]),int(item["price"]),int(game.gold)]
    _refresh_fair()

func _browse() -> void:
    market_index=(market_index+1)%FASHION.size()
    _trade()

func _purchase() -> void:
    if game==null or game.hero==null:
        return
    var item: Dictionary=FASHION[market_index]
    var price: int=int(item["price"])
    if not _flea_open():
        body.text="This artisan is preparing stock. Flea-market trading opens on scheduled days."
        return
    if game.gold<price:
        body.text="Not enough petals. This %s costs %d." % [str(item["name"]),price]
        return
    game.gold-=price
    collected[str(item["name"])]=true
    game.hero.profile[str(item["field"])]=int(item["value"])
    game.hero._rebuild_avatar()
    game.hero._save_profile()
    body.text="Purchased and equipped: %s! Your wardrobe now remembers this style." % str(item["name"])
    _save()

func _load() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load(PROFILE_PATH)!=OK:
        return
    var saved_memory: Variant=cfg.get_value("social","relationships",{})
    var saved_collection: Variant=cfg.get_value("social","wardrobe",{})
    if saved_memory is Dictionary:
        memory=saved_memory
    if saved_collection is Dictionary:
        collected=saved_collection

func _save() -> void:
    var cfg:=ConfigFile.new()
    cfg.set_value("social","relationships",memory)
    cfg.set_value("social","wardrobe",collected)
    if cfg.save(PROFILE_PATH)!=OK:
        push_warning("EVERBLOOM frontier social data could not be saved.")

func _panel_button(parent: BoxContainer,text_value: String,callback: Callable) -> void:
    var button:=Button.new()
    button.text=text_value
    button.custom_minimum_size=Vector2(120,32)
    button.pressed.connect(callback)
    parent.add_child(button)

func _create_panel() -> void:
    panel_layer=CanvasLayer.new()
    panel_layer.layer=12
    panel_layer.name="FrontierConversationUI"
    add_child(panel_layer)
    panel=PanelContainer.new()
    panel.position=Vector2(666,155)
    panel.custom_minimum_size=Vector2(452,0)
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(0.06,0.12,0.13,0.96)
    style.border_color=Color("#d7b785")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left=14
    style.content_margin_right=14
    style.content_margin_top=12
    style.content_margin_bottom=12
    panel.add_theme_stylebox_override("panel",style)
    panel_layer.add_child(panel)
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",5)
    panel.add_child(column)
    title=Label.new()
    title.add_theme_font_size_override("font_size",19)
    title.add_theme_color_override("font_color",Color("#f0d79d"))
    column.add_child(title)
    body=Label.new()
    body.custom_minimum_size=Vector2(424,112)
    body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size",14)
    body.add_theme_color_override("font_color",Color("#ebefe7"))
    column.add_child(body)
    fair=Label.new()
    fair.add_theme_font_size_override("font_size",12)
    fair.add_theme_color_override("font_color",Color("#b6cfba"))
    column.add_child(fair)
    var row:=HBoxContainer.new()
    column.add_child(row)
    for item in [["Talk",Callable(self,"_talk")],["Help",Callable(self,"_quest")],
                 ["Gift",Callable(self,"_gift")]]:
        _panel_button(row,item[0],item[1])
    var shop:=HBoxContainer.new()
    column.add_child(shop)
    _panel_button(shop,"Market",Callable(self,"_trade"))
    _panel_button(shop,"Next Item",Callable(self,"_browse"))
    _panel_button(shop,"Purchase",Callable(self,"_purchase"))
    _panel_button(column,"Close",Callable(panel,"hide"))
    panel.hide()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if game!=null and game.hero!=null and game.hero.studio_open:
        return
    if event.keycode==KEY_U:
        if panel.visible:
            panel.hide()
        else:
            _interact()
        get_viewport().set_input_as_handled()
