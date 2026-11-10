# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-troglodyte-enhanced.gd"

const GAIT_OUTPUT := "res://../work/creatures/native-form-audit/enhanced-source-gaps/troglodyte-gaits-%s.scn"
# The closest repeated cycle in the recovered walk, measured at 120 Hz
# across both feet, wrists, head and pelvis, including endpoint velocity.
const WALK_START := 412.0 / 120.0
const WALK_STEPS := 124
const SoleContact := preload("res://Presentation/SourceMountContact.gd")

func run() -> void:
	var row := Registry.entry(267)
	assert(row.has("troglodyte_enhanced"))
	var base: Dictionary = row.get("troglodyte_gaits", {}).get("base", row)
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(base, treatment)
		assert(FileAccess.get_sha256(source) == base.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				skins.append(Ground.skin_points(mesh, rig))
		assert(not skins.is_empty())
		var sole_probe := SoleContact.new()
		sole_probe.include_toe_descendants = true
		sole_probe.active = false
		rig.add_child(sole_probe)
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert(skins[0].surfaces[0].stride == 4)
		sole_probe.configure(mesh, false)
		assert(sole_probe.feet.size() == 2)
		var stance := fit_loop(player, rig, skins, "Idle", 144, peaceful_stance.bind(sole_probe))
		sole_probe.free()
		assert(library.add_animation("ReadyStance", stance) == OK)
		assert(library.add_animation("TroglodytePeaceWalk", fit_loop(player, rig, skins, "Walk", WALK_STEPS, fit_peaceful_walk)) == OK)
		assert(library.add_animation("TroglodyteSprint", fit_loop(player, rig, skins, "Walk", WALK_STEPS, fit_sprint)) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, GAIT_OUTPUT % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TROGLODYTE GAIT CANDIDATE: ", treatment, " / Enhanced groups 22, 24 and 25")
	quit()

func fit_loop(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary],
		source_name: String, steps: int, fit_pose: Callable) -> Animation:
	var source := player.get_animation(source_name)
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_LINEAR
	clip.length = steps / 120.0
	var targets := []
	var scene_root := player.get_node(player.root_node)
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		var node := scene_root.get_node(NodePath(path.get_concatenated_names())) as Node3D
		assert(node != null and path.get_subname_count() <= 1, str(path))
		var joint := -1
		if path.get_subname_count() == 1:
			joint = rig.find_bone(path.get_subname(0))
			assert(node == rig and joint >= 0, str(path))
		targets.append([node, joint])
		clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	var root_joint := rig.find_bone("bip01")
	player.play(source_name, 0.0)
	player.advance(0.0)
	var poses := []
	for frame in steps + 1:
		rig.reset_bone_poses()
		var source_time := WALK_START + frame / 120.0 if source_name == "Walk" else 0.0
		player.seek(source_time, true)
		rig.force_update_all_bone_transforms()
		fit_pose.call(rig, float(frame) / steps)
		var clearance := INF
		for skin: Dictionary in skins:
			clearance = minf(clearance, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(is_finite(clearance))
		var root_pose := rig.get_bone_global_pose(root_joint)
		root_pose.origin += rig.global_basis.inverse() * Vector3.UP * (.006 - clearance)
		rig.set_bone_global_pose(root_joint, root_pose)
		var pose := []
		for track in clip.get_track_count():
			var node: Node3D = targets[track][0]
			var joint: int = targets[track][1]
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: pose.append(node.position if joint < 0 else rig.get_bone_pose_position(joint))
				Animation.TYPE_ROTATION_3D: pose.append(node.quaternion if joint < 0 else rig.get_bone_pose_rotation(joint))
				Animation.TYPE_SCALE_3D: pose.append(node.scale if joint < 0 else rig.get_bone_pose_scale(joint))
				_: assert(false, str(clip.track_get_path(track)))
		poses.append(pose)
	for frame in poses.size():
		var time := frame / 120.0
		var closure := smoothstep(.84, 1.0, float(frame) / steps)
		for track in clip.get_track_count():
			var value: Variant = poses[frame][track]
			var first: Variant = poses[0][track]
			var last: Variant = poses[-1][track]
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D: clip.position_track_insert_key(track, time, value + (first - last) * closure)
				Animation.TYPE_ROTATION_3D:
					var correction: Quaternion = (first * last.inverse()).normalized()
					clip.rotation_track_insert_key(track, time, (Quaternion.IDENTITY.slerp(correction, closure) * value).normalized())
				Animation.TYPE_SCALE_3D: clip.scale_track_insert_key(track, time, value + (first - last) * closure)
	return clip

func fit_peaceful_walk(rig: Skeleton3D, _phase: float) -> void:
	var hips := joint_world(rig, "bip01 pelvis")
	var foot_goals := foot_poses(rig)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .075)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .055)
	for side: String in ["l", "r"]:
		var handedness := 1.0 if side == "l" else -1.0
		var wrist := joint_world(rig, "bip01 %s hand" % side) - hips
		fit_arm(rig, side, hips + Vector3(handedness * .99, wrist.y - .26, .36 + wrist.z * .45))
	for side: String in foot_goals:
		aim_foot(rig, side, foot_goals[side])

