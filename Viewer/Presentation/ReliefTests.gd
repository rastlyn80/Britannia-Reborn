extends SceneTree
# Mountain relief (docs/MOUNTAINS.md): lifted corners raise the drawn terrain,
# walkable corners keep their source height, and a dataset without relief is
# unchanged.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var folder := ProjectSettings.globalize_path("user://relief-test")
	DirAccess.make_dir_recursive_absolute(folder)
	# 8 x 8 corners from (100,200); one corner lifted by 40 units (10 m).
	var bytes := PackedByteArray()
	bytes.resize(64)
	bytes[3*8+4] = 40
	var file := FileAccess.open(folder.path_join("relief.u8"),FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	file = FileAccess.open(folder.path_join("relief.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"originX":100,"originY":200,"width":8,"height":8,"unitMeters":0.25}))
	file.close()
	var Relief := preload("res://Presentation/Relief.gd")
	var relief = Relief.open(folder)
	check(relief != null and is_equal_approx(relief.at(Vector2i(104,203)),10.0) and relief.at(Vector2i(103,203)) == 0.0,"relief reads one byte per corner in quarter metres")
	var area: Dictionary = relief.area(Rect2i(98,198,6,7))
	check(area.size() == 0 and relief.area(Rect2i(100,200,8,8)).size() == 1,"an area read returns only lifted corners inside the map")
	check(Relief.open(folder.path_join("missing")) == null,"a dataset without relief has none")
	var terrain: Array = []
	for y in range(200,208):
		for x in range(100,108): terrain.append({"x":x,"y":y,"z":10,"id":3})
	var world := {"originX":100,"originY":200,"width":8,"height":8,"elevationScale":0.2,"terrain":terrain,"statics":[],"landData":{"3":{"name":"grass","flags":0}},"relief":relief}
	var surface := preload("res://Presentation/TerrainSurface.gd").new()
	surface.index(world)
	check(is_equal_approx(surface.z(Vector2i(104,203)),12.0),"a lifted corner is drawn 10 m higher (%.2f)" % surface.z(Vector2i(104,203)))
	check(is_equal_approx(surface.z(Vector2i(102,202)),2.0),"other corners keep their source height")
	world.erase("relief")
	surface.index(world)
	check(is_equal_approx(surface.z(Vector2i(104,203)),2.0),"without relief the terrain is unchanged")
	print("RELIEF TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
