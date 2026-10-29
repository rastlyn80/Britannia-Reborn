extends RefCounted
# Settings per account and character: sound and music volume, interface size,
# gamepad, sky and every window's place. They switch when a character enters
# the world (the same account-serial key as its quickbar). Every change is
# also kept as the computer-wide "last used" value, so a character that has
# never played starts from what you used last. The world look (modern or
# classic) stays computer-wide: it picks the prepared world before sign-in.
const GLOBAL := "user://settings.cfg"
const FOLDER := "user://profiles"
static var key := ""

static func activate(profile_key: String) -> void:
	key = profile_key.validate_filename()

static func deactivate() -> void:
	key = ""

static func active() -> bool:
	return key != ""

static func _path() -> String:
	return "%s/%s.cfg" % [FOLDER,key]

static func value(section: String, name: String, fallback: Variant) -> Variant:
	if active():
		var own := ConfigFile.new()
		if own.load(_path()) == OK and own.has_section_key(section,name): return own.get_value(section,name)
	var shared := ConfigFile.new()
	if shared.load(GLOBAL) == OK and shared.has_section_key(section,name): return shared.get_value(section,name)
	return fallback

static func store(section: String, name: String, setting: Variant) -> void:
	var paths: Array = [GLOBAL]
	if active():
		DirAccess.make_dir_recursive_absolute(FOLDER)
		paths.append(_path())
	for path in paths:
		var config := ConfigFile.new()
		config.load(path)
		config.set_value(section,name,setting)
		config.save(path)

# Window places: the character's own, falling back to the last used anywhere.
static func windows_path() -> String:
	return "%s/%s.windows.json" % [FOLDER,key] if active() else "user://ui/windows.json"
