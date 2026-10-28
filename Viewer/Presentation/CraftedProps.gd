extends RefCounted
# Simple everyday objects built from photoscanned materials (CC0 Poly Haven
# timber, rusty iron, hessian, jacquard and cut stone from Art/Surfaces):
# rope, cloth bolts, wire coils, gears and springs, nails and hinges, barrel
# staves and hoops, boards and shafts, axles, curtain rods, troughs, hide
# frames, music stands, looms, winches, harrows, millstones, hourglasses,
# cannonballs and arrows, loose armour pieces, a backpack, a memorial and
# dust-sheeted chairs. Sizes are real-world metres; the object stands on
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
	"shirt":"garment:shirt:d8d0bc","fancy shirt":"garment:shirt:e8e0f0","ninja shirt":"garment:shirt:2a2a2e","long pants":"garment:pants:5a4a38","ninja pants":"garment:pants:2a2a2e","skirt":"garment:skirt:6a3a3a","cloak":"garment:cloak:3a3a48","gargish robe":"garment:cloak:2c4a50","kimono":"garment:robe:8a2a30","bandana":"garment:cloth:8a2020",
	"necklace":"jewel:e2b04a:0.09","silver necklace":"jewel:c9ccd2:0.09","beads":"jewel:8a3a2a:0.07","bracelet":"jewel:e2b04a:0.04","earrings":"earrings","gold belt":"jewel:e2b04a:0.2",
	"wood curls":"curls","cocoon":"eggcase","gruesome standard":"standard","broken furniture":"brokenshelf","standing harp":"harp:1.5","lap harp":"harp:0.6",
	"wall cracks":"cracks","cake":"cake","pilllow":"pillow","dried herbs":"herbs","bloody bandage":"bandage:b02020",
	"sewing kit":"sewing","paints and brush":"palette","baked pie":"pie:b8783a","unbaked pie":"pie:e8d0a0","full vials":"vials:1","empty vials":"vials:0","flask stand":"vials:0",
	"decorative armor":"armorstand","dough":"dough","horse shoes":"horseshoes","tambourine":"tambourine","blood moss":"reagent:8a1a14","sulfurous ash":"reagent:d8c030","spider's silk":"reagent:f0f0f0",
	"sextant parts":"brassparts","carrot":"carrot","dyes":"dyes","knitting":"knitting","bowl of lettuce":"bowl:5a9a3a","bowl of carrots":"bowl:d06a20","rudder":"rudder","bolas":"bolas","feather":"feather","feather%s":"feather","eye of newt":"reagent:a02020","sign":"plank",
	"chainmail leggings":"leggings:mail:b8bcc2","ringmail leggings":"leggings:mail:9a8058","leather sleeves":"sleeves:leather:6a4628","studded sleeves":"sleeves:studded:5a3a20","ringmail sleeves":"sleeves:mail:9a8058",
	"leather gorget":"gorget:leather:6a4628","studded gorget":"gorget:studded:5a3a20","platemail gorget":"gorget:plate:b8bcc2","bone armor":"bones:armor","bone gloves":"bones:gloves","bone legs":"bones:legs",
	"raw cotton":"cotton","bridle":"bridle","prow":"prow","dart trap":"darttrap","serpent crest":"crest","void essence":"essence","covered chair":"coveredchair","iron maiden":"ironmaiden",
	"century plant":"agave","backpack":"backpack","pampas grass":"pampas","memorial to gwenno":"memorial","horse barding":"barding",
	"glass":"glassmug","dice and cup":"dice","eggs":"eggs","egg case":"eggcase","lockpick":"picks:1","lockpicks":"picks:3","spike trap":"spikes","hatch":"hatch","rope ladder":"ropeladder","brush":"brush","coconut":"coconut","full apron":"garment:apron:9a968a","half apron":"garment:apron:9a968a",
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
# Polished mail and plate: the rust scan would read as brown, so plain steel.
static func _steel(c: String) -> StandardMaterial3D:
	var key := "steel/"+c
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.metallic = 0.6
		m.roughness = 0.4
		materials[key] = m
	return materials[key]

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

