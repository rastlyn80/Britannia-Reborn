extends RefCounted
# Door leaves built at the doorway's own size from photoscanned CC0 Poly Haven
# surfaces (Art/Surfaces): plank faces, ledges and a Z-brace on the back, long
# iron strap hinges with nail heads and a ring pull; strong and metal doors are
# studded and iron-banded, gates are open board-and-rail. The leaf spans x from
# 0 (hinge side) to width, stands on y = 0 and is centred on z.
static var materials := {}

static func surface(id: String, tint := Color.WHITE, metallic := 0.0) -> StandardMaterial3D:
	var key := id+tint.to_html()+str(metallic)
	if not materials.has(key):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Surfaces/manifest.json"))
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.metallic = metallic
		material.uv1_triplanar = true
		for entry in manifest.sets:
			if entry.id != id: continue
			material.uv1_scale = Vector3.ONE/float(entry.sizeMeters[0])
			for map in entry.maps:
				var texture: Texture2D = load("res://Art/Surfaces/"+str(map.file))
				match str(map.role):
					"albedo": material.albedo_texture = texture
					"normal":
						material.normal_enabled = true
						material.normal_texture = texture
					"roughness": material.roughness_texture = texture
		materials[key] = material
	return materials[key]

# Door type (server class name) -> style.
static func style_for(type: String) -> String:
	if "Gate" in type and not "Iron" in type: return "gate"
	if "Barred" in type or "IronGate" in type or "Portcullis" in type: return "bars"
	if "Metal" in type or "Strong" in type or "Iron" in type: return "strong"
	if "Light" in type: return "light"
	return "wood"

static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material, name := "") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material
	if name != "": mesh.name = name
	parent.add_child(mesh)
	return mesh

static func build(width: float, height: float, style: String) -> Node3D:
	var root := Node3D.new()
	var iron := surface("rusty_metal_02",Color(0.32,0.30,0.29),0.55)
	var thick := 0.07
	if style == "bars":
		var frame := surface("rusty_metal_02",Color(0.26,0.25,0.25),0.7)
		for y in [0.06,height*0.5,height-0.06]: _box(root,Vector3(width,0.06,0.05),Vector3(width/2,y,0),frame)
		for x in [0.04,width-0.04]: _box(root,Vector3(0.06,height,0.06),Vector3(x,height/2,0),frame)
		var bars := 7
		for i in bars:
			var bar := MeshInstance3D.new()
			var rod := CylinderMesh.new()
			rod.top_radius = 0.016
			rod.bottom_radius = 0.016
			rod.height = height-0.1
			rod.radial_segments = 8
			bar.mesh = rod
			bar.position = Vector3(width*(i+1)/(bars+1),height/2,0)
			bar.material_override = frame
			root.add_child(bar)
		return root
	if style == "gate":
		# Open board gate: vertical palings on two rails with a brace.
		var planks := surface("medieval_wood",Color(0.92,0.86,0.78))
		var count := 6
		for i in count:
			var x := width*(i+0.5)/count
			_box(root,Vector3(width/count*0.72,height*0.9,0.045),Vector3(x,height*0.47,0),planks)
		for y in [height*0.18,height*0.78]: _box(root,Vector3(width,0.11,0.05),Vector3(width/2,y,-0.045),planks)
		var brace := _box(root,Vector3(Vector2(width,height*0.6).length(),0.09,0.045),Vector3(width/2,height*0.48,-0.045),planks)
		brace.rotation.z = atan2(height*0.6,width)
		return root
	var face := surface("medieval_wood") if style == "strong" else surface("rough_pine_door",Color(1.12,1.04,0.96) if style == "light" else Color.WHITE)
	_box(root,Vector3(width,height,thick),Vector3(width/2,height/2,0),face,"Planks")
	# Back ledges and Z-brace.
	var ledge := surface("medieval_wood",Color(0.85,0.8,0.75))
	for y in [height*0.18,height*0.82]: _box(root,Vector3(width*0.94,0.13,0.035),Vector3(width/2,y,-thick/2-0.017),ledge)
	var span := Vector2(width*0.86,height*0.64)
	var brace := _box(root,Vector3(span.length(),0.11,0.035),Vector3(width/2,height/2,-thick/2-0.017),ledge)
	brace.rotation.z = atan2(span.y,span.x)
	# Strap hinges reaching most of the way across, with nail heads.
	var straps := [0.2,0.8] if style != "strong" else [0.12,0.38,0.62,0.88]
	for t in straps:
		var y: float = height*t
		_box(root,Vector3(width*(0.92 if style == "strong" else 0.74),0.055,0.012),Vector3(width*(0.46 if style == "strong" else 0.37),y,thick/2+0.006),iron)
		_box(root,Vector3(0.05,0.09,0.03),Vector3(0.025,y,0),iron)
		for k in 4:
			var nail := MeshInstance3D.new()
			var head := SphereMesh.new()
			head.radius = 0.012
			head.height = 0.012
			nail.mesh = head
			nail.position = Vector3(width*(0.1+0.18*k),y,thick/2+0.012)
			nail.material_override = iron
			root.add_child(nail)
	# Ring pull on a back plate, at hand height on the latch side.
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.045
	disc.bottom_radius = 0.045
	disc.height = 0.012
	plate.mesh = disc
	plate.rotation.x = PI/2
	plate.position = Vector3(width*0.84,1.0,thick/2+0.006)
	plate.material_override = iron
	root.add_child(plate)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.06
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = Vector3(width*0.84,0.95,thick/2+0.02)
	ring.material_override = iron
	root.add_child(ring)
	return root
