extends RefCounted
# "Classic" Britain keeps the reviewed looks; "modern" Britain also uses the
# owner-pack and CC0 library models wherever an item family has a matching slot
# (as graphics outside Britain always do). Each mode has its own prepared city
# cache, so switching back is instant. Saved in user://graphics.cfg; the bake and
# tests may force it with --modern-britain / --classic-britain.
const SETTINGS := "user://graphics.cfg"
static var cached := -1

static func modern() -> bool:
	if cached < 0:
		cached = 0
		var config := ConfigFile.new()
		if config.load(SETTINGS) == OK and str(config.get_value("graphics","britain","classic")) == "modern": cached = 1
		for arg in OS.get_cmdline_user_args():
			if arg == "--modern-britain": cached = 1
			if arg == "--classic-britain": cached = 0
	return cached == 1

static func set_modern(enabled: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("graphics","britain","modern" if enabled else "classic")
	config.save(SETTINGS)
	cached = 1 if enabled else 0

static func prepared(directory: String) -> String:
	return directory.path_join("prepared-modern" if modern() else "prepared")
