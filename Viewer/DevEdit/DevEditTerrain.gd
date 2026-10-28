extends RefCounted
# Pure, thread-safe terrain overlay math (no scene access). The baked terrain
# mesh places height samples at integer source coordinates (scene = source -
# origin). A developer edit is a per-sample height delta and/or surface paint;
# vertices are displaced by the bilinear interpolation of the deltas of their
# cell's four samples. Shared border vertices of two districts sit at the same
# source position and therefore receive exactly the same displacement, so
# regenerated neighbours meet without cracks. Only vertices of dirty cells are
# recomputed, always from the immutable baked base.
const Reconstruction = preload("res://Presentation/Reconstruction.gd")

static func cell_of(vertex: Vector3, origin: Vector2i) -> Vector2i:
	return Vector2i(floori(vertex.x+origin.x),floori(vertex.z+origin.y))

static func bucket(base: Array, origin: Vector2i) -> Dictionary:
	var vertices: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
	var lists := {}
	for i in vertices.size():
		var cell := cell_of(vertices[i],origin)
		if not lists.has(cell): lists[cell] = PackedInt32Array()
		lists[cell].append(i)
	return lists

static func surface_color(name: String) -> Color:
	return Reconstruction.terrain_color(name).srgb_to_linear()

static func surface_mask(name: String) -> Vector2:
	return Vector2(1 if name in ["cobblestones","stone","brick"] else 0,1 if name == "wooden floor" else 0)

# Height delta and its gradient at a source position.
static func displacement(at: Vector2, field: Dictionary) -> Vector3:
	var cell := Vector2i(floori(at.x),floori(at.y))
	var f := at-Vector2(cell)
	var a := float(field.get(cell,0.0))
	var b := float(field.get(cell+Vector2i.RIGHT,0.0))
	var c := float(field.get(cell+Vector2i.DOWN,0.0))
	var d := float(field.get(cell+Vector2i.ONE,0.0))
	var height := lerpf(lerpf(a,b,f.x),lerpf(c,d,f.x),f.y)
	var dx := lerpf(b-a,d-c,f.y)
	var dy := lerpf(c-a,d-b,f.x)
	return Vector3(height,dx,dy)

static func deform(base: Array, previous: Array, buckets: Dictionary, origin: Vector2i, field: Dictionary, colors: Dictionary, dirty: Dictionary) -> Dictionary:
	var base_vertices: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
	var base_normals: PackedVector3Array = base[Mesh.ARRAY_NORMAL]
	var base_colors: PackedColorArray = base[Mesh.ARRAY_COLOR] if base[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var base_masks: PackedVector2Array = base[Mesh.ARRAY_TEX_UV2] if base[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var vertices: PackedVector3Array = (previous[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (previous[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var tints: PackedColorArray = (previous[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate() if previous[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var masks: PackedVector2Array = (previous[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).duplicate() if previous[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var touched := 0
	for cell in dirty:
		if not buckets.has(cell): continue
		for i in buckets[cell]:
			var v := base_vertices[i]
			var at := Vector2(v.x+origin.x,v.z+origin.y)
			var shift := displacement(at,field)
			vertices[i] = Vector3(v.x,v.y+shift.x,v.z)
			var n := base_normals[i]
			if n.y > 0.05:
				# Heightfield normal (-hx, 1, -hz): add the delta's gradient.
				n = (n/n.y-Vector3(shift.y,0,shift.z)).normalized()
			normals[i] = n
			if not tints.is_empty() and not masks.is_empty():
				var c := Vector2i(floori(at.x),floori(at.y))
				var f := at-Vector2(c)
				var color := Color(0,0,0,0)
				var mask := Vector2.ZERO
				var painted := 0.0
				for corner in [[Vector2i.ZERO,(1-f.x)*(1-f.y)],[Vector2i.RIGHT,f.x*(1-f.y)],[Vector2i.DOWN,(1-f.x)*f.y],[Vector2i.ONE,f.x*f.y]]:
					var name: String = colors.get(c+corner[0],"")
					if name.is_empty() or corner[1] <= 0.0: continue
					color += surface_color(name)*corner[1]
					mask += surface_mask(name)*corner[1]
					painted += corner[1]
				tints[i] = base_colors[i]*(1.0-painted)+color if painted > 0 else base_colors[i]
				masks[i] = base_masks[i]*(1.0-painted)+mask if painted > 0 else base_masks[i]
			touched += 1
	var arrays := previous.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not tints.is_empty(): arrays[Mesh.ARRAY_COLOR] = tints
	if not masks.is_empty(): arrays[Mesh.ARRAY_TEX_UV2] = masks
	return {"arrays":arrays,"touched":touched}
