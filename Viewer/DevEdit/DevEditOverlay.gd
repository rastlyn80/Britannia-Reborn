extends Node3D
# Applies the developer edit overlay to the streamed, prepared districts. The
# baked baseline is never rewritten on disk: a hidden/moved/replaced static has
# its own baked geometry collapsed in place (per-static vertex range, instance
# or node recorded by the bake's source map) and, when moved or replaced, a
# live visual built by the shared Reconstruction rules. Terrain edits deform the
# baked terrain mesh of only the affected districts on a worker thread and are
# swapped in on the main thread; stale results are discarded by generation.
# Collision and native movement are never changed here: ModernUO stays
# authoritative, so gameplay-affecting edits remain visual previews.
const State = preload("res://DevEdit/DevEditState.gd")
const Terrain = preload("res://DevEdit/DevEditTerrain.gd")
const Batch = preload("res://Presentation/DistrictBatch.gd")
const MAX_TERRAIN_JOBS := 2
var stream: Node3D
var state: State
var districts: Dictionary = {}
var live: Dictionary = {}
var ghosts: Dictionary = {}
var markers: Dictionary = {}
var draft: Node3D
var batch_cache: Dictionary = {}
var show_markers := false
# Terrain: per district base arrays, vertex buckets by source cell, generation.
var terrain: Dictionary = {}
var terrain_jobs: Dictionary = {}
var terrain_pending: Dictionary = {}
# Bumped whenever a district's wanted terrain changes; older results are stale.
var terrain_generation: Dictionary = {}
# Measurements for docs/DEV_EDIT.md.
var stats := {"static_apply_us":[],"terrain_job_us":[],"terrain_swap_us":[],"terrain_rebuilt":[],"readback_us":[],"stale_discarded":0,"latency_ms":[]}
var waiting_latency: Dictionary = {}

func configure(districts_node: Node3D, edit_state: State) -> void:
	stream = districts_node
	state = edit_state
	stream.district_installed.connect(_installed)
	stream.district_retired.connect(_retired)
	state.targets_changed.connect(_targets_changed)
	state.previews_changed.connect(func(_author: String): refresh_ghosts())
	for at in stream.loaded: _installed(at,stream.loaded[at])

func origin() -> Vector2i:
	return stream.bounds.position

static func owner(x: float, y: float) -> Vector2i:
	return Vector2i(floori(x/64.0)*64,floori(y/64.0)*64)

# ---- district lifecycle ----

func _installed(at: Vector2i, node: Node3D) -> void:
	# A reinstalled (rebaked) district has new meshes: forget the old terrain base.
	terrain.erase(at)
	terrain_pending.erase(at)
	var maps: Dictionary = stream.source_maps.get(at,{"map":{},"info":{}})
	var records: Array = []
	var cells: Dictionary = {}
	var seen: Dictionary = {}
	for tile in stream.sources[at].statics:
		var base := "%d:%d:%d:%d" % [tile.x,tile.y,tile.z,tile.id]
		var key := base+":"+str(int(seen.get(base,0)))
		seen[base] = int(seen.get(base,0))+1
		var record := {"key":key,"target":"s:"+key,"x":int(tile.x),"y":int(tile.y),"z":int(tile.z),"id":int(tile.id),"hue":int(tile.hue),"index":records.size()}
		records.append(record)
		var cell := Vector2i(tile.x,tile.y)
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(record)
	districts[at] = {"node":node,"map":maps.map,"info":maps.info,"positions":maps.get("positions",{}),"records":records,"cells":cells,"hidden":{}}
	for record in records:
		if state.state_of(record.target) != "": apply_target(record.target)
	for target in state.targets:
		if target.begins_with("p:") and state.state_of(target) != "": apply_target(target)
	if _district_has_terrain(at): schedule_terrain([at])

func _retired(at: Vector2i) -> void:
	districts.erase(at)
	terrain.erase(at)
	terrain_pending.erase(at)
	for target in live.keys():
		if live[target].get_meta("district",Vector2i(-1,-1)) == at:
			live[target].queue_free()
			live.erase(target)
	for key in batch_cache.keys():
		if batch_cache[key].mesh.get_ref() == null: batch_cache.erase(key)

# ---- static editing ----

func record_for(target: String) -> Dictionary:
	var identity := State.static_identity(target)
	if identity.is_empty(): return {}
	var at := owner(identity.x,identity.y)
	if not districts.has(at): return {}
	for record in districts[at].cells.get(Vector2i(identity.x,identity.y),[]):
		if record.target == target: return record
	return {}

