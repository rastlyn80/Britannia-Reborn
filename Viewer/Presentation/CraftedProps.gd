extends RefCounted
# Simple everyday objects built from photoscanned materials (CC0 Poly Haven
# timber, rusty iron, hessian, jacquard and cut stone from Art/Surfaces):
# rope, cloth bolts, wire coils, gears and springs, nails and hinges, barrel
# staves and hoops, boards and shafts, axles, curtain rods, troughs, hide
# frames, music stands, looms, winches, harrows, millstones, hourglasses,
# cannonballs and arrows. Sizes are real-world metres; the object stands on
# y = 0 centred on its tile. Shapes follow the original art.
const NAMES := {
	"rope":"rope","tightrope":"rope","bolt of cloth":"cloth","pile of wool":"wool","bale of cotton":"bale",
	"copper wire":"wire:b87333","silver wire":"wire:c9ccd2","gold wire":"wire:e2b04a","iron wire":"wire:5a5c60",
	"gears":"gears","clock parts":"gears","axle with gears":"axlegears","springs":"springs","hinge":"hinge","nails":"nails","fitting":"fitting",
	"barrel staves":"staves","barrel hoops":"hoops","broken barrel":"brokenbarrel","unfinished barrel":"unfinishedbarrel",
	"board":"board","shaft":"shaft","axle":"axle","curtain rod":"rod",
	"water trough":"trough","stretched hide":"hideframe","music stand":"musicstand","upright loom":"loom","winch":"winch",
	"harrow":"harrow","millstones":"millstones","flour mill":"quern","hourglass":"hourglass","cannon ball":"cannonball","cannon balls":"cannonballs",
	"arrow":"arrow","arrows":"arrows","peg board":"pegboard","spool of thread":"spool","forged metal":"bar","shaft%s":"shaft","board%s":"board",
}
static var materials := {}

static func handles(name: String) -> bool:
	return NAMES.has(_key(name))

static func _key(name: String) -> String:
	return RegEx.create_from_string("%[^%]*%").sub(name.to_lower(),"",true).strip_edges()

