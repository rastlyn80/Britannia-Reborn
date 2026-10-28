extends SceneTree
# Headless developer-edit checks: protocol parsing and malformed-record
# rejection, undo/redo derivation, canonical numbers and brush parity with the
# server, terrain border continuity on synthetic districts, and (with local
# prepared data) static hide/move persistence across real district unload and
# reload plus cross-district terrain regeneration of only affected chunks.
const State = preload("res://DevEdit/DevEditState.gd")
const Overlay = preload("res://DevEdit/DevEditOverlay.gd")
const Terrain = preload("res://DevEdit/DevEditTerrain.gd")
var passed := 0
var failed := 0
var expected := 26
# The dummy (headless) renderer does not store vertex-region uploads; byte-level
# batch checks run when this suite is started with a real renderer.
var gpu := DisplayServer.get_name() != "headless"

func check(condition: bool, name: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		print("FAIL ",name)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	protocol()
	synthetic_terrain()
	await real_districts()
	# A script error aborts a section silently; require every check to have run.
	check(passed+failed >= expected,"all %d checks ran (%d did)" % [expected,passed+failed])
	print("DEV EDIT TESTS: %d passed, %d failed" % [passed,failed])
	quit(failed)

func protocol() -> void:
	var s := State.new()
	var sent: Array = []
	var sender := func(text: String) -> bool:
		sent.append(text)
		return true
	check(s.feed("hello|britain-dev|Ann|3|baseline"),"hello accepted")
	check(s.feed("cur|s:1600:1590:20:3645:0|2|Bob|hide"),"snapshot target")
	check(s.feed("hist|1|Ann|place|0|0|1") and s.feed("hist|2|Bob|hide|0|0|1") and s.feed("hist|3|Ann|move|0|0|1"),"history")
	check(s.feed("synced|3") and s.synced and s.revision == 3,"synced")
	check(not s.feed("cur|bad|x|Bob|hide") and not s.feed("bogus|1") and not s.feed("chg|99|p:1|x") and s.malformed == 3,"malformed records rejected")
	check(s.state_of("s:1600:1590:20:3645:0") == "hide" and s.revision_of("s:1600:1590:20:3645:0") == 2,"snapshot state and revision")
	check(s.undo_candidate() == 3 and s.redo_candidate() == 0,"undo stack from history")
	var request := s.set_state("s:1600:1590:20:3645:0","","restore",sender)
	check(request == 1 and sent[-1] == "set 1 s:1600:1590:20:3645:0 2 -","set names base revision")
	check(s.requests[1].status == "pending","request pending")
	s.feed("op|4|Ann|restore|1|1|0");s.feed("chg|4|s:1600:1590:20:3645:0|");s.feed("end|4")
	check(s.requests[1].status == "applied" and s.requests[1].seq == 4 and s.state_of("s:1600:1590:20:3645:0") == "" and s.author_of("s:1600:1590:20:3645:0") == "Ann","op applied atomically with attribution")
	s.feed("op|5|Ann|undo|1|2|4");s.feed("chg|5|s:1600:1590:20:3645:0|hide");s.feed("end|5")
	check(s.history[4].reverted_by == 5 and s.undo_candidate() == 3 and s.redo_candidate() == 5,"undo recorded, redo available")
	s.feed("op|6|Ann|place|1|3|0");s.feed("chg|6|p:1|a:3144:1601.5:1590:20:0");s.feed("end|6")
	check(s.redo_candidate() == 0,"new edit clears redo")
	var failing := s.set_state("p:1","","remove",sender)
	s.feed("reject|%d|conflict|p:1 is at revision 7 by Bob" % failing)
	check(s.requests[failing].status == "failed" and "Bob" in s.requests[failing].detail,"rejection marks request failed")
	s.feed("op|7|Bob|move|2|0|0");s.feed("chg|7|p:1|a:3144:1602:1590:20:0")
	check(s.state_of("p:1") == "a:3144:1601.5:1590:20:0","incomplete operation not applied")
	s.feed("end|7")
	check(s.malformed == 4 and s.state_of("p:1") == "a:3144:1601.5:1590:20:0","operation with wrong change count refused")
	check(s.place(3144,1601.5,1590.25,20,90,sender) > 0 and sent[-1].ends_with("3144 1601.5 1590.25 20 90"),"placement command")
	check(State.number(1600.0) == "1600" and State.number(1600.125) == "1600.13" and State.number(1601.5) == "1601.5","canonical numbers")
	var cells := State.brush_cells(1650,1650,2,8)
	check(cells.size() == 13 and cells[Vector2i(1650,1650)] == 8 and cells[Vector2i(1652,1650)] == 3 and cells[Vector2i(1651,1651)] == 4,"brush falloff matches server")
	check(State.brush_cells(10,10,1,-5)[Vector2i(11,10)] == -3,"negative falloff rounds away from zero")
	s.feed("pv|Bob|n|a:3144:1600:1590:20:0")
	check(s.previews.Bob.n == "a:3144:1600:1590:20:0","shared preview")
	s.feed("who|Bob|off")
	check(not s.previews.has("Bob"),"departing editor's previews cleared")
	check(s.set_state("s:1600:1590:20:3645:0","m:"+"9".repeat(120),"x",sender) == 0,"overlong command refused locally")

# Two synthetic 64x64 districts share the border x = 64.
func synthetic_terrain() -> void:
	var origin := Vector2i(0,0)
	var meshes: Array = []
	for at in [Vector2i(0,0),Vector2i(64,0)]:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var masks := PackedVector2Array()
		for y in range(at.y,at.y+64):
			for x in range(at.x,at.x+64):
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					vertices.append(Vector3(x+corner.x,1.0,y+corner.y));normals.append(Vector3.UP);colors.append(Color.GRAY);masks.append(Vector2.ZERO)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices;arrays[Mesh.ARRAY_NORMAL] = normals;arrays[Mesh.ARRAY_COLOR] = colors;arrays[Mesh.ARRAY_TEX_UV2] = masks
		meshes.append(arrays)
	var field := {}
	var paint := {}
	var cells := State.brush_cells(64,20,3,10)
	for cell in cells:
		field[cell] = float(cells[cell])*0.2
		paint[cell] = "dirt"
	var dirty := {}
	for cell in cells:
		for oy in range(-1,1):
			for ox in range(-1,1): dirty[cell+Vector2i(ox,oy)] = true
	var results: Array = []
	for arrays in meshes:
		results.append(Terrain.deform(arrays,arrays,Terrain.bucket(arrays,origin),origin,field,paint,dirty))
	var left: PackedVector3Array = results[0].arrays[Mesh.ARRAY_VERTEX]
	var right: PackedVector3Array = results[1].arrays[Mesh.ARRAY_VERTEX]
	var border := {}
	for v in left:
		if is_equal_approx(v.x,64.0): border[Vector2(v.x,v.z)] = v.y
	var matched := 0
	var mismatched := 0
	var raised := 0
	for v in right:
		if is_equal_approx(v.x,64.0) and border.has(Vector2(v.x,v.z)):
			if is_equal_approx(border[Vector2(v.x,v.z)],v.y): matched += 1
			else: mismatched += 1
			if v.y > 1.5: raised += 1
	check(matched > 0 and mismatched == 0 and raised > 0,"border vertices of both districts displaced identically (%d shared, %d raised)" % [matched,raised])
	check(results[0].touched > 0 and results[1].touched > 0 and results[0].touched < 4096*6,"only dirty cells recomputed")
	var undo: Dictionary = Terrain.deform(meshes[0],results[0].arrays,Terrain.bucket(meshes[0],origin),origin,{},{},dirty)
	check(undo.arrays[Mesh.ARRAY_VERTEX] == meshes[0][Mesh.ARRAY_VERTEX] and undo.arrays[Mesh.ARRAY_COLOR] == meshes[0][Mesh.ARRAY_COLOR],"clearing the field restores the exact baked base")
	check(Overlay.district_touches(Vector2i(0,0),64,20) and Overlay.district_touches(Vector2i(64,0),63,20) and not Overlay.district_touches(Vector2i(128,0),62,20),"border samples affect both neighbours only")

# ---- real prepared districts (owned local data; skipped when absent) ----

var stream: Node3D
var state: State
var overlay: Node3D
var folder := ""

func district(at: Vector2i, fresh: bool) -> Node3D:
	var path := folder.path_join("near_%d_%d.res" % [at.x,at.y])
	var resource: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE if fresh else ResourceLoader.CACHE_MODE_REUSE)
	var node: Node3D = resource.root_scene.instantiate()
	for part in resource.parts: node.add_child(part.instantiate())
	stream.add_child(node)
	stream.sources[at] = resource.decode()
	stream.source_maps[at] = {"map":resource.source_map,"info":resource.source_info,"positions":resource.source_positions}
	stream.loaded[at] = node
	stream.district_installed.emit(at,node)
	return node

