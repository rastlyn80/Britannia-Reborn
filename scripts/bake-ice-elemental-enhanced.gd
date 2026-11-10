# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ice-elemental/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const CrystalShell := preload("ice-elemental-crystal-shell.gd")
const Clips := {23: "IceElementalCrossedRise", 28: "IceElementalSpreadAlert"}
const Lengths := {23: 1.11, 28: .72}
const IceJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	var row := Registry.entry(161)
	for treatment: String in Profile.registered_assets(row):
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var actor := (load(source) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.play("Idle", 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var shell := CrystalShell.new().build(actor, rig)
		var skins: Array[Dictionary] = [Ground.skin_points(actor.find_child("Body", true, false), rig), Ground.skin_points(shell, rig)]
		for group: int in Clips:
			var clip := fit_grounded(player, rig, skins, Lengths[group], "bip01", IceJoints, pose_ice.bind(group), .005)
			assert(library.add_animation(Clips[group], clip) == OK)
		verify_base_clips(player, source)
		steer_crystal_blades(player, rig, shell)
		verify_body_keys(player, source)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(actor) == OK)
		assert(ResourceSaver.save(packed, Destination + "161-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		actor.free()
		print("ICE ELEMENTAL ", treatment, ": crossed-blade rise and single-foot spread, exact retained keys")
	quit()


func pose_ice(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 1.0 - smoothstep(.08, .91, phase) if group == 23 else .23 * smoothstep(.02, .60, phase)
	var spread := smoothstep(.09, .56, phase) if group == 28 else 0.0
	var cross := crouch if group == 23 else 0.0
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var sign_x := 1.0 if side == "l" else -1.0
		var offset := Vector3(sign_x * .09 * crouch, 0, sign_x * .10 * crouch)
		if side == "r":
			offset += Vector3(-.09, .32, .21) * spread
		foot.origin += rig.global_basis.inverse() * offset
		feet.append(foot)
	var root_bone := rig.find_bone("bip01")
	var hips := rig.get_bone_global_pose(root_bone)
	hips.origin += rig.global_basis.inverse() * Vector3(.16 * spread, -.48 * crouch, .15 * crouch)
	rig.set_bone_global_pose(root_bone, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .32 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .37 * cross - .09 * spread)
	turn_world(rig, "bip01 spine2", Vector3.UP, .21 * cross - .13 * spread)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.19 * cross)
	turn_world(rig, "bip01 head", Vector3.UP, -.14 * cross + .17 * spread)
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip01 spine2")
	left = left.lerp(chest + Vector3(.20, -.10, .44), cross)
	right = right.lerp(chest + Vector3(-.19, -.29, .91), cross)
	left = left.lerp(chest + Vector3(.88, .14, .16), spread)
	right = right.lerp(chest + Vector3(-.85, .20, .29), spread)
	fit_arm(rig, "l", left)
	fit_arm(rig, "r", right)
	point_blade(rig, "l", Vector3.DOWN.slerp(Vector3(-.91, -.31, -.12).normalized(), cross)
		.slerp(Vector3(.91, .13, .31).normalized(), spread))
	point_blade(rig, "r", Vector3.DOWN.slerp(Vector3(.83, -.32, .45).normalized(), cross)
		.slerp(Vector3(-.90, .23, .32).normalized(), spread))


func point_blade(rig: Skeleton3D, side: String, direction: Vector3) -> void:
	var hand := rig.find_bone("bip01 %s hand" % side)
	var blade := rig.find_bone("cp_grasp_%shand" % side)
	var origin := rig.get_bone_global_pose(hand).origin
	Arms.aim(rig, hand, blade, origin + rig.global_basis.inverse() * direction)
	rig.force_update_all_bone_transforms()


func steer_crystal_blades(player: AnimationPlayer, rig: Skeleton3D, shell: MeshInstance3D) -> void:
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tips := {}
	for side: String in CrystalShell.BladeJoint:
		tips[side] = CrystalShell.local_tip(shell, rig, side).normalized()
	for name: String in player.get_animation_list():
		var animation := player.get_animation(name)
		var tracks := {}
		for side: String in CrystalShell.BladeJoint:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("%s:%s" % [path, CrystalShell.BladeJoint[side]]))
			tracks[side] = track
		player.stop()
		player.play(name, 0.0)
		player.advance(0.0)
		var samples := ceili(animation.length * 96.0)
		for sample in samples + 1:
			var phase := float(sample) / samples
			var time := phase * animation.length
			player.seek(time, true)
			rig.force_update_all_bone_transforms()
			for side: String in CrystalShell.BladeJoint:
				var tip: Vector3 = tips[side]
				var hand := rig.find_bone("bip01 %s hand" % side)
				var frame := (rig.global_transform * rig.get_bone_global_pose(hand)).basis.orthonormalized()
				var direction := frame * tip
				var sign_x := 1.0 if side == "l" else -1.0
				var outside := Vector3(sign_x * .77, -.29, .42).normalized()
				var amount := .30
				match name:
					"Run":
						amount = .86
					"Walk":
						amount = .63
					"Death":
						amount = .60 * (1.0 - smoothstep(.010, .075, phase)) + fall_clearance(phase)
						outside = fall_direction(rig, side, outside)
					"Death2":
						amount = maxf(.08, fall_clearance(phase))
						outside = fall_direction(rig, side, outside)
					"IceElementalCrossedRise":
						amount = .84 * smoothstep(.43, .57, phase) * (1.0 - smoothstep(.69, .92, phase))
					"IceElementalSpreadAlert", "Idle":
						amount = 0.0
				var wanted := frame.inverse() * direction.slerp(outside, amount)
				animation.rotation_track_insert_key(tracks[side], time, Quaternion(tip, wanted.normalized()))


func fall_clearance(phase: float) -> float:
	return .93 * smoothstep(.64, .70, phase) * (1.0 - smoothstep(.85, .99, phase))


func fall_direction(rig: Skeleton3D, side: String, fallback: Vector3) -> Vector3:
	var wrist := joint_world(rig, "bip01 %s hand" % side)
	var pelvis := joint_world(rig, "bip01 pelvis")
	var shoulder := joint_world(rig, "bip01 neck")
	var torso := Geometry3D.get_closest_point_to_segment(wrist, pelvis, shoulder)
	var away := (wrist - torso).normalized()
	var above := (away + Vector3.UP * .34).normalized()
	return fallback if above.is_zero_approx() else above


static func verify_body_keys(player: AnimationPlayer, source: String) -> void:
	var original := (load(source) as PackedScene).instantiate()
	var prior := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name: String in prior.get_animation_list():
		var before := prior.get_animation(name)
		var after := player.get_animation(name)
		assert(before.length == after.length and before.get_track_count() + 2 == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
		for track in range(before.get_track_count(), after.get_track_count()):
			assert(str(after.track_get_path(track).get_concatenated_subnames()) in CrystalShell.BladeJoint.values())
	original.free()
