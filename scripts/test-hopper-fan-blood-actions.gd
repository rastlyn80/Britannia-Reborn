extends "res://../scripts/test-cyclops-titan-ice-actions.gd"

const PACKAGE := "hopper_fan_blood_actions"
const FORMS := [302, 247, 159]
const FAN_BLOCKS := {15:"BlockRight", 16:"FanGuardLeft", 17:"FanFlourish"}
const HOPPER := {3:"Death", 5:"Attack2", 6:"Attack2", 15:"HopperRecoil", 16:"HopperRecoil", 18:"HopperStretch"}
const BLOOD := {7:"BloodOverhead", 8:"BloodHeldReach", 15:"BloodRecoilRight", 16:"BloodRecoilLeft", 18:"BloodReach"}

func install_packages() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % PACKAGE
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == FORMS.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in FORMS and row.status == "prepared" and row.family == PACKAGE)
			Registry.entries[body] = row
	else:
		for body: int in FORMS:
			assert(Registry.entry(body).get("classic_gesture_batch") == PACKAGE)

func run() -> void:
	install_packages()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in FORMS:
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in TREATMENTS:
			sample_hopper(session, plane, 302, treatment)
			sample_fan(session, plane, treatment)
			sample_blood(session, plane, treatment)
		plane.free()
		await physics_frame
	assert(checked == 2196)
	print("HOPPER, FAN DANCER AND BLOOD ELEMENTAL: ", checked, " decoded terrain poses and nine static corpse hues")
	quit()

func sample_hopper(session: Node, plane: StaticBody3D, body: int, treatment: String) -> void:
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
	Earlier.check_earlier_keys(player, Registry.entry(body).classic_gesture_base_assets[treatment])
	var normal := plane.global_basis.y.normalized()
	var lowest := INF
	for slot: int in [5, 6, 15, 16, 18, 3]:
		assert(actor.receive_action(decode(session, body, slot)) and actor.current_clip == HOPPER[slot])
		player.advance(0.15)
		for sample in 17:
			player.seek(player.current_animation_length * sample / 16.0, true)
			var gap := Ground.minimum_plane_gap(actor.skin, rig, rig.global_transform, plane.global_position, normal)
			lowest = minf(lowest, gap)
			assert(actor.global_transform == Transform3D.IDENTITY and gap > -0.009, "%s/%s/%s at %s/%s floor %s" % [body, treatment, slot, plane.rotation, sample, gap])
			checked += 1
		actor.dead = false
	print(body, " ", treatment, " ", plane.rotation, " min gap ", lowest)
	actor.free()

func sample_fan(session: Node, plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(247)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(247, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var normal := plane.global_basis.y.normalized()
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var hands := [rig.find_bone("bip01 r hand"), rig.find_bone("bip01 l hand")]
	var props := {}
	for slot: int in FAN_BLOCKS:
		assert(actor.receive_action(decode(session, 247, slot)) and actor.current_clip == FAN_BLOCKS[slot])
		player.advance(0.16)
		var initial: Array[Vector3] = []
		var reach := [0.0, 0.0]
		var gap := INF
		for frame in 19:
			player.seek(player.current_animation_length * frame / 18.0, true)
			rig.force_update_all_bone_transforms()
			if frame == 0:
				for bone: int in hands:
					initial.append(rig.get_bone_global_pose(bone).origin)
			for index in hands.size():
				reach[index] = maxf(reach[index], initial[index].distance_to(rig.get_bone_global_pose(hands[index]).origin))
			for settle_step in 12:
				actor._physics_process(1.0 / 30.0)
				actor.contact._process_modification_with_delta(1.0 / 30.0)
			actor.settle_stance()
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal))
			assert(actor.global_transform == Transform3D.IDENTITY)
			checked += 1
		assert(gap >= 0.0015, "%s/%d floor: %s" % [treatment, slot, gap])
		props[slot] = [reach, gap]
	assert(props[15][0] != props[16][0] and props[17][0] != props[16][0])
	print(treatment, " ", plane.rotation, " hands / min floor ", props)
	actor.free()

func sample_blood(session: Node, plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(159)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(159, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	Earlier.check_earlier_keys(player, Registry.entry(159).classic_gesture_base_assets[treatment])
	if treatment == "modern":
		assert(not actor.fluid_materials.is_empty())
		assert(actor.fluid_materials[0].shader.resource_path.ends_with("SourceFluidElementalSurface.gdshader"))
	var normal := plane.global_basis.y.normalized()
	var left := rig.find_bone("bip01 l hand")
	var right := rig.find_bone("bip01 r hand")
	for slot: int in BLOOD:
		assert(actor.receive_action(decode(session, 159, slot)) and actor.current_clip == BLOOD[slot])
		player.advance(0.15)
		var lowest := INF
		var l_min := INF
		var l_max := -INF
		var forward_min := INF
		var forward_max := -INF
		for frame in 17:
			player.seek(player.current_animation_length * frame / 16.0, true)
			for settle_step in 4:
				actor._physics_process(1.0 / 30.0)
				actor.contact._process_modification_with_delta(1.0 / 30.0)
			var gap := Ground.minimum_plane_gap(actor.support_skin, rig, rig.global_transform, plane.global_position, normal)
			lowest = minf(lowest, gap)
			var hand := rig.to_global(rig.get_bone_global_pose(left).origin)
			l_min = minf(l_min, hand.y)
			l_max = maxf(l_max, hand.y)
			var extension := rig.to_global(rig.get_bone_global_pose(right).origin).z
			forward_min = minf(forward_min, extension)
			forward_max = maxf(forward_max, extension)
			assert(actor.global_transform == Transform3D.IDENTITY)
			checked += 1
		assert(lowest >= -0.003, "%s %d has floor penetration %s" % [treatment, slot, lowest])
		if slot == 7:
			assert(l_max - l_min > 0.22)
		if slot in [8, 18]:
			assert(forward_max - forward_min > 0.15)
		print(treatment, " ", plane.rotation, " slot ", slot, " floor ", lowest, " lift ", l_max-l_min,
			" forward range ", forward_max-forward_min)
	actor.free()
