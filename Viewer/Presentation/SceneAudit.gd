extends SceneTree
# Audit of the presented 3D city (not the source records): builds every static
# with the same Reconstruction as the streaming bake and measures real visual
# bounds. Reports
#   roof-gap        roof whose underside is well above the walls beneath it
#   roof-unsupported roof with no wall/pier/post anywhere under its footprint
#   floating        chimney/prop/asset with nothing under its base
#   buried          wall whose base is well below the terrain at its cell
#   overlap         two props/assets occupying the same space (flicker)
# -- [--list] [--rect=x0,y0,x1,y1]   writes outputs/britain/scene-audit.local.json
const STRUCTURE := ["wall","window","corner","trim","gable","beam","pier","pillar","post","archway","arch","door","chimney","fence"]
const LOOSE := ["prop","asset","chimney","table","bench","counter","bed"]
const SUPPORT := ["wall","window","corner","trim","gable","beam","pier","pillar","post","archway","arch","floor","landing","stairs","roof","table","bench","counter","bed","prop","asset","fence","door","planter","rock","log"]

func _initialize() -> void: call_deferred("run")

# Bounds from the transform chain (nodes are never added to the scene tree).
static func bounds_of(node: Node3D) -> AABB:
	var boxes: Array = []
	_collect(node,Transform3D.IDENTITY,boxes)
	if boxes.is_empty(): return AABB(node.position,Vector3.ZERO)
	var box: AABB = boxes[0]
	for part in boxes: box = box.merge(part)
	return box