func info_for(record: Dictionary) -> Dictionary:
	var at := owner(record.x,record.y)
	var raw := str(districts.get(at,{}).get("info",{}).get(record.key,"||0"))
	var parts := raw.split("|")
	var detail: Dictionary = stream.world.staticData.get(str(record.id),{})
	var entries: Array = districts.get(at,{}).get("map",{}).get(record.key,[])
	var kind := parts[0] if parts.size() > 0 else ""
	var reconstruction_state := parts[1] if parts.size() > 1 else ""
	var solid := parts.size() > 2 and parts[2] == "1"
	var flags := int(detail.get("flags",0))
	var blocking := solid or bool(flags & 0x40)
	var reason := ""
	if districts.get(at,{}).get("map",{}).is_empty(): reason = "this prepared cache predates source maps; rebake with scripts/prepare-streaming.ps1"
	elif entries.is_empty(): reason = "no individually owned geometry (merged into a neighbour or not drawn)"
	elif kind in Batch.LIVE_EDIT_EXCLUDED: reason = "joined architecture or special surface (%s): live editing would break joined walls/roofs; needs a district rebake" % kind
	elif not Batch.live_editable(kind,reconstruction_state): reason = "part of a multi-tile assembly (%s)" % reconstruction_state
	return {"kind":kind,"state":reconstruction_state,"solid":solid,"blocking":blocking,"name":str(detail.get("name","")),"height":int(detail.get("height",0)),"entries":entries.size(),"editable":reason.is_empty(),"reason":reason,"district":at}

func apply_target(target: String) -> void:
	var started := Time.get_ticks_usec()
	if target.begins_with("s:"):
		var record := record_for(target)
		if record.is_empty(): return
		var desired := state.state_of(target)
		_set_hidden(record,desired != "")
		_replace_live(target,desired,record)
	elif target.begins_with("p:"):
		_replace_live(target,state.state_of(target),{})
	stats.static_apply_us.append(Time.get_ticks_usec()-started)
	_update_marker(target)

func _replace_live(target: String, desired: String, record: Dictionary) -> void:
	if live.has(target):
		live[target].queue_free()
		live.erase(target)
	var place := State.placement(desired)
	if place.is_empty(): return
	var at := owner(record.x,record.y) if not record.is_empty() else owner(place.x,place.y)
	if not districts.has(at): return
	var node := visual(int(place.id),float(place.x),float(place.y),int(place.z),int(place.yaw),int(record.get("hue",0)))
	node.set_meta("district",at)
	node.set_meta("dev_target",target)
	add_child(node)
	live[target] = node

func _set_hidden(record: Dictionary, hide: bool) -> void:
	var at := owner(record.x,record.y)
	var district: Dictionary = districts[at]
	if bool(district.hidden.get(record.key,false)) == hide: return
	var node: Node3D = district.node
	var stored: Array = district.positions.get(record.key,[])
	var batched := 0
	for entry in district.map.get(record.key,[]):
		var part := node.get_node_or_null(NodePath(str(entry[0])))
		if part == null: continue
		match int(entry[1]):
			0:
				if part is MeshInstance3D: collapse_range(part,int(entry[2]),int(entry[3]),hide,stored[batched] if batched < stored.size() else PackedVector3Array())
				batched += 1
			1:
				if part is MultiMeshInstance3D and part.multimesh:
					var i := int(entry[2])
					var d: PackedFloat32Array = part.instance_data
					var original := Transform3D(Basis(Vector3(d[i*12],d[i*12+4],d[i*12+8]),Vector3(d[i*12+1],d[i*12+5],d[i*12+9]),Vector3(d[i*12+2],d[i*12+6],d[i*12+10])),Vector3(d[i*12+3],d[i*12+7],d[i*12+11]))
					part.multimesh.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),original.origin) if hide else original)
			2: part.visible = not hide
	if hide: district.hidden[record.key] = true
	else: district.hidden.erase(record.key)

