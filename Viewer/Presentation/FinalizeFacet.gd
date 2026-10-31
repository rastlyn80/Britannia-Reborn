extends "res://Presentation/BakeStreaming.gd"
# Publishes a facet baked in windows (scripts/bake-facet.ps1): checks that every
# district's stamp is current, merges the windows' rule catalogs, bakes the
# regional horizon and writes the index. It plans nothing, so it has no
# district limit. Kept apart from BakeStreaming.gd on purpose: that script is
# part of every district's stamp, so editing it would mark the whole facet out
# of date; this one reuses its signature and helpers unchanged.
#   godot --headless --path Viewer --script res://Presentation/FinalizeFacet.gd -- --dataset=<dir> --modern-britain
# --accept-unchanged re-stamps districts whose baked files exist but whose
# stamp predates a code change. Only for a change verified not to alter map
# geometry (e.g. 31 October 2026: Reconstruction.gd gained a corpse branch for
# dynamic items carrying a body, which map statics never have); it prints how
# many it accepted.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dataset="): directory = arg.substr(10)
	directory = ProjectSettings.globalize_path(directory)
	# The same signature as BakeStreaming.run(), so the stamps match.
	signature = Rules.fingerprint(directory)
	signature += dependency_signature("res://Presentation/BakeStreaming.gd",{})
	signature += FileAccess.get_sha256("res://local-art/water/catalog.json") if FileAccess.file_exists("res://local-art/water/catalog.json") else "no-water"
	signature += preload("res://Presentation/LocalTrees.gd").signature()
	signature += preload("res://Presentation/LocalPlants.gd").signature()
	signature += preload("res://Presentation/LocalProps.gd").signature()
	signature += preload("res://Presentation/LocalLibrary.gd").signature()
	signature += "modern-britain" if preload("res://Presentation/GraphicsMode.gd").modern() else "classic-britain"
	signature = signature.sha256_text()
	output = preload("res://Presentation/GraphicsMode.gd").prepared(directory)
	var index_path := output.path_join("index.json")
	var manual := preload("res://Presentation/ManualOverrides.gd").new()
	manual.load_from(directory)
	var data := preload("res://Presentation/AtlasData.gd").new()
	if not data.open(directory.path_join("atlas.json")): push_error("Missing owned atlas data");quit(1);return
	var entries: Array = []
	var stamps: Dictionary = {}
	var stale: Array = []
	var accept := "--accept-unchanged" in OS.get_cmdline_user_args()
	var accepted := 0
	for entry in data.manifest.chunks:
		var at := Vector2i(entry.x,entry.y)
		var tag := "%d_%d" % [at.x,at.y]
		var expected := signature+":"+manual.chunk_digest(at)
		stamps[tag] = expected.sha256_text().left(16)
		var stamp := output.path_join(tag+".stamp")
		if not FileAccess.file_exists(stamp) or FileAccess.get_file_as_string(stamp).trim_suffix(":") != expected.trim_suffix(":"):
			var baked: bool = FileAccess.file_exists(stamp) and FileAccess.file_exists(output.path_join("near_"+tag+".res")) and FileAccess.file_exists(output.path_join("far_"+tag+".res"))
			if accept and baked:
				var marker := FileAccess.open(stamp,FileAccess.WRITE);marker.store_string(expected);marker.close()
				accepted += 1
			else: stale.append(tag)
		entries.append([at.x,at.y])
	if not stale.is_empty():
		push_error("%d district(s) out of date, e.g. %s; bake their windows first (scripts/bake-facet.ps1)." % [stale.size(),", ".join(stale.slice(0,5))])
		quit(1);return
	var catalog: Dictionary = {}
	var catalogs := output.path_join("catalogs")
	if DirAccess.dir_exists_absolute(catalogs):
		for name in DirAccess.get_files_at(catalogs):
			var part: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalogs.path_join(name)))
			if part is Dictionary:
				for key in part:
					if not catalog.has(key): catalog[key] = part[key]
	var manifest: Dictionary = data.manifest
	var frame := Vector2(int(manifest.originX),int(manifest.originY))
	var macro_entries := macros(data,frame)
	if macro_entries.is_empty(): push_error("Regional horizon bake failed; prepared index not published");quit(1);return
	var index: Dictionary = {"schema":1,"signature":signature,"facet":1,"originX":manifest.originX,"originY":manifest.originY,"width":manifest.width,"height":manifest.height,"landData":manifest.landData,"staticData":manifest.staticData,"catalog":catalog,"chunks":entries,"macros":macro_entries,"stamps":stamps,"overrides":manual.digest(),"files":alternates}
	var file := FileAccess.open(index_path+".pending",FileAccess.WRITE);file.store_string(JSON.stringify(index));file.close()
	assert(DirAccess.rename_absolute(index_path+".pending",index_path) == OK)
	print("FACET FINALIZED: %d districts, %d horizon tiles, %d catalog rules; %d re-stamped as unchanged" % [entries.size(),macro_entries.size(),catalog.size(),accepted])
	quit()
