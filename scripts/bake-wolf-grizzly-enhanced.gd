# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-brown-bear-cougar-enhanced.gd"

const WolfGrizzlyFolder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/wolf-grizzly/"
const WolfClips := {4: "GreyWolfSnap", 15: "GreyWolfLowRecoil", 25: "GreyWolfQuietStand",
	26: "GreyWolfScentWatch", 27: "GreyWolfHowl", 28: "GreyWolfEarAlert"}
const WolfLengths := {4: .65, 15: .70, 25: .90, 26: 1.05, 27: 1.10, 28: .60}
const GrizzlyClips := {4: "GrizzlyHighSwipe", 15: "GrizzlyUprightWarning", 23: "GrizzlyWakeAndRise",
	25: "GrizzlyQuietStand", 26: "GrizzlyScentTurn", 27: "GrizzlyRaisedGuard", 28: "GrizzlyRearAlert"}

func run() -> void:
	var lengths := BearLengths.duplicate()
	lengths[23] = .99
	prepare_body(212, GrizzlyClips, lengths, CommonJoints + ["bip01 spine2", "box01",
		"bip01 l horselink", "bip01 r horselink"], pose_brown_bear, WolfGrizzlyFolder)
	prepare_body(25, WolfClips, WolfLengths, CommonJoints + ["bip01 neck1", "bip01 jaw", "bip01 tail1", "bip01 tail2"],
		pose_wolf, WolfGrizzlyFolder)
	quit()

func pose_wolf(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var rise := 0.0
	var gaze := 0.0
	var yaw := 0.0
	var ears := 0.0
	var jaw := 0.0
	var reach := 0.0
	var tail := 0.0
	match group:
		4:
			var snap := envelope(phase, .07, .32, .40, .59)
			crouch = .37 * (1.0 - snap)
			rise = .60 * snap
			gaze = -.24 * snap
			jaw = .57 * snap
			reach = .36 * (1.0 - snap)
			tail = .59 * snap
		15:
			var straighten := envelope(phase, .23, .63, .79, 1.0)
			crouch = .84 - .62 * straighten
			rise = .18 * straighten
			gaze = .25 * crouch - .24 * straighten
			reach = .50 * crouch
		25:
			gaze = .022 * sin(TAU * phase)
			tail = .04 * sin(TAU * phase)
		26:
			var scent := envelope(phase, .05, .36, .63, .84)
			crouch = .16 * scent
			gaze = .32 * scent - .18 * envelope(phase, .65, .83, .91, 1.0)
			yaw = .22 * sin(TAU * phase) * sin(PI * phase)
			ears = .18 * scent
		27:
			var howl := envelope(phase, .13, .32, .69, .95)
			crouch = .34 * envelope(phase, 0.0, .12, .19, .31)
			rise = .19 * howl
			gaze = -.71 * howl
			jaw = .29 * howl + .05 * sin(TAU * phase * 2.0) * howl
			ears = .34 * howl
		28:
			gaze = -.09 * envelope(phase, .0, .43, .62, 1.0)
			ears = -.25 * sin(PI * phase)
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.43 * rise + .14 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.26 * rise + .26 * crouch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .18 * rise + .40 * gaze)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .26 * gaze)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .36 * gaze)
	turn_world(rig, "bip01 head", Vector3.UP, yaw)
	turn_world(rig, "bip01 jaw", Vector3.RIGHT, jaw)
	turn_world(rig, "bip01 ponytail1", Vector3.BACK, ears)
	turn_world(rig, "bip01 ponytail2", Vector3.BACK, -ears)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.29 * crouch + .46 * tail)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .40 * tail)
	turn_world(rig, "bip01 tail2", Vector3.UP, .26 * yaw)
	for side: String in ["l", "r"]:
		var fore_reach := reach if side == "l" else reach * .25
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.44 * crouch - .66 * fore_reach + .30 * rise)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .65 * crouch - .30 * fore_reach + .68 * rise)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, -.18 * crouch + .18 * fore_reach)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .25 * rise - .43 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.22 * rise + .47 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .11 * rise + .16 * crouch)
	anchor_hind_paws(rig, anchor)
