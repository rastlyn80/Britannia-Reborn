extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const MEER_BODIES := [770, 773]
const MEER_FAMILY := "meer_forward_falls"

func run() -> void:
	Registry.load_index()
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var path := "res://../work/creatures/meer_forward_falls/prepared-client.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == MEER_BODIES.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	for body: int in MEER_BODIES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == MEER_FAMILY)
		for treatment: String in row.assets:
			verify_direction(body, treatment)
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in MEER_BODIES:
			for phase: float in [0.08, 0.45, 0.78]:
				witness(plane, body, 3, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 18 and checked == 738)
	print("MEER ALTERNATE CORPSES: ", handoffs, " decoded handoffs and ", checked, " terrain poses")
	quit()

func verify_direction(body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	Earlier.check_earlier_keys(player, actor.entry.classic_gesture_base_assets[treatment])
	var head := rig.find_bone("bip01 head")
	var pelvis := rig.find_bone("bip01 pelvis")
	assert(head >= 0 and pelvis >= 0)
	var directions := []
	if body == 773:
		actor.set_equipment([{"id": 0x0f50, "layer": 2}])
		assert(actor.crossbow.visible)
	for clip: String in ["Death", "Death2"]:
		actor.current_clip = clip
		player.play(clip, 0.0)
		player.advance(0.0)
		for sample in 21:
			player.seek(player.current_animation_length * sample / 20.0, true)
			if body == 773:
				var hand := rig.to_global(rig.get_bone_global_pose(actor.right_grasp).origin)
				assert(actor.crossbow.to_global(actor.GRIP).distance_to(hand) < 0.0001)
		var top := rig.to_global(rig.get_bone_global_pose(head).origin)
		var base := rig.to_global(rig.get_bone_global_pose(pelvis).origin)
		assert(top.y < 0.39)
		directions.append(top.z - base.z)
	assert(directions[0] > 0.70 and directions[1] < -0.70)
	actor.free()