# Collapses (or restores) one static's vertices inside a merged batch with a
# single upload of the contiguous position stream. The bake stores the original
# positions of live-editable statics; older caches fall back to reading the
# vertex buffer back once per mesh (a GPU synchronization).
func collapse_range(part: MeshInstance3D, from: int, count: int, hide: bool, original := PackedVector3Array()) -> bool:
	var mesh: Mesh = part.mesh
	if mesh == null: return false
	if original.size() == count and count > 0:
		var region := original.to_byte_array()
		if hide:
			var anchor := original[0]
			var collapsed := PackedVector3Array()
			collapsed.resize(count)
			collapsed.fill(anchor)
			region = collapsed.to_byte_array()
		RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(),0,from*12,region)
		return true
	var id := mesh.get_instance_id()
	if not batch_cache.has(id):
		var started := Time.get_ticks_usec()
		var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),0)
		stats.readback_us.append(Time.get_ticks_usec()-started)
		var data: PackedByteArray = surface.get("vertex_data",PackedByteArray())
		var format := int(surface.get("format",0))
		var vertices := int(surface.get("vertex_count",0))
		if data.is_empty() or format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES: return false
		batch_cache[id] = {"mesh":weakref(mesh),"data":data,"vertices":vertices,"stride":RenderingServer.mesh_surface_get_format_vertex_stride(format,vertices),"offset":RenderingServer.mesh_surface_get_format_offset(format,vertices,Mesh.ARRAY_VERTEX)}
	var cache: Dictionary = batch_cache[id]
	if from < 0 or from+count > int(cache.vertices) or count <= 0: return false
	var stride := int(cache.stride)
	var offset := int(cache.offset)
	var region: PackedByteArray = cache.data.slice(from*stride,(from+count)*stride)
	if hide:
		var anchor := Vector3(region.decode_float(offset),region.decode_float(offset+4),region.decode_float(offset+8))
		for v in count:
			region.encode_float(v*stride+offset,anchor.x)
			region.encode_float(v*stride+offset+4,anchor.y)
			region.encode_float(v*stride+offset+8,anchor.z)
	RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(),0,from*stride,region)
	return true

# Shared rules build the same object family the converter uses. Position is
# fractional tile coordinates; yaw is degrees clockwise seen from above.
func visual(id: int, x: float, y: float, z: int, yaw: int, hue: int = 0) -> Node3D:
	var source := {"x":floori(x),"y":floori(y),"z":z,"id":id,"hue":hue}
	var node: Node3D = stream.reconstruction.build(source,stream.world)
	if node.get_child_count() == 0:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.mesh.size = Vector3(0.4,0.4,0.4)
		box.position.y = 0.2
		node.add_child(box)
	node.position += Vector3(x-floori(x),0,y-floori(y))
	node.rotation.y = -deg_to_rad(yaw)
	return node

func _targets_changed(targets: Array, seq: int, _author: String, _action: String) -> void:
	var terrain_cells: Array = []
	for target in targets:
		if target.begins_with("t:"): terrain_cells.append(target)
		else: apply_target(target)
	# Rebuild only districts whose terrain actually differs from what is shown.
	if not terrain_cells.is_empty(): schedule_terrain(affected_districts(terrain_cells).filter(func(at: Vector2i): return not terrain.get(at,{}).get("cells",[]).is_empty() or _district_has_terrain(at)))
	if waiting_latency.has(seq) and terrain_cells.is_empty():
		stats.latency_ms.append(Time.get_ticks_msec()-int(waiting_latency[seq]))
		waiting_latency.erase(seq)

# ---- previews and markers ----

func ghostify(node: Node3D, color: Color, label: String) -> Node3D:
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(color,0.45)
	for geometry in node.find_children("*","GeometryInstance3D",true,false):
		geometry.transparency = 0.35
		geometry.material_overlay = overlay
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tag := Label3D.new()
	tag.text = label
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = color
	tag.outline_size = 8
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.no_depth_test = true
	tag.position.y = 1.6
	node.add_child(tag)
	return node

func box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color,0.3)
	mesh.material_override = material
	mesh.position = at+Vector3(0,size.y/2,0)
	return mesh

static func author_color(author: String, mine: bool) -> Color:
	if mine: return Color("ffd34d")
	return Color.from_hsv(fmod(float(author.hash() & 0xffff)/65535.0,1.0),0.55,1.0)

func scene_point(x: float, y: float, z: float) -> Vector3:
	return Vector3(x-origin().x+0.5,z*0.2,y-origin().y+0.5)

# Source records with eligibility, for rule scopes (loaded districts only).
func records_in(area: Rect2i) -> Array:
	var found: Array = []
	for at in districts:
		if not Rect2i(at,Vector2i(64,64)).intersects(area): continue
		for record in districts[at].records:
			if not area.has_point(Vector2i(record.x,record.y)): continue
			var info := info_for(record)
			found.append({"target":record.target,"x":record.x,"y":record.y,"z":record.z,"id":record.id,"name":info.name,"kind":info.kind,"editable":info.editable,"reason":info.reason})
	return found

