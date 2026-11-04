extends "res://../scripts/test-troll-weapon-trial.gd"

const BODY := 86
const PROP := "OphidianBardiche"
const CLIP := "BardicheDip"
const ACTIONS := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", CLIP, "Death", "LieDown"]
const Clearance := preload("res://../scripts/ophidian-bardiche-clearance.gd")

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var original := Registry.entry(BODY)
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var trial := original.duplicate(true)
		trial.assets = {}
		trial.classic_action_categories = {"11": CLIP}
		trial.presentation_script = "res://Presentation/SourceArmedLizardmanVisual.gd"
		for treatment: String in ["original", "rounded", "modern"]:
			trial.assets[treatment] = "res://local-art/creatures/ophidian-86-bardiche-" + treatment + ".scn"
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
	for treatment: String in ["original", "rounded", "modern"]:
		if active:
			assert(FileAccess.get_sha256(original.assets[treatment]) == original.authored_action_scene_sha256[treatment])
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(actor.receive_action(game.last_mobile_actions[SERIAL]) and actor.current_clip == CLIP)
		if not check_bardiche(actor, treatment):
			quit(1)
			return
		actor.free()
	for hue in [0, 53, 0x8035]:
		check_corpse(BODY, hue, PROP)
	await check_handoff(BODY, PROP, Vector3.RIGHT, 0.0)
	for axis in [Vector3.RIGHT, Vector3.FORWARD]:
		for slope in [-0.14, 0.14]:
			await check_handoff(BODY, PROP, axis, slope)
	await check_handoff(BODY, PROP, Vector3.RIGHT, 0.0, 0.35)
	await check_handoff(BODY, PROP, Vector3.RIGHT, 0.0, -0.35)
	Registry.entries[BODY] = original
	game.free()
	print("OPHIDIAN BARDICHE: three decoded routes, three static corpse hues and seven finite-terrain handoffs")
	quit()

func check_bardiche(actor: Node3D, treatment: String) -> bool:
	var weapon := actor.find_child(PROP, true, false) as MeshInstance3D
	assert(weapon != null and weapon.mesh.get_faces().size() == 162)
	assert(weapon.get_active_material(0) is StandardMaterial3D)
	var rig := weapon.get_parent() as Skeleton3D
	var joint := weapon.skin.get_bind_bone(0)
	var grasp := rig.get_bone_parent(joint)
	assert(rig.get_bone_name(joint) == "ophidian bardiche" and rig.get_bone_name(grasp) == "cp_grasp_rhand")
	var player: AnimationPlayer = actor.animator
	check_preserved_tracks(player, treatment)
	var skin := Ground.skin_points(weapon, rig)
	var body_mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(body_mesh != weapon)
	var body_skin := Ground.skin_points(body_mesh, rig)
	var clearance := Clearance.new(body_mesh, rig)
	var head := rig.find_bone("bip01 head")
	var root_pose := actor.global_transform
	var floors := {}
	var conflicts := {}
	var grip_error := 0.0
	var dip_floor := INF
	var head_start := 0.0
	var head_dip := 0.0
	var blade_above_head := 0.0
	for clip: String in ACTIONS:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var floor := INF
		var intersections := 0
		var collapse := clip in ["Death", "LieDown"]
		var samples := 1441 if collapse else 121
		var intersection_stride := 12 if collapse else 3
		for sample in samples:
			player.seek(player.get_animation(clip).length * float(sample) / (samples - 1), true)
			rig.force_update_all_bone_transforms()
			var pose := rig.global_transform * rig.get_bone_global_pose(joint)
			var grip := rig.to_global(rig.get_bone_global_pose(grasp).origin)
			grip_error = maxf(grip_error, pose.origin.distance_to(grip))
			floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			if sample % intersection_stride == 0:
				clearance.update_pose()
				if clearance.intersects(pose):
					intersections += 1
			if clip == CLIP:
				var head_y := rig.to_global(rig.get_bone_global_pose(head).origin).y
				if sample == 0:
					head_start = head_y
				head_dip = maxf(head_dip, head_start - head_y)
				blade_above_head = maxf(blade_above_head, (pose * Vector3.UP).y - head_y)
				dip_floor = minf(dip_floor, Ground.minimum_plane_gap(body_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			if not actor.global_transform.is_equal_approx(root_pose):
				return false
		floors[clip] = floor
		conflicts[clip] = intersections
	print(treatment, " weapon floors ", floors, " grip error ", grip_error,
		" head dip / blade above head / body floor ", [head_dip, blade_above_head, dip_floor],
		" sampled shaft and blade centerline conflicts ", conflicts)
	# The runtime corrects the armed collapse against the actual terrain. Its
	# uncompensated pose can pass through the floor briefly on the refined skin.
	for clip: String in ["Death", "LieDown"]:
		if floors[clip] < -0.015 or conflicts[clip] > 1:
			return false
		floors.erase(clip)
		conflicts.erase(clip)
	return (grip_error < 0.001 and floors.values().min() > 0.001 and dip_floor > -0.005
		and head_dip > 0.07 and blade_above_head > 0.15 and conflicts.values().max() == 0)

func check_preserved_tracks(player: AnimationPlayer, treatment: String) -> void:
	var path := "res://local-art/creatures/ophidians_ophidian_warrior-" + treatment + ".gltf"
	var source := (load(path) as PackedScene).instantiate()
	var original := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for label in original.get_animation_list():
		var before := original.get_animation(label)
		var after := player.get_animation(label)
		assert(before.length == after.length and before.get_track_count() + 1 == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	source.free()
