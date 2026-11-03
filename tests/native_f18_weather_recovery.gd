extends SceneTree
const Weather = preload("res://scripts/farming_weather_recovery.gd")
func _initialize() -> void:
    var a = Weather.new(30, 40)
    var b = Weather.new(30, 40)
    for epoch in range(112):
        var event_name: String = ["clear", "heat", "storm", "flood", "frost", "drought"][epoch % 6]
        assert(a.advance(epoch, event_name, 2)["ok"])
        assert(b.advance(epoch, event_name, 2)["ok"])
        assert(not a.advance(epoch, event_name, 2)["ok"])
        if epoch % 9 == 0:
            var id := "care_%d" % epoch
            assert(a.recover(id, 0, "heat") == b.recover(id, 0, "heat"))
            assert(not a.recover(id, 0, "heat")["ok"])
        if epoch % 14 == 0:
            var json: String = JSON.stringify(a.snapshot())
            var parsed = JSON.parse_string(json)
            var resumed = Weather.new()
            assert(resumed.restore(parsed))
            a = resumed
        assert(a.snapshot() == b.snapshot())
        assert(a.recovery_credits >= 0)
        assert(a.credits_spent + a.recovery_credits == 40)
        for stress in a.bed_stress:
            assert(stress >= 0 and stress <= 100)
    var corrupt = a.snapshot()
    corrupt["bed_stress"][0] = -1
    var before = a.snapshot()
    assert(not a.restore(corrupt))
    assert(a.snapshot() == before)
    print("F18 deterministic 112-day weather/recovery acceptance PASS")
    quit(0)
