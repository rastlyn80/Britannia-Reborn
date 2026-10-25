extends SceneTree
const Surface = preload("res://Presentation/MovementSurface.gd")
const Retarget = preload("res://Presentation/AnimationRetarget.gd")
var checks := 0
var failures := 0
class TestSession extends "res://Network/GameSession.gd":
	var sent: Array[PackedByteArray] = []
	func send(bytes: PackedByteArray) -> void: sent.append(bytes)

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS ",description)
	else:
		failures += 1
		push_error(description)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := {"terrain":[],"statics":[],"landData":{"1":{"name":"grass","flags":0}},"staticData":{"2":{"height":20,"flags":64}}}
	for y in range(0,8):
		for x in range(0,8): world.terrain.append({"x":x,"y":y,"z":20,"id":1})
	world = JSON.parse_string(JSON.stringify(world))
	var surface := Surface.new()
	surface.index(world)
	var player := {"serial":7,"x":3,"y":3,"z":20,"direction":4,"facet":1}
	check(surface.predict(player,0).get("y") == 2,"prediction uses source-backed flat ground")
	check(surface.predict({"x":7,"y":7,"z":20},0).is_empty(),"missing terrain prevents speculative movement")
	world.statics.append({"x":4,"y":3,"z":20,"id":2})
	surface.index(world)
	check(surface.predict(player,2).is_empty(),"source wall prevents speculative wall penetration")
	check(surface.predict(player,1).is_empty(),"diagonal prediction cannot cut a blocked corner")
	var session := TestSession.new()
	root.add_child(session)
	session.set_process(false)
	session.phase = "world"
	session.player = player.duplicate()
	session.surface = surface
	var starts := []
	session.movement_started.connect(func(position: Dictionary,seconds: float): starts.append([position,seconds]))
	check(session.walk(0) and session.move_interval == 20,"turn avoids a full walking delay")
	session.feed(PackedByteArray([0x22,0,0]))
	check(session.player.x == 3 and session.player.y == 3 and session.player.direction == 0 and not session.awaiting_position,"turn ACK changes orientation without a resync round trip")
	session.next_walk = 0
	check(session.walk(0) and starts.size() == 1 and session.player.y == 3,"render prediction starts before server ACK, committed position waits")
	check(starts[0][0].y == 2 and is_equal_approx(starts[0][1],0.405),"predicted endpoint and pace follow walk timing")
	session.feed(PackedByteArray([0x22,77,0]))
	check(session.player.y == 3 and session.outstanding == 1,"unmatched ACK cannot commit speculative movement")
	session.feed(PackedByteArray([0x22,1,0]))
	check(session.player.y == 2 and not session.awaiting_position and session.sent.size() == 2,"matching ACK commits source-backed endpoint without per-step resync")
	session.next_walk = 0
	session.walk(0,true)
	check(session.move_interval == 205 and session.sent.back()[1] == 0x80,"run uses server run flag and continuous shorter segment")
	session.feed(PackedByteArray([0x21,2,0,3,0,2,0,20]))
	check(session.player.y == 2 and session.outstanding == -1 and session.requested_position.is_empty(),"server rejection discards predicted endpoint")
	session.surface = null
	session.next_walk = 0
	session.walk(0)
	session.feed(PackedByteArray([0x22,0,0]))
	check(session.awaiting_position and session.sent.back() == PackedByteArray([0x22,0,0]),"ambiguous elevation falls back to authoritative resync")
	session.queue_free()
	var speech := preload("res://Network/GameSession.gd").speech_packet("[PreviewWhere")
	check(speech[0] == 0xad and speech.size() == preload("res://Network/LoginProtocol.gd").read_be(speech,1,2) and speech.slice(8,12) == PackedByteArray([69,78,85,0]),"native server command uses framed Unicode speech and language header")
	check(preload("res://Network/GameSession.gd").unicode_text(speech,12) == "[PreviewWhere" and preload("res://Network/GameSession.gd").speech_packet("[Go\nSave").is_empty(),"command payload roundtrips and rejects multiline input")
	var bounds := TestSession.new()
	root.add_child(bounds)
	bounds.set_process(false)
	bounds.phase = "world"
	bounds.player = {"serial":7,"x":3,"y":2,"z":20,"direction":0,"facet":1}
	bounds.preview_bounds = Rect2i(2,2,2,2)
	check(not bounds.walk(0) and bounds.sent.is_empty(),"regular movement cannot leave the rendered preview bounds")
	var resets := []
	bounds.position_reset.connect(func(position: Dictionary): resets.append(position))
	bounds.return_to_britain()
	check(bounds.returning_home and bounds.sent.size() == 2 and bounds.sent.back() == PackedByteArray([0x22,0,0]),"return home requests a real server command and authoritative position")
	bounds.feed(PackedByteArray([0x20,0,0,0,7,1,0x90,0,0,0,0,6,0x42,6,0x37,0,0,0,20]))
	check(not bounds.returning_home and bounds.player.x == 1602 and bounds.player.y == 1591 and resets.size() == 1,"confirmed home teleport clears recovery state and resets presentation")
	bounds.queue_free()
	# Rest-pose fixture proves bone-name compatibility alone is insufficient.
	var from := Skeleton3D.new()
	var to := Skeleton3D.new()
	for rig in [from,to]: rig.add_bone("thigh_l")
	from.set_bone_rest(0,Transform3D(Basis(Vector3.RIGHT,0.2),Vector3(0.1,0.4,0)))
	to.set_bone_rest(0,Transform3D(Basis(Vector3.RIGHT,0.35),Vector3(0.12,0.43,0)))
	var clip := Animation.new()
	var position := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(position,NodePath("Armature/Skeleton3D:thigh_l"))
	clip.position_track_insert_key(position,0,from.get_bone_rest(0).origin)
	var rotation := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(rotation,NodePath("Armature/Skeleton3D:thigh_l"))
	clip.rotation_track_insert_key(rotation,0,from.get_bone_rest(0).basis.get_rotation_quaternion())
	var fixed := Retarget.retarget(clip,from,to)
	check(fixed.track_get_key_value(position,0).is_equal_approx(to.get_bone_rest(0).origin),"animation translation retargets to target limb proportions")
	check(fixed.track_get_key_value(rotation,0).is_equal_approx(to.get_bone_rest(0).basis.get_rotation_quaternion()),"animation rotation retargets to target rest orientation")
	from.free()
	to.free()
	var roofs := preload("res://Presentation/RoofPlan.gd").new()
	var roof_world := {"elevationScale":0.2,"statics":[{"x":10,"y":10,"z":0,"id":1},{"x":11,"y":10,"z":3,"id":1}]}
	roof_world = JSON.parse_string(JSON.stringify(roof_world))
	roofs.index(roof_world,{"1":{"kind":"roof","rise":[1,0],"material":"slate"}})
	check(is_equal_approx(roofs.tiles[0].heights[2],roofs.tiles[1].heights[0]) and is_equal_approx(roofs.tiles[0].heights[5],roofs.tiles[1].heights[3]),"roof corners and midpoints meet across original tile boundaries")
	var roof_geometry := preload("res://Presentation/GeometryLibrary.gd").new().roof({"x":10,"y":10,"z":0},{"rise":[1,0]},ShaderMaterial.new())
	var roof_normals: PackedVector3Array = roof_geometry.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(roof_normals[0].y > 0.5,"roof surface normals face daylight instead of the interior")
	roof_geometry.free()
	check(not roofs.tiles[0].exposed[1] and roofs.tiles[0].exposed[0] and roofs.joined_samples > 0,"roof plan distinguishes continuous slopes from exposed gables/eaves")
	var facade := preload("res://Presentation/Facade.gd").new()
	var facade_world := {"staticData":{"1":{"height":20}},"statics":[]}
	for x in 7: facade_world.statics.append({"x":x,"y":0,"z":0,"id":1})
	facade_world = JSON.parse_string(JSON.stringify(facade_world))
	facade.index(facade_world,{"1":{"kind":"wall","axis":"x","asset":"plaster"}})
	check(facade.runs == 1 and facade.plans[3].left_post and not facade.plans[2].left_post,"continuous facade shares structural posts across source cells")
	if FileAccess.file_exists("res://play-world.json"):
		var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://play-world.json"))
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/static-catalog.json")).rules
		roofs.index(actual,catalog)
		facade.index(actual,catalog)
		check(roofs.tiles.size() > 500 and facade.plans.size() > 300,"real converter JSON builds roof and facade plans rather than missing numeric IDs")
		var shared := {}
		var watertight := true
		for ordinal in roofs.tiles:
			var tile: Dictionary = roofs.tiles[ordinal]
			for i in 9:
				var key := Vector3i(tile.cell.x*2+i%3,tile.cell.y*2+i/3,tile.component)
				if shared.has(key) and not is_equal_approx(shared[key],tile.heights[i]): watertight = false
				shared[key] = tile.heights[i]
		check(watertight and roofs.joined_samples > 1000,"actual Britain roof has consistent heights at every shared corner and midpoint")
		var roof_low := Vector2(INF,INF)
		var roof_high := Vector2(-INF,-INF)
		var anchor := Vector2.ZERO
		for ordinal in roofs.tiles:
			var tile: Dictionary = roofs.tiles[ordinal]
			if tile.material != "slate" or tile.boundary_fragment: continue
			roof_low = roof_low.min(Vector2(tile.cell))
			roof_high = roof_high.max(Vector2(tile.cell))
			var source: Dictionary = actual.statics[ordinal]
			var offset: Array = catalog[str(int(source.id))].anchorOffset
			anchor = Vector2(offset[0],offset[1])
		var wall_low := Vector2(INF,INF)
		var wall_high := Vector2(-INF,-INF)
		for source in actual.statics:
			var rule: Dictionary = catalog[str(int(source.id))]
			if rule.kind not in ["wall","window","corner","arch"] or source.z != 0: continue
			var cell := Vector2(source.x,source.y)
			if cell.x < roof_low.x-2 or cell.x > roof_high.x+1 or cell.y < roof_low.y-2 or cell.y > roof_high.y+1: continue
			wall_low = wall_low.min(cell)
			wall_high = wall_high.max(cell)
		check(((roof_low+roof_high+Vector2.ONE)/2+anchor).is_equal_approx((wall_low+wall_high)/2+Vector2(0.5,0.5)),"slate building roof and wall bounds share a centre after source-art anchor correction")
		surface.index(actual)
		check(surface.predict({"x":1605,"y":1590,"z":18},6).get("z") == 20,"gentle street-edge prediction samples height corners without inheriting neighboring impassability")
	var avatar := preload("res://Presentation/Avatar.gd").new()
	root.add_child(avatar)
	await process_frame
	avatar.rotation.y = 0
	avatar.animate(true,0.31,0.016,2.45)
	check(avatar.rotation.y > 0 and avatar.rotation.y < 0.31,"arbitrary 360-degree heading rotates gradually without snapping")
	avatar.animate(true,0.31,0.1,2.45)
	avatar.animate(false,0.31,0.016,0)
	check(avatar.current_clip != "Idle","short packet gaps do not restart the gait")
	avatar.rotation.y = PI-0.05
	avatar.animate(true,-PI+0.05,0.016,2.45)
	check(absf(wrapf(avatar.rotation.y-(PI-0.05),-PI,PI)) < 0.05,"rotation crosses 360-degree wrap by the shortest arc")
	for i in 60: avatar.animate(true,0.31,1.0/60.0,2.66)
	check(avatar.current_clip == "Jog_Fwd" and absf(avatar.animator.speed_scale-1.0) < 0.02,"locomotion pace matches measured native stride instead of frantic short steps")
	var rig: Skeleton3D = avatar.find_children("*","Skeleton3D",true,false)[0]
	avatar.animator.play("Walk",0)
	avatar.animator.advance(0)
	var left_min := INF
	var right_min := INF
	for i in 48:
		avatar.animator.seek(avatar.animator.get_animation("Walk").length*i/48.0,true)
		left_min = minf(left_min,rig.get_bone_global_pose(rig.find_bone("foot_l")).origin.y)
		right_min = minf(right_min,rig.get_bone_global_pose(rig.find_bone("foot_r")).origin.y)
	check(absf(left_min-right_min) < 0.015,"retargeted left and right legs reach matching ground-contact heights")
	var assembly = preload("res://Presentation/Reconstruction.gd").new()
	var fixture := {"statics":[{"id":330,"x":0,"y":0,"z":20},{"id":330,"x":1,"y":0,"z":20},{"id":330,"x":1,"y":0,"z":23},{"id":2911,"x":4,"y":0,"z":20},{"id":2911,"x":5,"y":0,"z":20}],"elevationScale":0.2}
	assembly.index(fixture)
	check(assembly.groups[0].indices.size() == 3 and assembly.groups[0].max_z == 26,"stacked gable wedges assemble into one continuous infill")
	check(assembly.groups[3].indices.size() == 2 and assembly.groups[3].size == Vector2(2,1),"adjacent bench component tiles share one full-length bench")
	var bench: Node3D = assembly.geometry.furniture(Vector2(3,0.5),"bench")
	check(bench.get_child_count() == 7,"long bench uses one seat and spaced supports instead of overlapping whole models")
	bench.free()
	avatar.queue_free()
	await process_frame
	print("STREET/MOVEMENT: %d passed / %d total" % [checks-failures,checks])
	quit(failures)