func unload(at: Vector2i) -> void:
	stream.district_retired.emit(at)
	stream.loaded[at].free()
	stream.loaded.erase(at)
	stream.sources.erase(at)
	stream.source_maps.erase(at)

func positions(part: MeshInstance3D, from: int, count: int) -> PackedByteArray:
	var data: PackedByteArray = RenderingServer.mesh_get_surface(part.mesh.get_rid(),0).vertex_data
	return data.slice(from*12,(from+count)*12)

func real_districts() -> void:
	folder = ProjectSettings.globalize_path("res://../outputs/britain/prepared")
	if not FileAccess.file_exists(folder.path_join("index.json")):
		print("DEV EDIT TESTS: prepared Britain data not present; real-district checks skipped")
		return
	expected += 16
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("index.json")))
	stream = preload("res://Presentation/LiveDistricts.gd").new()
	stream.bounds = Rect2i(index.originX,index.originY,index.width,index.height)
	stream.world = {"schema":1,"facet":"Trammel","originX":index.originX,"originY":index.originY,"width":index.width,"height":index.height,"elevationScale":0.2,"landData":index.landData,"staticData":index.staticData,"terrain":[],"statics":[]}
	stream.reconstruction.catalog = index.catalog
	stream.reconstruction.index(stream.world)
	preload("res://Presentation/SurfaceLibrary.gd").source_origin = Vector2(stream.bounds.position)
	root.add_child(stream)
	state = State.new()
	state.feed("hello|britain-dev|Ann|0|b")
	state.feed("synced|0")
	overlay = Overlay.new()
	stream.add_child(overlay)
	var a := Vector2i(1600,1536)
	var b := Vector2i(1664,1536)
	var c := Vector2i(1600,1472)
	district(a,false)
	district(b,false)
	district(c,false)
	overlay.configure(stream,state)
	check(overlay.districts.size() == 3,"overlay tracks installed districts")
	# Find editable statics owning a batched vertex range and a whole node or instance.
	var batched := {}
	var other := {}
	for record in overlay.districts[a].records:
		var info: Dictionary = overlay.info_for(record)
		if not info.editable: continue
		for entry in overlay.districts[a].map[record.key]:
			if int(entry[1]) == 0 and batched.is_empty() and overlay.districts[a].map[record.key].size() == 1: batched = {"record":record,"entry":entry}
			if int(entry[1]) == 2 and other.is_empty(): other = {"record":record,"entry":entry}
	check(not batched.is_empty() and not other.is_empty(),"editable batched and standalone statics exist")
	var architecture := 0
	for record in overlay.districts[a].records:
		if overlay.info_for(record).kind == "wall" and not overlay.info_for(record).editable: architecture += 1
	check(architecture > 0,"joined architecture is identified as not live-editable")
	var part: MeshInstance3D = overlay.districts[a].node.get_node(NodePath(str(batched.entry[0])))
	var original := positions(part,int(batched.entry[2]),int(batched.entry[3]))
	var target: String = batched.record.target
	var neighbour_from := int(batched.entry[2])+int(batched.entry[3])
	var neighbour_before := positions(part,neighbour_from,4)
	state.feed("op|1|Ann|hide|1|0|0");state.feed("chg|1|%s|hide" % target);state.feed("end|1")
	var collapsed := positions(part,int(batched.entry[2]),int(batched.entry[3]))
	var first := collapsed.slice(0,12)
	var uniform := true
	for v in int(batched.entry[3]): uniform = uniform and collapsed.slice(v*12,v*12+12) == first
	if gpu: check(collapsed != original and uniform,"hidden static's batched vertices collapse to one point")
	else: check(overlay.districts[a].hidden.has(batched.record.key),"hidden static's batch range collapsed (bookkeeping; bytes need a renderer)")
	check(overlay.batch_cache.is_empty() and overlay.districts[a].positions.has(batched.record.key),"hide used the baked original positions: no GPU readback")
	check(positions(part,neighbour_from,4) == neighbour_before,"neighbouring geometry untouched")
	var standalone: Node3D = overlay.districts[a].node.get_node(NodePath(str(other.entry[0])))
	var moved_state := "m:%s:%d:%d:90:%d" % [State.number(other.record.x+1.5),other.record.y,other.record.z,other.record.id]
	state.feed("op|2|Ann|move|1|0|0");state.feed("chg|2|%s|%s" % [other.record.target,moved_state]);state.feed("end|2")
	check(not standalone.visible and overlay.live.has(other.record.target),"moved static hides its baked node and gets a live visual")
	check(overlay.live[other.record.target].position.distance_to(overlay.scene_point(other.record.x+1.5,other.record.y,other.record.z)) < 0.6,"live visual at the new coordinates")
	# Unload and reload district a from disk: edits must re-apply.
	unload(a)
	check(not overlay.live.has(other.record.target),"live visual leaves with its district")
	district(a,true)
	part = overlay.districts[a].node.get_node(NodePath(str(batched.entry[0])))
	collapsed = positions(part,int(batched.entry[2]),int(batched.entry[3]))
	if gpu: check(collapsed != original and collapsed.slice(0,12) == collapsed.slice(12,24),"hide survives unload/reload from disk")
	else: check(overlay.districts[a].hidden.has(batched.record.key),"hide survives unload/reload from disk (bookkeeping)")
	standalone = overlay.districts[a].node.get_node(NodePath(str(other.entry[0])))
	check(not standalone.visible and overlay.live.has(other.record.target),"move survives unload/reload")
	state.feed("op|3|Ann|undo|1|0|1");state.feed("chg|3|%s|" % target);state.feed("end|3")
	check(positions(part,int(batched.entry[2]),int(batched.entry[3])) == original,"undo restores the exact baked vertices")
	# Terrain brush across the a|b border at x = 1664; c must not rebuild.
	var cells := State.brush_cells(1664,1560,2,10)
	state.feed("op|4|Ann|brush|%d|0|0" % cells.size())
	for cell in cells: state.feed("chg|4|t:%d:%d|h:%d:dirt" % [cell.x,cell.y,cells[cell]])
	var started := Time.get_ticks_msec()
	state.feed("end|4")
	var before_a: PackedVector3Array = overlay.terrain_mesh(a).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	while not overlay.idle() and Time.get_ticks_msec()-started < 20000: await process_frame
	var rebuilt: Array = overlay.stats.terrain_rebuilt.map(func(entry: Dictionary): return entry.district)
	check(rebuilt.size() == 2 and a in rebuilt and b in rebuilt and not c in rebuilt,"only the two touched districts rebuilt (%s)" % str(rebuilt))
	var va: PackedVector3Array = overlay.terrain_mesh(a).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = overlay.terrain_mesh(b).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edge := {}
	for v in va:
		if is_equal_approx(v.x,576.0) and v.z > 146 and v.z < 158: edge[Vector2(v.x,v.z)] = v.y
	var shared := 0
	var cracks := 0
	for v in vb:
		if edge.has(Vector2(v.x,v.z)):
			shared += 1
			if not is_equal_approx(edge[Vector2(v.x,v.z)],v.y): cracks += 1
	var lifted := 0
	for i in va.size():
		if va[i].y-before_a[i].y > 0.1: lifted += 1
	check(shared > 0 and cracks == 0 and lifted > 0,"terrain raised across the border with no cracks (%d shared border vertices, %d lifted)" % [shared,lifted])
	print("DEV EDIT MEASURE: terrain job us ",overlay.stats.terrain_job_us," swap us ",overlay.stats.terrain_swap_us," readback us ",overlay.stats.readback_us)
	# Reload b from disk: terrain edits re-apply to the fresh mesh.
	unload(b)
	district(b,true)
	started = Time.get_ticks_msec()
	while not overlay.idle() and Time.get_ticks_msec()-started < 20000: await process_frame
	var vb2: PackedVector3Array = overlay.terrain_mesh(b).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vb2 == vb,"terrain edit survives unload/reload")
	# A newer generation supersedes an in-flight job; stale results never install.
	state.feed("op|5|Ann|brush|1|0|0");state.feed("chg|5|t:1664:1560|h:20:dirt");state.feed("end|5")
	overlay._process(0.0)
	state.feed("op|6|Ann|brush|1|0|0");state.feed("chg|6|t:1664:1560|h:-4:dirt");state.feed("end|6")
	started = Time.get_ticks_msec()
	while not overlay.idle() and Time.get_ticks_msec()-started < 20000: await process_frame
	var final: PackedVector3Array = overlay.terrain_mesh(a).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected_low := true
	for i in final.size():
		if absf(final[i].x-576.0) < 0.01 and absf(final[i].z-152.0) < 0.01: expected_low = expected_low and final[i].y < before_a[i].y
	check(expected_low and overlay.stats.stale_discarded >= 1,"stale terrain result discarded; newest edit visible")
	stream.queue_free()
