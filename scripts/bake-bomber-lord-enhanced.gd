# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/orc-bomber-ogre-lord/"
const Bomber := {4: "OrcBomberCastAndDip", 23: "OrcBomberUnfold", 26: "OrcBomberPalmCheck",
	27: "OrcBomberHighFeint", 28: "OrcBomberForwardGuard"}
const Lord := {4: "OgreLordDownwardClub", 23: "OgreLordCrouchRise", 26: "OgreLordClubCheck",
	27: "OgreLordOverheadGuard", 28: "OgreLordClubLift"}
const BomberLengths := {4: .78, 23: 1.06, 26: .87, 27: .83, 28: .86}
const LordLengths := {4: .84, 23: 1.06, 26: .91, 27: 1.06, 28: .98}
const LimbJoints := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	prepare_body(182, Bomber, BomberLengths, LimbJoints + ["bip01 spine3"], pose_bomber, Destination)
	prepare_body(83, Lord, LordLengths, LimbJoints, pose_lord, Destination)
	quit()


func pose_bomber(rig: Skeleton3D, phase: float, group: int) -> void:
	var bow := 0.0
	var raise := 0.0
	var reach := 0.0
	var turn := 0.0
	var palm := 0.0
	match group:
		4:
			raise = 1.0 - smoothstep(.03, .28, phase)
			reach = envelope(phase, .06, .30, .38, .73)
			bow = .80 * envelope(phase, .12, .46, .62, .96)
			turn = .38 * reach - .28 * raise
		23:
			bow = 1.0 - smoothstep(.08, .85, phase)
			palm = .32 * bow
		26:
			palm = envelope(phase, .02, .29, .67, .97)
			turn = .20 * sin(TAU * phase) * sin(PI * phase)
		27:
			raise = .77 * envelope(phase, .04, .27, .36, .59)
			reach = .68 * envelope(phase, .25, .57, .73, .97)
			bow = .62 * reach
			turn = .25 * reach - .21 * raise
		28:
			palm = .82 * smoothstep(.08, .67, phase)
			reach = .45 * smoothstep(.17, .76, phase)
			turn = -.22 * palm
	pose_weight(rig, bow, turn, .24)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .27 * bow - .13 * raise)
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	var right_high := head + Vector3(-.48, .49, .03)
	var right_forward := chest + Vector3(-.42, .02, .74)
	var left_low := chest + Vector3(.35, -.39, .51)
	var left_check := head + Vector3(.31, -.20, .50)
	fit_arm(rig, "r", right.lerp(chest + Vector3(-.40, -.47, .39), .65 * bow).lerp(right_high, raise).lerp(right_forward, reach))
	fit_arm(rig, "l", left.lerp(left_low, .61 * bow + .21 * reach).lerp(left_check, palm))
	turn_world(rig, "bip01 l hand", Vector3.BACK, -.42 * palm)
	turn_world(rig, "bip01 r hand", Vector3.UP, -.23 * reach)


func pose_lord(rig: Skeleton3D, phase: float, group: int) -> void:
	var bow := 0.0
	var high := 0.0
	var drive := 0.0
	var turn := 0.0
	var check := 0.0
	match group:
		4:
			high = envelope(phase, .02, .26, .31, .52)
			drive = envelope(phase, .24, .51, .63, .93)
			bow = .90 * drive
			turn = .38 * drive - .45 * high
		23:
			bow = 1.0 - smoothstep(.03, .83, phase)
			check = .74 * bow
		26:
			check = .78 + .18 * sin(TAU * phase) * sin(PI * phase)
			bow = .20 * check
		27:
			high = .88 - .48 * envelope(phase, .10, .40, .67, .96)
			drive = .30 * envelope(phase, .24, .51, .74, .92)
			turn = .27 * sin(TAU * phase) * sin(PI * phase)
		28:
			high = .84 * smoothstep(.06, .88, phase)
			drive = .25 * (1.0 - high)
			turn = -.27 * high
	pose_weight(rig, bow, turn, .28)
	var head := joint_world(rig, "bip01 head")
	var chest := joint_world(rig, "bip01 spine2")
	var hip := joint_world(rig, RootJoint)
	turn_world(rig, "bip01 r upperarm", Vector3.BACK, -.26)
	turn_world(rig, "bip01 l upperarm", Vector3.BACK, .18)
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	var club_low := hip + Vector3(-.95, -.15, .77)
	var club_high := head + Vector3(-.90, .56, .15)
	var club_check := chest + Vector3(-.96, -.42, .53)
	fit_arm(rig, "r", right.lerp(club_check, check).lerp(club_high, high).lerp(club_low, drive))
	fit_arm(rig, "l", left.lerp(chest + Vector3(.93, -.37, .56), .38 * bow + .31 * high + .28 * drive))
	turn_world(rig, "bip01 r hand", Vector3.BACK, -.34 * high + .38 * drive)
	turn_world(rig, "bip01 r hand", Vector3.UP, .24 * check - .20 * drive)


func pose_weight(rig: Skeleton3D, bow: float, turn: float, drop: float) -> void:
	var left := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
	var right := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
	var pelvis := rig.find_bone(RootJoint)
	var pose := rig.get_bone_global_pose(pelvis)
	pose.origin += rig.global_basis.inverse() * Vector3(.09 * turn, -drop * bow, -.12 * bow)
	rig.set_bone_global_pose(pelvis, pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .31 * bow)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .37 * bow)
	turn_world(rig, "bip01 spine1", Vector3.UP, .52 * turn)
	turn_world(rig, "bip01 spine2", Vector3.UP, .63 * turn)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.28 * bow)
	turn_world(rig, "bip01 head", Vector3.UP, -.25 * turn)
	fit_foot(rig, "l", left)
	fit_foot(rig, "r", right)

