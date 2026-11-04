extends SceneTree

const REGISTRY := preload("res://Presentation/CreatureRegistry.gd")
const GROUND := preload("res://Presentation/SourceGroundLookup.gd")
const ART := "res://local-art/creatures/"

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var receipt := {"recipe": FileAccess.get_sha256("res://../scripts/bake-occurrence-deaths.gd"), "scenes": {}}
	for body: int in [17, 18]:
		var row := REGISTRY.entry(body)
		assert(row.classic_gesture_batch == "orc_ettin_reactions")
		var scenes := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source: String = row.assets[treatment]
			var output := ART + "occurrence-death-%d-%s.scn" % [body, treatment]
			assert(source != output and FileAccess.get_sha256(source) == row.asset_sha256[treatment])
			bake(body, treatment, source, output)
			scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		receipt.scenes[str(body)] = scenes
	var report := FileAccess.open(ART + "occurrence-death-bake.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(receipt, "\t") + "\n")
	report.close()
	quit()

func bake(body: int, treatment: String, source: String, output: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := GROUND.skin_points(mesh, rig)
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.64
	clip.loop_mode = Animation.LOOP_NONE
	var driven: Dictionary = {}
	var joints := ["bip01 pelvis", "bip01 spine1", "bip01 spine2", "bip01 l thigh", "bip01 r thigh",
		"bip01 l calf", "bip01 r calf", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]
	for track in clip.get_track_count():
		var joint := str(clip.track_get_path(track).get_concatenated_subnames())
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if joint in joints and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			driven[joint] = track
	assert(driven.size() == joints.size())
	var pelvis := rig.find_bone("bip01 pelvis")
	var path := clip.track_get_path(driven["bip01 pelvis"])
	var placement := clip.find_track(path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, path)
	var least := INF
	player.deterministic = true
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 65:
		var phase := float(frame) / 64.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var fall := smoothstep(0.04, 0.87, phase)
		var throw := sin(PI * smoothstep(0.0, 0.75, phase))
		var tilt := (-1.86 if body == 17 else -1.60) * fall
		var twist := (0.20 if body == 17 else -0.31) * fall
		rotate(rig, "bip01 pelvis", Vector3.RIGHT, tilt)
		rotate(rig, "bip01 pelvis", Vector3.UP, twist)
		rotate(rig, "bip01 spine1", Vector3.RIGHT, 0.25 * throw)
		rotate(rig, "bip01 spine2", Vector3.FORWARD, -0.11 * fall)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			var prefix := "bip01 " + side
			rotate(rig, prefix + " thigh", Vector3.RIGHT, (0.14 + sign * 0.16) * fall)
			rotate(rig, prefix + " calf", Vector3.RIGHT, (-0.41 - sign * 0.10) * throw - 0.14 * fall)
			rotate(rig, prefix + " upperarm", Vector3.FORWARD, sign * (0.62 * throw + 0.30 * fall))
			rotate(rig, prefix + " upperarm", Vector3.RIGHT, (-0.12 + sign * 0.28) * throw)
			rotate(rig, prefix + " forearm", Vector3.RIGHT, -0.29 * throw + sign * 0.12 * fall)
			var settle := smoothstep(0.62, 0.98, phase)
			var hip_world := rig.to_global(rig.get_bone_global_pose(pelvis).origin)
			var reach := Vector3(sign * (0.46 if body == 17 else 0.85), -0.13, -0.13)
			settle_arm(rig, prefix, hip_world + reach, settle)
		var hip := rig.get_bone_global_pose(pelvis)
		hip.origin += rig.global_basis.inverse() * Vector3(0.09 * twist, 0.0, -0.24 * fall)
		rig.set_bone_global_pose(pelvis, hip)
		rig.force_update_all_bone_transforms()
		var gap := GROUND.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		hip = rig.get_bone_global_pose(pelvis)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(pelvis, hip)
		rig.force_update_all_bone_transforms()
		least = minf(least, GROUND.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		var time := clip.length * phase
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(pelvis))
		for joint: String in driven:
			clip.rotation_track_insert_key(driven[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	assert(player.get_animation_library("").add_animation("Death2", clip) == OK)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print(body, " ", treatment, " rear collapse, minimum nominal floor ", least)

func rotate(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis((rig.global_basis.inverse() * axis).normalized(), angle) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func settle_arm(rig: Skeleton3D, prefix: String, target: Vector3, amount: float) -> void:
	if amount <= 0.0:
		return
	var upper := rig.find_bone(prefix + " upperarm")
	var elbow := rig.find_bone(prefix + " forearm")
	var hand := rig.find_bone(prefix + " hand")
	var a := rig.get_bone_global_pose(upper).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var goal := c.lerp(rig.to_local(target), amount)
	var axis := (goal - a).normalized()
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var length := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + length * length) / (2.0 * length)
	var pole := (b - a).slide(axis).normalized()
	aim(rig, upper, elbow, a + axis * along + pole * sqrt(maxf(0.0, first * first - along * along)))
	aim(rig, elbow, hand, a + axis * length)

func aim(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var direction := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(direction, (target - pose.origin).normalized())) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
