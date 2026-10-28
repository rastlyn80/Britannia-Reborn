extends RefCounted
# Fences built from photoscanned materials instead of low-poly kit panels:
# rustic split-rail fences (log posts, three rails) in the scanned timber,
# wrought-iron railings (bars with spear tips between two rails) and stone
# piers carrying timber rails. Which parts each graphic shows (post, rails)
# follows the original art. Rails run from the tile centre toward each
# neighbouring fence piece (links, from Reconstruction), so runs meet cleanly
# at corners, T-junctions and ends; a post stands at the centre wherever the
# art has one or the run ends or turns. A piece with no neighbours lays its
# rails along local X (-0.5..0.5) through a centred post and Reconstruction
# turns y-axis pieces.
const WOOD := {2141:"post+rails",2142:"post+rails",2143:"post",2144:"rails",2145:"rails",2146:"post+rails",2147:"post+rails",2148:"post+rails",2149:"post"}
const IRON_CORNERS := [2082,2122]
const STONE := {2288:"post",2297:"post+rails",2298:"post+rails"}
const LOG := "5a4a3a"
const RAIL := "6b5644"
# The top rail reaches just under the source piece height (1.2 m), so what UO lays on a
# fence (hay over a stall divider) rests on a real rail.
const WOOD_RAILS := [0.36,0.75,1.13]
const STONE_RAILS := [0.45,0.85]
static var iron_material: StandardMaterial3D

static func handles(name: String) -> bool:
	var n := name.to_lower()
	return n == "wooden fence" or n == "iron fence" or n == "stone rail"

# Post-only pieces (porch posts, run ends drawn as a lone post) join no rails.
static func has_rails(id: int) -> bool:
	return str(WOOD.get(id,STONE.get(id,"post+rails"))) != "post"

# height: the source piece's height in metres; stacked: another fence piece
# continues above, so posts run the full height without a cap and meet it.
# links: world directions (x east, y south) toward joined neighbours.
static func build(name: String, id: int, geometry: RefCounted, facade: RefCounted, height := 1.2, stacked := false, links: Array = []) -> Node3D:
	var root := Node3D.new()
	root.set_meta("model","fence")
	var n := name.to_lower()
	var parts: String = str((STONE if n == "stone rail" else WOOD).get(id,"post+rails"))
	if not links.is_empty():
		root.set_meta("world_aligned",true)
		var straight: bool = links.size() == 2 and links[0] == -links[1]
		var post: bool = parts != "rails" or not straight
		if n == "iron fence":
			_iron_centre(root)
			for direction in links: _iron_half(_toward(root,direction))
		elif n == "stone rail":
			_pier(root,facade)
			for direction in links: _rails(_toward(root,direction),geometry,0.17,0.5,STONE_RAILS,false)
		else:
			if post: _post(root,geometry,Vector3.ZERO,maxf(height,0.6),stacked)
			for direction in links: _rails(_toward(root,direction),geometry,0.0,0.5,WOOD_RAILS,false)
		return root
	if n == "iron fence":
		_iron_run(root,Transform3D.IDENTITY)
		if id in IRON_CORNERS: _iron_run(root,Transform3D(Basis(Vector3.UP,PI/2),Vector3.ZERO))
		return root
	if n == "stone rail":
		_pier(root,facade)
		if parts != "post":
			_rails(root,geometry,-0.5,-0.17,STONE_RAILS,false)
			_rails(root,geometry,0.17,0.5,STONE_RAILS,false)
		return root
	# Posts always stand at the tile centre, so stacked post-only pieces (porch
	# posts) line up with the railing posts below them, linked or not.
	if parts in ["post","post+rails"]: _post(root,geometry,Vector3.ZERO,maxf(height,0.6),stacked)
	if parts in ["rails","post+rails"]: _rails(root,geometry,-0.5,0.5,WOOD_RAILS,true)
	return root

