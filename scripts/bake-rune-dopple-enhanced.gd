# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/rune-beetle-doppleganger/"
const Rune := {1: "RuneBeetleQuietGuard", 25: "RuneBeetlePeaceWatch", 26: "RuneBeetleCrestDip",
	27: "RuneBeetleScarletCrest", 28: "RuneBeetleGuardAlert"}
const Dopple := {12: "DopplegangerCrossedSweep", 23: "DopplegangerFormRise", 26: "DopplegangerLowWatch",
	27: "DopplegangerHighGuard", 28: "DopplegangerStepAlert"}
const RuneLengths := {1: .95, 25: .92, 26: 1.03, 27: .97, 28: .72}
const DoppleLengths := {12: 1.02, 23: 1.19, 26: 1.11, 27: .92, 28: .74}
const BodyJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head"]
const PairArms := ["bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]
const PairLegs := ["bip01 l thigh", "bip01 l calf", "bip01 l foot",
	"bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	prepare_body(244, Rune, RuneLengths, BodyJoints + PairArms + PairLegs + ["bone01", "bone02"], pose_rune, Destination)
	prepare_body(777, Dopple, DoppleLengths, BodyJoints + PairArms + PairLegs + ["bip01 spine2"],
		pose_dopple, Destination, bake_dopple_growth)
	quit()


func pose_rune(rig: Skeleton3D, phase: float, group: int) -> void:
	var pitch := 0.0
	var twist := 0.0
	var spread := 0.0
	var crest := 0.0
	var effort := sin(PI * phase)
	match group:
		1:
			pitch = .04 * effort
			twist = .06 * sin(TAU * phase)
		25:
			pitch = -.11 * effort
			spread = .05 * effort
		26:
			pitch = .18 * envelope(phase, .09, .45, .58, .97)
			twist = .13 * effort * sin(TAU * phase)
			crest = .22 * effort
		27:
			crest = .77 * (envelope(phase, .04, .23, .32, .51) + envelope(phase, .53, .81, .90, 1.0))
			spread = .18 * effort
			pitch = -.13 * crest
		28:
			spread = .20 * smoothstep(.13, .77, phase)
			pitch = .12 * smoothstep(.05, .73, phase)
			twist = -.14 * effort
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .32 * pitch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .56 * pitch)
	turn_world(rig, "bip01 head", Vector3.UP, twist)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.23 * pitch)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bone02" if side == "l" else "bone01", Vector3.RIGHT, -crest)
		turn_world(rig, "bone02" if side == "l" else "bone01", Vector3.UP, sign_x * (.90 * crest + .24 * spread))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.UP, sign_x * spread)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .14 * pitch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.23 * pitch)


func form_scale(phase: float) -> Vector3:
	return Vector3.ONE * lerpf(.045, 1.0, smoothstep(.08, .67, phase))


func bake_dopple_growth(motion: Animation, rig: Skeleton3D, group: int) -> void:
	if group != 23:
		return
	var rig_path: NodePath
	for track in motion.get_track_count():
		if motion.track_get_path(track).get_concatenated_subnames() == RootJoint:
			rig_path = NodePath(str(motion.track_get_path(track).get_concatenated_names()) + ":__root")
			break
	assert(not rig_path.is_empty() and rig.find_bone("__root") >= 0)
	var channel := motion.find_track(rig_path, Animation.TYPE_SCALE_3D)
	if channel < 0:
		channel = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(channel, rig_path)
	else:
		motion.track_remove_key(channel, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		motion.scale_track_insert_key(channel, phase * motion.length, form_scale(phase))


func pose_dopple(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var raise := 0.0
	var reach := 0.0
	var turn := 0.0
	var step := 0.0
	match group:
		12:
			raise = .79 * envelope(phase, .06, .34, .48, .88)
			reach = .62 * envelope(phase, .29, .61, .77, .99)
			step = .48 * reach
			turn = -.38 * raise + .32 * reach
		23:
			rig.set_bone_pose_scale(rig.find_bone("__root"), form_scale(phase))
			rig.force_update_all_bone_transforms()
			fold = 1.0 - smoothstep(.11, .73, phase)
			raise = .84 * envelope(phase, .25, .47, .63, .91)
			reach = .29 * envelope(phase, .29, .63, .79, .98)
		26:
			reach = .38 + .19 * sin(TAU * phase) * sin(PI * phase)
			turn = .19 * sin(TAU * phase) * sin(PI * phase)
		27:
			raise = .73 + .16 * sin(TAU * phase) * sin(PI * phase)
			fold = .24
			step = .32 * raise
			turn = .29 * raise
		28:
			step = .79 * smoothstep(.08, .83, phase)
			reach = .72 * smoothstep(.19, .81, phase)
			turn = -.25 * reach
	var left_foot := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
	var right_foot := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
	left_foot.origin += rig.global_basis.inverse() * Vector3(.14 * step, .12 * sin(PI * step), .39 * step)
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.07 * turn, -.38 * fold, .10 * step)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .41 * fold)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .42 * fold - .17 * raise)
	turn_world(rig, "bip01 spine2", Vector3.UP, .79 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.24 * fold)
	turn_world(rig, "bip01 head", Vector3.UP, -.41 * turn)
	fit_foot(rig, "l", left_foot)
	fit_foot(rig, "r", right_foot)
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	fit_arm(rig, "r", right.lerp(chest + Vector3(-.46, -.61, .52), .71 * fold)
		.lerp(head + Vector3(-.49, .36, .31), raise).lerp(chest + Vector3(-.48, -.24, .94), reach))
	fit_arm(rig, "l", left.lerp(chest + Vector3(.46, -.54, .44), .73 * fold)
		.lerp(chest + Vector3(.53, -.11, .96), .78 * reach))
	turn_world(rig, "bip01 r hand", Vector3.BACK, -.21 * raise)
	turn_world(rig, "bip01 l hand", Vector3.BACK, .17 * reach)
