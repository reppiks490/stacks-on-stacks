extends SceneTree
# P13/P14/P16: renderer-backed capture of the ACTUAL game scene.
# Requires graphical Godot; process time is not GPU time or FPS.
const SCENE_PATH := "res://scenes/main.tscn"
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 120
const OUTPUT_NAME := "everbloom_principal_actual_scene.png"
const METADATA_NAME := "everbloom_principal_actual_scene.json"

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var error := change_scene_to_file(SCENE_PATH)
    if error != OK:
        push_error("VISUAL CAPTURE: scene load failed: %d" % error)
        quit(2)
        return
    for i in range(WARMUP_FRAMES):
        await process_frame
    if current_scene == null:
        push_error("VISUAL CAPTURE: no instantiated game scene")
        quit(3)
        return
    var viewport := current_scene.get_viewport()
    var camera := viewport.get_camera_3d()
    if camera == null:
        push_error("VISUAL CAPTURE: no active Camera3D")
        quit(3)
        return
    # Record the camera BEFORE sampling; moving cameras invalidate matched comparisons.
    var initial_transform := camera.global_transform
    var initial_fov := camera.fov
    var frame_times: Array[float] = []
    var draw_calls: Array[int] = []
    for i in range(SAMPLE_FRAMES):
        await process_frame
        frame_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
        draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
    if camera.global_transform != initial_transform or not is_equal_approx(camera.fov, initial_fov):
        push_error("VISUAL CAPTURE: camera moved during sampling; comparison invalid")
        quit(6)
        return
    await RenderingServer.frame_post_draw
    var shot := viewport.get_texture().get_image()
    if shot == null or shot.is_empty() or shot.get_width() < 2 or shot.get_height() < 2:
        push_error("VISUAL CAPTURE: invalid renderer output")
        quit(4)
        return
    var image_path := "user://" + OUTPUT_NAME
    if shot.save_png(image_path) != OK:
        push_error("VISUAL CAPTURE: screenshot write failed")
        quit(5)
        return
    var total_ms := 0.0
    var max_ms := 0.0
    var total_calls := 0
    for i in range(frame_times.size()):
        total_ms += frame_times[i]
        max_ms = maxf(max_ms, frame_times[i])
        total_calls += draw_calls[i]
    var metadata := {
        "scene": SCENE_PATH,
        "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
        "camera_path": str(camera.get_path()),
        "camera_transform": str(initial_transform),
        "camera_fov": initial_fov,
        "viewport_width": shot.get_width(),
        "viewport_height": shot.get_height(),
        "warmup_frames": WARMUP_FRAMES,
        "sample_frames": SAMPLE_FRAMES,
        "mean_process_ms": total_ms / SAMPLE_FRAMES,
        "max_process_ms": max_ms,
        "mean_draw_calls": float(total_calls) / SAMPLE_FRAMES,
        "limitations": "Not GPU timing, FPS, visual acceptance, collision, save, or mobile evidence"
    }
    var file := FileAccess.open("user://" + METADATA_NAME, FileAccess.WRITE)
    if file == null:
        push_error("VISUAL CAPTURE: metadata write failed")
        quit(7)
        return
    file.store_string(JSON.stringify(metadata, "\t") + "\n")
    file.close()
    print("VISUAL CAPTURE PASS image=%s metadata=%s" % [ProjectSettings.globalize_path(image_path), ProjectSettings.globalize_path("user://" + METADATA_NAME)])
    print("PROCESS mean_ms=%.3f max_ms=%.3f; DRAW CALLS mean=%.1f; NOT FPS/GPU" % [metadata["mean_process_ms"], max_ms, metadata["mean_draw_calls"]])
    quit(0)
