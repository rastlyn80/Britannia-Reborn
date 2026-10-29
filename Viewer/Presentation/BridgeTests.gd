extends SceneTree
# Bridge presentation rules on synthetic source fixtures (no game data):
# wooden footbridges drawn once as a fitted timber bridge (TimberBridge.gd),
# solid square piers from 2x2 wall rings under a paved top, and no stairwell
# balustrades on pier tops or paved foundations.
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

static func meshes(node: Node, found: Array) -> Array:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh: found.append(node)
	for child in node.get_children(): meshes(child,found)
	return found

func footbridge(with_ramps: bool) -> Dictionary:
	var world := {"originX":0,"originY":0,"width":12,"height":8,"elevationScale":0.2,"terrain":[],"statics":[],
		"landData":{"1":{"name":"water"},"2":{"name":"dirt"}},
		"staticData":{"1205":{"name":"wooden boards","height":0,"flags":0x200},"2170":{"name":"wooden ramp","height":5,"flags":0x200},"2172":{"name":"wooden ramp","height":5,"flags":0x200},
			"2176":{"name":"wooden rail","height":5,"flags":0x40},"1848":{"name":"wood","height":10,"flags":0x200}}}
	for y in range(-2,8):
		for x in 12: world.terrain.append({"id":1 if x >= 3 and x <= 7 else 2,"x":x,"y":y,"z":-5 if x >= 3 and x <= 7 else 10})
	for y in range(1,5):
		for x in range(3,8): world.statics.append({"id":1205,"x":x,"y":y,"z":20})
		if with_ramps:
			world.statics.append({"id":2172,"x":2,"y":y,"z":15})
			world.statics.append({"id":1848,"x":2,"y":y,"z":10})
			world.statics.append({"id":2170,"x":8,"y":y,"z":15})
	for x in range(3,8):
		world.statics.append({"id":2176,"x":x,"y":0,"z":20})
		world.statics.append({"id":2176,"x":x,"y":5,"z":20})
	return world

func run() -> void:
	var world := footbridge(true)
	var reconstruction := preload("res://Presentation/Reconstruction.gd").new()
	reconstruction.index(world)
	var timber: RefCounted = reconstruction.timber_bridges
	check(timber.plans.size() == 1,"a deck of boards over water with ramps is one footbridge")
	check(timber.members.size() == world.statics.size(),"boards, ramps, cribbing and rails all belong to it")
	var anchor: int = timber.plans.keys()[0]
	check(str(world.staticData[str(int(world.statics[anchor].id))].name) == "wooden boards","the bridge is drawn by a deck board")
	var plan: Dictionary = timber.plans[anchor]
	check(plan.axis_x and plan.u0 == 2 and plan.u1 == 8,"span runs between the ramps")
	check(is_equal_approx(float(plan.profile[0].y),3.0) and is_equal_approx(float(plan.profile[-1].y),3.0),"ramp ends meet the banks at the ramps' low edge")
	var top := -100.0
	for p in plan.profile: top = maxf(top,float(p.y))
	check(is_equal_approx(top,4.0),"walking surface reaches the source deck height")
	var drawn: Node3D = reconstruction.build(world.statics[anchor],world,anchor)
	var parts := meshes(drawn,[])
	check(parts.size() == 2 and parts.all(func(m): return m.mesh.get_surface_count() == 1),"boards and timbers are two meshes")
	var box: AABB = parts[0].get_aabb()
	for m in parts: box = box.merge(m.get_aabb())
	check(box.size.x > 6.5 and box.size.z > 3.8,"the bridge covers its footprint")
	check(drawn.get_meta("solid",false),"the drawn bridge is solid for collision")
	var others := 0
	for i in world.statics.size():
		if i == anchor: continue
		var member: Node3D = reconstruction.build(world.statics[i],world,i)
		if member.get_child_count() == 0 and str(member.get_meta("source_state","")).begins_with("group-component"): others += 1
		member.free()
	check(others == world.statics.size()-1,"every other member is a component without its own visual")
	drawn.free()
	var dock := footbridge(false)
	reconstruction.index(dock)
	check(reconstruction.timber_bridges.plans.is_empty(),"a jetty without ramps keeps its own pieces")

	# A square pier: four sandstone wall pieces round 2x2 cells, paved on top.
	var pier := {"originX":0,"originY":0,"width":6,"height":6,"elevationScale":0.2,"terrain":[],"landData":{},"statics":[],
		"staticData":{"387":{"name":"sandstone wall","height":10,"flags":0x50},"372":{"name":"sandstone wall","height":10,"flags":0x50},
			"1183":{"name":"sandstone paver","height":0,"flags":0x200},"1900":{"name":"sandstone","height":10,"flags":0x200},"1902":{"name":"sandstone stairs","height":5,"flags":0x200}}}
	for cell in [Vector2i(1,1),Vector2i(2,1),Vector2i(1,2),Vector2i(2,2)]:
		for z in [5,15]: pier.statics.append({"id":387 if cell.y == 1 else 372,"x":cell.x,"y":cell.y,"z":z})
		pier.statics.append({"id":1183,"x":cell.x,"y":cell.y,"z":25})
	# The deck beside it: paved stone blocks, and steps up at its end.
	for x in range(0,5):
		pier.statics.append({"id":1900,"x":x,"y":3,"z":-5})
		pier.statics.append({"id":1183,"x":x,"y":3,"z":5})
	pier.statics.append({"id":1902,"x":3,"y":0,"z":0})
	# The ring's two facings (its source art runs east-west and north-south).
	reconstruction.catalog["387"] = {"kind":"trim","axis":"x"}
	reconstruction.catalog["372"] = {"kind":"trim","axis":"y"}
	reconstruction.index(pier)
	check(reconstruction.pillar_blocks.size() == 8,"a closed masonry ring under a paved top is a solid pier")
	check(reconstruction.stairwell_rails.is_empty(),"no stairwell balustrade on a pier top or along a paved deck")
	var block: Node3D = reconstruction.build(pier.statics[0],pier,0)
	var block_box: AABB = meshes(block,[])[0].get_aabb()
	check(block_box.size.x > 0.95 and block_box.size.z > 0.95,"each pier piece draws a full solid block")
	block.free()
	pier.statics = pier.statics.filter(func(s): return int(s.id) != 1183 or int(s.z) != 25)
	reconstruction.index(pier)
	check(reconstruction.pillar_blocks.is_empty(),"an open-topped ring keeps its wall faces")
	print("BRIDGE TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