func target_point(target: String) -> Vector3:
	if live.has(target): return live[target].position
	var place := State.placement(state.state_of(target))
	if target.begins_with("p:") and not place.is_empty(): return scene_point(place.x,place.y,place.z)
	var record := record_for(target)
	return Vector3.INF if record.is_empty() else scene_point(record.x,record.y,record.z)

# Scope highlight: one translucent box per target (selection, rule results).
var highlighted: Node3D
func highlight(targets: Array, color: Color = Color("4fc3f7")) -> void:
	if highlighted: highlighted.queue_free()
	highlighted = null
	if targets.is_empty(): return
	highlighted = Node3D.new()
	for target in targets:
		var at := target_point(target)
		if at != Vector3.INF: highlighted.add_child(box(at,Vector3(0.9,0.9,0.9),color))
	add_child(highlighted)

func preview_node(target: String, desired: String, color: Color, label: String) -> Node3D:
	if target.begins_with("g:"):
		# Group preview: evaluate the shared rule on this client's own records.
		var rule := preload("res://DevEdit/DevEditQuery.gd").parse(desired)
		if rule.has("error") or not rule.has("area"): return null
		var result := preload("res://DevEdit/DevEditQuery.gd").evaluate(rule,records_in(rule.area),state)
		var root := Node3D.new()
		for t in result.targets:
			var at := target_point(t)
			if at != Vector3.INF: root.add_child(box(at,Vector3(1.0,1.2,1.0),color))
		if root.get_child_count() == 0:
			root.free()
			return null
		var first: Vector3 = root.get_child(0).position
		ghostify(root,color,"%s · %d objects" % [label,result.targets.size()])
		root.get_child(root.get_child_count()-1).position = first+Vector3(0,2.2,0)
		return root
	if target.begins_with("b:"):
		var f := target.split(":")
		var cx := int(f[1]);var cy := int(f[2]);var r := int(f[3])
		var root := Node3D.new()
		var ground := ground_height(Vector2(cx,cy))
		var disc := box(Vector3(cx-origin().x+0.5,ground,cy-origin().y+0.5),Vector3(r*2+1,0.15,r*2+1),color)
		root.add_child(disc)
		return ghostify(root,color,label)
	if desired == "hide":
		var record := record_for(target)
		if record.is_empty(): return null
		var height := maxf(0.4,float(stream.world.staticData.get(str(record.id),{}).get("height",2))*0.2)
		var root := Node3D.new()
		root.add_child(box(scene_point(record.x,record.y,record.z),Vector3(1.05,height,1.05),Color(1,0.25,0.2)))
		return ghostify(root,color,label)
	var place := State.placement(desired)
	if place.is_empty(): return null
	return ghostify(visual(int(place.id),float(place.x),float(place.y),int(place.z),int(place.yaw)),color,label)

func refresh_ghosts() -> void:
	for key in ghosts: ghosts[key].queue_free()
	ghosts.clear()
	for author in state.previews:
		for target in state.previews[author]:
			var node := preview_node(target,state.previews[author][target],author_color(author,author == state.me),"PREVIEW · %s" % author)
			if node:
				add_child(node)
				ghosts[author+"|"+target] = node

func set_draft(target: String, desired: String, label: String) -> void:
	clear_draft()
	if target.is_empty(): return
	draft = preview_node(target,desired,Color("ffd34d"),label)
	if draft: add_child(draft)

func clear_draft() -> void:
	if draft: draft.queue_free()
	draft = null

func set_markers(enabled: bool) -> void:
	show_markers = enabled
	for target in state.targets: _update_marker(target)

# Accepted edits carry a small attribution tag while the panel is open, so
# accepted state is visibly distinct from (translucent) previews.
func _update_marker(target: String) -> void:
	if markers.has(target):
		markers[target].queue_free()
		markers.erase(target)
	if not show_markers or state.state_of(target) == "" or target.begins_with("t:"): return
	var at := Vector3.INF
	if live.has(target): at = live[target].position
	else:
		var record := record_for(target)
		if not record.is_empty(): at = scene_point(record.x,record.y,record.z)
	if at == Vector3.INF: return
	var tag := Label3D.new()
	tag.text = "%s · %s r%d" % [state.author_of(target),"hidden" if state.state_of(target) == "hide" else "edited",state.revision_of(target)]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("7ee08a")
	tag.font_size = 32
	tag.pixel_size = 0.003
	tag.outline_size = 6
	tag.position = at+Vector3(0,1.9,0)
	add_child(tag)
	markers[target] = tag