static func _collect(node: Node, parent: Transform3D, boxes: Array) -> void:
	var at := parent*(node as Node3D).transform if node is Node3D else parent
	if node is MeshInstance3D and (node as MeshInstance3D).mesh and node.get_meta("kind","") != "dressing": boxes.append(at*(node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		if child.get_meta("kind","") != "dressing": _collect(child,at,boxes)

func run() -> void:
	var rect := Rect2i(0,0,1<<16,1<<16)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rect="):
			var v := arg.substr(7).split_floats(",")
			rect = Rect2i(int(v[0]),int(v[1]),int(v[2]-v[0]),int(v[3]-v[1]))
	var data := preload("res://Presentation/AtlasData.gd").new()
	data.open(ProjectSettings.globalize_path("res://../outputs/britain/atlas.json"))
	var plan := preload("res://Presentation/RegionalContext.gd").new()
	plan.prepare(data)
	var world: Dictionary = plan.world
	var recon = plan.reconstruction
	var scale := float(world.elevationScale)
	var ground := {}
	for t in world.terrain: ground[Vector2i(t.x,t.y)] = float(t.z)*scale
	var pieces: Array[Dictionary] = []
	var by_cell := {}
	var built := 0
	for at in plan.chunks:
		var models: Array = []
		for i in plan.chunks[at]:
			var s: Dictionary = world.statics[i]
			if not rect.has_point(Vector2i(s.x,s.y)): continue
			var node: Node3D = recon.build(s,world,i)
			if node: models.append(node)
		preload("res://Presentation/ContactSettle.gd").settle(models,world.staticData)
		for node in models:
			if node.get_child_count() > 0:
				var s: Dictionary = world.statics[int(node.get_meta("source_ordinal",0))]
				var piece := {"i":int(node.get_meta("source_ordinal",0)),"id":int(s.id),"x":int(s.x),"y":int(s.y),"z":int(s.z),"kind":str(node.get_meta("kind","")),"box":bounds_of(node),"name":str(world.staticData.get(str(int(s.id)),{}).get("name",""))}
				pieces.append(piece)
				var cell := Vector2i(s.x,s.y)
				if not by_cell.has(cell): by_cell[cell] = []
				by_cell[cell].append(piece)
			node.free()
		built += models.size()
		recon.report.clear()
		await process_frame
	var eave_gaps: Array = []
	var findings := {"roof-gap":[],"roof-unsupported":[],"floating":[],"buried":[],"overlap":[]}
	var origin := Vector2(world.originX,world.originY)
	for p in pieces:
		var box: AABB = p.box
		var cell := Vector2i(p.x,p.y)
		var bottom: float = box.position.y
		match str(p.kind):
			"roof":
				# Eave tiles (a wall beside them) must sit on the wall tops; interior
				# and ridge tiles rise above them by design.
				var best := -INF
				for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					for q in by_cell.get(cell+offset,[]):
						if not str(q.kind) in ["wall","window","corner","gable","trim","pier","pillar","post","archway"]: continue
						var top: float = (q.box as AABB).end.y
						if top > bottom+0.6: continue
						best = maxf(best,top)
				if best > -INF and bottom-best > 0.45 and bottom-best < 3.0: eave_gaps.append(p.merged({"gap":bottom-best}))
			"wall","window","corner":
				var land: float = plan.surface.z(cell) if ground.has(cell) else -INF
				if land-bottom > 0.6: findings["buried"].append(p.merged({"depth":land-bottom}))
		if str(p.kind) in LOOSE and not str(p.name).begins_with("wall ") and not "banner" in str(p.name) and not "sconce" in str(p.name) and not "painting" in str(p.name) and not "tapestr" in str(p.name):
			var support: float = ground.get(cell,-INF)
			var centre := Vector2(box.get_center().x,box.get_center().z)
			for dx in range(-2,3):
				for dy in range(-2,3):
					for q in by_cell.get(cell+Vector2i(dx,dy),[]):
						if q == p or not str(q.kind) in SUPPORT: continue
						var qb: AABB = q.box
						if centre.x < qb.position.x-0.05 or centre.x > qb.end.x+0.05 or centre.y < qb.position.z-0.05 or centre.y > qb.end.z+0.05: continue
						var top: float = qb.end.y
						if top <= bottom+0.12: support = maxf(support,top)
			if str(p.kind) == "chimney":
				for dx in range(-1,2):
					for dy in range(-1,2):
						for q in by_cell.get(cell+Vector2i(dx,dy),[]):
							if q != p and str(q.kind) in ["roof","wall","corner","window","gable"] and (q.box as AABB).position.y <= bottom+0.1: support = maxf(support,minf((q.box as AABB).end.y,bottom))
			if bottom-support > 0.3: findings["floating"].append(p.merged({"gap":bottom-support}))
			for q in by_cell.get(cell,[]):
				if q == p or int(q.i) < int(p.i) or not str(q.kind) in LOOSE: continue
				var shared: AABB = box.intersection(q.box)
				if shared.has_volume() and shared.get_volume() > 0.5*minf(box.get_volume(),(q.box as AABB).get_volume()): findings["overlap"].append(p.merged({"with":"%d %s" % [q.id,q.name]}))
	# Roof components that touch no wall anywhere along their edge.
	var roofs := {}
	for p in pieces:
		if str(p.kind) == "roof": roofs[Vector3i(p.x,p.y,p.z)] = p
	var seen := {}
	for key in roofs:
		if seen.has(key): continue
		var stack := [key]
		var members := []
		var touches := false
		while not stack.is_empty():
			var at: Vector3i = stack.pop_back()
			if seen.has(at) or not roofs.has(at): continue
			seen[at] = true
			members.append(roofs[at])
			for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				for q in by_cell.get(Vector2i(at.x,at.y)+offset,[]):
					if str(q.kind) in ["wall","window","corner","gable","trim","pier","pillar","post","archway"]: touches = true
			for dz in range(-6,7):
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next := Vector3i(at.x+offset.x,at.y+offset.y,at.z+dz)
					if roofs.has(next) and not seen.has(next): stack.append(next)
		if not touches: findings["roof-unsupported"].append_array(members)
		# Only each roof's lowest course (its eaves) must rest on the walls.
		var lowest := 1 << 20
		for m in members: lowest = mini(lowest,int(m.z))
		for m in members:
			if int(m.z) > lowest+1: continue
			for g in eave_gaps:
				if g.i == m.i: findings["roof-gap"].append(g)
	var report := {}
	for key in findings:
		var by_id := {}
		for f in findings[key]:
			var label := "%d %s" % [f.id,f.name]
			if not by_id.has(label): by_id[label] = []
			by_id[label].append("%d,%d,%d" % [f.x,f.y,f.z])
		var labels := by_id.keys()
		labels.sort_custom(func(a,b): return by_id[a].size() > by_id[b].size())
		print("%s: %d" % [key.to_upper(),findings[key].size()])
		for label in labels.slice(0,12): print("   %4d  %s  e.g. %s" % [by_id[label].size(),label,str(by_id[label].slice(0,3))])
		report[key] = by_id
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../outputs/britain/scene-audit.local.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SCENE AUDIT: %d pieces built" % pieces.size())
	quit()
