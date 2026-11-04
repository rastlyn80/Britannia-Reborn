extends "res://../scripts/bake-skeleton-axe-trial.gd"

const ART_DIR := "res://local-art/creatures/"
const RECEIPT := "res://../work/creatures/mul-motion-review/dragon-daemon-bake.json"
const DRAGONS := ["dragons_dragon_blasted", "dragons_dragon_blasted_red"]
const DAEMONS := ["daemons_daemon", "daemons_daemon_black_gate", "daemons_daemon_elder", "daemons_daemon_ice_fiend"]
const DRAGON_JOINTS := ["bip01 neck1", "bip01 neck2", "bip01 neck3", "bip01 head",
	"box06", "box01", "box07", "box02", "bip01 tail1", "bip01 tail2"]
const DAEMON_JOINTS := ["bip01 spine1", "bip01 spine2", "bip01 neck1", "bip01 head",
	"daemon l mainwing01", "daemon r mainwing01", "daemon l mainwing02", "daemon r mainwing02",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]

func run() -> void:
	var outputs := {}
	for kind: String in DRAGONS + DAEMONS:
		var dragon := kind in DRAGONS
		var forms := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := ART_DIR + kind + "-" + treatment + ".gltf"
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			if dragon:
				author(player, rig, "DragonDip", 0.70, DRAGON_JOINTS)
				author(player, rig, "DragonBreath", 2.25, DRAGON_JOINTS)
			else:
				if kind == "daemons_daemon":
					author(player, rig, "DaemonWingCheck", 0.76, DAEMON_JOINTS)
				author(player, rig, "DaemonCast", 1.14, DAEMON_JOINTS)
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := ART_DIR + kind + "-classic-" + treatment + ".scn"
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			forms[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
			model.free()
		outputs[kind] = forms
		print("CLASSIC DRAGON/DAEMON: ", kind, " / three treatments")
	var file := FileAccess.open(RECEIPT, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"joint_solver": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"forms": outputs,
	}))
	file.close()
	quit()

func author(player: AnimationPlayer, rig: Skeleton3D, label: String, seconds: float, names: Array) -> void:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = seconds
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var path := player.get_node(player.root_node).get_path_to(rig)
	var joints: Array[int] = []
	var tracks: Array[int] = []
	var bases: Array[Quaternion] = []
	for name: String in names:
		var joint := rig.find_bone(name)
		var track := motion.find_track(NodePath("%s:%s" % [path, name]), Animation.TYPE_ROTATION_3D)
		assert(joint >= 0 and track >= 0)
		joints.append(joint)
		tracks.append(track)
		bases.append(rig.get_bone_pose_rotation(joint))
	var inverse := rig.global_basis.inverse()
	var right := (inverse * Vector3.RIGHT).normalized()
	var forward := (inverse * Vector3.BACK).normalized()
	var up := (inverse * Vector3.UP).normalized()
	var dragon := names == DRAGON_JOINTS
	var limb_axis := up if dragon else right
	for sample in 91:
		var phase := float(sample) / 90.0
		for i in joints.size():
			rig.set_bone_pose_rotation(joints[i], bases[i])
		rig.force_update_all_bone_transforms()
		var angles := dragon_angles(label, phase) if dragon else daemon_angles(label, phase)
		for i in joints.size():
			var axis := limb_axis
			if i < 4:
				axis = right
			elif i < 8:
				axis = forward
			rotate_joint(rig, joints[i], Quaternion(axis, angles[i]))
			motion.rotation_track_insert_key(tracks[i], seconds * phase, rig.get_bone_pose_rotation(joints[i]))
	if label == "DragonBreath":
		add_breath_jaw(motion, player.get_animation("Attack2"), path)
	assert(player.get_animation_library("").add_animation(label, motion) == OK)

func add_breath_jaw(motion: Animation, source: Animation, rig_path: NodePath) -> void:
	# Preserve the source attack's weighted jaw and tongue poses.
	for name: String in ["box14", "box15"]:
		var path := NodePath("%s:%s" % [rig_path, name])
		var position := motion.find_track(path, Animation.TYPE_POSITION_3D)
		var rotation := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		var source_position := source.find_track(path, Animation.TYPE_POSITION_3D)
		var source_rotation := source.find_track(path, Animation.TYPE_ROTATION_3D)
		assert(mini(position, rotation) >= 0 and mini(source_position, source_rotation) >= 0)
		var closed_point: Vector3 = motion.track_get_key_value(position, 0)
		var closed_rotation: Quaternion = motion.track_get_key_value(rotation, 0)
		var open_point := source.position_track_interpolate(source_position, source.length * 0.54)
		var open_rotation := source.rotation_track_interpolate(source_rotation, source.length * 0.54)
		for sample in 91:
			var phase := float(sample) / 90.0
			var opening := pulse(phase, 0.36, 0.57, 0.79, 0.98)
			motion.position_track_insert_key(position, motion.length * phase, closed_point.lerp(open_point, opening))
			motion.rotation_track_insert_key(rotation, motion.length * phase, closed_rotation.slerp(open_rotation, opening))

func dragon_angles(label: String, phase: float) -> Array[float]:
	var head := 0.36 * pulse(phase, 0.02, 0.42, 0.58, 1.0)
	var wings := -0.15 * pulse(phase, 0.04, 0.26, 0.40, 0.96)
	if label == "DragonBreath":
		var inhale := pulse(phase, 0.04, 0.35, 0.42, 0.61)
		var release := pulse(phase, 0.41, 0.61, 0.79, 1.0)
		head = -0.29 * inhale + 0.14 * release
		wings = -0.12 * inhale + 0.80 * release
	var sway := sin(phase * TAU) * pulse(phase, 0.0, 0.30, 0.70, 1.0)
	return [head * 0.84, head * 0.72, head * 0.49, -head * 0.61,
		-wings, wings, -wings * 0.42, wings * 0.42, sway * 0.21, sway * 0.14]

func daemon_angles(label: String, phase: float) -> Array[float]:
	var lean := 0.20 * pulse(phase, 0.03, 0.33, 0.47, 0.95)
	var wings := -0.52 * pulse(phase, 0.06, 0.52, 0.67, 1.0)
	var reach := 0.0
	if label == "DaemonCast":
		var crouch := pulse(phase, 0.05, 0.34, 0.52, 0.94)
		reach = pulse(phase, 0.37, 0.67, 0.77, 1.0)
		lean = 0.15 * (crouch + reach)
		wings = 0.36 * crouch - 0.43 * reach
	return [lean * 0.65, lean * 0.70, -lean * 0.30, -lean * 0.30,
		-wings, wings, -wings * 0.30, wings * 0.30,
		-reach * 0.39, -reach * 0.73, reach * 0.12, reach * 0.27]

func pulse(phase: float, start: float, high: float, held: float, end: float) -> float:
	return smoothstep(start, high, phase) * (1.0 - smoothstep(held, end, phase))
