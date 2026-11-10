# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/orc-captain-black-solen-worker/"
const Captain := {23: "OrcCaptainAxeBraceRise", 28: "OrcCaptainLowAxeAlert"}
const Worker := {12: "BlackSolenRaisedClawPair", 23: "BlackSolenLowUnfold", 26: "BlackSolenAntennaWatch",
	27: "BlackSolenHighClawFeint", 28: "BlackSolenQuietAlert"}
const CaptainLengths := {23: 1.03, 28: .66}
const WorkerLengths := {12: 1.08, 23: 1.12, 26: 1.12, 27: 1.06, 28: .90}
const Upper := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]
const Feet := ["bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const LegPairs := ["lf", "lm", "lr", "rf", "rm", "rr"]
const AxeBone := "orc captain axe"


func run() -> void:
	var captain_joints := ["bip01 pelvis", "bip01 spine3", AxeBone] + Upper + Feet
	prepare_body(7, Captain, CaptainLengths, captain_joints, pose_captain, Destination)
	var worker_joints := ["bip01 pelvis", "bip01 tail1", "antenna l", "antenna r", "mandible l", "mandible r"] + Upper
	for leg: String in LegPairs:
		worker_joints.append("legbone %s1" % leg)
		worker_joints.append("legbone %s2" % leg)
	prepare_body(805, Worker, WorkerLengths, worker_joints, pose_worker, Destination)
	quit()


func pose_captain(rig: Skeleton3D, phase: float, group: int) -> void:
	var rising := group == 23
	var crouch := 1.0 - smoothstep(.12, .93, phase) if rising else .22 + .34 * smoothstep(.05, .87, phase)
	var guard := .83 * crouch if rising else smoothstep(.15, .77, phase)
	var gaze := -.22 * guard + .11 * sin(PI * phase)
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		if side == "r" and not rising:
			var step := smoothstep(.31, .75, phase)
			foot.origin += rig.global_basis.inverse() * Vector3(-.11 * step, .078 * sin(PI * step), .15 * step)
		feet.append(foot)
	var pelvis := rig.find_bone(RootJoint)
	var pose := rig.get_bone_global_pose(pelvis)
	pose.origin += rig.global_basis.inverse() * Vector3(-.07 * guard, -.64 * crouch, -.09 * crouch)
	rig.set_bone_global_pose(pelvis, pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .23 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .42 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.UP, .18 * gaze)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.30 * crouch)
	turn_world(rig, "bip01 head", Vector3.UP, gaze)
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip01 spine1")
	var wrist := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	var aim := chest + Vector3(-.51, -.40, .47)
	if not rising:
		aim += Vector3(-.10, .015, .14) * smoothstep(.39, .82, phase)
	fit_arm(rig, "r", wrist.lerp(aim, maxf(guard, .72 * crouch)))
	fit_arm(rig, "l", left.lerp(chest + Vector3(.36, -.30, .36), .75 * crouch + .15 * guard))
	var neutral := Vector3(-.37, -.34, .85).normalized()
	var braced := Vector3(-.83, .20, .55).normalized()
	if rising:
		braced = Vector3(-.42, .19, .89).normalized()
	point_captain_axe(rig, neutral.slerp(braced, guard))


func point_captain_axe(rig: Skeleton3D, direction: Vector3) -> void:
	var axe := rig.find_bone(AxeBone)
	var parent := rig.get_bone_parent(axe)
	var basis := rig.global_basis * rig.get_bone_global_pose(parent).basis
	rig.set_bone_pose_rotation(axe, Quaternion(Vector3.UP, (basis.inverse() * direction).normalized()))
	rig.force_update_all_bone_transforms()


func pose_worker(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var raise_claws := 0.0
	var splay := 0.0
	var scan := 0.0
	var reach := 0.0
	match group:
		12:
			raise_claws = envelope(phase, .08, .34, .61, .95)
			reach = .56 * envelope(phase, .53, .71, .84, 1.0)
			fold = .17 * reach
		23:
			fold = 1.0 - smoothstep(.25, .86, phase)
			reach = .33 * envelope(phase, .11, .46, .73, .98)
		26:
			scan = .35 * sin(TAU * phase) * sin(PI * phase)
			raise_claws = .24 * envelope(phase, .05, .34, .63, .97)
		27:
			raise_claws = .77 * envelope(phase, .12, .49, .61, .98)
			splay = .62 * raise_claws
			scan = -.20 * sin(PI * phase)
		28:
			scan = -.17 * smoothstep(.08, .73, phase)
			reach = .28 * smoothstep(.11, .82, phase)
			fold = .12 * reach
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .60 * fold - .34 * raise_claws + .22 * reach)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .33 * fold - .24 * raise_claws)
	turn_world(rig, "bip01 spine2", Vector3.UP, .52 * scan)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.29 * fold)
	turn_world(rig, "bip01 head", Vector3.UP, .62 * scan)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.23 * fold + .11 * raise_claws)
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var high := head + Vector3(sign_x * (.38 + .41 * splay), .53 + .19 * sign_x * scan, .28)
		var low := chest + Vector3(sign_x * .32, -.44, .60)
		var forward := chest + Vector3(sign_x * .47, -.06, .74)
		hand = hand.lerp(low, fold).lerp(high, raise_claws).lerp(forward, reach)
		fit_arm(rig, side, hand)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, sign_x * (.39 * raise_claws - .22 * fold))
		turn_world(rig, "antenna " + side, Vector3.UP, .55 * scan + sign_x * .13 * raise_claws)
		turn_world(rig, "mandible " + side, Vector3.UP, sign_x * (.31 * raise_claws + .22 * reach))
	for leg: String in LegPairs:
		var side := 1.0 if leg.begins_with("l") else -1.0
		turn_world(rig, "legbone %s1" % leg, Vector3.BACK, side * (.09 * fold - .10 * splay))
		turn_world(rig, "legbone %s2" % leg, Vector3.BACK, side * (-.13 * fold + .08 * splay))
