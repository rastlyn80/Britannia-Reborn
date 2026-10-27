extends RefCounted

# A flat interior liner only over source-supported rooms, bounded by the
# connected roof's lowest eave. It does not invent ceilings over open terrain.
var ceilings := {}
var wall_caps := {}
var floor_sources := {}

func index(world: Dictionary, reconstruction) -> void:
	ceilings.clear()
	wall_caps.clear()
	floor_sources.clear()
	var floor_levels := {}
	for s in world.statics:
		if reconstruction.rule_for(s.id).get("kind")!="floor":continue
		var at:=Vector2i(s.x,s.y)
		if not floor_levels.has(at):floor_levels[at]=[]
		floor_levels[at].append(s)
	var overhead := {}
	for ordinal in reconstruction.roofs.tiles:
		var roof: Dictionary = reconstruction.roofs.tiles[ordinal]
		if roof.boundary_fragment: continue
		var source: Dictionary = world.statics[ordinal]
		var anchor: Array = reconstruction.rule_for(source.id).get("anchorOffset",[-1,-1])
		var at: Vector2i = roof.cell+Vector2i(int(anchor[0]),int(anchor[1]))
		if not overhead.has(at): overhead[at] = []
		overhead[at].append(float(roof.eave)-0.16)
	# UO also encodes indoor floors in map.mul land cells, not just statics.
	for i in world.get("terrain",[]).size():
		var source: Dictionary = world.terrain[i]
		if reconstruction.info(world,source.id,false).get("name","").to_lower() == "wooden floor": floor_sources[-i-1] = source
	for i in world.statics.size():
		if reconstruction.rule_for(world.statics[i].id).get("kind") == "floor" and reconstruction.groups.get(i,{}).get("owner",i) == i: floor_sources[i] = world.statics[i]
	for at in reconstruction.floors.repairs: floor_sources[at] = {"x":at.x,"y":at.y,"z":at.z}
	var scale := float(world.elevationScale)
	var land_ceilings := {}
	for source in world.get("terrain",[]):
		if reconstruction.info(world,source.id,false).get("name","").to_lower() == "wooden floor": land_ceilings[Vector2i(source.x,source.y)] = float(source.z)*scale-0.12
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var kind: String = reconstruction.rule_for(s.id).get("kind","")
		var levels: Array = overhead.get(Vector2i(s.x,s.y),[])
		var base := float(s.z)*scale
		if kind in ["wall","window","corner"]:
			var detail: Dictionary = reconstruction.info(world,s.id,true)
			var top := base+float(detail.get("height",20))*scale
			for level in levels:
				if level > top+0.01 and level-top <= 2.5 and level-base >= 1.85:
					wall_caps[i] = {"bottom":top-base,"height":level-top}

	for i in floor_sources:
		var s: Dictionary = floor_sources[i]
		var levels: Array = overhead.get(Vector2i(s.x,s.y),[])
		var base := float(s.z)*scale
		var chosen := INF
		var land_level: float = land_ceilings.get(Vector2i(s.x,s.y),-INF)
		if land_level-base >= 1.85 and land_level-base <= 5.0: chosen = land_level
		for level in levels:
			if level-base >= 1.85 and level-base <= 5.0: chosen = minf(chosen,level)
		if chosen == INF: continue
		# A higher source floor already supplies the ceiling for lower storeys.
		var covered := false
		for other in floor_levels.get(Vector2i(s.x,s.y),[]):
			if other.x == s.x and other.y == s.y and other.z > s.z and other.z*scale <= chosen and reconstruction.rule_for(other.id).get("kind") == "floor": covered = true
		if not covered: ceilings[i] = chosen-base

	# Close the half-cell perimeter above wall centres, including concave room
	# corners where there is no floor tile on the wall's own cell.
	var room_levels := {}
	for i in ceilings:
		var floor: Dictionary = floor_sources[i]
		room_levels[Vector2i(floor.x,floor.y)] = float(floor.z)*scale+float(ceilings[i])
	for i in world.statics.size():
		var wall: Dictionary = world.statics[i]
		if reconstruction.rule_for(wall.id).get("kind") not in ["wall","window","corner"]: continue
		var at := Vector2i(wall.x,wall.y)
		if room_levels.has(at): continue
		var chosen := INF
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not room_levels.has(at+offset): continue
			var level: float = room_levels[at+offset]
			if level-float(wall.z)*scale < 1.85 or level-float(wall.z)*scale > 5.0: continue
			for roof_level in overhead.get(at,[]):
				if absf(roof_level-level) < 0.01: chosen = minf(chosen,level)
		if chosen < INF:
			floor_sources["wall/"+str(i)] = wall
			ceilings["wall/"+str(i)] = chosen-float(wall.z)*scale


func build(world: Dictionary, reconstruction, region: Rect2i = Rect2i()) -> Node3D:
	var root := Node3D.new()
	root.name = "DerivedInteriorShell"
	root.set_meta("solid",true)
	for ordinal in ceilings:
		var s: Dictionary = floor_sources[ordinal]
		if region.has_area() and not region.has_point(Vector2i(s.x,s.y)): continue
		var slab: Node3D = reconstruction.floors.slab(ordinal,reconstruction.facade.material("wood"))
		# The ceiling underside is its own surface, below the upper floor.
		# Its top must never coincide with the map.mul floor above it.
		slab.mesh = slab.mesh.duplicate()
		slab.mesh.size.y = 0.10
		slab.position.y = -0.05
		slab.position += Vector3(s.x-int(world.originX)+0.5,s.z*float(world.elevationScale)+ceilings[ordinal]+0.10,s.y-int(world.originY)+0.5)
		root.add_child(slab)
	for ordinal in wall_caps:
		var s: Dictionary = world.statics[ordinal]
		if region.has_area() and not region.has_point(Vector2i(s.x,s.y)): continue
		var cap: Dictionary = wall_caps[ordinal]
		var part: Node3D
		# The cap continues the wall it tops (brick, stone, timber or plaster).
		var family: String = reconstruction.wall_family(world,int(s.id))
		if reconstruction.rule_for(s.id).kind == "corner": part = reconstruction.facade.corner(cap.height,reconstruction.facade.corners.get(ordinal,{}),family)
		else: part = reconstruction.facade.panel(cap.height,false,reconstruction.facade.plans.get(ordinal,{}),family)
		if reconstruction.rule_for(s.id).get("axis") == "y": part.rotation.y = PI/2
		part.position = Vector3(s.x-int(world.originX)+0.5,s.z*float(world.elevationScale)+cap.bottom,s.y-int(world.originY)+0.5)
		root.add_child(part)
	return root
