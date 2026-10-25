extends SceneTree

# The same reconstruction used by the interactive viewer is baked at conversion
# time. No second set of Britain-specific fixes and no mutation of source IR.
func _initialize() -> void: call_deferred("run")

func own_children(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = owner_root
		own_children(child,owner_root)

func mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children(): count += mesh_count(child)
	return count

func run() -> void:
	var output := ""
	var source := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.substr(9)
		if arg.begins_with("--world="): source = arg.substr(8)
	if output.is_empty() or source.is_empty():
		push_error("Conversion pass requires --world=IR.json and --output=directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	await process_frame
	if scene.reconstruction.unresolved > 0:
		scene.reconstruction.save_report(output.path_join("reconstruction.json"))
		push_error("Unmapped source IDs require new shared rules; see reconstruction.json")
		scene.free()
		quit(1)
		return
	var baked := Node3D.new()
	baked.name = "ConvertedWorld"
	baked.set_meta("source_ir_sha256",FileAccess.get_sha256(source))
	for child in scene.get_children():
		if child == scene.static_root or child.name == "BlendedTerrain" or child.name == "DistrictLighting" or child is StaticBody3D:
			var copy: Node = child.duplicate()
			baked.add_child(copy)
			copy.set_script(null)
	own_children(baked,baked)
	var packed := PackedScene.new()
	var result := packed.pack(baked)
	if result == OK: result = ResourceSaver.save(packed,output.path_join("converted-world.tscn"))
	if result == OK:
		var saved: PackedScene = ResourceLoader.load(output.path_join("converted-world.tscn"),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		if saved == null: result = ERR_FILE_CORRUPT
		else:
			var restored := saved.instantiate()
			print("BAKE RELOAD: ",mesh_count(restored)," / ",mesh_count(baked)," meshes")
			if mesh_count(restored) != mesh_count(baked): result = ERR_FILE_CORRUPT
			restored.free()
	scene.reconstruction.save_report(output.path_join("reconstruction.json"))
	var rules := {}
	var files := DirAccess.get_files_at("res://Presentation")
	files.sort()
	for file in files:
		if file.get_extension() in ["gd","gdshader","gdshaderinc","json"]:
			rules["Presentation/"+file] = FileAccess.get_sha256("res://Presentation/"+file)
	rules["World.gd"] = FileAccess.get_sha256("res://World.gd")
	var peaks: Array = []
	for cell in scene.terrain_surface.peak_repairs:
		peaks.append({"x":cell.x,"y":cell.y,"source_z":scene.terrain_surface.samples[cell].z,"display_z":scene.terrain_surface.peak_repairs[cell]})
	var manifest := {"schema":1,"source_ir_sha256":FileAccess.get_sha256(source),"godot":Engine.get_version_info().string,"rule_sha256":rules,"source_statics":scene.world.statics.size(),"accounted":scene.reconstruction.mapped,"unmapped":scene.reconstruction.unresolved,"derived_ceiling_panels":scene.interior_shell.ceilings.size(),"natural_peak_repairs":peaks,"terrain_floor_overrides":scene.terrain_surface.floor_overrides.size(),"architecture":scene.reconstruction.facade.audit(),"scene":"converted-world.tscn","coverage":"reconstruction.json","assets":"References installed project assets; do not redistribute proprietary input or derived output."}
	var file := FileAccess.open(output.path_join("conversion-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("CONVERSION RECONSTRUCTION: ",manifest.accounted," source records; ",manifest.derived_ceiling_panels," ceiling panels; baked scene result ",result)
	baked.free()
	scene.free()
	for i in 3: await process_frame
	quit(0 if result == OK else 1)
