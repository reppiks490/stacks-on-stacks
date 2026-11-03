extends SceneTree
# P13/P14/P16: native, renderer-backed evidence capture of the ACTUAL game scene.
# This is a diagnostic harness, not an authored asset or visual-quality approval.
# Run with a graphical Godot instance; --headless cannot produce valid screenshots.
const SCENE_PATH := "res://scenes/main.tscn"
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 120
const OUTPUT_NAME := "everbloom_principal_actual_scene.png"

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var error := change_scene_to_file(SCENE_PATH)
    if error != OK:
        push_error("VISUAL CAPTURE: failed to load main scene: %d" % error)
        quit(2)
        return
    for i in range(WARMUP_FRAMES):
        await process_frame
    var camera := root.get_viewport().get_camera_3d()
    if camera == null:
        push_error("VISUAL CAPTURE: no active Camera3D; cannot claim screenshot evidence")
        quit(3)
        return
    var frame_times: Array[float] = []
    var draw_calls: Array[int] = []
    for i in range(SAMPLE_FRAMES):
        await process_frame
        frame_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
        draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
    await RenderingServer.frame_post_draw
    var image := root.get_viewport().get_texture().get_image()
    if image == null or image.is_empty():
        push_error("VISUAL CAPTURE: renderer produced no image")
        quit(4)
        return
    var path := "user://" + OUTPUT_NAME
    var save_error := image.save_png(path)
    if save_error != OK:
        push_error("VISUAL CAPTURE: PNG write failed: %d" % save_error)
        quit(5)
        return
    var total_ms := 0.0
    var max_ms := 0.0
    var total_calls := 0
    for i in range(frame_times.size()):
        total_ms += frame_times[i]
        max_ms = maxf(max_ms, frame_times[i])
        total_calls += draw_calls[i]
    print("VISUAL CAPTURE PASS scene=%s image=%s size=%dx%d frames=%d" % [SCENE_PATH, ProjectSettings.globalize_path(path), image.get_width(), image.get_height(), SAMPLE_FRAMES])
    print("PROCESS ONLY mean_ms=%.3f max_ms=%.3f (not full frame time or FPS)" % [total_ms / SAMPLE_FRAMES, max_ms])
    print("DRAW CALLS mean=%.1f (renderer dependent)" % [float(total_calls) / SAMPLE_FRAMES])
    print("REQUIRES separate before/after matching camera, GPU frame pacing, save/collision and mobile acceptance")
    quit(0)
