extends RefCounted
# Optional owner-supplied shop/guild sign faces (scripts/install-sign-art.py into
# the ignored res://local-art/signs). Each sign pair (two facings of one sign,
# graphics 2979-3086) shares the image of its first graphic. Without them the
# caller keeps its plain board, so the public build never depends on them.
const ROOT := "res://local-art/signs"
const FIRST := 2979
const LAST := 3086
static var materials := {}

static func key(graphic: int) -> int:
	return graphic-(graphic-FIRST)%2 if graphic >= FIRST and graphic <= LAST else graphic

static func face(graphic: int) -> StandardMaterial3D:
	var id := key(graphic)
	if not materials.has(id):
		var path := "%s/%d.png" % [ROOT,id]
		var material: StandardMaterial3D = null
		if FileAccess.file_exists(path+".import") or ResourceLoader.exists(path):
			material = StandardMaterial3D.new()
			material.albedo_texture = load(path)
			material.roughness = 0.82
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[id] = material
	return materials[id]

static func signature() -> String:
	return FileAccess.get_sha256(ROOT+"/catalog.json") if FileAccess.file_exists(ROOT+"/catalog.json") else "none"

# Square board hanging on two iron links from an arm at arm_y, centred on x=0,
# painted with the face on both sides (the back is turned so it reads correctly).
static func board(root: Node3D, geometry: RefCounted, material: Material, side: float, arm_y: float) -> float:
	var centre := arm_y-0.17-side/2
	var frame: MeshInstance3D = geometry.crafted_box(root,Vector3(side+0.06,side+0.06,0.06),Vector3(0,centre,0),"3a2a1c")
	frame.name = "SignBoard"
	for facing in [1.0,-1.0]:
		var quad := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(side,side)
		quad.mesh = plane
		quad.position = Vector3(0,centre,facing*0.031)
		if facing < 0: quad.rotation.y = PI
		quad.material_override = material
		quad.name = "SignFace"
		root.add_child(quad)
	for x in [-side*0.36,side*0.36]:
		var link: MeshInstance3D = geometry.cylinder(root,0.012,0.17,Vector3(x,arm_y-0.085,0),"2f3333")
		link.name = "SignLink"
	return centre
