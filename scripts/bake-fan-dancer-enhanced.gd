# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/skittering-hopper-fan-dancer/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Clips := {4: "FanDancerSteppingSweep", 23: "FanDancerTurningRise", 26: "FanDancerFanScreen",
	27: "FanDancerRearStepFlourish", 28: "FanDancerCrossedAlert"}
const Lengths := {4: .98, 23: 1.32, 26: 1.14, 27: 1.26, 28: 1.13}
const FanJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "r_cuff_bone", "l_cuff_bone",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	var row := Registry.entry(247)
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
		for group: int in Clips:
			var clip := fit_grounded(player, rig, skins, Lengths[group], "bip01", FanJoints, pose_dancer.bind(group), .005)
			assert(library.add_animation(Clips[group], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "247-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("FAN DANCER ", treatment, ": five fitted motions with original fans and retained keys")
	quit()


func pulse(phase: float, start: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, end, phase))


func pose_dancer(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var right_high := 0.0
	var left_high := 0.0
	var right_low := 0.0
	var left_low := 0.0
	var twist := 0.0
	var brace := 0.0
	var step := 0.0
	match group:
		4:
			right_high = pulse(phase, .02, .19, .23, .44)
			left_high = .82 * smoothstep(.35, .68, phase)
			right_low = .86 * smoothstep(.28, .59, phase)
			dip = .52 * pulse(phase, .29, .52, .74, 1.0)
			step = pulse(phase, .05, .40, .69, .98)
			twist = .52 * right_high - .68 * left_high
		23:
			dip = .79 * (1.0 - smoothstep(.05, .79, phase))
			right_low = .71 * dip
			left_high = .92 * pulse(phase, .10, .47, .68, .95)
			right_high = .45 * smoothstep(.58, .91, phase)
			step = pulse(phase, .10, .38, .54, .88)
			twist = -.55 * left_high + .36 * right_high
		26:
			brace = .70 + .07 * sin(TAU * phase)
			twist = .08 * sin(TAU * phase)
			dip = .06
		27:
			right_high = .84 * pulse(phase, .12, .49, .64, .94)
			left_low = .78 * pulse(phase, .02, .41, .66, .98)
			left_high = .38 * pulse(phase, .28, .57, .70, .93)
			step = .78 * pulse(phase, .12, .49, .74, 1.0)
			twist = .66 * right_high
		28:
			brace = .67 * (1.0 - smoothstep(.10, .28, phase))
			right_high = pulse(phase, .13, .53, .63, .91)
			left_high = .79 * pulse(phase, .28, .61, .72, .96)
			dip = .64 * smoothstep(.64, .95, phase)
			right_low = .55 * dip
			left_low = .48 * dip
			step = .48 * pulse(phase, .22, .60, .80, 1.0)
			twist = .65 * right_high - .47 * left_high
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var offset := Vector3(.045, 0.0, .065) if side == "l" else Vector3(-.14, .23, -.27) * step
		foot.origin += rig.global_basis.inverse() * offset
		feet.append(foot)
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var root_bone := rig.find_bone("bip01")
	var hips := rig.get_bone_global_pose(root_bone)
	hips.origin += rig.global_basis.inverse() * Vector3(.11 * step, -.31 * dip + .025 * step, .12 * dip)
	rig.set_bone_global_pose(root_bone, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 pelvis", Vector3.UP, .35 * twist)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .32 * dip - .12 * step)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .41 * dip)
	turn_world(rig, "bip01 spine1", Vector3.UP, .69 * twist)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.20 * dip)
	turn_world(rig, "bip01 head", Vector3.UP, -.20 * twist)
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip01 spine1")
	right = right.lerp(chest + Vector3(-.29, .51, .31), right_high).lerp(chest + Vector3(-.52, -.31, .29), right_low)
	left = left.lerp(chest + Vector3(.47, .45, .28), left_high).lerp(chest + Vector3(.49, -.31, .39), left_low)
	right = right.lerp(chest + Vector3(-.14, -.06, .48), brace)
	left = left.lerp(chest + Vector3(.21, .11, .51), brace)
	fit_arm(rig, "r", right)
	fit_arm(rig, "l", left)
	turn_world(rig, "bip01 r hand", Vector3.BACK, -.44 * right_high + .61 * right_low - .17 * brace)
	turn_world(rig, "bip01 l hand", Vector3.BACK, .46 * left_high - .62 * left_low + .20 * brace)
	turn_world(rig, "r_cuff_bone", Vector3.RIGHT, -.17 * right_high + .22 * right_low)
	turn_world(rig, "l_cuff_bone", Vector3.RIGHT, -.19 * left_high + .22 * left_low)
