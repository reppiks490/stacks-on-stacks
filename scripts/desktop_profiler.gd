extends CanvasLayer
## Desktop GPU/CPU pacing instrument. F9 begins/stops a 30-second real run.
## Results are written only when sampled on the player's actual machine.
const REPORT_PATH := "user://everbloom_performance_latest.json"
const SAMPLE_DURATION: float=30.0
var game
var overlay: PanelContainer
var status: Label
var running: bool=false
var elapsed: float=0.0
var fps_samples: Array[float]=[]
var frame_ms_samples: Array[float]=[]
var draw_calls: Array[float]=[]
var memory_peak_mb: float=0.0
var sample_clock: float=0.0
var monitor_enabled: bool=true
var last_report: Dictionary={}

func setup(host) -> void:
    game=host
    layer=8
    _make_overlay()
    set_process(true)

func _make_overlay() -> void:
    overlay=PanelContainer.new()
    overlay.position=Vector2(820,14)
    overlay.custom_minimum_size=Vector2(300,0)
    overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(0.045,0.12,0.14,0.83)
    style.border_color=Color("#bdb79e")
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.content_margin_left=13
    style.content_margin_right=13
    style.content_margin_top=8
    style.content_margin_bottom=8
    overlay.add_theme_stylebox_override("panel",style)
    add_child(overlay)
    status=Label.new()
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size=Vector2(274,45)
    status.add_theme_font_size_override("font_size",12)
    status.add_theme_color_override("font_color",Color("#f6e9d0"))
    overlay.add_child(status)
    status.text="LIVE FPS / DEVICE PROFILER\nF9: 30s benchmark   F10: hide"

func _start_report() -> void:
    running=true
    elapsed=0.0
    sample_clock=0.0
    fps_samples.clear()
    frame_ms_samples.clear()
    draw_calls.clear()
    memory_peak_mb=0.0
    if game!=null:
        game._show("Benchmark started: explore, travel or ride normally for 30 seconds.")

func _percentile(sorted: Array[float],ratio: float) -> float:
    if sorted.is_empty():
        return 0.0
    var index: int=clampi(int(floor(float(sorted.size()-1)*ratio)),0,sorted.size()-1)
    return sorted[index]

func _mean(data: Array[float]) -> float:
    if data.is_empty():
        return 0.0
    var total: float=0.0
    for value in data:
        total+=value
    return total/float(data.size())

func _sample_frame(delta: float) -> void:
    if delta>0.0 and delta<0.5:
        frame_ms_samples.append(delta*1000.0)
    sample_clock+=delta
    if sample_clock>=1.0:
        sample_clock-=1.0
        fps_samples.append(float(Engine.get_frames_per_second()))
        draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        memory_peak_mb=maxf(memory_peak_mb,float(Performance.get_monitor(Performance.MEMORY_STATIC))/1048576.0)

func _write_report() -> void:
    running=false
    if fps_samples.is_empty() or frame_ms_samples.is_empty():
        status.text="Profiler: no complete FPS sample collected. F9 to retry."
        return
    var sorted_fps: Array[float]=fps_samples.duplicate()
    sorted_fps.sort()
    var sorted_frame_ms: Array[float]=frame_ms_samples.duplicate()
    sorted_frame_ms.sort()
    last_report={
        "game":"EVERBLOOM: The Living Valley",
        "source":"Actual on-device Godot Engine/Performance monitors",
        "renderer":"Godot running client — check Project Settings for renderer tier",
        "os":OS.get_name(),
        "elapsed_seconds":snappedf(elapsed,0.01),
        "fps_mean":snappedf(_mean(fps_samples),0.1),
        "fps_p10":snappedf(_percentile(sorted_fps,0.10),0.1),
        "fps_min":snappedf(sorted_fps[0],0.1),
        "fps_max":snappedf(sorted_fps[sorted_fps.size()-1],0.1),
        "frame_ms_mean":snappedf(_mean(frame_ms_samples),0.01),
        "frame_ms_p95":snappedf(_percentile(sorted_frame_ms,0.95),0.01),
        "draw_calls_mean":snappedf(_mean(draw_calls),0.1),
        "static_memory_peak_mb":snappedf(memory_peak_mb,0.1),
        "camera_position":[
            game.hero.global_position.x,game.hero.global_position.y,game.hero.global_position.z
        ] if game!=null and game.hero!=null else [],
        "samples_1sec":fps_samples.size(),
        "samples_frames":frame_ms_samples.size()
    }
    var file:=FileAccess.open(REPORT_PATH,FileAccess.WRITE)
    if file==null:
        status.text="Profiler finished but JSON could not be written."
        push_warning("EVERBLOOM performance report write failed")
        return
    file.store_string(JSON.stringify(last_report,"  "))
    file.close()
    status.text="BENCHMARK COMPLETE\nAvg %.1f  P10 %.1f FPS  P95 %.1f ms\nF9 new test; report saved to user data." % [
        float(last_report["fps_mean"]),float(last_report["fps_p10"]),
        float(last_report["frame_ms_p95"])]
    if game!=null:
        game._show("Real-device benchmark saved: %s" % OS.get_user_data_dir())

func _process(delta: float) -> void:
    if running:
        elapsed+=delta
        _sample_frame(delta)
        status.text="BENCHMARK %.0f / 30s\nFPS %d   Draw %d   Peak RAM %.0f MB" % [
            elapsed,Engine.get_frames_per_second(),
            int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
            memory_peak_mb]
        if elapsed>=SAMPLE_DURATION:
            _write_report()
    elif last_report.is_empty():
        status.text="LIVE FPS  %d   |   F9 30s benchmark\nF10 hide • world/farm/city comparisons" % Engine.get_frames_per_second()

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode==KEY_F9:
        if running:
            _write_report()
        else:
            _start_report()
        get_viewport().set_input_as_handled()
    elif event.keycode==KEY_F10:
        monitor_enabled=not monitor_enabled
        overlay.visible=monitor_enabled
        get_viewport().set_input_as_handled()
