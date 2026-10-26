extends RefCounted
const Geometry = preload("res://Presentation/GeometryLibrary.gd")
var tiles := {}
var joined_samples := 0
var exposed_edges := 0

func index(world: Dictionary, catalog: Dictionary) -> void:
	tiles.clear()
	joined_samples = 0
	exposed_edges = 0
	var vertices := {}
	var cells := {}
	for ordinal in world.statics.size():
		var s: Dictionary = world.statics[ordinal]
		var rule: Dictionary = catalog.get(str(int(s.id)),{})
		if rule.get("kind") != "roof": continue
		var heights: Array[float] = []
		for y in 3:
			for x in 3:
				var height := float(s.z)*float(world.elevationScale)+Geometry.roof_height(x*0.5,y*0.5,rule)
				heights.append(height)
				var key := Vector2i(int(s.x)*2+x,int(s.y)*2+y)
				if not vertices.has(key): vertices[key] = []
				vertices[key].append({"ordinal":ordinal,"sample":y*3+x,"height":height,"material":rule.material})
		tiles[ordinal] = {"heights":heights,"exposed":[true,true,true,true],"eave":heights.min(),"cell":Vector2i(s.x,s.y),"material":rule.material,"base":float(s.z)*float(world.elevationScale)}
		var cell := Vector2i(s.x,s.y)
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(ordinal)
	# Join edge midpoints as well as corners, preserving ridge peaks. Distinct
	# storeys remain separate; no snapping a roof onto another roof below it.
	var visited := {}
	var components: Array = []
	for ordinal in tiles:
		if visited.has(ordinal): continue
		var pending := [ordinal]
		var component: Array = []
		var eave := INF
		while not pending.is_empty():
			var current: int = pending.pop_back()
			if visited.has(current): continue
			visited[current] = true
			component.append(current)
			var tile: Dictionary = tiles[current]
			eave = minf(eave,tile.heights.min())
			var offsets := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
			for edge in 4:
				for neighbor in cells.get(tile.cell+offsets[edge],[]):
					var next: Dictionary = tiles[neighbor]
					if next.material == tile.material and absf(next.base-tile.base) < 1.9:
						tile.exposed[edge] = false
						if not visited.has(neighbor): pending.append(neighbor)
		components.append(component)
		var low := Vector2i(100000,100000)
		var high := Vector2i(-100000,-100000)
		for member in component:
			low = low.min(tiles[member].cell)
			high = high.max(tiles[member].cell)
		var at_boundary := low.x == int(world.get("originX",-100001)) or low.y == int(world.get("originY",-100001)) or high.x == int(world.get("originX",0))+int(world.get("width",-100001))-1 or high.y == int(world.get("originY",0))+int(world.get("height",-100001))-1
		var fragment := at_boundary and (high.x == low.x or high.y == low.y)
		for member in component:
			tiles[member].component = components.size()-1
			tiles[member].boundary_fragment = fragment
			tiles[member].eave = eave
			if world.has("originX"):
				var cell: Vector2i = tiles[member].cell
				if cell.x == int(world.originX): tiles[member].exposed[3] = false
				if cell.y == int(world.originY): tiles[member].exposed[0] = false
				if cell.x == int(world.originX)+int(world.width)-1: tiles[member].exposed[1] = false
				if cell.y == int(world.originY)+int(world.height)-1: tiles[member].exposed[2] = false
			for edge in tiles[member].exposed:
				if edge: exposed_edges += 1

	# Original roof art can encode a corner using a different local profile.
	# A connected roof still has one height at each shared mesh sample. Resolve
	# within that component, never across independently stacked buildings.
	for key in vertices:
		var clusters := {}
		for sample in vertices[key]:
			var component: int = tiles[sample.ordinal].component
			if not clusters.has(component): clusters[component] = []
			clusters[component].append(sample)
		for component in clusters: join_cluster(clusters[component])
	for component in components:
		var eave := INF
		for member in component: eave = minf(eave,tiles[member].heights.min())
		for member in component: tiles[member].eave = eave

	# A shared height is also a shared lighting normal. Computing these from
	# the complete component avoids a shading seam at tile/chunk boundaries.
	var profiles := {}
	for ordinal in tiles:
		var tile:Dictionary=tiles[ordinal]
		if not profiles.has(tile.component):profiles[tile.component]={}
		for y in 3:
			for x in 3:profiles[tile.component][tile.cell*2+Vector2i(x,y)]=tile.heights[y*3+x]
	for ordinal in tiles:
		var tile:Dictionary=tiles[ordinal]
		var profile:Dictionary=profiles[tile.component]
		var normals:Array[Vector3]=[]
		for y in 3:
			for x in 3:
				var at:Vector2i=tile.cell*2+Vector2i(x,y)
				var center:float=profile[at]
				var dx:float=(float(profile.get(at+Vector2i.RIGHT,center))-float(profile.get(at+Vector2i.LEFT,center)))/(0.5*(int(profile.has(at+Vector2i.RIGHT))+int(profile.has(at+Vector2i.LEFT)))) if profile.has(at+Vector2i.RIGHT) or profile.has(at+Vector2i.LEFT) else 0.0
				var dy:float=(float(profile.get(at+Vector2i.DOWN,center))-float(profile.get(at+Vector2i.UP,center)))/(0.5*(int(profile.has(at+Vector2i.DOWN))+int(profile.has(at+Vector2i.UP)))) if profile.has(at+Vector2i.DOWN) or profile.has(at+Vector2i.UP) else 0.0
				normals.append(Vector3(-dx,1,-dy).normalized())
		tile.normals=normals

func join_cluster(samples: Array) -> void:
	if samples.is_empty(): return
	var height := 0.0
	for sample in samples: height += sample.height
	height /= samples.size()
	for sample in samples:
		tiles[sample.ordinal].heights[sample.sample] = height
		if samples.size() > 1: joined_samples += 1