# ---- picking ----

# Marches the camera ray through loaded source records (and live visuals), so
# selection works for objects without collision. Returns {} when nothing hit.
func pick(camera: Camera3D, screen: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var limit := 160.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from,from+direction*limit,1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty(): limit = from.distance_to(hit.position)+0.6
	var best := {}
	var best_t := INF
	for target in live:
		var bounds := visual_bounds(live[target])
		var t: Variant = bounds.intersects_ray(from,direction)
		if t != null and from.distance_to(t) < best_t:
			best_t = from.distance_to(t)
			best = {"target":target,"live":true}
	var step := 0.2
	var t := 0.0
	var visited := {}
	while t < minf(limit,best_t):
		var p := from+direction*t
		var cell := Vector2i(floori(p.x)+origin().x,floori(p.z)+origin().y)
		var at := owner(cell.x,cell.y)
		if districts.has(at):
			for record in districts[at].cells.get(cell,[]):
				var base := float(record.z)*0.2
				var height := maxf(0.25,float(stream.world.staticData.get(str(record.id),{}).get("height",1))*0.2)
				if p.y >= base-0.1 and p.y <= base+height+0.1 and not visited.has(record.target):
					visited[record.target] = true
					if state.state_of(record.target) == "hide": continue
					if t < best_t:
						best_t = t
						best = {"target":record.target,"record":record}
		if not best.is_empty() and best.has("record"): break
		t += step
	if best.is_empty() and not hit.is_empty():
		var point: Vector3 = hit.position
		return {"ground":Vector3(point.x+origin().x,point.z+origin().y,round(point.y/0.2))}
	if not hit.is_empty(): best.ground = Vector3(hit.position.x+origin().x,hit.position.z+origin().y,round(hit.position.y/0.2))
	return best

static func visual_bounds(node: Node3D) -> AABB:
	var result := AABB(node.global_position-Vector3(0.3,0,0.3),Vector3(0.6,0.6,0.6))
	for geometry in node.find_children("*","VisualInstance3D",true,false):
		if geometry is Label3D: continue
		result = result.merge(geometry.global_transform*geometry.get_aabb())
	return result

func ground_height(cell: Vector2) -> float:
	var at := owner(cell.x,cell.y)
	if stream.sources.has(at):
		for tile in stream.sources[at].terrain:
			if int(tile.x) == int(cell.x) and int(tile.y) == int(cell.y): return float(tile.z)*0.2+float(State.terrain(state.state_of("t:%d:%d" % [cell.x,cell.y])).dz)*0.2
	return 0.0

# ---- terrain ----

func _district_has_terrain(at: Vector2i) -> bool:
	for target in state.targets:
		if target.begins_with("t:") and state.state_of(target) != "":
			var f: PackedStringArray = target.split(":")
			if district_touches(at,int(f[1]),int(f[2])): return true
	return false

# A district's terrain mesh spans source x in [at.x, at.x+64] inclusive; a
# sample influences the cells on both sides of it.
static func district_touches(at: Vector2i, x: int, y: int) -> bool:
	return x >= at.x-1 and x <= at.x+64 and y >= at.y-1 and y <= at.y+64

func affected_districts(cells: Array) -> Array:
	var result := {}
	for target in cells:
		var f: PackedStringArray = target.split(":")
		for at in districts:
			if district_touches(at,int(f[1]),int(f[2])): result[at] = true
	return result.keys()

func terrain_mesh(at: Vector2i) -> MeshInstance3D:
	if not districts.has(at): return null
	var node: Node3D = districts[at].node
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial and child.material_override.shader and child.material_override.shader.resource_path.ends_with("Ground.gdshader"): return child
	return null

func schedule_terrain(list: Array) -> void:
	for at in list:
		if not districts.has(at): continue
		terrain_generation[at] = int(terrain_generation.get(at,0))+1
		terrain_pending[at] = true

class TerrainJob extends RefCounted:
	var at: Vector2i
	var generation: int
	var origin: Vector2i
	var base: Array
	var buckets: Dictionary
	var field: Dictionary
	var colors: Dictionary
	var dirty: Dictionary
	var previous: Array
	var arrays: Array
	var touched := 0
	var started := 0
	var elapsed := 0
	func run() -> void:
		started = Time.get_ticks_usec()
		if buckets.is_empty(): buckets = Terrain.bucket(base,origin)
		var result: Dictionary = Terrain.deform(base,previous,buckets,origin,field,colors,dirty)
		arrays = result.arrays
		touched = result.touched
		elapsed = Time.get_ticks_usec()-started

func _process(_delta: float) -> void:
	# Completed jobs: install only the newest generation of a still-loaded district.
	for at in terrain_jobs.keys():
		var job: TerrainJob = terrain_jobs[at].job
		if not WorkerThreadPool.is_task_completed(terrain_jobs[at].task): continue
		WorkerThreadPool.wait_for_task_completion(terrain_jobs[at].task)
		terrain_jobs.erase(at)
		var entry: Dictionary = terrain.get(at,{})
		if entry.is_empty() or job.generation != int(terrain_generation.get(at,0)) or not districts.has(at) or job.base != entry.base:
			stats.stale_discarded += 1
			continue
		entry.buckets = job.buckets
		var mesh_node := terrain_mesh(at)
		if mesh_node == null: continue
		var swap_started := Time.get_ticks_usec()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,job.arrays)
		mesh_node.mesh = mesh
		entry.current = job.arrays
		entry.cells = job.dirty.keys()
		stats.terrain_swap_us.append(Time.get_ticks_usec()-swap_started)
		stats.terrain_job_us.append(job.elapsed)
		stats.terrain_rebuilt.append({"district":at,"vertices":job.touched,"frame":Engine.get_process_frames()})
		for seq in waiting_latency.keys():
			stats.latency_ms.append(Time.get_ticks_msec()-int(waiting_latency[seq]))
			waiting_latency.erase(seq)
	for at in terrain_pending.keys():
		if terrain_jobs.size() >= MAX_TERRAIN_JOBS: break
		if terrain_jobs.has(at): continue
		terrain_pending.erase(at)
		_start_terrain(at)