static func _model(p: Node3D, path: String, size: float, at := Vector3.ZERO, rot := Vector3.ZERO, tint: Variant = null) -> Node3D:
	if not ResourceLoader.exists(path): return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for mi in n.find_children("*","MeshInstance3D",true,false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k := size/maxf(maxf(box.size.x,box.size.y),maxf(box.size.z,0.001))
	var holder := Node3D.new()
	holder.add_child(n)
	n.scale = Vector3.ONE*k
	n.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*k
	holder.position = at
	holder.rotation = rot
	if tint != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.metallic = 0.9
		m.roughness = 0.35
		for mi in n.find_children("*","MeshInstance3D",true,false): (mi as MeshInstance3D).material_override = m
	p.add_child(holder)
	return holder

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
		"garment":
			# Laid-out garment: panels of photoscanned cloth with a little drape.
			var cm := _mat("hessian_230",Color(kind.get_slice(":",2)),0.0,0.95,5.0)
			match kind.get_slice(":",1):
				"shirt":
					_box(root,Vector3(0.42,0.025,0.5),Vector3(0,0.0125,0),cm)
					for sx in [-1.0,1.0]: _box(root,Vector3(0.36,0.022,0.14),Vector3(sx*0.33,0.011,-0.15),cm,Vector3(0,sx*0.35,0))
					_box(root,Vector3(0.14,0.03,0.06),Vector3(0,0.015,-0.24),cm)
				"pants":
					_box(root,Vector3(0.36,0.025,0.16),Vector3(0,0.0125,-0.33),cm)
					for sx in [-1.0,1.0]: _box(root,Vector3(0.16,0.024,0.72),Vector3(sx*0.1,0.012,0.08),cm,Vector3(0,sx*0.08,0))
				"skirt":
					var sk := _cyl(root,0.36,0.03,Vector3(0,0.015,0.05),cm,Vector3.ZERO,0.36,24); sk.scale = Vector3(1.0,1.0,0.75)
					_box(root,Vector3(0.3,0.03,0.06),Vector3(0,0.016,-0.24),cm)
				"cloak", "robe":
					var cl := _box(root,Vector3(0.8,0.03,1.0),Vector3(0,0.015,0),cm)
					for i in 3: _box(root,Vector3(0.05,0.05,0.95),Vector3(-0.25+i*0.25,0.03,0),cm)
					if kind.get_slice(":",1) == "robe": for sx in [-1.0,1.0]: _box(root,Vector3(0.4,0.025,0.2),Vector3(sx*0.5,0.012,-0.3),cm,Vector3(0,sx*0.3,0))
				"apron":
					_box(root,Vector3(0.5,0.02,0.65),Vector3(0,0.01,0),cm)
					for sx in [-1.0,1.0]: _cyl(root,0.006,0.45,Vector3(sx*0.35,0.006,-0.25),cm,Vector3(0,sx*0.6,PI/2),-1,6)
				"cloth":
					_box(root,Vector3(0.35,0.015,0.35),Vector3(0,0.008,0),cm,Vector3(0,0.785,0))
		"jewel":
			var gold := StandardMaterial3D.new(); gold.albedo_color = Color(kind.get_slice(":",1)); gold.metallic = 1.0; gold.roughness = 0.22
			var r := float(kind.get_slice(":",2))
			_torus(root,r-0.004,r,Vector3(0,0.004,0),gold)
			var gem := StandardMaterial3D.new(); gem.albedo_color = Color("c02a3a"); gem.roughness = 0.05
			_sphere(root,0.01 if r < 0.05 else 0.014,Vector3(0,0.012,r),gem)
		"earrings":
			var eg := StandardMaterial3D.new(); eg.albedo_color = Color("e2b04a"); eg.metallic = 1.0; eg.roughness = 0.22
			for x in [-0.025,0.025]: _torus(root,0.008,0.012,Vector3(x,0.003,0),eg,Vector3(PI/2,0,0))
		"glassmug":
			var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.7,0.75,0.95,0.45); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.roughness = 0.05; gm.metallic = 0.1
			_cyl(root,0.04,0.12,Vector3(0,0.06,0),gm,Vector3.ZERO,0.035)
			_torus(root,0.02,0.028,Vector3(0.045,0.06,0),gm,Vector3(PI/2,0,0))
		"dice":
			_cyl(root,0.04,0.1,Vector3(-0.05,0.05,0),_mat("brown_mud_dry",Color("7a2a20"),0.0,0.7,6.0),Vector3.ZERO,0.035)
			for at in [Vector3(0.04,0.01,0.02),Vector3(0.07,0.01,-0.02)]: _box(root,Vector3(0.02,0.02,0.02),at,_mat("white_plaster_02",Color("f2efe6"),0.0,0.4,8.0),Vector3(0,rnd.randf(),0))
		"eggcase":
			var sac := _sphere(root,0.18,Vector3(0,0.12,0),_mat("white_plaster_02",Color("e8e6dc"),0.0,0.6,6.0)); sac.scale = Vector3(1.0,0.65,1.3)
		"eggs":
			var em := _mat("white_plaster_02",Color("f2ecdc"),0.0,0.5,8.0)
			for i in 3:
				var e := _sphere(root,0.025,Vector3(i*0.045-0.045,0.022,rnd.randf_range(-0.02,0.02)),em); e.scale = Vector3(0.8,0.9,1.2)
		"picks":
			for i in int(kind.get_slice(":",1)): _box(root,Vector3(0.12,0.004,0.006),Vector3(0,0.003+i*0.003,i*0.012),_iron(),Vector3(0,rnd.randf_range(-0.3,0.3),0))
		"spikes":
			_box(root,Vector3(0.9,0.03,0.9),Vector3(0,0.015,0),_iron())
			for i in 5:
				for k in 5: _cyl(root,0.0,0.18,Vector3(i*0.18-0.36,0.12,k*0.18-0.36),_iron(),Vector3.ZERO,0.025,6)
		"hatch":
			for i in 5: _box(root,Vector3(0.18,0.04,0.95),Vector3(i*0.19-0.38,0.02,0),_wood())
			for z in [-0.3,0.3]: _box(root,Vector3(0.9,0.012,0.06),Vector3(0,0.045,z),_iron())
			_torus(root,0.03,0.04,Vector3(0.3,0.05,0),_iron(),Vector3(PI/2,0,0))
		"ropeladder":
			for x in [-0.2,0.2]: _cyl(root,0.012,2.4,Vector3(x,1.2,0),_cloth("b89a68"),Vector3.ZERO,-1,6)
			for i in 8: _cyl(root,0.018,0.4,Vector3(0,0.2+i*0.28,0),_wood(),Vector3(0,0,PI/2),-1,8)
		"brush":
			_box(root,Vector3(0.16,0.03,0.06),Vector3(0,0.035,0),_wood())
			_box(root,Vector3(0.15,0.025,0.055),Vector3(0,0.012,0),_cloth("3a2a1a"))
		"coconut":
			_sphere(root,0.07,Vector3(0,0.07,0),_mat("brown_mud_dry",Color("6a4a30"),0.0,0.9,6.0))
		"curls":
			for i in 8: _torus(root,0.012,0.018,Vector3(rnd.randf_range(-0.2,0.2),0.012,rnd.randf_range(-0.2,0.2)),_mat("medieval_wood",Color("e0b880"),0.0,0.8,8.0),Vector3(rnd.randf()*PI,rnd.randf()*PI,0))
		"standard":
			_cyl(root,0.025,1.9,Vector3(0,0.95,0),_wood(),Vector3.ZERO,-1,8)
			_model(root,"res://Art/Objaverse/deer_skull/deer_skull.glb",0.35,Vector3(0,1.9,0))
			_box(root,Vector3(0.3,0.5,0.01),Vector3(0.17,1.5,0),_cloth("6a2a20"))
		"brokenshelf":
			_box(root,Vector3(0.04,1.4,0.35),Vector3(-0.4,0.7,0),_wood())
			_box(root,Vector3(0.04,0.9,0.35),Vector3(0.4,0.45,0),_wood(),Vector3(0,0,0.15))
			for i in 3: _box(root,Vector3(0.8,0.03,0.33),Vector3(0,0.3+i*0.4,0),_wood(),Vector3(0,0,(i-1)*0.12))
		"harp":
			var hh := float(kind.get_slice(":",1))
			_box(root,Vector3(0.05,hh,0.05),Vector3(-hh*0.25,hh*0.5,0),_wood())
			_box(root,Vector3(hh*0.55,0.05,0.05),Vector3(0,hh*0.95,0),_wood(),Vector3(0,0,-0.2))
			_box(root,Vector3(0.05,hh*0.9,0.06),Vector3(hh*0.22,hh*0.5,0),_wood(),Vector3(0,0,0.25))
			for i in 8: _cyl(root,0.002,hh*(0.85-i*0.07),Vector3(-hh*0.2+i*hh*0.05,hh*0.5,0),_mat("rusty_metal_02",Color("e2c070"),1.0,0.3,8.0),Vector3.ZERO,-1,4)
		"cracks":
			var crack := StandardMaterial3D.new()
			crack.albedo_color = Color(0.08,0.07,0.06)
			var cy := 0.4
			for i in 6:
				_box(root,Vector3(0.015,0.25,0.01),Vector3(rnd.randf_range(-0.15,0.15),cy,-0.49),crack,Vector3(0,0,rnd.randf_range(-0.6,0.6)))
				cy += 0.2
		"coveredchair":
			# A dust sheet over a chair: draped skirt, seat and tall back.
			var sh := _mat("white_plaster_02",Color("f4f2ec"),0.0,0.95,3.0)
			var low := _cyl(root,0.3,0.5,Vector3(0,0.25,0),sh,Vector3(0,PI/8,0),0.36,8)
			low.scale = Vector3(1.0,1.0,0.9)
			_box(root,Vector3(0.48,0.6,0.14),Vector3(0,0.78,-0.2),sh,Vector3(-0.08,0,0))
			_cyl(root,0.07,0.48,Vector3(0,1.08,-0.22),sh,Vector3(0,0,PI/2),-1,10)
		"cake":
			_cyl(root,0.14,0.12,Vector3(0,0.06,0),_mat("white_plaster_02",Color("f4e8c8"),0.0,0.6,6.0))
			for i in 6: _sphere(root,0.015,Vector3(cos(i)*0.1,0.125,sin(i)*0.1),_mat("white_plaster_02",Color("c02030"),0.0,0.3,6.0))
		"pillow":
			var pl := _sphere(root,0.25,Vector3(0,0.06,0),_cloth("d8d4cc"))
			pl.scale = Vector3(1.0,0.25,1.0)
		"herbs":
			for i in 5: _cyl(root,0.004,0.25,Vector3(rnd.randf_range(-0.02,0.02),0.12,rnd.randf_range(-0.02,0.02)),_mat("leafy_grass",Color("8a9a4a"),0.0,0.9,8.0),Vector3(rnd.randf_range(-0.3,0.3),0,rnd.randf_range(-0.3,0.3)),0.012,4)
			_torus(root,0.012,0.018,Vector3(0,0.2,0),_cloth("b89a68"))
		"bandage":
			for i in 3: _cyl(root,0.025,0.05,Vector3(i*0.06-0.06,0.025,0),_cloth("f2efe6"),Vector3(0,0,PI/2))
			_box(root,Vector3(0.12,0.002,0.04),Vector3(0,0.051,0),_mat("brown_mud_dry",Color(kind.get_slice(":",1)),0.0,0.3,6.0))
		"sewing":
			_cyl(root,0.1,0.06,Vector3(0,0.03,0),_mat("hessian_230",Color("c8a878"),0.0,0.9,6.0))
			for i in 3: _cyl(root,0.015,0.035,Vector3(i*0.035-0.035,0.075,0),_cloth(["b02020","2040a0","e0d0a0"][i]))
		"palette":
			var pal := _cyl(root,0.14,0.008,Vector3(0,0.004,0),_wood())
			pal.scale = Vector3(1.0,1.0,0.75)
			for i in 5: _sphere(root,0.012,Vector3(cos(i*1.2)*0.08,0.01,sin(i*1.2)*0.06),_mat("white_plaster_02",Color(["c02020","2050c0","e0c020","30a040","f0f0f0"][i]),0.0,0.3,6.0))
			_cyl(root,0.004,0.22,Vector3(0.1,0.012,0.05),_wood(),Vector3(0,0.5,PI/2),-1,6)
		"pie":
			_cyl(root,0.12,0.045,Vector3(0,0.0225,0),_mat("brown_mud_dry",Color(kind.get_slice(":",1)),0.0,0.8,8.0),Vector3.ZERO,0.105)
		"vials":
			_box(root,Vector3(0.3,0.04,0.08),Vector3(0,0.02,0),_wood())
			var vg := StandardMaterial3D.new()
			vg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			vg.roughness = 0.05
			vg.albedo_color = Color(0.4,0.6,1.0,0.6) if kind.get_slice(":",1) == "1" else Color(0.85,0.9,0.95,0.3)
			for i in 4: _cyl(root,0.012,0.16,Vector3(i*0.07-0.105,0.1,0),vg,Vector3.ZERO,-1,8)
		"armorstand":
			_cyl(root,0.03,1.6,Vector3(0,0.8,0),_wood(),Vector3.ZERO,-1,8)
			_box(root,Vector3(0.45,0.05,0.45),Vector3(0,0.025,0),_wood())
			_model(root,"res://Art/Objaverse/armor_plate/armor_plate.glb",0.6,Vector3(0,0.95,0),Vector3.ZERO,Color("9a9ea6"))
			_model(root,"res://Art/Objaverse/armor_helm/armor_helm.glb",0.32,Vector3(0,1.55,0),Vector3.ZERO,Color("9a9ea6"))
		"dough":
			var dg := _sphere(root,0.1,Vector3(0,0.04,0),_mat("white_plaster_02",Color("f0e4c8"),0.0,0.7,6.0))
			dg.scale = Vector3(1.0,0.45,0.85)
		"horseshoes":
			for i in 3: _torus(root,0.035,0.05,Vector3(i*0.07-0.07,0.008,rnd.randf_range(-0.03,0.03)),_iron())
		"tambourine":
			_torus(root,0.1,0.12,Vector3(0,0.02,0),_wood())
			_cyl(root,0.1,0.004,Vector3(0,0.035,0),_mat("white_plaster_02",Color("e8dcc0"),0.0,0.7,6.0))
			for i in 5: _cyl(root,0.012,0.005,Vector3(cos(i*1.25)*0.11,0.02,sin(i*1.25)*0.11),_mat("rusty_metal_02",Color("e2c070"),1.0,0.3,8.0))
		"reagent":
			var rm := _mat("brown_mud_dry",Color(kind.get_slice(":",1)),0.0,0.8,8.0)
			for i in 3: _cyl(root,0.0,0.04,Vector3(rnd.randf_range(-0.04,0.04),0.02,rnd.randf_range(-0.04,0.04)),rm,Vector3.ZERO,0.04,10)
		"brassparts":
			var br := _mat("rusty_metal_02",Color("d0a040"),1.0,0.3,8.0)
			_torus(root,0.06,0.07,Vector3(0,0.005,0),br)
			_box(root,Vector3(0.12,0.006,0.012),Vector3(0.05,0.006,0.04),br,Vector3(0,0.5,0))
		"carrot":
			_cyl(root,0.02,0.16,Vector3(0,0.02,0),_mat("brown_mud_dry",Color("e07020"),0.0,0.6,8.0),Vector3(0,0,PI/2),0.002,8)
			_cyl(root,0.012,0.08,Vector3(-0.1,0.02,0),_mat("leafy_grass",Color("4a8a2a"),0.0,0.8,8.0),Vector3(0,0,PI/2),0.0,6)
		"dyes":
			for i in 3:
				_cyl(root,0.05,0.09,Vector3(i*0.11-0.11,0.045,0),_mat("brown_mud_dry",Color("8a6a4a"),0.0,0.8,6.0))
				_cyl(root,0.045,0.005,Vector3(i*0.11-0.11,0.09,0),_mat("white_plaster_02",Color(["3040a0","a02020","d8b030"][i]),0.0,0.4,6.0))
		"knitting":
			_sphere(root,0.06,Vector3(0,0.06,0),_cloth("d8d4cc"))
			for x in [-0.03,0.03]: _cyl(root,0.003,0.25,Vector3(x,0.08,0),_wood(),Vector3(0.6,0,0.4),-1,6)
		"bowl":
			_cyl(root,0.12,0.07,Vector3(0,0.035,0),_wood(),Vector3.ZERO,0.08)
			for i in 6: _sphere(root,0.03,Vector3(rnd.randf_range(-0.06,0.06),0.075,rnd.randf_range(-0.06,0.06)),_mat("leafy_grass",Color(kind.get_slice(":",1)),0.0,0.7,8.0))
		"rudder":
			_box(root,Vector3(0.08,1.6,0.06),Vector3(0,0.03,0),_wood(),Vector3(PI/2,0,0))
			_box(root,Vector3(0.45,0.05,0.8),Vector3(0.2,0.03,0.4),_wood())
		"bolas":
			for i in 3:
				var ba := TAU*i/3.0
				_sphere(root,0.035,Vector3(cos(ba)*0.25,0.035,sin(ba)*0.25),_stone())
				_cyl(root,0.004,0.25,Vector3(cos(ba)*0.125,0.01,sin(ba)*0.125),_cloth("8a6a40"),Vector3(0,-ba,PI/2),-1,4)
		"feather":
			var fe := _sphere(root,0.05,Vector3(0,0.005,0),_cloth("f2efe6"))
			fe.scale = Vector3(2.4,0.06,0.5)
		"plank":
			_box(root,Vector3(0.7,0.4,0.04),Vector3(0,1.3,-0.46),_wood())
		"leggings":
			# Mail leggings laid flat: two legs joined at the waist.
			var lm := _steel(kind.get_slice(":",2))
			_box(root,Vector3(0.34,0.05,0.14),Vector3(0,0.025,-0.33),lm)
			for sx in [-1.0,1.0]: _box(root,Vector3(0.15,0.05,0.72),Vector3(sx*0.1,0.025,0.08),lm,Vector3(0,sx*0.1,0))
		"sleeves":
			var style := kind.get_slice(":",1)
			var sm := _steel(kind.get_slice(":",2)) if style == "mail" else _mat("brown_mud_dry",Color(kind.get_slice(":",2)),0.0,0.6,6.0)
			for sx in [-1.0,1.0]:
				var yaw: float = sx*0.3
				_cyl(root,0.045,0.5,Vector3(sx*0.14,0.06,0),sm,Vector3(PI/2,yaw,0),0.06,12)
				if style == "studded":
					for k in 4: _sphere(root,0.012,Vector3(sx*0.14+sin(yaw)*(k*0.1-0.15),0.11,cos(yaw)*(k*0.1-0.15)),_iron())
		"gorget":
			var gstyle := kind.get_slice(":",1)
			var gm := _steel(kind.get_slice(":",2)) if gstyle == "plate" else _mat("brown_mud_dry",Color(kind.get_slice(":",2)),0.0,0.6,6.0)
			_cyl(root,0.075,0.08,Vector3(0,0.06,0),gm,Vector3.ZERO,0.085,20)
			var flare := _torus(root,0.08,0.16,Vector3(0,0.02,0),gm)
			flare.scale = Vector3(1.0,0.5,0.85)
			if gstyle == "studded":
				for k in 8: _sphere(root,0.01,Vector3(cos(k*TAU/8)*0.15,0.026,sin(k*TAU/8)*0.12),_iron())
		"bones":
			var bone := _mat("white_plaster_02",Color("d8cca0"),0.0,0.7,6.0)
			match kind.get_slice(":",1):
				"armor":
					for k in 6: _cyl(root,0.03,0.05,Vector3(0,0.03,-0.25+k*0.1),bone,Vector3(PI/2,0,0),-1,8)
					for k in 5:
						for sx in [-1.0,1.0]: _cyl(root,0.012,0.3,Vector3(sx*0.16,0.025,-0.2+k*0.09),bone,Vector3(0,sx*0.25,PI/2),-1,6)
					for sx in [-1.0,1.0]:
						var pad := _sphere(root,0.11,Vector3(sx*0.3,0.04,-0.3),bone)
						pad.scale = Vector3(1.0,0.35,1.0)
					_box(root,Vector3(0.5,0.015,0.06),Vector3(0,0.065,-0.32),_mat("brown_mud_dry",Color("5a3a20"),0.0,0.6,6.0))
				"gloves":
					for sx in [-1.0,1.0]:
						_box(root,Vector3(0.09,0.03,0.1),Vector3(sx*0.12,0.015,0),bone)
						for f in 4: _cyl(root,0.008,0.08,Vector3(sx*0.12-0.03+f*0.02,0.012,0.09),bone,Vector3(PI/2,0,0),-1,6)
				"legs":
					for sx in [-1.0,1.0]:
						_cyl(root,0.025,0.45,Vector3(sx*0.12,0.03,-0.22),bone,Vector3(PI/2,0,0),-1,8)
						_cyl(root,0.02,0.42,Vector3(sx*0.12,0.03,0.24),bone,Vector3(PI/2,0,0),-1,8)
						_sphere(root,0.045,Vector3(sx*0.12,0.04,0.01),bone)
		"cotton":
			for i in 7: _sphere(root,rnd.randf_range(0.04,0.06),Vector3(rnd.randf_range(-0.1,0.1),0.045,rnd.randf_range(-0.1,0.1)),_mat("white_plaster_02",Color("fbfaf6"),0.0,0.95,8.0))
		"bridle":
			var lt := _mat("brown_mud_dry",Color("7a4a24"),0.0,0.6,6.0)
			_torus(root,0.13,0.145,Vector3(0,0.008,0),lt)
			_torus(root,0.07,0.085,Vector3(0.12,0.008,0.1),lt)
			_cyl(root,0.008,0.6,Vector3(-0.15,0.008,-0.15),lt,Vector3(PI/2,0.8,0),-1,6)
			_model(root,"res://Art/Objaverse/horse_bit/horse_bit.glb",0.16,Vector3(0.18,0,0.05))
		"prow":
			# A ship's bow section: a planked wedge of hull, decked over, with its stem post.
			var hull := _cyl(root,0.4,0.9,Vector3(0,0.45,0),_wood(),Vector3.ZERO,0.55,3)
			hull.scale = Vector3(1.4,1.0,0.8)
			var deck := _cyl(root,0.41,0.04,Vector3(0,0.91,0),_mat("medieval_wood",Color("e0c8a0"),0.0,0.85,2.5),Vector3.ZERO,-1,3)
			deck.scale = Vector3(1.4,1.0,0.8)
			_box(root,Vector3(0.08,1.1,0.08),Vector3(0.56,0.55,0),_wood())
		"darttrap":
			_box(root,Vector3(0.3,0.3,0.03),Vector3(0,1.0,-0.48),_stone())
			var hole := StandardMaterial3D.new()
			hole.albedo_color = Color(0.05,0.04,0.04)
			for k in 3: _cyl(root,0.015,0.02,Vector3(-0.08+k*0.08,1.0,-0.46),hole,Vector3(PI/2,0,0),-1,8)
		"crest":
			# Oval silver plaque with the red serpent ring, hung on the wall.
			var silver := _steel("c9ccd2")
			var plaque := _cyl(root,0.22,0.03,Vector3(0,1.6,-0.47),silver,Vector3(PI/2,0,0),-1,24)
			plaque.scale = Vector3(0.7,1.0,1.0)
			var ring := _torus(root,0.1,0.14,Vector3(0,1.6,-0.45),_mat("brown_mud_dry",Color("a01818"),0.0,0.4,6.0),Vector3(PI/2,0,0))
			ring.scale = Vector3(0.7,1.0,1.0)
			_sphere(root,0.04,Vector3(0,1.6,-0.45),_mat("rusty_metal_02",Color("2a2a2e"),0.8,0.4,6.0))
		"essence":
			var em := StandardMaterial3D.new()
			em.albedo_color = Color("ff9a20")
			em.emission_enabled = true
			em.emission = Color("ff8a10")
			em.emission_energy_multiplier = 3.0
			var es := _sphere(root,0.22,Vector3(0,0.06,0),em)
			es.scale = Vector3(1.6,0.35,0.9)
			var ol := OmniLight3D.new()
			ol.light_color = Color("ff9a30")
			ol.omni_range = 1.5
			ol.light_energy = 1.2
			ol.position = Vector3(0,0.3,0)
			root.add_child(ol)
		"ironmaiden":
			var im := _mat("rusty_metal_02",Color("4a5060"),0.8,0.5,3.0)
			var body := _cyl(root,0.24,1.7,Vector3(0,0.85,0),im,Vector3.ZERO,0.3,8)
			body.scale = Vector3(1.0,1.0,0.75)
			var crown := _sphere(root,0.24,Vector3(0,1.72,0),im)
			crown.scale = Vector3(1.0,0.7,0.75)
			var face := _sphere(root,0.11,Vector3(0,1.55,0.17),_mat("rusty_metal_02",Color("8a8a90"),0.9,0.4,6.0))
			face.scale = Vector3(0.8,1.0,0.4)
			for k in 3: _box(root,Vector3(0.52,0.03,0.04),Vector3(0,0.4+k*0.45,0.2),_iron())
		"agave":
			# Century plant: a low rosette of blades and a tall flowering stalk.
			var lf := _mat("leafy_grass",Color("6a8a6a"),0.0,0.7,6.0)
			for i in 9:
				var a := TAU*i/9.0
				_box(root,Vector3(0.07,0.5,0.015),Vector3(cos(a)*0.12,0.22,sin(a)*0.12),lf,Vector3(0.6,PI/2-a,0))
			_cyl(root,0.02,2.4,Vector3(0,1.4,0),_mat("medieval_wood",Color("8a8a50"),0.0,0.85,4.0),Vector3.ZERO,0.035,8)
			var yel := _mat("leafy_grass",Color("e8c030"),0.0,0.8,8.0)
			for k in 6:
				var ka := k*2.4
				for j in 3: _sphere(root,0.045,Vector3(cos(ka)*(0.1+j*0.04),1.55+k*0.22+j*0.03,sin(ka)*(0.1+j*0.04)),yel)
		"pampas":
			_model(root,"res://Art/Objaverse/grass_clump/grass_clump.glb",0.9)
			var plume := _mat("white_plaster_02",Color("f2ecdc"),0.0,0.95,8.0)
			var stem := _mat("leafy_grass",Color("a0a070"),0.0,0.9,8.0)
			for i in 10:
				var a := TAU*i/10.0+rnd.randf()*0.4
				var top := Vector3(cos(a)*rnd.randf_range(0.1,0.3),rnd.randf_range(1.3,1.7),sin(a)*rnd.randf_range(0.1,0.3))
				var q := Quaternion(Vector3.UP,top.normalized())
				var st := _cyl(root,0.006,top.length(),top/2.0,stem,Vector3.ZERO,-1,5)
				st.quaternion = q
				var pl := _sphere(root,0.05,top,plume)
				pl.quaternion = q
				pl.scale = Vector3(1.5,4.0,1.5)
		"memorial":
			# Gwenno's memorial: an inscribed headstone over a bed of flowers.
			_box(root,Vector3(0.9,0.12,0.5),Vector3(0,0.06,0),_stone())
			var pale := _mat("castle_wall_varriation",Color("e0dcd2"),0.0,0.8,3.0)
			_box(root,Vector3(0.7,1.1,0.12),Vector3(0,0.67,-0.12),pale)
			_cyl(root,0.35,0.12,Vector3(0,1.22,-0.12),pale,Vector3(PI/2,0,0),-1,20)
			var leaf := _mat("leafy_grass",Color("4a7a3a"),0.0,0.8,6.0)
			for i in 10: _sphere(root,0.05,Vector3(rnd.randf_range(-0.4,0.4),0.14,rnd.randf_range(0.02,0.22)),leaf)
			for i in 10: _sphere(root,0.03,Vector3(rnd.randf_range(-0.4,0.4),0.19,rnd.randf_range(0.02,0.22)),_mat("leafy_grass",Color(["d02a2a","e8c030","f0f0f0","c060c0"][i%4]),0.0,0.6,8.0))
		"barding":
			# Horse barding hung over a sawhorse, the shaffron at its head.
			for x in [-0.6,0.6]:
				for sz in [-1.0,1.0]: _box(root,Vector3(0.06,0.95,0.06),Vector3(x,0.45,sz*0.18),_wood(),Vector3(-sz*0.3,0,0))
			_box(root,Vector3(1.5,0.1,0.1),Vector3(0,0.9,0),_wood())
			var mail := _steel("b8bcc2")
			for sz in [-1.0,1.0]: _box(root,Vector3(1.4,0.6,0.03),Vector3(0,0.68,sz*0.2),mail,Vector3(-sz*0.35,0,0))
			_box(root,Vector3(1.4,0.04,0.3),Vector3(0,0.96,0),mail)
			_model(root,"res://Art/Objaverse/shaffron/shaffron.glb",0.55,Vector3(0.85,0.5,0),Vector3(0,-PI/2,0))
		"backpack":
			# Leather backpack: body, rounded flap with a buckle, shoulder straps.
			var lb := _mat("brown_mud_dry",Color("8a5a30"),0.0,0.6,6.0)
			_box(root,Vector3(0.32,0.38,0.16),Vector3(0,0.19,0),lb)
			_box(root,Vector3(0.33,0.2,0.02),Vector3(0,0.3,0.09),lb,Vector3(0.12,0,0))
			_cyl(root,0.08,0.33,Vector3(0,0.38,0.0),lb,Vector3(0,0,PI/2),-1,10)
			_box(root,Vector3(0.04,0.04,0.012),Vector3(0,0.22,0.105),_mat("rusty_metal_02",Color("d0a040"),1.0,0.3,8.0))
			for sx in [-1.0,1.0]: _box(root,Vector3(0.04,0.34,0.012),Vector3(sx*0.09,0.2,-0.085),_mat("brown_mud_dry",Color("5a3a1e"),0.0,0.6,6.0))
		"bar":
			_box(root,Vector3(0.3,0.03,0.05),Vector3(0,0.015,0),_iron())
	for mi in root.find_children("*","MeshInstance3D",true,false): (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root