func peaceful_stance(rig: Skeleton3D, phase: float, sole_probe: SkeletonModifier3D) -> void:
	var breath := .5 - .5 * cos(phase * TAU)
	var hips := joint_world(rig, "bip01 pelvis")
	var foot_goals := foot_poses(rig)
	for side: String in foot_goals:
		var foot: Transform3D = foot_goals[side]
		var point := rig.to_global(foot.origin)
		point.z = lerpf(point.z, hips.z, .48)
		foot.origin = rig.to_local(point)
		foot_goals[side] = foot
	var root_index := rig.find_bone("bip01")
	var root_pose := rig.get_bone_global_pose(root_index)
	root_pose.origin += rig.global_basis.inverse() * Vector3(0, -.23 - .05 * breath, -.02)
	rig.set_bone_global_pose(root_index, root_pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .20)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .11 + .05 * breath)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .13 - .05 * breath)
	hips = joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "l", hips + Vector3(.96, -.94 - .04 * breath, .73))
	fit_arm(rig, "r", hips + Vector3(-1.05, -.91 - .05 * breath, .58))
	# The source's upper-body edits affect the leg chains. Plant the soles last.
	for index in 2:
		var side := "l" if index == 0 else "r"
		var goal: Transform3D = foot_goals[side]
		aim_foot(rig, side, goal)
		for correction in 3:
			var gap: float = sole_probe.sole(sole_probe.feet[index]).y - .006
			if absf(gap) < .002:
				break
			goal.origin -= rig.global_basis.inverse() * Vector3.UP * gap
			aim_foot(rig, side, goal)

func fit_sprint(rig: Skeleton3D, _phase: float) -> void:
	var hips := joint_world(rig, "bip01 pelvis")
	var foot_goals := foot_poses(rig)
	var foot_phase := {}
	for side: String in foot_goals:
		var foot: Transform3D = foot_goals[side]
		var point := rig.to_global(foot.origin)
		var stride := point.z - hips.z
		foot_phase[side] = stride
		point.z += .34 * stride
		foot.origin = rig.to_local(point)
		foot_goals[side] = foot
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .29)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .20)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.10)
	for side: String in ["l", "r"]:
		var handedness := 1.0 if side == "l" else -1.0
		var stride: float = foot_phase[side]
		fit_arm(rig, side, hips + Vector3(handedness * .95, -.64 - .10 * stride, .95 - .74 * stride))
	for side: String in foot_goals:
		aim_foot(rig, side, foot_goals[side])

func foot_poses(rig: Skeleton3D) -> Dictionary:
	return {"l": rig.get_bone_global_pose(rig.find_bone("bip01 l foot")),
		"r": rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))}

func aim_foot(rig: Skeleton3D, side: String, goal: Transform3D) -> void:
	var thigh := rig.find_bone("bip01 %s thigh" % side)
	var calf := rig.find_bone("bip01 %s calf" % side)
	var foot := rig.find_bone("bip01 %s foot" % side)
	var knee := Legs.knee_target(rig.get_bone_global_pose(thigh).origin,
		rig.get_bone_global_pose(calf).origin, rig.get_bone_global_pose(foot).origin, goal.origin)
	Arms.aim(rig, thigh, calf, knee)
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, calf, foot, goal.origin)
	rig.force_update_all_bone_transforms()
	goal.origin = rig.get_bone_global_pose(foot).origin
	rig.set_bone_global_pose(foot, goal)
	rig.force_update_all_bone_transforms()
