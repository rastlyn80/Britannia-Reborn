extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Arms := preload("res://Presentation/WaterElementalFidgets.gd")
const GESTURES := {15: "BoneInward", 16: "BoneWide", 17: "BoneStretch", 18: "Fidget2"}
const BODY_SLOTS := {5: "Attack2", 6: "Attack3"}

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var donor_path := Registry.asset_path(Registry.entry(309))
	var donor_digest := FileAccess.get_sha256(donor_path)
	assert(donor_digest == "cbd480a7a45e02c3d4809dae3a8afd58e263f36b14f265d366eed4147705a6c9")
	var donor := (load(donor_path) as PackedScene).instantiate()
	root.add_child(donor)
	var source := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var from := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var donor_idle := neutral(source, from)
	var scenes := {}
	for body: int in [50, 56]:
		var row := Registry.entry(body)
		assert(not row.has("classic_gesture_batch"))
		var treatments := {}
		for treatment: String in row.assets:
			var path: String = row.assets[treatment]
			var digest := FileAccess.get_sha256(path)
			assert(digest == row.asset_sha256[treatment])
			var output := "res://local-art/creatures/skeleton-actions-%d-%s.scn" % [body, treatment]
			bake(path, output, source, from, donor_idle)
			treatments[treatment] = {"source": digest, "scene": FileAccess.get_sha256(output)}
		scenes[str(body)] = treatments
	donor.free()
	var proof := FileAccess.open("res://local-art/creatures/skeleton-actions-bake.json", FileAccess.WRITE)
	assert(proof != null)
	proof.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"arm_solver": FileAccess.get_sha256("res://Presentation/WaterElementalFidgets.gd"),
		"skin_solver": FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),
		"donor": donor_digest, "scenes": scenes}))
	proof.close()
	quit()

