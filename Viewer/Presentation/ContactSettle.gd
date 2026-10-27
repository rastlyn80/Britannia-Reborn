extends RefCounted
# Settles loose objects onto what is really under them once a district's pieces
# are built: source Z gives the original sprite stacking (a table is 6 Z = 1.2 m
# tall), but presented models have their own heights (a 0.82 m table), so plates,
# goblets, candles or chests drawn at source height float above or sink into it.
# Wall-mounted pieces (torches, sconces, banners, paintings) are left alone.
const LOOSE := ["prop","asset","table","bench","counter","bed","chimney"]
const SUPPORT := ["wall","window","corner","trim","gable","beam","pier","pillar","post","archway","arch","floor","landing","stairs","roof","table","bench","counter","bed","prop","asset","fence","door","planter","rock","log"]
const HUNG := ["wall ","banner","sconce","painting","tapestr","portrait","map","sign","mirror","clock","hanging","chandelier"]

static func bounds(node: Node3D) -> AABB:
	var boxes: Array = []
	_collect(node,node.transform,boxes)
	if boxes.is_empty(): return AABB(node.position,Vector3.ZERO)
	var box: AABB = boxes[0]
	for part in boxes: box = box.merge(part)
	return box

static func _collect(node: Node, at: Transform3D, boxes: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh: boxes.append(at*(node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		if child is Node3D and child.get_meta("kind","") != "dressing": _collect(child,at*(child as Node3D).transform,boxes)

static func hung(name: String) -> bool:
	for word in HUNG:
		if word in name: return true
	return false

# models: built static nodes of one district (positions in the district frame);
# ground: Callable(Vector2i native cell) -> presented terrain height or -INF.
# Floating objects drop and sunken ones rise. Returns how many objects moved.
static func settle(models: Array, names: Dictionary, ground: Callable = Callable()) -> int:
	var cells := {}
	var entries: Array = []
	for node in models:
		if not is_instance_valid(node) or node.get_child_count() == 0: continue
		var xyz: Vector3i = node.get_meta("source_xyz",Vector3i.ZERO)
		var entry := {"node":node,"kind":str(node.get_meta("kind","")),"box":bounds(node),"cell":Vector2i(xyz.x,xyz.y),"name":str(names.get(str(int(node.get_meta("source_id",0))),{}).get("name",""))}
		entries.append(entry)
		if not cells.has(entry.cell): cells[entry.cell] = []
		cells[entry.cell].append(entry)
	var moved := 0
	for entry in entries:
		if not entry.kind in LOOSE or entry.kind == "chimney" or hung(entry.name): continue
		if entry.kind in ["table","bench","counter","bed"]: continue
		var box: AABB = entry.box
		var bottom := box.position.y
		var centre := Vector2(box.get_center().x,box.get_center().z)
		var support := -INF
		if ground.is_valid(): support = float(ground.call(entry.cell))
		for dx in range(-2,3):
			for dy in range(-2,3):
				for other in cells.get(entry.cell+Vector2i(dx,dy),[]):
					if other == entry or not other.kind in SUPPORT: continue
					var under: AABB = other.box
					if centre.x < under.position.x-0.02 or centre.x > under.end.x+0.02 or centre.y < under.position.z-0.02 or centre.y > under.end.z+0.02: continue
					# Surfaces at or below the object's base, or up to 0.5 m above it
					# when the object has sunk into them (models whose pivot is not
					# at their base).
					if under.end.y <= bottom+0.5 and under.position.y < bottom: support = maxf(support,under.end.y)
		if support == -INF: continue
		var gap := bottom-support
		if (gap > 0.03 and gap < 1.6) or (gap < -0.02 and gap > -0.5):
			(entry.node as Node3D).position.y -= gap
			entry.box = AABB(box.position-Vector3(0,gap,0),box.size)
			moved += 1
	return moved
