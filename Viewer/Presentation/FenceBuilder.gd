extends RefCounted
# Fences built from photoscanned materials instead of low-poly kit panels:
# rustic split-rail fences (log posts, three rails) in the scanned timber,
# wrought-iron railings (bars with spear tips between two rails) and stone
# piers carrying timber rails. One source tile is one piece, laid out along
# local X across the tile (-0.5..0.5); Reconstruction turns y-axis pieces.
# Which parts each graphic shows (post, rails, a corner's second run) follows
# the original art.
const WOOD := {2141:"post+rails",2142:"post+rails",2143:"post",2144:"rails",2145:"rails",2146:"post+rails",2147:"post+rails",2148:"post+rails",2149:"post"}
const IRON_CORNERS := [2082,2122]
const STONE := {2288:"post",2297:"post+rails",2298:"post+rails"}
const LOG := "5a4a3a"
const RAIL := "6b5644"
static var iron_material: StandardMaterial3D

static func handles(name: String) -> bool:
	var n := name.to_lower()
	return n == "wooden fence" or n == "iron fence" or n == "stone rail"

# height: the source piece's height in metres; stacked: another fence piece
# continues above, so posts run the full height without a cap and meet it.
static func build(name: String, id: int, geometry: RefCounted, facade: RefCounted, height := 1.2, stacked := false) -> Node3D:
	var root := Node3D.new()
	root.set_meta("model","fence")
	var n := name.to_lower()
	if n == "iron fence":
		_iron_run(root,Transform3D.IDENTITY)
		if id in IRON_CORNERS: _iron_run(root,Transform3D(Basis(Vector3.UP,PI/2),Vector3.ZERO))
		return root
	var parts: String = str((STONE if n == "stone rail" else WOOD).get(id,"post+rails"))
	if n == "stone rail":
		facade.piece(root,Vector3(0.34,1.15,0.34),Vector3(-0.33,0.575,0),"stone")
		facade.piece(root,Vector3(0.40,0.08,0.40),Vector3(-0.33,1.19,0),"stone")
		if parts != "post": _rails(root,geometry,-0.16,0.5,[0.45,0.85])
		return root
	if parts in ["post","post+rails","corner"]: _post(root,geometry,Vector3(-0.44,0,0),maxf(height,0.6),stacked)
	if parts in ["rails","post+rails","corner"]: _rails(root,geometry,-0.5,0.5,[0.32,0.62,0.92])
	if parts == "corner":
		var turned := Node3D.new()
		turned.rotation.y = PI/2
		root.add_child(turned)
		_rails(turned,geometry,-0.5,0.5,[0.32,0.62,0.92])
	return root

# Split log post spanning the whole piece height, with a weathered cut top
# where nothing continues above.
static func _post(parent: Node3D, geometry: RefCounted, at: Vector3, height: float, stacked: bool) -> void:
	var shaft := height if stacked else height-0.04
	geometry.crafted_box(parent,Vector3(0.15,shaft,0.14),at+Vector3(0,shaft/2,0),LOG)
	if not stacked: geometry.crafted_box(parent,Vector3(0.12,0.04,0.11),at+Vector3(0,shaft+0.02,0),"5b4936")

# Split rails at the given heights; each sags and twists a little.
static func _rails(parent: Node3D, geometry: RefCounted, from: float, to: float, heights: Array) -> void:
	for i in heights.size():
		var rail: MeshInstance3D = geometry.crafted_box(parent,Vector3(to-from,0.075,0.055),Vector3((from+to)/2,float(heights[i]),0.02*(i%2)),RAIL)
		rail.rotation = Vector3(0.05*((i%3)-1),0,0.012*((i%2)*2-1))

# Wrought-iron railing: bottom and top rails, square bars with spear tips.
static func _iron_run(parent: Node3D, transform: Transform3D) -> void:
	if iron_material == null:
		iron_material = StandardMaterial3D.new()
		iron_material.albedo_color = Color("26282a")
		iron_material.metallic = 0.75
		iron_material.roughness = 0.5
	var run := Node3D.new()
	run.transform = transform
	parent.add_child(run)
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
	for y in [0.12,1.12]:
		_part(run,rail,Vector3(0,y,0))
	for i in 8:
		var x := -0.4375+i*0.125
		_part(run,bar,Vector3(x,0.65,0))
		_part(run,tip,Vector3(x,1.35,0))

static func _part(parent: Node3D, mesh: Mesh, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = iron_material
	instance.position = at
	parent.add_child(instance)