func bake(path: String, output: String, source: Skeleton3D, from: AnimationPlayer, donor_idle: Dictionary) -> void:
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var target_idle := neutral(rig, player)
	var meshes: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			meshes.append(Ground.skin_points(mesh, rig))
	for slot: int in BODY_SLOTS:
		var label: String = BODY_SLOTS[slot]
		var motion := retarget(from, source, donor_idle, rig, player, target_idle, meshes, label)
		assert(player.get_animation_library("").add_animation(label, motion) == OK)
	for slot: int in GESTURES:
		var motion := gesture(player, rig, meshes, slot)
		assert(player.get_animation_library("").add_animation(GESTURES[slot], motion) == OK)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func neutral(rig: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var pose := {}
	for index in rig.get_bone_count():
		var world := rig.global_transform * rig.get_bone_global_pose(index)
		pose[rig.get_bone_name(index)] = world
	return pose

func retarget(from: AnimationPlayer, source: Skeleton3D, donor_idle: Dictionary,
		rig: Skeleton3D, player: AnimationPlayer, target_idle: Dictionary,
		meshes: Array[Dictionary], label: String) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.64
	clip.loop_mode = Animation.LOOP_NONE
	var rotation := {}
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		var joint := str(path.get_concatenated_subnames())
		for i in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, i)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and donor_idle.has(joint) and joint.begins_with("bip01 "):
			rotation[rig.find_bone(joint)] = track
	var pelvis := rig.find_bone("bip01 pelvis")
	var placement := clip.find_track(clip.track_get_path(rotation[pelvis]), Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, clip.track_get_path(rotation[pelvis]))
	var joints := rotation.keys()
	joints.sort()
	var hand := rig.find_bone("bip01 r hand")
	from.play(label, 0.0)
	from.advance(0.0)
	var duration := from.current_animation_length
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 65:
		var phase := float(frame) / 64.0
		from.seek(duration * phase, true)
		source.force_update_all_bone_transforms()
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		for bone: int in joints:
			var name := rig.get_bone_name(bone)
			var donor_bone := source.find_bone(name)
			var previous: Transform3D = donor_idle[name]
			var target: Transform3D = target_idle[name]
			var moving := source.global_transform * source.get_bone_global_pose(donor_bone)
			var change := moving.basis.orthonormalized() * previous.basis.orthonormalized().inverse()
			var desired := rig.global_basis.orthonormalized().inverse() * change * target.basis.orthonormalized()
			var pose := rig.get_bone_global_pose(bone)
			pose.basis = desired.orthonormalized()
			rig.set_bone_global_pose(bone, pose)
			rig.force_update_all_bone_transforms()
		if label == "Attack3":
			var swing := sin(PI * phase)
			var hand_world := rig.to_global(rig.get_bone_global_pose(hand).origin)
			var hip_world := rig.to_global(rig.get_bone_global_pose(pelvis).origin)
			var reach := hand_world - hip_world
			var capped := Vector3(reach.x - 0.12 * swing, minf(reach.y, 0.74), reach.z + 0.12 * swing)
			fit_arm(rig, "r", hip_world + capped)
			var shaft := Vector3(-0.75, 0.30, 0.56).lerp(Vector3(0.50, 0.45, -0.71), phase).normalized()
			point_axe(rig, shaft, 0.55 * swing)
		var hip := rig.get_bone_global_pose(pelvis)
		var gap := INF
		for surface: Dictionary in meshes:
			gap = minf(gap, Ground.minimum_plane_gap(surface, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(pelvis, hip)
		rig.force_update_all_bone_transforms()
		var time := clip.length * phase
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(pelvis))
		for bone: int in joints:
			clip.rotation_track_insert_key(rotation[bone], time, rig.get_bone_pose_rotation(bone))
	return clip

func gesture(player: AnimationPlayer, rig: Skeleton3D, meshes: Array[Dictionary], slot: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.48 if slot in [15, 16] else 0.80
	clip.loop_mode = Animation.LOOP_NONE
	var driven := {}
	var torso := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head"]
	for track in clip.get_track_count():
		var joint := str(clip.track_get_path(track).get_concatenated_subnames())
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and (
			joint in torso or joint.ends_with("upperarm") or joint.ends_with("forearm") or joint.ends_with("hand")):
			driven[rig.find_bone(joint)] = track
	var pelvis := rig.find_bone("bip01 pelvis")
	var pelvis_path := clip.track_get_path(driven[rig.find_bone("bip01 spine")])
	var position_path := NodePath(str(pelvis_path.get_concatenated_names()) + ":bip01 pelvis")
	var placement := clip.find_track(position_path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, position_path)
	var right := rig.find_bone("bip01 r hand")
	var left := rig.find_bone("bip01 l hand")
	var target_right: Vector3 = {15: Vector3(-0.42, 0.40, 0.65), 16: Vector3(-0.87, 0.51, 0.12),
		17: Vector3(-0.86, 0.45, 0.18), 18: Vector3(-0.36, 1.02, 0.18)}[slot]
	var target_left: Vector3 = {15: Vector3(0.38, 0.06, -0.33), 16: Vector3(0.78, 0.33, 0.28),
		17: Vector3(0.85, 0.52, 0.24), 18: Vector3(0.38, -0.07, 0.22)}[slot]
	var shaft: Vector3 = {15: Vector3(-0.35, -0.11, 0.93), 16: Vector3(0.06, 0.15, 0.99),
		17: Vector3(-0.78, 0.18, 0.59), 18: Vector3(-0.09, 0.20, -0.98)}[slot]
	player.play("Idle", 0.0)
	player.advance(0.0)
	for i in 65:
		var phase := float(i) / 64.0
		var pulse := smoothstep(0.05, 0.47, phase) * (1.0 - smoothstep(0.52, 1.0, phase))
		if slot == 15:
			pulse = smoothstep(0.06, 0.90, phase)
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var hip := rig.get_bone_global_pose(pelvis)
		var centre := rig.to_global(hip.origin)
		for label: String in torso:
			var index := rig.find_bone(label)
			var pose := rig.get_bone_global_pose(index)
			var axis := Vector3.UP if slot != 15 else Vector3.RIGHT
			var angle := {15: 0.14, 16: -0.12, 17: 0.05, 18: -0.06}[slot] as float
			pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), angle * pulse)) * pose.basis
			rig.set_bone_global_pose(index, pose)
			rig.force_update_all_bone_transforms()
		var a := rig.to_global(rig.get_bone_global_pose(right).origin)
		var b := rig.to_global(rig.get_bone_global_pose(left).origin)
		fit_arm(rig, "r", a.lerp(centre + target_right, pulse))
		fit_arm(rig, "l", b.lerp(centre + target_left, pulse))
		point_axe(rig, shaft, pulse)
		var gap := INF
		for surface: Dictionary in meshes:
			gap = minf(gap, Ground.minimum_plane_gap(surface, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(pelvis, hip)
		rig.force_update_all_bone_transforms()
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(pelvis))
		for index: int in driven:
			clip.rotation_track_insert_key(driven[index], time, rig.get_bone_pose_rotation(index))
	return clip

func fit_arm(rig: Skeleton3D, side: String, target: Vector3) -> void:
	var upper := rig.find_bone("bip01 %s upperarm" % side)
	var joint := rig.find_bone("bip01 %s forearm" % side)
	var hand := rig.find_bone("bip01 %s hand" % side)
	var a := rig.get_bone_global_pose(upper).origin
	var b := rig.get_bone_global_pose(joint).origin
	var c := rig.get_bone_global_pose(hand).origin
	var goal := rig.to_local(target)
	var direction := (goal - a).normalized()
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var distance := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var pole := (b - a).slide(direction).normalized()
	if pole.is_zero_approx():
		pole = Vector3.UP.slide(direction).normalized()
	Arms.aim(rig, upper, joint, a + direction * along + pole * sqrt(maxf(0.0, first * first - along * along)))
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, joint, hand, a + direction * distance)
	rig.force_update_all_bone_transforms()

func point_axe(rig: Skeleton3D, direction: Vector3, weight: float) -> void:
	var axe := rig.find_bone("skeleton axe")
	if axe < 0:
		return
	var hand := rig.find_bone("bip01 r hand")
	var shaft := rig.get_bone_global_pose(axe).basis.y.normalized()
	var target := (rig.global_basis.inverse() * direction).normalized()
	var pose := rig.get_bone_global_pose(hand)
	pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(shaft, target), weight)) * pose.basis
	rig.set_bone_global_pose(hand, pose)
	rig.force_update_all_bone_transforms()
