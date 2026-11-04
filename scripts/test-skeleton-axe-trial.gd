extends "res://../scripts/test-troll-weapon-trial.gd"

const BODY := 56
const AXE := "SkeletonAxe"

func run() -> void:
	var original := Registry.entry(BODY)
	var sibling := Registry.entry(57).duplicate(true)
	var active := "--active" in OS.get_cmdline_user_args()
	var trial := original.duplicate(true)
	trial.bodies = original.bodies.filter(func(identity: Dictionary): return int(identity.body) == BODY)
	trial.assets = {}
	for treatment in ["original", "rounded", "modern"]:
		var path := "res://local-art/creatures/skeleton-56-axe-trial-%s.scn" % treatment
		if active:
			assert(original.assets[treatment] == path and original.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
		else:
			trial.assets[treatment] = path
	trial.classic_action_categories = trial.get("classic_action_categories", {}).merged({"11": "AxeReach"}, true)
	trial.presentation_script = "res://Presentation/SourceArmedLizardmanVisual.gd"
	if active:
		assert(original.classic_action_categories["11"] == "AxeReach")
	else:
		Registry.entries[BODY] = trial
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	const SERIAL := 0x4100
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	for treatment in ["original", "rounded", "modern"]:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(actor.receive_action(game.last_mobile_actions[SERIAL]) and actor.current_clip == "AxeReach")
		if not check_axe(actor, treatment):
			quit(1)
			return
		actor.queue_free()
		await process_frame
	for hue in [0, 53, 0x8035]:
		check_corpse(BODY, hue, AXE)
	for axis in [Vector3.RIGHT, Vector3.FORWARD]:
		for slope in [-0.14, 0.14]:
			await check_handoff(BODY, AXE, axis, slope)
	await check_handoff(BODY, AXE, Vector3.RIGHT, 0.0, 0.35)
	await check_handoff(BODY, AXE, Vector3.RIGHT, 0.0, -0.35)
	assert(Registry.entry(57) == sibling)
	if active:
		var avatar := preload("res://Presentation/HumanAvatar.gd").new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		assert(avatar.horse_visual.find_child(AXE, true, false) != null)
		avatar.apply_server_appearance({"body": 57, "hue": 0x8035}, [])
		assert(avatar.horse_visual.find_child(AXE, true, false) == null)
		avatar.apply_server_appearance({"body": BODY, "hue": 0x8035}, [])
		assert(avatar.horse_visual.find_child(AXE, true, false) != null)
		avatar.free()
	Registry.entries[BODY] = original
	game.free()
	print("SKELETON AXE: three decoded routes, three corpse hues and six finite-terrain handoffs")
	quit()

func check_axe(actor: Node3D, treatment: String) -> bool:
	var weapon := actor.find_child(AXE, true, false) as MeshInstance3D
	assert(weapon != null and weapon.mesh.surface_get_array_len(0) == 198)
	var rig := weapon.get_parent() as Skeleton3D
	var joint := weapon.skin.get_bind_bone(0)
	var grasp := rig.get_bone_parent(joint)
	assert(rig.get_bone_name(joint) == "skeleton axe" and rig.get_bone_name(grasp) == "cp_grasp_rhand")
	var player: AnimationPlayer = actor.animator
	var skin := Ground.skin_points(weapon, rig)
	var root_pose := actor.global_transform
	var floors := {}
	var drift := 0.0
	var horizontal_error := 0.0
	player.stop()
	for clip in ["Idle", "Walk", "Run", "Attack", "Hit", "AxeReach", "Death"]:
		player.play(clip, 0.0)
		player.advance(0.0)
		var floor := INF
		var samples := 481 if clip == "Death" else 121
		for sample in samples:
			player.seek(player.get_animation(clip).length * float(sample) / (samples - 1), true)
			rig.force_update_all_bone_transforms()
			var pose := rig.global_transform * rig.get_bone_global_pose(joint)
			var grip := rig.to_global(rig.get_bone_global_pose(grasp).origin)
			drift = maxf(drift, pose.origin.distance_to(grip))
			floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			if clip == "AxeReach" and sample in range(42, 71):
				horizontal_error = maxf(horizontal_error, absf(pose.basis.y.normalized().y))
			if not actor.global_transform.is_equal_approx(root_pose):
				return false
		floors[clip] = floor
	print("Skeleton Axe ", treatment, " minimum gaps ", floors, " grip drift ", drift, " reach shaft tilt ", horizontal_error)
	return drift < 0.002 and horizontal_error < 0.20 and floors.values().min() >= 0.004
