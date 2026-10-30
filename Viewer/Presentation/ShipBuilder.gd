extends RefCounted
# Classic boats drawn as ships: a lofted plank hull, deck, rails, a mast with
# yard and square sail, a bowsprit or dragon prow, and a rudder, sized from
# the multi's component bounds (scripts/prepare-multis.py) and turned to its
# facing. Boat multis 0x00-0x17: small, small dragon, medium, medium dragon,
# large, large dragon; each four ids north, east, south, west. Local origin is
# the multi's centre tile; the deck stands 3 Z above the boat (as the server's
# deck tiles do), so walking on it agrees with the movement cells.
const ELEVATION := 0.2
const DECK_Z := 3

static func handles(id: int) -> bool:
	return id >= 0 and id < 0x18

static func _surface(name: String, tint: Color, scale := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var path := "res://Art/Surfaces/%s_diff_1k.jpg" % name
	if ResourceLoader.exists(path): material.albedo_texture = load(path)
	var normal := "res://Art/Surfaces/%s_nor_gl_1k.jpg" % name
	if ResourceLoader.exists(normal):
		material.normal_enabled = true
		material.normal_texture = load(normal)
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE*scale
	material.roughness = 0.85
	return material

# Scanned ships (CC-BY Sketchfab, Art/Objaverse) per size and kind: a caravel,
# the Nao Victoria and a weathered galleon; dragon boats are a Norse longship
# with a carved dragon prow and shields along the rail. bow: +1 when the model's bow points
# to +Z, -1 to -Z. deck: the deck's height as a share of the model's length
# (measured by ray casts onto the hull), so the scaled deck meets the server
# deck, DECK_Z above the boat.
const MODELS := {
	"0/false":{"model":"ship_caravel","bow":1,"deck":0.111},
	"1/false":{"model":"ship_nao","bow":1,"deck":0.218},
	"2/false":{"model":"ship_galleon","bow":1,"deck":0.161},
	"0/true":{"model":"ship_longship","bow":-1,"deck":0.063},
	"1/true":{"model":"ship_longship","bow":-1,"deck":0.063},
	"2/true":{"model":"ship_longship","bow":-1,"deck":0.063},
}

static func scanned(id: int) -> Dictionary:
	var spec: Dictionary = MODELS.get("%d/%s" % [id/8,(id/4)%2 == 1],{})
	if spec.is_empty() or not ResourceLoader.exists("res://Art/Objaverse/%s/%s.glb" % [spec.model,spec.model]): return {}
	return spec

# Bounds are the component bounds of the north-facing shape (Rect2i of tiles).
static func build(id: int, bounds: Rect2i) -> Node3D:
	var facing := id%4
	var dragon := (id/4)%2 == 1
	var size := (id/8)
	# Bounds of the ship as if facing north: length along y.
	var length_tiles := maxi(bounds.size.x,bounds.size.y)+1
	var width_tiles := mini(bounds.size.x,bounds.size.y)+1
	var spec := scanned(id)
	if not spec.is_empty(): return _scanned_ship(spec,facing,length_tiles,width_tiles,id)
	var root := Node3D.new()
	root.name = "Ship"
	var hull_wood := _surface("brown_planks_03",Color(0.72,0.6,0.48),0.9)
	var deck_wood := _surface("brown_planks_03",Color(0.95,0.86,0.72),0.8)
	var trim := _surface("medieval_wood",Color(0.55,0.42,0.3),1.0)
	var half_length := length_tiles/2.0
	var half_width := width_tiles/2.0-0.15
	var deck_y := DECK_Z*ELEVATION
	var keel_y := deck_y-1.1
	var rail_y := deck_y+0.32
	# Stations from bow (t = 0, local -z) to stern (t = 1).
	var stations := 22
	var rings: Array = []
	for i in stations+1:
		var t := float(i)/stations
		var z := -half_length+t*length_tiles
		var beam := half_width*(pow(minf(1.0,t/0.42),0.55) if t < 0.42 else 1.0-0.22*pow(maxf(0.0,(t-0.7)/0.3),1.6))
		beam = maxf(beam,0.04)
		var sheer := 0.35*pow(1.0-minf(1.0,t/0.3),2.0)+0.18*pow(maxf(0.0,(t-0.85)/0.15),2.0)
		var depth := keel_y+0.35*pow(1.0-minf(1.0,t/0.25),2.0)
		rings.append([
			Vector3(-beam,rail_y+sheer,z),
			Vector3(-beam*0.92,deck_y-0.35,z),
			Vector3(-beam*0.55,depth+0.15,z),
			Vector3(0,depth,z),
			Vector3(beam*0.55,depth+0.15,z),
			Vector3(beam*0.92,deck_y-0.35,z),
			Vector3(beam,rail_y+sheer,z)])
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in stations:
		var a: Array = rings[i]
		var b: Array = rings[i+1]
		for k in a.size()-1:
			hull.add_vertex(a[k]); hull.add_vertex(b[k]); hull.add_vertex(b[k+1])
			hull.add_vertex(a[k]); hull.add_vertex(b[k+1]); hull.add_vertex(a[k+1])
	# Transom: the stern closed flat.
	var last: Array = rings[stations]
	for k in range(1,last.size()-1):
		hull.add_vertex(last[0]); hull.add_vertex(last[k+1]); hull.add_vertex(last[k])
	hull.generate_normals()
	var hull_mesh := MeshInstance3D.new()
	hull_mesh.name = "Hull"
	hull_mesh.mesh = hull.commit()
	hull_mesh.material_override = hull_wood
	# Both sides of the planking show (the rail's inner face is seen from the deck).
	hull_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(hull_mesh)
	# Deck: the hull outline at deck height.
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in stations:
		var a: Array = rings[i]
		var b: Array = rings[i+1]
		var al := Vector3(a[1].x,deck_y,a[1].z)
		var ar := Vector3(a[5].x,deck_y,a[5].z)
		var bl := Vector3(b[1].x,deck_y,b[1].z)
		var br := Vector3(b[5].x,deck_y,b[5].z)
		deck.add_vertex(al); deck.add_vertex(br); deck.add_vertex(bl)
		deck.add_vertex(al); deck.add_vertex(ar); deck.add_vertex(br)
	deck.generate_normals()
	var deck_mesh := MeshInstance3D.new()
	deck_mesh.name = "Deck"
	deck_mesh.mesh = deck.commit()
	deck_mesh.material_override = deck_wood
	root.add_child(deck_mesh)
	# Rail caps along both gunwales.
	for side in [0,6]:
		for i in stations:
			var p: Vector3 = rings[i][side]
			var q: Vector3 = rings[i+1][side]
			_bar(root,p,q,0.07,trim)
	# Mast, yard and sail amidships, a little forward.
	var mast_z := -length_tiles*0.06
	var mast_height := 4.2+size*0.9
	var mast := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.11
	pole.height = mast_height
	mast.mesh = pole
	mast.position = Vector3(0,deck_y+mast_height/2,mast_z)
	mast.material_override = trim
	root.add_child(mast)
	var yard_width := half_width*2.0+0.9
	_bar(root,Vector3(-yard_width/2,deck_y+mast_height-0.35,mast_z+0.12),Vector3(yard_width/2,deck_y+mast_height-0.35,mast_z+0.12),0.06,trim)
	var sail := SurfaceTool.new()
	sail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 8
	var rows := 6
	var top := deck_y+mast_height-0.4
	var bottom := deck_y+1.25
	var grid: Array = []
	for r in rows+1:
		var line: Array = []
		for c in columns+1:
			var u := float(c)/columns
			var v := float(r)/rows
			var bulge := 0.45*sin(u*PI)*sin(maxf(0.08,v)*PI*0.9)
			line.append(Vector3(lerpf(-yard_width/2+0.1,yard_width/2-0.1,u)*(1.0-0.08*v),lerpf(top,bottom,v),mast_z+0.18+bulge))
		grid.append(line)
	for r in rows:
		for c in columns:
			sail.set_uv(Vector2(float(c)/columns,float(r)/rows)); sail.add_vertex(grid[r][c])
			sail.set_uv(Vector2(float(c+1)/columns,float(r+1)/rows)); sail.add_vertex(grid[r+1][c+1])
			sail.set_uv(Vector2(float(c)/columns,float(r+1)/rows)); sail.add_vertex(grid[r+1][c])
			sail.set_uv(Vector2(float(c)/columns,float(r)/rows)); sail.add_vertex(grid[r][c])
			sail.set_uv(Vector2(float(c+1)/columns,float(r)/rows)); sail.add_vertex(grid[r][c+1])
			sail.set_uv(Vector2(float(c+1)/columns,float(r+1)/rows)); sail.add_vertex(grid[r+1][c+1])
	sail.generate_normals()
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("e4d8bd") if not dragon else Color("8f2f28")
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sail_mesh := MeshInstance3D.new()
	sail_mesh.name = "Sail"
	sail_mesh.mesh = sail.commit()
	sail_mesh.material_override = cloth
	root.add_child(sail_mesh)
	# Rigging: stays from masthead to bow and stern.
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color("3b3125")
	var head := Vector3(0,deck_y+mast_height-0.05,mast_z)
	_bar(root,head,Vector3(0,rail_y+0.3,-half_length+0.2),0.015,rope)
	_bar(root,head,Vector3(0,rail_y+0.15,half_length-0.3),0.015,rope)
	for side in [-1,1]: _bar(root,head,Vector3(side*half_width,rail_y,mast_z+0.6),0.012,rope)
	# Prow: a bowsprit, or a carved dragon neck and head.
	var bow := Vector3(0,rail_y+0.35,-half_length)
	if dragon:
		var neck := [bow,bow+Vector3(0,0.55,-0.35),bow+Vector3(0,1.0,-0.45),bow+Vector3(0,1.25,-0.25)]
		for k in neck.size()-1: _bar(root,neck[k],neck[k+1],0.16-k*0.03,trim)
		var skull := MeshInstance3D.new()
		var snout := PrismMesh.new()
		snout.size = Vector3(0.3,0.26,0.55)
		skull.mesh = snout
		skull.position = bow+Vector3(0,1.3,-0.42)
		skull.rotation = Vector3(-PI/2-0.3,0,0)
		skull.material_override = trim
		root.add_child(skull)
	else:
		_bar(root,bow,bow+Vector3(0,0.35,-1.1),0.06,trim)
	# Rudder at the stern.
	var rudder := MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.1,1.2,0.5)
	rudder.mesh = blade
	rudder.position = Vector3(0,deck_y-0.35,half_length+0.22)
	rudder.material_override = trim
	root.add_child(rudder)
	root.rotation.y = [0.0,-PI/2,PI,PI/2][facing]
	return root