static func _mat(id: String, tint := Color.WHITE, metallic := 0.0, roughness := 0.85, scale := 2.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [id,tint.to_html(),metallic]
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Surfaces/manifest.json"))
		for entry in manifest.sets:
			if entry.id != id: continue
			for map in entry.maps:
				if map.role == "albedo": m.albedo_texture = load("res://Art/Surfaces/"+str(map.file))
				if map.role == "normal":
					m.normal_enabled = true
					m.normal_texture = load("res://Art/Surfaces/"+str(map.file))
		m.albedo_color = tint
		m.metallic = metallic
		m.roughness = roughness
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE*scale
		materials[key] = m
	return materials[key]

static func _wood() -> StandardMaterial3D: return _mat("medieval_wood",Color("c8b8a0"),0.0,0.85,2.5)
static func _iron() -> StandardMaterial3D: return _mat("rusty_metal_02",Color("8a8a8a"),0.7,0.55,3.0)
static func _stone() -> StandardMaterial3D: return _mat("castle_wall_varriation",Color("d0ccc4"),0.0,0.9,3.0)
static func _cloth(c: String) -> StandardMaterial3D: return _mat("hessian_230",Color(c),0.0,0.95,4.0)

static func _box(p: Node3D, size: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; mi.mesh = b; mi.material_override = m; mi.position = at; mi.rotation = rot; p.add_child(mi); return mi

static func _cyl(p: Node3D, r: float, h: float, at: Vector3, m: Material, rot := Vector3.ZERO, r2 := -1.0, sides := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r if r2 < 0 else r2; c.height = h; c.radial_segments = sides; c.rings = 1
	mi.mesh = c; mi.material_override = m; mi.position = at; mi.rotation = rot; p.add_child(mi); return mi

static func _torus(p: Node3D, inner: float, outer: float, at: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = inner; t.outer_radius = outer; t.rings = 24; t.ring_segments = 8
	mi.mesh = t; mi.material_override = m; mi.position = at; mi.rotation = rot; p.add_child(mi); return mi

static func _sphere(p: Node3D, r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = r; s.height = r*2; mi.mesh = s; mi.material_override = m; mi.position = at; p.add_child(mi); return mi

static func build(name: String, seed := 0) -> Node3D:
	var kind: String = NAMES.get(_key(name),"")
	if kind == "": return null
	var root := Node3D.new()
	root.set_meta("model","crafted:"+kind)
	var rnd := RandomNumberGenerator.new(); rnd.seed = seed
	var flat := Vector3(0,0,PI/2)
	match kind.get_slice(":",0):
		"rope":
			_cyl(root,0.018,1.1,Vector3(0,0.018,0),_cloth("b89a68"),flat,-1,8)
			_torus(root,0.07,0.1,Vector3(0.55,0.018,0),_cloth("b89a68"),Vector3(PI/2,0,0))
		"cloth":
			_cyl(root,0.09,0.9,Vector3(0,0.09,0),_mat("floral_jacquard",Color("9aa6b8"),0.0,0.9,3.0),flat)
			_cyl(root,0.02,1.0,Vector3(0,0.09,0),_wood(),flat,-1,8)
		"wool":
			for i in 5: _sphere(root,0.12,Vector3(rnd.randf_range(-0.12,0.12),0.1,rnd.randf_range(-0.12,0.12)),_cloth("ece6d8"))
		"bale":
			_box(root,Vector3(0.7,0.45,0.45),Vector3(0,0.225,0),_cloth("efe9dc"))
			for x in [-0.2,0.2]: _box(root,Vector3(0.02,0.46,0.46),Vector3(x,0.225,0),_cloth("8a7050"))
		"wire":
			var c := Color(kind.get_slice(":",1))
			for i in 4: _torus(root,0.06,0.075,Vector3(0,0.01+i*0.012,0),_mat("rusty_metal_02",c,1.0,0.35,6.0))
		"gears":
			for i in 3:
				var g := _cyl(root,0.04+i*0.015,0.012,Vector3(i*0.08-0.08,0.006,rnd.randf_range(-0.04,0.04)),_mat("rusty_metal_02",Color("c8a050"),1.0,0.35,6.0),Vector3.ZERO,-1,12+i*4)
				g.rotation.y = rnd.randf()
		"axlegears":
			_cyl(root,0.01,0.25,Vector3(0,0.05,0),_iron(),flat,-1,8)
			for x in [-0.08,0.08]: _cyl(root,0.05,0.012,Vector3(x,0.05,0),_mat("rusty_metal_02",Color("c8a050"),1.0,0.35,6.0),flat,-1,16)
		"springs":
			for i in 2:
				var s := Node3D.new(); s.position = Vector3(i*0.08-0.04,0,0); root.add_child(s)
				for k in 6: _torus(s,0.012,0.02,Vector3(0,0.01+k*0.01,0),_iron())
		"hinge":
			_box(root,Vector3(0.12,0.006,0.05),Vector3(-0.06,0.003,0),_iron()); _box(root,Vector3(0.12,0.006,0.05),Vector3(0.06,0.003,0),_iron())
			_cyl(root,0.008,0.06,Vector3(0,0.008,0),_iron(),Vector3(PI/2,0,0),-1,8)
		"nails":
			_cyl(root,0.07,0.06,Vector3(0,0.03,0),_wood(),Vector3.ZERO,0.065)
			for i in 6: _cyl(root,0.003,0.07,Vector3(rnd.randf_range(-0.04,0.04),0.08,rnd.randf_range(-0.04,0.04)),_iron(),Vector3(rnd.randf_range(-0.4,0.4),0,rnd.randf_range(-0.4,0.4)),-1,6)
		"fitting":
			_box(root,Vector3(0.05,0.12,0.012),Vector3(0,0.06,0),_iron())
		"staves":
			for i in 5:
				var st := _box(root,Vector3(0.09,0.02,0.8),Vector3(i*0.1-0.2,0.01+ (i%2)*0.02,rnd.randf_range(-0.05,0.05)),_wood())
				st.rotation.y = rnd.randf_range(-0.25,0.25)
		"hoops":
			for i in 2: _torus(root,0.27,0.3,Vector3(i*0.12,0.012+i*0.02,0),_iron(),Vector3(rnd.randf_range(-0.1,0.1),0,0))
		"brokenbarrel":
			for i in 6:
				var a := TAU*i/6.0
				var st := _box(root,Vector3(0.09,0.03,0.75),Vector3(cos(a)*0.25,0.02,sin(a)*0.15),_wood()); st.rotation.y = a*0.6
			_torus(root,0.27,0.3,Vector3(0.1,0.015,0),_iron(),Vector3(0.3,0,0))
		"unfinishedbarrel":
			_cyl(root,0.28,0.06,Vector3(0,0.03,0),_wood())
			for i in 10:
				var a := TAU*i/10.0
				var st := _box(root,Vector3(0.11,0.85,0.03),Vector3(cos(a)*0.28,0.42,sin(a)*0.28),_wood()); st.rotation.y = -a+PI/2
			_torus(root,0.29,0.31,Vector3(0,0.12,0),_iron())
		"board":
			_box(root,Vector3(1.0,0.03,0.14),Vector3(0,0.015,0),_wood())
		"shaft":
			_cyl(root,0.006,0.7,Vector3(0,0.006,0),_wood(),flat,-1,6)
		"axle":
			_cyl(root,0.04,1.1,Vector3(0,0.04,0),_wood(),flat,-1,10)
		"rod":
			_cyl(root,0.015,1.2,Vector3(0,0.015,0),_wood(),flat,-1,8)
			for x in [-0.6,0.6]: _sphere(root,0.03,Vector3(x,0.015,0),_wood())
		"trough":
			_box(root,Vector3(1.0,0.06,0.5),Vector3(0,0.03,0),_wood())
			for z in [-0.23,0.23]: _box(root,Vector3(1.0,0.45,0.05),Vector3(0,0.255,z),_wood())
			for x in [-0.48,0.48]: _box(root,Vector3(0.05,0.45,0.5),Vector3(x,0.255,0),_wood())
			var water := _box(root,Vector3(0.9,0.01,0.4),Vector3(0,0.38,0),null)
			var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.16,0.26,0.3,0.85); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; wm.roughness = 0.05; wm.metallic = 0.2
			water.material_override = wm
		"hideframe":
			for x in [-0.45,0.45]: _cyl(root,0.025,1.5,Vector3(x,0.75,0),_wood(),Vector3.ZERO,-1,8)
			for y in [0.2,1.3]: _cyl(root,0.02,0.95,Vector3(0,y,0),_wood(),flat,-1,8)
			_box(root,Vector3(0.75,0.95,0.012),Vector3(0,0.75,0),_mat("brown_mud_dry",Color("a07850"),0.0,0.7,2.0))
		"musicstand":
			for i in 3:
				var a := TAU*i/3.0
				_cyl(root,0.012,0.4,Vector3(cos(a)*0.12,0.18,sin(a)*0.12),_wood(),Vector3(sin(a)*0.5,0,-cos(a)*0.5),-1,6)
			_cyl(root,0.014,0.9,Vector3(0,0.75,0),_wood(),Vector3.ZERO,-1,8)
			_box(root,Vector3(0.45,0.32,0.015),Vector3(0,1.25,0.03),_wood(),Vector3(-0.35,0,0))
		"loom":
			for x in [-0.6,0.6]: _box(root,Vector3(0.07,1.8,0.07),Vector3(x,0.9,0),_wood())
			for y in [0.25,1.75]: _box(root,Vector3(1.25,0.07,0.07),Vector3(0,y,0),_wood())
			_box(root,Vector3(1.1,1.4,0.01),Vector3(0,1.0,0),_mat("hessian_230",Color("d8c8a0"),0.0,0.95,6.0))
		"winch":
			for x in [-0.4,0.4]: _box(root,Vector3(0.08,0.5,0.4),Vector3(x,0.25,0),_wood())
			_cyl(root,0.12,0.72,Vector3(0,0.35,0),_cloth("b89a68"),flat)
			_cyl(root,0.02,1.0,Vector3(0,0.35,0),_iron(),flat,-1,8)
		"harrow":
			for i in 4: _box(root,Vector3(1.2,0.06,0.06),Vector3(0,0.12,i*0.3-0.45),_wood())
			for i in 3: _box(root,Vector3(0.06,0.06,1.0),Vector3(i*0.5-0.5,0.16,0),_wood())
			for i in 4:
				for k in 4: _cyl(root,0.01,0.12,Vector3(k*0.35-0.52,0.06,i*0.3-0.45),_iron(),Vector3.ZERO,0.0,6)
		"millstones":
			_cyl(root,0.45,0.18,Vector3(0,0.09,0),_stone()); _cyl(root,0.45,0.18,Vector3(0.1,0.27,0.05),_stone())
		"quern":
			_box(root,Vector3(1.0,0.6,1.0),Vector3(0,0.3,0),_wood())
			_cyl(root,0.4,0.15,Vector3(0,0.68,0),_stone()); _cyl(root,0.4,0.15,Vector3(0,0.83,0),_stone())
			_cyl(root,0.02,0.4,Vector3(0.3,1.0,0),_wood(),Vector3.ZERO,-1,8)
		"hourglass":
			for y in [0.01,0.29]: _cyl(root,0.06,0.02,Vector3(0,y,0),_wood())
			var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.85,0.9,0.95,0.35); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.roughness = 0.05
			_cyl(root,0.05,0.13,Vector3(0,0.085,0),gm,Vector3.ZERO,0.005); _cyl(root,0.005,0.13,Vector3(0,0.215,0),gm,Vector3.ZERO,0.05)
			_cyl(root,0.03,0.03,Vector3(0,0.035,0),_mat("coast_sand_01",Color("e8d8a8"),0.0,0.9,4.0),Vector3.ZERO,0.045)
			for a in [0.0,2.1,4.2]: _cyl(root,0.006,0.28,Vector3(cos(a)*0.055,0.15,sin(a)*0.055),_wood(),Vector3.ZERO,-1,6)
		"cannonball":
			_sphere(root,0.07,Vector3(0,0.07,0),_iron())
		"cannonballs":
			for at in [Vector3(-0.08,0.07,0),Vector3(0.08,0.07,0),Vector3(0,0.07,0.13),Vector3(0,0.18,0.045)]: _sphere(root,0.07,at,_iron())
		"arrow", "arrows":
			for i in (1 if kind == "arrow" else 6):
				var a := Node3D.new(); a.position = Vector3(0,0.008+i*0.004,i*0.02-0.05); a.rotation.y = rnd.randf_range(-0.08,0.08); root.add_child(a)
				_cyl(a,0.004,0.75,Vector3(0,0,0),_wood(),flat,-1,6)
				_cyl(a,0.008,0.05,Vector3(0.38,0,0),_iron(),Vector3(0,0,-PI/2),0.0,6)
				_box(a,Vector3(0.1,0.002,0.025),Vector3(-0.33,0,0),_cloth("e8e0d0"))
		"pegboard":
			_box(root,Vector3(0.6,0.4,0.02),Vector3(0,0.2,0),_wood())
		"spool":
			_cyl(root,0.025,0.06,Vector3(0,0.03,0),_cloth("d8d0c0"),Vector3.ZERO,-1,12)
			for y in [0.002,0.058]: _cyl(root,0.032,0.004,Vector3(0,y,0),_wood())
		"bar":
			_box(root,Vector3(0.3,0.03,0.05),Vector3(0,0.015,0),_iron())
	for mi in root.find_children("*","MeshInstance3D",true,false): (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root
