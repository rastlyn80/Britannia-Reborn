extends SceneTree
# Dungeons, cave entrances and death presentation (docs/DUNGEONS.md), on
# synthetic map chunks: no game data needed.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")

# A BRW chunk: every land tile `land` at z 0, plus statics [id,dx,dy,z].
static func chunk(at: Vector2i, land: int, statics: Array = [], heights: Callable = Callable()) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(24+64*64*3+statics.size()*7)
	data.encode_u32(0,0x31575242)
	data.encode_u32(4,at.x)
	data.encode_u32(8,at.y)
	data.encode_u32(12,64)
	data.encode_u32(16,64)
	data.encode_u32(20,statics.size())
	for i in 4096:
		data.encode_u16(24+i*3,land)
		data.encode_s8(24+i*3+2,int(heights.call(i%64,i/64)) if heights.is_valid() else 0)
	for i in statics.size():
		var s: Array = statics[i]
		var offset := 24+4096*3+i*7
		data.encode_u16(offset,s[0])
		data.encode_u8(offset+2,s[1])
		data.encode_u8(offset+3,s[2])
		data.encode_s8(offset+4,s[3])
	return data

func run() -> void:
	var under = preload("res://Presentation/Underground.gd").new()
	root.add_child(under)
	under.setup("",{"elevationScale":0.2,"landData":{"581":{"name":"cave"},"3":{"name":"grass"}}})
	check(under.cave_land.has(581) and not under.cave_land.has(3),"cave land is recognised by its tile name")
	# A void district beside grass: the player enters near the void, leaves well away.
	for y in range(-1,2):
		for x in range(-1,3):
			var at := Vector2i(x*64,y*64)
			under.chunks[at] = chunk(at,0x244 if x >= 1 else 3)
	check(under.district_underground(Vector2i(64,0)) and not under.district_underground(Vector2i(0,0)),"a district of void land is drawn as a cave, grass is not")
	check(under.update(Vector2i(10,10),0.0,0.1) == 0.0 and not under.inside,"far from any void the player is outdoors")
	under.update(Vector2i(60,10),0.0,0.1)
	check(under.inside,"near the void the player is underground")
	var depth := 0.0
	for i in 30: depth = under.update(Vector2i(60,10),0.0,0.1)
	check(depth == 1.0,"the darkness eases in over about a second and a half")
	under.update(Vector2i(50,10),0.0,0.1)
	check(under.inside,"hysteresis: a few steps back from the void stays underground")
	under.update(Vector2i(20,10),0.0,0.1)
	check(not under.inside,"well away from the void the player is outdoors again")
	# A cave mouth: blockers on flat ground before a hill rising to the north.
	under.chunks.clear()
	var blockers: Array = []
	for y in range(36,40):
		for x in range(28,37): blockers.append([0x3B60+(x-28),x,y,0])
	for y in range(-1,2):
		for x in range(-1,2):
			var at := Vector2i(x*64,y*64)
			var hill := func(_tx: int, ty: int) -> int: return clampi((34-(at.y+ty))*8,0,100)
			under.chunks[at] = chunk(at,3,blockers if at == Vector2i.ZERO else [],hill)
	var mouths: Array = under.entrances(Vector2i.ZERO)
	check(mouths.size() == 1,"one blocker cluster gives one entrance (%d)" % mouths.size())
	if mouths.size() == 1:
		var entrance: Dictionary = mouths[0]
		var facing: Vector3 = entrance.transform.basis.z
		check(facing.z > 0.9,"the opening faces downhill, away from the hill (%s)" % facing)
		check(entrance.transform.origin.z < 37.0 and entrance.transform.origin.z > 33.0,"it sits at the foot of the rise (%s)" % entrance.transform.origin)
		check(entrance.width >= 2.6 and entrance.width <= 4.6,"its width follows the cluster (%.2f)" % entrance.width)
		var mouth: Node3D = under.build_mouth(entrance)
		check(mouth.get_node("Opening").mesh.get_surface_count() == 1 and mouth.get_node("Frame").mesh.get_surface_count() == 1,"the opening has a dark tunnel and a rock frame")
		mouth.free()
	var outline: PackedVector2Array = under.arch(3.0,2.6)
	check(outline[0].y < 0.0 and outline[outline.size()-1].y < 0.0 and absf(outline[7].y-2.6) < 0.05,"the arch reaches below ground and peaks at its height")
	# Ghost bodies are the same human, drawn ethereal.
	var Wardrobe := preload("res://Presentation/HumanWardrobe.gd")
	check(Wardrobe.human(0x192) and Wardrobe.human(0x193) and Wardrobe.female(0x193) and not Wardrobe.female(0x192) and Wardrobe.ghost(0x193) and not Wardrobe.ghost(0x190),"ghost bodies 0x192/0x193 keep their human body and sex")
	# Lighting: underground removes sun and sky and closes black fog in; death drains colour.
	var stage := Node3D.new()
	root.add_child(stage)
	var rig = preload("res://Presentation/LightingRig.gd").new()
	stage.add_child(rig)
	rig.configure(stage,{},null,false,false)
	rig.set_underground(1.0,Vector3.ZERO)
	check(rig.sun.light_energy == 0.0 and rig.environment.fog_depth_end <= 50.0 and rig.environment.background_mode == Environment.BG_COLOR and rig.torch.visible,"underground: no sun or sky, black fog within 50 m and a glow around you")
	var dark: float = rig.environment.ambient_light_energy
	check(not rig.torch.shadow_enabled and rig.torch.omni_range < 14.0,"underground with no light source: only a soft glow around you")
	rig.set_underground(1.0,Vector3.ZERO,true)
	rig._process(0.1)
	check(rig.torch.shadow_enabled and rig.torch.omni_range > 15.0 and rig.torch.light_energy > 2.0,"a lit torch in hand lights the way, warm and casting shadows")
	rig.receive_server_environment({"personal_light":26})
	rig.set_underground(1.0,Vector3.ZERO,false)
	check(rig.environment.ambient_light_energy > dark*1.6,"Night Sight brightens the dungeon (%.2f to %.2f)" % [dark,rig.environment.ambient_light_energy])
	rig.receive_server_environment({})
	rig.set_underground(0.0,Vector3.ZERO)
	check(rig.sun.light_energy > 0.0 and rig.environment.background_mode == Environment.BG_SKY and not rig.torch.visible,"outdoors again: sun, sky and no carried light")
	rig.set_dead(true)
	for i in 120: rig._process(0.05)
	check(rig.environment.adjustment_saturation == 0.0,"dead: the world is black and white")
	rig.set_dead(false)
	for i in 120: rig._process(0.05)
	check(rig.environment.adjustment_saturation > 0.9,"resurrected: colour returns")
	var death = preload("res://Network/DeathScreen.gd").new()
	var seen: Array = []
	death.dead_changed.connect(func(value: bool): seen.append(value))
	death._set_dead(true)
	death._set_dead(false)
	check(seen == [true,false],"the death screen reports dying and resurrection")
	death.free()
	print("UNDERGROUND TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