# The scanned hull, scaled so its length is the footprint's, its deck lifted
# to the server deck, the bow turned to the boat's facing; ShipMotion gives it
# the swell and the foam.
static func _scanned_ship(spec: Dictionary, facing: int, length_tiles: int, width_tiles: int, id: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Ship"
	root.set_script(preload("res://Presentation/ShipMotion.gd"))
	var hull := Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	var model: Node3D = load("res://Art/Objaverse/%s/%s.glb" % [spec.model,spec.model]).instantiate()
	var box := AABB()
	var first := true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var part: AABB = (mesh as MeshInstance3D).transform*(mesh as MeshInstance3D).get_aabb()
		box = part if first else box.merge(part)
		first = false
	var length := float(length_tiles)
	var k := length/maxf(box.size.z,0.001)
	model.scale = Vector3.ONE*k
	model.position = Vector3(-box.get_center().x*k,DECK_Z*ELEVATION-float(spec.deck)*length,-box.get_center().z*k)
	if int(spec.bow) > 0: model.rotation.y = PI; model.position.x = -model.position.x; model.position.z = -model.position.z
	hull.add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false): (mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.set_meta("ship_model",str(spec.model))
	root.call("setup",hull,length,float(width_tiles),id)
	root.rotation.y = [0.0,-PI/2,PI,PI/2][facing]
	return root

static func _bar(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var length := a.distance_to(b)
	if length < 0.001: return
	var piece := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	piece.mesh = mesh
	piece.material_override = material
	piece.position = (a+b)/2
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	piece.basis = Basis(side,up,side.cross(up).normalized()).orthonormalized()
	parent.add_child(piece)
