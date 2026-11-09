extends "res://../scripts/test-gargoyle-kitsune-larva-actions.gd"

const BATCH := "bomber_ogre_rune_dopple_actions"
const NewPacket := preload("res://../scripts/test-efreet-actions.gd")
const ROUTES := {
	182: {15: "OrcBomberBrace", 18: "OrcBomberScan"},
	83: {3: "Death2", 4: "OverheadHammer", 6: "HighUppercut", 11: "FaceWipe", 15: "ShoulderTurn", 16: "ChestBrace", 18: "ShoulderScratch"},
	244: {11: "RuneCrestProbe", 15: "BlockLeft", 16: "BlockRight"},
	777: {15: "DopplegangerRecoil", 18: "DopplegangerReach"},
}

var sampled := 0
var minimum := {}
var peak_lift := {}
var route_count := 0
var newer_count := 0
var corpse_count := 0

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var pin := FileAccess.get_sha256(index)
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var path := "res://../work/creatures/bomber_ogre_rune_dopple_actions/prepared-client.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == ROUTES.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in ROUTES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == BATCH)
		session.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for treatment: String in TREATMENTS:
			verify_routes(session, body, treatment)
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
			corpse.free()
			corpse_count += 1
	for tilt: Vector3 in SLOPES:
		var floor := await support(tilt)
		for body: int in ROUTES:
			for treatment: String in TREATMENTS:
				sample_new(session, floor, body, treatment)
		floor.free()
		await physics_frame
	assert(FileAccess.get_sha256(index) == pin and sampled == 3906 and minimum.values().min() > 0.0005)
	assert(route_count == 156 and newer_count == 54 and corpse_count == 12)
	assert(peak_lift[83] < 0.045 and peak_lift[244] < 0.08, str(peak_lift))
	print("BOMBER, OGRE LORD, RUNE BEETLE AND DOPPLEGANGER: ", sampled, " terrain poses, ", route_count,
		" Classic and ", newer_count, " newer selections and ", corpse_count, " corpse hues; ground gaps ", minimum,
		"; peak gesture correction ", peak_lift)
	quit()

func verify_routes(session: Node, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.apply_identity(body, 0x8035)
	assert(actor.native_body == body and actor.native_hue == 0x8035)
	var player: AnimationPlayer = actor.animator
	Earlier.check_earlier_keys(player, actor.entry.classic_gesture_base_assets[treatment])
	for slot: String in actor.entry.classic_motion_references:
		actor.dead = false
		player.stop()
		var request := decode(session, body, int(slot))
		assert(request.body == body and actor.receive_action(request))
		assert(actor.current_clip == actor.entry.classic_action_categories[slot] and actor.get_meta("native_action") == request)
		route_count += 1
	for kind: String in actor.entry.new_action_categories:
		actor.dead = false
		player.stop()
		var request := NewPacket.decode_new(session, body, int(kind), 0, 0)
		assert(request.body == body and actor.receive_action(request))
		assert(actor.current_clip == actor.entry.new_action_categories[kind] and actor.get_meta("native_action") == request)
		newer_count += 1
	actor.free()

func sample_new(session: Node, floor: StaticBody3D, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := floor.global_basis.y.normalized()
	var anchor := actor.global_transform
	for warmup in 30:
		actor._physics_process(1.0 / 60.0)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
	for slot: int in ROUTES[body]:
		player.stop()
		actor.dead = false
		actor._physics_process(1.0 / 60.0)
		var request := decode(session, body, slot)
		assert(actor.receive_action(request) and actor.current_clip == ROUTES[body][slot])
		player.advance(0.15)
		for frame in 31:
			player.seek(player.current_animation_length * frame / 30.0, true)
			if actor.dead and actor.has_method("settle_collapse"):
				actor.settle_collapse()
			else:
				actor._physics_process(1.0 / 60.0)
				actor.contact._process_modification_with_delta(1.0 / 60.0)
				rig.force_update_all_bone_transforms()
				actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.global_position, normal)
			assert(is_finite(gap) and actor.global_transform == anchor)
			var key := "%d:%d" % [body, slot]
			minimum[key] = minf(minimum.get(key, INF), gap)
			sampled += 1
	if body in [83, 244]:
		peak_lift[body] = maxf(float(peak_lift.get(body, 0.0)), actor.gesture.peak)
	actor.free()
