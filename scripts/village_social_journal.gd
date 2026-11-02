extends CanvasLayer
## V19: first-party read-only social recap, derived from authoritative Village state.
## Does not mint rewards or introduce a new save schema.
var village
var opener: Button
var panel: PanelContainer
var entries: VBoxContainer
var close_button: Button
var rendered_text: String = ""
var paused_before_open: bool = false

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
    opener.text = "Neighbors [L]"
    opener.tooltip_text = "Open the social journal (L, controller Back, or tap)"
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
    panel.anchor_left = 0.09
    panel.anchor_top = 0.08
    panel.anchor_right = 0.91
    panel.anchor_bottom = 0.92
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.055, 0.11, 0.13, 0.97)
    background.border_color = Color(0.66, 0.81, 0.68)
    background.set_border_width_all(2)
    background.set_content_margin_all(18)
    panel.add_theme_stylebox_override("panel", background)
    surface.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    panel.add_child(layout)
    var header := HBoxContainer.new()
    layout.add_child(header)
    var title := Label.new()
    title.text = "Larkspur • Neighbors & Memories"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 22)
    header.add_child(title)
    close_button = Button.new()
    close_button.name = "CloseSocialJournal"
    close_button.text = "Close"
    close_button.tooltip_text = "Return to the valley (Escape, L or controller Back)"
    close_button.focus_mode = Control.FOCUS_ALL
    close_button.pressed.connect(close_journal)
    header.add_child(close_button)

    var hint := Label.new()
    hint.text = "Read-only memories • scroll with arrows, wheel, swipe or controller"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(hint)

    var scroller := ScrollContainer.new()
    scroller.name = "NeighborRecapScroll"
    scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroller)
    entries = VBoxContainer.new()
    entries.name = "NeighborRecapEntries"
    entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    entries.add_theme_constant_override("separation", 14)
    scroller.add_child(entries)

    var footer := Label.new()
    footer.text = "Memories are earned through conversations, gifts, shifts and celebrations."
    footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(footer)
    panel.visible = false

func refresh() -> void:
    if village == null or entries == null:
        return
    for child in entries.get_children():
        child.queue_free()
    var lines: Array[String] = []
    for record in village.social_recap():
        var last_gift: String = str(record["last_gift_item"])
        if last_gift.is_empty():
            last_gift = "none yet"
        var line: String = "%s — %s\nFriendship: %d (%s)\nConversations: %d  •  Gifts: %d  •  Work shifts: %d  •  Festival visits: %d\nLast gift: %s  •  Recollections: %d" % [
            record["name"], record["role"], record["friendship"], record["tier"],
            record["talks"], record["gifts"], record["jobs"], record["festivals"],
            last_gift, record["gift_recollections"]]
        lines.append(line)
        var label := Label.new()
        label.text = line
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        entries.add_child(label)
    rendered_text = "\n\n".join(lines)

func open_journal() -> void:
    if panel == null or panel.visible:
        return
    refresh()
    paused_before_open = get_tree().paused
    get_tree().paused = true
    panel.visible = true
    opener.visible = false
    close_button.grab_focus()

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

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if not event.pressed or event.echo:
            return
        if event.physical_keycode == KEY_L or event.keycode == KEY_L:
            toggle_journal()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible and event.keycode == KEY_ESCAPE:
            close_journal()
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_BACK:
            toggle_journal()
            get_viewport().set_input_as_handled()
        elif panel != null and panel.visible and event.button_index == JOY_BUTTON_B:
            close_journal()
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if panel != null and panel.visible and get_tree() != null:
        get_tree().paused = paused_before_open
