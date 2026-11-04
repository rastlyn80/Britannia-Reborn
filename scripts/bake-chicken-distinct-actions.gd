extends SceneTree
## Two independent, rig-fitted hen poses for the Classic rear strike and seated fall.
const INPUT := "res://Art/Creatures/Chicken/chicken.glb"
const OUTPUT := "res://local-art/creatures/chicken-distinct-actions.res"
const CANDIDATE := "res://local-art/creatures/chicken-distinct-candidate.scn"
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const FPS := 240
const LANDING := "Death2"
const STRIKE := "RearStrike"

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var model := (load(INPUT) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var owner := player.get_node(player.root_node)
	var motion := owner.get_node("AuthoredChickenMotion") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 2)
	var library := AnimationLibrary.new()
	player.play("Idle", 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var standing: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		standing.append(rig.get_bone_pose(bone))
	for label: String in [STRIKE, LANDING]:
		for bone in rig.get_bone_count():
			rig.set_bone_pose(bone, standing[bone])
		var animation := bake(player, rig, motion, meshes, label)
		assert(library.add_animation(label, animation) == OK)
	var existing := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", existing)
	assert(existing.get_animation_list().size() == 19)
	for label: String in library.get_animation_list():
		assert(existing.add_animation(label, library.get_animation(label)) == OK)
		player.play(label, 0.0)
		player.advance(0.0)
		for frame in 121:
			player.seek(player.current_animation_length * frame / 120.0, true)
			rig.force_update_all_bone_transforms()
			var gap := bounds(meshes, rig).position.y
			assert(gap > -0.001 and gap < 0.04)
	player.play("Idle", 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	player.stop()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	assert(ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, CANDIDATE, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	var receipt := FileAccess.open("res://local-art/creatures/chicken-distinct-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"source": FileAccess.get_sha256(INPUT), "scene": FileAccess.get_sha256(CANDIDATE),
		"library": FileAccess.get_sha256(OUTPUT), "recipe": FileAccess.get_sha256(get_script().resource_path)}))
	receipt.close()
	print("CHICKEN DISTINCT ACTIONS: 242 grounded skin poses on the independent licensed rig")
	quit()

func bake(player: AnimationPlayer, rig: Skeleton3D, motion: Node3D, meshes: Array, label: String) -> Animation:
	var dying := label == LANDING
	var base := player.get_animation("Idle")
	var animation := base.duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_NONE
	var length := 0.82 if dying else 0.58
	animation.length = length
	var feet: Array[String] = ["Leg_L.001", "Leg_L.002", "Leg_R.001", "Leg_R.002"]
	var root_bones: Array[String] = []
	for bone in rig.get_bone_count():
		if rig.get_bone_parent(bone) < 0:
			root_bones.append(rig.get_bone_name(bone))
	assert(root_bones.size() == 8)
	var adjusted := root_bones + feet
	var keys := {}
	var owner := player.get_node(player.root_node)
	var rig_path := String(owner.get_path_to(rig))
	for name in adjusted:
		var path := NodePath(rig_path + ":" + name)
		var index := animation.find_track(path, Animation.TYPE_ROTATION_3D)
		if index < 0:
			index = animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(index, path)
		clear_keys(animation, index)
		keys[name] = index
	var translations := {}
	for name in root_bones:
		var path := NodePath(rig_path + ":" + name)
		var index := animation.find_track(path, Animation.TYPE_POSITION_3D)
		if index < 0:
			index = animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(index, path)
		clear_keys(animation, index)
		translations[name] = index
	var motion_track := animation.find_track(NodePath("AuthoredChickenMotion"), Animation.TYPE_POSITION_3D)
	assert(motion_track >= 0)
	clear_keys(animation, motion_track)
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var reference: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		reference.append(rig.get_bone_pose(bone))
	var frames := roundi(length * FPS)
	for frame in frames + 1:
		var phase := float(frame) / frames
		var time := phase * length
		for bone in rig.get_bone_count():
			rig.set_bone_pose(bone, reference[bone])
		rig.force_update_all_bone_transforms()
		motion.position = Vector3.ZERO
		var rear := smoothstep(0.04, 0.31, phase) * (1.0 - smoothstep(0.38, 0.72, phase))
		var strike := smoothstep(0.29, 0.52, phase) * (1.0 - smoothstep(0.56, 0.92, phase))
		var lower := smoothstep(0.27, 0.79, phase)
		var wing := smoothstep(0.03, 0.31, phase) * (1.0 - smoothstep(0.32, 0.71, phase))
		if dying:
			pitch_body(rig, root_bones, -0.16 * wing + 0.49 * lower)
			rotate_joint(rig, "Leg_L.001", Vector3.RIGHT, 1.16 * lower)
			rotate_joint(rig, "Leg_R.001", Vector3.RIGHT, 1.08 * lower)
			rotate_joint(rig, "Leg_L.002", Vector3.RIGHT, 0.92 * lower)
			rotate_joint(rig, "Leg_R.002", Vector3.RIGHT, 0.82 * lower)
			motion.position.z = 0.035 * lower
		else:
			pitch_body(rig, root_bones, -0.34 * rear + 0.51 * strike)
			rotate_joint(rig, "Leg_L.001", Vector3.RIGHT, -0.48 * rear + 0.30 * strike)
			rotate_joint(rig, "Leg_L.002", Vector3.RIGHT, 0.42 * rear)
			motion.position.z = 0.07 * strike
		rig.force_update_all_bone_transforms()
		motion.position.y = 0.002 + (0.021 * rear if not dying else 0.007 * sin(PI * phase)) - bounds(meshes, rig).position.y
		for name in adjusted:
			animation.rotation_track_insert_key(keys[name], time, rig.get_bone_pose_rotation(rig.find_bone(name)))
		for name in root_bones:
			animation.position_track_insert_key(translations[name], time, rig.get_bone_pose_position(rig.find_bone(name)))
		animation.position_track_insert_key(motion_track, time, motion.position)
	return animation

func clear_keys(animation: Animation, track: int) -> void:
	for key in range(animation.track_get_key_count(track) - 1, -1, -1):
		animation.track_remove_key(track, key)

# The seven evaluated curved-bone segments are independent rig roots.
# Pitch those roots around the same hip pivot as the ordinary skeleton.
func pitch_body(rig: Skeleton3D, root_bones: Array[String], angle: float) -> void:
	var axis := (rig.global_basis.orthonormalized().inverse() * Vector3.RIGHT).normalized()
	var rotation := Quaternion(axis, angle)
	var pivot := rig.get_bone_global_pose(rig.find_bone("Hip")).origin
	for name in root_bones:
		var bone := rig.find_bone(name)
		var pose := rig.get_bone_pose(bone)
		pose.origin = pivot + rotation * (pose.origin - pivot)
		pose.basis = Basis(rotation) * pose.basis
		rig.set_bone_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func rotate_joint(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var parent := rig.get_bone_parent(bone)
	var parent_basis := rig.global_basis * rig.get_bone_global_pose(parent).basis
	var local_axis := (parent_basis.orthonormalized().inverse() * axis).normalized()
	rig.set_bone_pose_rotation(bone, Quaternion(local_axis, angle) * rig.get_bone_pose_rotation(bone))
	rig.force_update_all_bone_transforms()

func bounds(meshes: Array, rig: Skeleton3D) -> AABB:
	return Geometry.deformed_bounds(meshes[0], rig).merge(Geometry.deformed_bounds(meshes[1], rig))