# A child turned so its local +X points along a world direction (x east, y south).
static func _toward(parent: Node3D, direction: Vector2i) -> Node3D:
	var half := Node3D.new()
	half.rotation.y = atan2(-float(direction.y),float(direction.x))
	parent.add_child(half)
	return half

static func _pier(parent: Node3D, facade: RefCounted) -> void:
	facade.piece(parent,Vector3(0.34,1.15,0.34),Vector3(0,0.575,0),"stone")
	facade.piece(parent,Vector3(0.40,0.08,0.40),Vector3(0,1.19,0),"stone")

# Split log post spanning the whole piece height, with a weathered cut top
# where nothing continues above.
static func _post(parent: Node3D, geometry: RefCounted, at: Vector3, height: float, stacked: bool) -> void:
	var shaft := height if stacked else height-0.04
	geometry.crafted_box(parent,Vector3(0.15,shaft,0.14),at+Vector3(0,shaft/2,0),LOG)
	if not stacked: geometry.crafted_box(parent,Vector3(0.12,0.04,0.11),at+Vector3(0,shaft+0.02,0),"5b4936")

# Split rails at the given heights. A whole-tile rail may sag and twist a
# little; half rails meeting another half at a junction stay true so they join.
static func _rails(parent: Node3D, geometry: RefCounted, from: float, to: float, heights: Array, weathered: bool) -> void:
	for i in heights.size():
		var rail: MeshInstance3D = geometry.crafted_box(parent,Vector3(to-from,0.075,0.055),Vector3((from+to)/2,float(heights[i]),0.02*(i%2) if weathered else 0.0),RAIL)
		if weathered: rail.rotation = Vector3(0.05*((i%3)-1),0,0.012*((i%2)*2-1))

# Wrought-iron railing: bottom and top rails, square bars with spear tips
# every 0.125 m (offset half a step from tile edges, so tiles repeat evenly).
static var iron_meshes := {}

static func _iron() -> Dictionary:
	if iron_meshes.is_empty():
		iron_material = StandardMaterial3D.new()
		iron_material.albedo_color = Color("26282a")
		iron_material.metallic = 0.75
		iron_material.roughness = 0.5
		var bar := BoxMesh.new()
		bar.size = Vector3(0.022,1.3,0.022)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.028
		tip.height = 0.1
		tip.radial_segments = 4
		tip.rings = 1
		var rail := BoxMesh.new()
		rail.size = Vector3(1.0,0.035,0.035)
		var half_rail := BoxMesh.new()
		half_rail.size = Vector3(0.5,0.035,0.035)
		var newel := BoxMesh.new()
		newel.size = Vector3(0.05,1.38,0.05)
		iron_meshes = {"bar":bar,"tip":tip,"rail":rail,"half_rail":half_rail,"newel":newel}
	return iron_meshes

static func _iron_run(parent: Node3D, transform: Transform3D) -> void:
	var meshes := _iron()
	var run := Node3D.new()
	run.transform = transform
	parent.add_child(run)
	for y in [0.12,1.12]:
		_part(run,meshes.rail,Vector3(0,y,0))
	for i in 8:
		var x := -0.4375+i*0.125
		_part(run,meshes.bar,Vector3(x,0.65,0))
		_part(run,meshes.tip,Vector3(x,1.35,0))

# A junction or run end gets a slightly heavier newel the half runs meet.
static func _iron_centre(parent: Node3D) -> void:
	_part(parent,_iron().newel,Vector3(0,0.69,0))

static func _iron_half(parent: Node3D) -> void:
	var meshes := _iron()
	for y in [0.12,1.12]:
		_part(parent,meshes.half_rail,Vector3(0.25,y,0))
	for i in 4:
		var x := 0.0625+i*0.125
		_part(parent,meshes.bar,Vector3(x,0.65,0))
		_part(parent,meshes.tip,Vector3(x,1.35,0))

static func _part(parent: Node3D, mesh: Mesh, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = iron_material
	instance.position = at
	parent.add_child(instance)
