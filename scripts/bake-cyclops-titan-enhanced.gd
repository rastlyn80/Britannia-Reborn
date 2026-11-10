# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/cyclops-titan/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Clips := {
	75: {4: "CyclopsOverheadMallet", 23: "CyclopsRiseWithMallet", 26: "CyclopsPalmGlance",
		27: "CyclopsRaisedMallet", 28: "CyclopsForwardGuard"},
	76: {4: "TitanOverheadHammerfist", 23: "TitanWideRise", 26: "TitanShoulderShift",
		27: "TitanRaisedFists", 28: "TitanShoulderAlert"},
}
const Durations := {4: 1.13, 23: 1.19, 26: 1.25, 27: .88, 28: .82}
const GiantJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	for body: int in Clips:
		var row := Registry.entry(body)
		for treatment: String in Profile.registered_assets(row):
			var source := Registry.asset_path(row, treatment)
			assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
			player.remove_animation_library("")
			player.add_animation_library("", library)
			var skins: Array[Dictionary] = [Ground.skin_points(model.find_child("Body", true, false), rig)]
			var joints := GiantJoints.duplicate()
			if body == 75:
				joints.append("cyclopsmallet")
				skins.append(Ground.skin_points(model.find_child("CyclopsMallet", true, false), rig))
			for group: int in Clips[body]:
				var clip := fit_grounded(player, rig, skins, Durations[group], "bip01", joints, pose_giant.bind(body, group), .008)
				assert(library.add_animation(Clips[body][group], clip) == OK)
			verify_base_clips(player, source)
			player.stop()
			rig.reset_bone_poses()
			var packed := PackedScene.new()
			assert(packed.pack(model) == OK)
			assert(ResourceSaver.save(packed, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
			model.free()
			print("CYCLOPS AND TITAN ", body, "/", treatment, ": five fitted motions; retained keys verified")
	quit()


func envelope(phase: float, start: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, end, phase))


func pose_giant(rig: Skeleton3D, phase: float, body: int, group: int) -> void:
	var cyclops := body == 75
	var draw := 0.0
	var swing := 0.0
	var dip := 0.0
	var brace := 0.0
	var glance := 0.0
	var twist := 0.0
	match group:
		4:
			draw = envelope(phase, .04, .34, .39, .68)
			swing = envelope(phase, .38, .70, .75, 1.0)
			dip = .94 * swing
			twist = -.40 * draw + .55 * swing
		23:
			dip = 1.0 - smoothstep(.05, .82, phase)
			brace = .32 * envelope(phase, .25, .62, .72, 1.0)
			twist = -.24 * dip
		26:
			glance = envelope(phase, .10, .43, .64, .96)
			twist = .18 * glance + .07 * sin(TAU * phase)
			dip = .14 * glance
		27:
			draw = .88 * envelope(phase, .06, .57, .78, 1.0)
			brace = .74 * envelope(phase, .14, .50, .76, 1.0)
			twist = -.42 * draw
		28:
			brace = .79 * smoothstep(.09, .65, phase)
			dip = .28 * brace
			twist = .25 * brace - (.17 * sin(TAU * phase) if not cyclops else 0.0)

	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var feet := stance(rig, phase, group, cyclops)
	var root_bone := rig.find_bone("bip01")
	var hips := rig.get_bone_global_pose(root_bone)
	hips.origin += rig.global_basis.inverse() * Vector3(.13 * twist, -.52 * dip + .06 * draw, .31 * swing - .11 * draw)
	rig.set_bone_global_pose(root_bone, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 pelvis", Vector3.UP, .55 * twist)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .44 * dip - .15 * draw)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .40 * dip)
	turn_world(rig, "bip01 spine2", Vector3.UP, .82 * twist)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .19 * dip)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.21 * dip + .12 * glance)
	turn_world(rig, "bip01 head", Vector3.UP, .40 * glance - .28 * twist)
	turn_world(rig, "bip01 l clavicle", Vector3.FORWARD, .09 * brace)
	turn_world(rig, "bip01 r clavicle", Vector3.FORWARD, -.13 * draw)
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip01 spine2")
	right = right.lerp(chest + Vector3(-1.03, .01, .32), dip)
	right = right.lerp(chest + Vector3(-1.13, 1.26, -.23), draw)
	right = right.lerp(chest + Vector3(-1.04, -.72, .78), swing)
	right = right.lerp(chest + Vector3(-1.04, .44, .75), brace * .75)
	left = left.lerp(chest + Vector3(.79, -.28, .70), dip)
	left = left.lerp(chest + Vector3(.78, .32, .69), glance)
	left = left.lerp(chest + (Vector3(.95, .34, .92) if cyclops else Vector3(1.03, 1.06, .53)), brace)
	left = left.lerp(chest + Vector3(.94, .10, .92), .42 * draw + .22 * swing)
	if group == 26:
		fit_arm(rig, "r", right)
		fit_arm(rig, "l", left)
	else:
		fit_giant_arm(rig, "r", right, draw)
		fit_giant_arm(rig, "l", left, .55 * draw)
	if cyclops:
		pose_mallet(rig, draw, swing, dip, brace)
	else:
		turn_world(rig, "bip01 r hand", Vector3.RIGHT, -.20 * draw + .23 * swing)
		turn_world(rig, "bip01 l hand", Vector3.RIGHT, .24 * glance - .25 * brace)


