extends SceneTree
# Settings per account and character (Network/Profile.gd): each character
# keeps its own; a new one starts from the last used. The real settings and
# window places are backed up first and restored after.
const Profile = preload("res://Network/Profile.gd")
const Windows = preload("res://Network/ModernWindow.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func backup(path: String) -> Variant:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null

func restore(path: String, saved: Variant) -> void:
	if saved == null:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		return
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(saved)
	file.close()

func run() -> void:
	var settings: Variant = backup(Profile.GLOBAL)
	var places: Variant = backup(Windows.PLACES)
	var a := "profile-test-a-%d" % Time.get_ticks_msec()
	var b := "profile-test-b-%d" % Time.get_ticks_msec()
	Profile.activate(a)
	Profile.store("audio","music_volume",0.2)
	Windows._write_place("testwindow",Vector2(11,22))
	Profile.deactivate()
	Profile.activate(b)
	check(is_equal_approx(float(Profile.value("audio","music_volume",0.45)),0.2),"A new character starts from the last used setting")
	check(Windows._places().get("testwindow",[]) == [11.0,22.0],"…and the last used window places")
	Profile.store("audio","music_volume",0.9)
	Windows._write_place("testwindow",Vector2(33,44))
	Profile.deactivate()
	Profile.activate(a)
	check(is_equal_approx(float(Profile.value("audio","music_volume",0.45)),0.2),"Each character keeps its own setting")
	check(Windows._places().get("testwindow",[]) == [11.0,22.0],"Each character keeps its own window places")
	Profile.activate(b)
	check(is_equal_approx(float(Profile.value("audio","music_volume",0.45)),0.9),"The other character's setting is its own too")
	Profile.deactivate()
	for key in [a,b]:
		for suffix in [".cfg",".windows.json"]:
			var path := "%s/%s%s" % [Profile.FOLDER,key,suffix]
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	restore(Profile.GLOBAL,settings)
	restore(Windows.PLACES,places)
	check(backup(Profile.GLOBAL) == settings and backup(Windows.PLACES) == places,"The real settings are untouched")
	print("PROFILE TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
