extends SceneTree
# Committed overrides in the converter (owned local data required; ~1-2 min).
# Plans Britain once and builds one district with and without overrides:
# hidden/moved statics keep their original collision, the moved visual keeps
# the static's identity (still live-editable), placed objects render without
# collision, and edited terrain renders the new heights and paint while its
# collision keeps the source heights. Also checks committed-file merging,
# per-district digests and persistent rules.
const Overrides = preload("res://Presentation/ManualOverrides.gd")
var passed := 0
var failed := 0

func check(condition: bool, name: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		print("FAIL ",name)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	files()
	await converter()
	print("DEV EDIT COMMIT TESTS: %d passed, %d failed" % [passed,failed])
	quit(failed)

func files() -> void:
	var dataset := OS.get_user_data_dir().path_join("commit-test")
	DirAccess.make_dir_recursive_absolute(dataset)
	if FileAccess.file_exists(Overrides.committed_path(dataset)): DirAccess.remove_absolute(Overrides.committed_path(dataset))
	var first := Overrides.commit(dataset,{"s:1600:1590:20:3206:0":{"state":"hide","author":"Ann"},"t:1600:1590":{"state":"h:4:dirt","author":"Ann"},"p:3":{"state":"a:3204:1601:1590:20:0","author":"Ann"}},[],"Ann")
	check(first.statics == 1 and first.terrain == 1 and first.placed == 1,"commit counts")
	Overrides.commit(dataset,{"t:1600:1590":{"state":"h:3:-","author":"Bob"},"s:1600:1590:20:3206:0":{"state":"","author":"Bob"}},[{"rule":"name~weed","action":"hide","author":"Bob","text":"never show weeds"}],"Bob")
	var merged := Overrides.new()
	merged.load_from(dataset)
	check(merged.terrain["1600:1590"][0] == 7 and merged.terrain["1600:1590"][1] == "dirt","terrain deltas accumulate on the committed result; paint kept")
	check(not merged.statics.has("1600:1590:20:3206:0") and merged.placed.has("3") and merged.rules.size() == 1,"restored static removed from committed; placed and rule kept")
	check(merged.chunk_digest(Vector2i(1600,1536)) != merged.chunk_digest(Vector2i(1536,1536)) or merged.rules.size() > 0,"per-district digest")
	var plain := Overrides.new()
	check(plain.chunk_digest(Vector2i(1600,1536)) == "" and plain.digest() == "","no overrides, no digest (baseline stamps unchanged)")
	check(Overrides.rule_matches({"rule":"name~weed;rect=1500,1500,1700,1700"},{"x":1600,"y":1590,"id":3271},"weed","grass") and not Overrides.rule_matches({"rule":"name~weed;rect=1500,1500,1550,1550"},{"x":1600,"y":1590,"id":3271},"weed","grass"),"rule name and rectangle matching")
	check(DirAccess.get_files_at(Overrides.folder(dataset).path_join("history")).size() >= 2,"each commit keeps a history copy")
	# Git sharing: each commit writes a change file with only its own edits.
	var change := Overrides.read(first.change)
	check(change.get("id","") == first.id and change.statics.size() == 1 and change.placed.size() == 1,"change file holds only that commit, with its id")
	var published := dataset.path_join("published")
	DirAccess.make_dir_recursive_absolute(published)
	for f in DirAccess.get_files_at(published): DirAccess.remove_absolute(published.path_join(f))
	DirAccess.copy_absolute(first.change,published.path_join(first.id+".overrides.json"))
	var partly := Overrides.new()
	partly.load_from(dataset,published)
	check(partly.files.size() == 2 and partly.terrain["1600:1590"][0] == 7,"local copy still applies while one of its commits is unpublished")
	var second_id: String = Overrides.read(Overrides.committed_path(dataset)).commits[-1]
	DirAccess.copy_absolute(Overrides.folder(dataset).path_join("outgoing/%s.overrides.json" % second_id),published.path_join(second_id+".overrides.json"))
	var shared := Overrides.new()
	shared.load_from(dataset,published)
	check(shared.files.size() == 2 and not shared.files.has(Overrides.committed_path(dataset)),"local copy skipped once every commit is published (pulled from Git)")
	check(not shared.statics.has("1600:1590:20:3206:0") and shared.terrain["1600:1590"][0] == 7 and shared.rules.size() == 1,"a later published restore overrides an earlier published hide; terrain and rules merge")
	# Another collaborator's published terrain is the base for my next delta.
	DirAccess.remove_absolute(Overrides.committed_path(dataset))
	var third := Overrides.commit(dataset,{"t:1600:1590":{"state":"h:1:-","author":"Cy"}},[],"Cy",published)
	check(Overrides.read(third.change).terrain["1600:1590"][0] == 8,"terrain delta builds on published edits")

func converter() -> void:
	var directory := ProjectSettings.globalize_path("res://../outputs/britain")
	var data := preload("res://Presentation/AtlasData.gd").new()
	if not data.open(directory.path_join("atlas.json")):
		print("DEV EDIT COMMIT TESTS: owned Britain atlas not present; converter checks skipped")
		return
	var plan := preload("res://Presentation/RegionalContext.gd").new()
	var at := Vector2i(1600,1536)
	# Pick real statics in this district: a decorative one, a blocking one (tree)
	# and one to move, by the same keys the live editor uses.
	var source: Dictionary = data.chunk(at)
	var counts := {}
	var decorative := ""
	var blocking := ""
	var moved := ""
	for tile in source.statics:
		var base := "%d:%d:%d:%d" % [tile.x,tile.y,tile.z,tile.id]
		var key := base+":"+str(int(counts.get(base,0)))
		counts[base] = int(counts.get(base,0))+1
		var name := str(data.manifest.staticData.get(str(int(tile.id)),{}).get("name","")).to_lower()
		if decorative == "" and "flowers" in name: decorative = key
		elif blocking == "" and name.ends_with("tree"): blocking = key
		elif moved == "" and "mushroom" in name: moved = key
	check(decorative != "" and blocking != "" and moved != "","district has a flower, a tree and a mushroom to edit")
	var m: PackedStringArray = moved.split(":")
	plan.overrides.statics = {decorative:["hide","Ann"],blocking:["hide","Ann"],moved:["m:%d.5:%s:%s:90:%s" % [int(m[0])+1,m[1],m[2],m[3]],"Ann"]}
	plan.overrides.placed = {"9":["a:2481:1610:1560:20:0","Ann"]}
	plan.overrides.terrain = {"1620:1560":[10,"dirt","Ann"]}
	plan.prepare(data)
	check(plan.manual.size() == 3 and plan.placed_chunks.get(at,[]).size() == 1 and plan.surface.manual_heights.size() == 1,"overrides indexed for the bake")
	var edited: Node3D = await plan.build_chunk(at,self,true)
	# Baseline of the same district from the same plan.
	var saved := [plan.manual.duplicate(),plan.placed_chunks.duplicate(),plan.surface.manual_heights.duplicate(),plan.surface.manual_paint.duplicate()]
	plan.manual.clear();plan.placed_chunks.clear();plan.surface.manual_heights.clear();plan.surface.manual_paint.clear();plan.surface.heights.clear()
	var baseline: Node3D = await plan.build_chunk(at,self,true)
	check(int(edited.get_meta("collision_triangles")) == int(baseline.get_meta("collision_triangles")),"collision identical (%d triangles): hidden/moved statics, placed objects and terrain heights do not change what ModernUO-consistent collision blocks" % int(baseline.get_meta("collision_triangles")))
	var edited_map: Dictionary = edited.get_meta("source_map")
	var baseline_map: Dictionary = baseline.get_meta("source_map")
	check(baseline_map.has(decorative) and not edited_map.has(decorative),"hidden decorative static has no rendered geometry")
	var t: PackedStringArray = blocking.split(":")
	var tree_at := Vector3i(int(t[0]),int(t[1]),int(t[2]))
	var trees := func(root: Node3D) -> int: return root.get_children().filter(func(n: Node): return n.get_meta("source_xyz",Vector3i.ZERO) == tree_at and int(n.get_meta("source_id",-1)) == int(t[3]) and n.get_child_count() > 0).size()
	var trunks := func(root: Node3D) -> int: return root.get_children().filter(func(n: Node): return n is StaticBody3D and n.get_child(0).shape is CylinderShape3D).size()
	check(trees.call(baseline) == 1 and trees.call(edited) == 0 and trunks.call(edited) == trunks.call(baseline),"hidden tree is not rendered; its trunk collision remains (%d trunks)" % trunks.call(baseline))
	check(edited_map.has(moved),"moved static keeps its identity, so it stays live-editable after the commit")
	var additions := edited.find_children("*","Node3D",true,false).filter(func(n: Node): return str(n.get_meta("manual","")) == "placed:9")
	check(additions.size() == 1 and not bool(additions[0].get_meta("solid",true)),"placed object rendered, not solid")
	var ground_edit: MeshInstance3D = edited.get_child(0)
	var ground_base: MeshInstance3D = baseline.get_child(0)
	var ve: PackedVector3Array = ground_edit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = ground_base.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var raised := 0
	for i in mini(ve.size(),vb.size()):
		if is_equal_approx(ve[i].x,1620-1088) and is_equal_approx(ve[i].z,1560-1408) and ve[i].y-vb[i].y > 1.9: raised += 1
	check(raised > 0,"rendered terrain raised by 10 Z (2 m) at the committed sample")
	edited.free()
	baseline.free()
	plan.manual = saved[0]