func fit_giant_arm(rig: Skeleton3D, side: String, wrist: Vector3, raised: float) -> void:
	var shoulder := rig.find_bone("bip01 %s upperarm" % side)
	var elbow := rig.find_bone("bip01 %s forearm" % side)
	var hand := rig.find_bone("bip01 %s hand" % side)
	var origin := rig.get_bone_global_pose(shoulder).origin
	var bend := rig.get_bone_global_pose(elbow).origin
	var grip := rig.get_bone_global_pose(hand).origin
	var goal := rig.to_local(wrist)
	var axis := (goal - origin).normalized()
	var upper := origin.distance_to(bend)
	var lower := bend.distance_to(grip)
	var length := clampf(origin.distance_to(goal), absf(upper - lower) + .001, upper + lower - .012)
	var along := (upper * upper - lower * lower + length * length) / (2.0 * length)
	# A stable outboard elbow plane avoids snapping through the upper-arm axis at the top of the swing.
	var sign_x := 1.0 if side == "l" else -1.0
	var preferred := Vector3(sign_x, -.20 + .34 * raised, -.47 + .22 * raised)
	var pole := (rig.global_basis.inverse() * preferred).slide(axis).normalized()
	Arms.aim(rig, shoulder, elbow, origin + axis * along + pole * sqrt(maxf(0.0, upper * upper - along * along)))
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, elbow, hand, origin + axis * length)
	rig.force_update_all_bone_transforms()


func stance(rig: Skeleton3D, phase: float, group: int, cyclops: bool) -> Array[Transform3D]:
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var sign_x := 1.0 if side == "l" else -1.0
		var offset := Vector3(.08 * sign_x, 0, 0)
		if group in [4, 27]:
			var step := smoothstep(.06, .41, phase)
			var reset := smoothstep(.79, 1.0, phase)
			var length := .40 if group == 27 else .27
			if side == "r":
				offset += Vector3(-.12 * (step - reset), .095 * (sin(PI * step) + sin(PI * reset)), -length * (step - reset))
			else:
				offset.z += .11 * sign_x
		elif group == 23:
			offset.x += sign_x * (.16 if not cyclops else .10)
		foot.origin += rig.global_basis.inverse() * offset
		feet.append(foot)
	return feet


func pose_mallet(rig: Skeleton3D, draw: float, swing: float, dip: float, brace: float) -> void:
	var shaft := Vector3(-.48, .72, .49).normalized()
	shaft = shaft.slerp(Vector3(-.53, .82, -.21).normalized(), draw)
	shaft = shaft.slerp(Vector3(-.72, -.12, .68).normalized(), swing)
	shaft = shaft.slerp(Vector3(-.63, .67, .35).normalized(), .36 * dip + .39 * brace)
	var joint := rig.find_bone("cyclopsmallet")
	var pose := rig.get_bone_global_pose(joint)
	var heading := Basis(Quaternion(Vector3.UP, shaft)) * Basis(Vector3.UP, .32 - .39 * draw + .22 * swing)
	pose.basis = rig.global_basis.orthonormalized().inverse() * heading
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()
