extends SceneTree
## Principal P04/P05/P16: genuine separate-process Linux writer-lock probe.
## Run only with an isolated XDG_DATA_HOME; never against player saves.
const SaveService = preload("res://scripts/save_service.gd")
const READY_PATH: String = "user://principal_multiprocess_ready.marker"
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    assertions += 1
    if not condition:
        failures += 1
        push_error("PRINCIPAL MULTIPROCESS FAIL: " + description)

func _payload(currency: int) -> Dictionary:
    return {
        "schema": 1, "year": 2, "season": 3, "day": 14,
        "minute": 1234.5, "gold": currency, "energy": 75.0,
        "inventory": {"turnip": currency - 100, "fodder": 4},
        "farm": [], "village": {"affection": {"mira": 8}},
        "animals": {"__paddocks__": [{"forage": 7}, {"forage": 4}, {"forage": 2}]},
        "hero_position": [0.0, 1.0, 0.0]
    }

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    _check(args.size() == 1, "exactly one probe mode supplied after --")
    if args.size() != 1:
        _finish("invalid")
        return
    var mode: String = args[0]
    var lock_path: String = ProjectSettings.globalize_path(SaveService.WRITE_LOCK_PATH)
    match mode:
        "seed":
            _check(not FileAccess.file_exists(SaveService.SAVE_PATH)
                    and not FileAccess.file_exists(SaveService.BACKUP_PATH),
                    "isolated save paths initially empty")
            _check(not DirAccess.dir_exists_absolute(lock_path),
                    "isolated lock initially absent")
            _check(SaveService.write_payload(_payload(125)), "first baseline save")
            _check(SaveService.write_payload(_payload(150)), "second baseline save")
            _check(int(SaveService.read_payload().get("gold", -1)) == 150,
                    "baseline primary has latest currency")
            _check(int(SaveService._read_one(SaveService.BACKUP_PATH).get("gold", -1)) == 125,
                    "baseline backup retains previous currency")
            _check(not FileAccess.file_exists(SaveService.TEMP_PATH),
                    "baseline leaves no temp file")
        "hold":
            _check(DirAccess.make_dir_absolute(lock_path) == OK,
                    "holder process exclusively acquired writer directory")
            if failures != 0:
                _finish(mode)
                return
            var marker: FileAccess = FileAccess.open(READY_PATH, FileAccess.WRITE)
            _check(marker != null, "holder marker can be written")
            if marker != null:
                marker.store_string("ready")
                marker.flush()
                _check(marker.get_error() == OK, "holder marker flushed")
                marker.close()
            if failures != 0:
                _finish(mode)
                return
            print("PRINCIPAL MULTIPROCESS HOLDER READY")
            OS.delay_msec(30000)
            # A normal holder releases the lock; the CI deliberately kills
            # this process first to model a crash without guessing lock age.
            _check(DirAccess.remove_absolute(lock_path) == OK,
                    "normal holder releases lock")
        "contend":
            _check(DirAccess.dir_exists_absolute(lock_path),
                    "contender observes lock held by another or crashed process")
            var before_primary: String = FileAccess.get_file_as_string(SaveService.SAVE_PATH)
            var before_backup: String = FileAccess.get_file_as_string(SaveService.BACKUP_PATH)
            _check(not before_primary.is_empty() and not before_backup.is_empty(),
                    "contender starts with both authoritative save copies")
            _check(not SaveService.write_payload(_payload(999)),
                    "contending writer fails closed")
            _check(FileAccess.get_file_as_string(SaveService.SAVE_PATH) == before_primary,
                    "rejected writer cannot change primary bytes")
            _check(FileAccess.get_file_as_string(SaveService.BACKUP_PATH) == before_backup,
                    "rejected writer cannot change backup bytes")
            _check(not FileAccess.file_exists(SaveService.TEMP_PATH),
                    "rejected writer cannot create temp")
            var observed: Dictionary = SaveService.read_payload()
            _check(int(observed.get("gold", -1)) == 150
                    and int(observed.get("inventory", {}).get("turnip", -1)) == 50,
                    "rejected writer cannot duplicate money or items")
            _check(DirAccess.dir_exists_absolute(lock_path),
                    "rejected writer never removes another process lock")
        "commit":
            _check(not DirAccess.dir_exists_absolute(lock_path),
                    "manual isolated lock recovery completed")
            _check(SaveService.write_payload(_payload(175)),
                    "post-recovery writer commits")
            var current: Dictionary = SaveService.read_payload()
            var previous: Dictionary = SaveService._read_one(SaveService.BACKUP_PATH)
            _check(int(current.get("gold", -1)) == 175
                    and int(current.get("inventory", {}).get("turnip", -1)) == 75,
                    "post-recovery currency and inventory conserved")
            _check(int(previous.get("gold", -1)) == 150
                    and int(previous.get("inventory", {}).get("turnip", -1)) == 50,
                    "post-recovery backup retains previous authoritative state")
            _check(not FileAccess.file_exists(SaveService.TEMP_PATH)
                    and not DirAccess.dir_exists_absolute(lock_path),
                    "successful commit releases lock and temp")
        _:
            _check(false, "unsupported probe mode " + mode)
    _finish(mode)

func _finish(mode: String) -> void:
    print("PRINCIPAL MULTIPROCESS %s: %d assertions, %d failures" % [
        mode, assertions, failures])
    quit(0 if failures == 0 else 1)