func _start_terrain(at: Vector2i) -> void:
	var mesh_node := terrain_mesh(at)
	if mesh_node == null: return
	if not terrain.has(at):
		var started := Time.get_ticks_usec()
		var base := mesh_node.mesh.surface_get_arrays(0)
		stats.readback_us.append(Time.get_ticks_usec()-started)
		if base.is_empty() or (base[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): return
		terrain[at] = {"base":base,"current":base,"buckets":{},"cells":[]}
	var entry: Dictionary = terrain[at]
	var field := {}
	var colors := {}
	for target in state.targets:
		if not target.begins_with("t:"): continue
		var f: PackedStringArray = target.split(":")
		var x := int(f[1]);var y := int(f[2])
		if not district_touches(at,x,y): continue
		var t := State.terrain(state.state_of(target))
		if int(t.dz) != 0: field[Vector2i(x,y)] = float(t.dz)*0.2
		if str(t.surface) != "-": colors[Vector2i(x,y)] = str(t.surface)
	# Cells whose vertices may change: previously edited plus currently edited.
	var dirty := {}
	for cell in entry.cells: dirty[cell] = true
	for sample in field.keys()+colors.keys():
		for oy in range(-1,1):
			for ox in range(-1,1): dirty[sample+Vector2i(ox,oy)] = true
	var job := TerrainJob.new()
	job.at = at;job.generation = int(terrain_generation.get(at,0));job.origin = origin();job.base = entry.base;job.previous = entry.current
	job.buckets = entry.buckets;job.field = field;job.colors = colors;job.dirty = dirty
	terrain_jobs[at] = {"job":job,"task":WorkerThreadPool.add_task(job.run)}

# Joining pays one-time costs up front, one item per frame: each approved
# asset's art is loaded once, and resident districts' terrain bases are read
# back (a GPU synchronization), so later edits do not stall on them.
var warming := false
func warm(ids: Array) -> void:
	warming = true
	for id in ids:
		var node := visual(int(id),float(origin().x),float(origin().y),0,0)
		node.free()
		await get_tree().process_frame
	for at in districts.keys():
		var mesh_node := terrain_mesh(at)
		if mesh_node == null or terrain.has(at): continue
		var started := Time.get_ticks_usec()
		var base := mesh_node.mesh.surface_get_arrays(0)
		stats.readback_us.append(Time.get_ticks_usec()-started)
		if not base.is_empty(): terrain[at] = {"base":base,"current":base,"buckets":{},"cells":[]}
		await get_tree().process_frame
	warming = false

func idle() -> bool:
	return terrain_jobs.is_empty() and terrain_pending.is_empty()

func _exit_tree() -> void:
	for at in terrain_jobs: WorkerThreadPool.wait_for_task_completion(terrain_jobs[at].task)
