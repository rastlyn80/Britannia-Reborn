extends "res://../scripts/bake-skeleton-axe-trial.gd"

const ART_DIR := "res://local-art/creatures/"
const RECEIPT := "res://../work/creatures/mul-motion-review/terathan-bake.json"
const TERATHANS := {70: "terathan_terathan_warrior", 71: "terathan_terathan_drone", 72: "terathan_terathan_queen"}
const UPPER_BODY := ["bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]
const CAST_JOINTS := ["bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l hand", "bip01 r hand", "bip01 tail1"]

func run() -> void:
	var outputs := {}
	for body: int in TERATHANS:
		var forms := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := ART_DIR + str(TERATHANS[body]) + "-" + treatment + ".gltf"
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			if body == 72:
				bake_dip(player, "MatriarchDip", "Fidget", UPPER_BODY + ["bip01 spine1", "bip01 tail1", "bip01 tail2"], Vector2(0.04, 0.57), 0.68)
				bake_cast(player, rig, "TerathanCast", false)
				bake_cast(player, rig, "Cast2", true)
			else:
				bake_dip(player, "PincerDip", "Attack", UPPER_BODY, Vector2(0.12, 0.68))
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := ART_DIR + "terathan-%d-classic-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			forms[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
			model.free()
		outputs[str(body)] = forms
		print("TERATHAN CLASSIC ", body, " / three treatments")
	var receipt := FileAccess.open(RECEIPT, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"joint_solver": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"forms": outputs,
	}))
	receipt.close()
	quit()

func held_idle(player: AnimationPlayer, length: float) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = length
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
	return motion

func bake_dip(player: AnimationPlayer, label: String, donor: String, names: Array, span: Vector2, strength := 1.0) -> void:
	var source := player.get_animation(donor)
	var motion := held_idle(player, 0.77)
	for track in motion.get_track_count():
		var path := motion.track_get_path(track)
		if motion.track_get_type(track) != Animation.TYPE_ROTATION_3D or str(path.get_subname(0)) not in names:
			continue
		var from := source.find_track(path, Animation.TYPE_ROTATION_3D)
		assert(from >= 0)
		var base: Quaternion = motion.track_get_key_value(track, 0)
		for sample in 91:
			var phase := float(sample) / 90.0
			var blend := strength * pulse(phase, 0.0, 0.16, 0.72, 1.0)
			var donor_phase := lerpf(span.x, span.y, smoothstep(0.0, 0.86, phase))
			var pose := source.rotation_track_interpolate(from, donor_phase * source.length)
			motion.rotation_track_insert_key(track, phase * motion.length, base.slerp(pose, blend))
	assert(player.get_animation_library("").add_animation(label, motion) == OK)

func bake_cast(player: AnimationPlayer, rig: Skeleton3D, label: String, overhead: bool) -> void:
	var motion := held_idle(player, 0.88)
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var axis := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	var joints: Array[int] = []
	var tracks: Array[int] = []
	var rotations: Array[Quaternion] = []
	for name: String in CAST_JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		var path := NodePath("%s:%s" % [rig_path, name])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		joints.append(joint)
		tracks.append(track)
		rotations.append(rig.get_bone_pose_rotation(joint))
	for sample in 91:
		var phase := float(sample) / 90.0
		var lift := pulse(phase, 0.0, 0.42, 0.58, 0.90)
		var release := pulse(phase, 0.52, 0.70, 0.78, 1.0)
		var upper := -1.15 * lift - 0.40 * release if overhead else -0.62 * lift - 0.48 * release
		var forearm := -0.30 * lift + 0.18 * release if overhead else -0.22 * lift + 0.10 * release
		var angles := [-0.10 * lift, -0.09 * lift, 0.12 * lift, upper, upper * 0.93,
			forearm, forearm * 1.08, 0.16 * lift, 0.10 * lift, -0.04 * lift]
		for i in joints.size():
			rig.set_bone_pose_rotation(joints[i], rotations[i])
		for i in joints.size():
			rotate_joint(rig, joints[i], Quaternion(axis, angles[i]))
			motion.rotation_track_insert_key(tracks[i], phase * motion.length, rig.get_bone_pose_rotation(joints[i]))
	assert(player.get_animation_library("").add_animation(label, motion) == OK)

func pulse(phase: float, start: float, high: float, held: float, end: float) -> float:
	return smoothstep(start, high, phase) * (1.0 - smoothstep(held, end, phase))
