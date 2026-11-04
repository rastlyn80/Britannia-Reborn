extends "res://../scripts/test-spider-mongbat-gestures.gd"

const BODY := 4
const ACTIONS := {11: "KneelingLunge", 12: "Cast"}
const TREATMENTS := ["original", "rounded", "modern"]

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var base := Registry.entry(BODY)
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var trial := base.duplicate(true)
		trial.assets = {}
		trial.classic_action_categories = {"11": "KneelingLunge", "12": "Cast"}
		for treatment: String in TREATMENTS:
			trial.assets[treatment] = "res://local-art/creatures/gargoyle-4-classic-" + treatment + ".scn"
		Registry.entries[BODY] = trial
	for treatment: String in TREATMENTS:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		var original_path := "res://local-art/creatures/gargoyles_gargoyle-" + treatment + ".gltf"
		check_tracks(actor.animator, original_path)
		for slot: int in ACTIONS:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(SERIAL, 4))
			packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
			assert(actor.current_clip == ACTIONS[slot] and actor.native_hue == 0x8035 and actor.contact.enabled)
			if not sample_gesture(actor, ACTIONS[slot], treatment):
				quit(1)
				return
			actor._process(actor.action_remaining + 0.001)
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == "Idle")
		actor.free()
	for hue in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	Registry.entries[BODY] = base
	game.free()
	print("GARGOYLE CLASSIC: six decoded routes, 606 full-skin poses and three static corpse hues")
	quit()

func point(rig: Skeleton3D, joint: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint)).origin)

func sample_gesture(actor: Node3D, clip: String, treatment: String) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var root_pose := actor.global_transform
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var pelvis_start := point(rig, "bip01 pelvis")
	var foot_start := point(rig, "bip01 l foot")
	var floor_min := INF
	var floor_max := -INF
	var pelvis_drop := 0.0
	var foot_step := 0.0
	var left_hand_rise := -INF
	var right_hand_rise := -INF
	var return_error := 0.0
	for i in 101:
		player.seek(player.get_animation(clip).length * float(i) / 100.0, true)
		rig.force_update_all_bone_transforms()
		var floor_gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		floor_min = minf(floor_min, floor_gap)
		floor_max = maxf(floor_max, floor_gap)
		var pelvis := point(rig, "bip01 pelvis")
		var foot := point(rig, "bip01 l foot")
		var head := point(rig, "bip01 head")
		pelvis_drop = maxf(pelvis_drop, pelvis_start.y - pelvis.y)
		foot_step = maxf(foot_step, foot.z - foot_start.z)
		left_hand_rise = maxf(left_hand_rise, point(rig, "bip01 l hand").y - head.y)
		right_hand_rise = maxf(right_hand_rise, point(rig, "bip01 r hand").y - head.y)
		if i == 100:
			return_error = maxf(pelvis.distance_to(pelvis_start), foot.distance_to(foot_start))
		if not actor.global_transform.is_equal_approx(root_pose):
			return false
	print(treatment, " ", clip, " floor min/max, pelvis drop, foot step, hand rise, return ",
		[floor_min, floor_max, pelvis_drop, foot_step, left_hand_rise, right_hand_rise, return_error])
	if floor_min < -0.015 or floor_max > 0.015:
		return false
	if clip == "KneelingLunge":
		return pelvis_drop > 0.40 and foot_step > 0.4 and return_error < 0.005
	return left_hand_rise > 0.05 and right_hand_rise > 0.05
