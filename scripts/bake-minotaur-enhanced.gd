# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/minotaur-enhanced/"
const Body := 263
const Clips := {4: "MinotaurHornHook", 11: "MinotaurLowFeint", 15: "MinotaurHighWard",
	23: "MinotaurCrouchingRise", 25: "MinotaurQuietStand", 26: "MinotaurScentTurn",
	27: "MinotaurWideThreat", 28: "MinotaurForwardGuard"}
const Durations := {4: .91, 11: .77, 15: .65, 23: 1.12, 25: 1.13, 26: 1.02, 27: .99, 28: .75}
const MinotaurJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l hand", "bip01 r hand", "bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf",
	"bip01 l horselink", "bip01 r horselink", "bip01 l foot", "bip01 r foot", "bip01 tail", "bip01 tail1", "bip01 tail2"]


func run() -> void:
	prepare_body(Body, Clips, Durations, MinotaurJoints, pose_minotaur, Destination, configure_motion)
	quit()


func configure_motion(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_minotaur(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var bow := 0.0
	var turn := 0.0
	var raise := 0.0
	var open := 0.0
	var punch := 0.0
	var reach := 0.0
	match group:
		4:
			var windup := envelope(phase, .02, .26, .36, .59)
			var strike := envelope(phase, .29, .49, .60, .90)
			turn = -.42 * windup + .49 * strike
			crouch = .25 * windup
			raise = .77 * windup
			punch = .86 * strike
			reach = .18 * strike
			bow = .28 * strike
		11:
			var hunch := envelope(phase, .10, .45, .59, .97)
			crouch = .43 * hunch
			bow = .52 * hunch
			open = .15 * hunch
			reach = .29 * hunch
		15:
			var ward := envelope(phase, .03, .31, .58, .95)
			raise = .91 * ward
			open = .24 * ward
			bow = -.15 * ward
			turn = -.13 * ward
		23:
			crouch = .93 * (1.0 - smoothstep(.16, .92, phase))
			bow = .48 * crouch
			raise = .71 * envelope(phase, .33, .60, .72, .96)
			open = .28 * raise
		25:
			bow = .024 * sin(TAU * phase)
			open = .022 * (1.0 - cos(TAU * phase))
			turn = .032 * sin(TAU * phase)
		26:
			var sniff := envelope(phase, .08, .36, .64, .97)
			bow = .18 * sniff
			turn = .23 * sin(TAU * phase) * sniff
			reach = .14 * sniff
		27:
			var threat := envelope(phase, .05, .40, .61, .97)
			open = .70 * threat
			bow = .29 * threat
			reach = .41 * threat
			crouch = .16 * threat
		28:
			var guard := smoothstep(.11, .80, phase)
			open = .23 * guard
			reach = .58 * guard
			crouch = .29 * guard
			turn = -.24 * guard
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .14 * bow - .13 * crouch)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .21 * bow + .23 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .21 * bow + .14 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.UP, .44 * turn)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.21 * crouch + .12 * bow)
	turn_world(rig, "bip01 head", Vector3.UP, .44 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.24 * bow)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var striking := punch if side == "r" else .20 * punch
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.UP, .24 * turn)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.78 * raise - .68 * reach - .93 * striking)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.52 * open + .24 * raise))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.59 * raise - .36 * reach + .51 * striking)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.18 * open - .12 * reach))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.46 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .69 * crouch)
		turn_world(rig, "bip01 %s horselink" % side, Vector3.RIGHT, -.20 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.08 * crouch)
	turn_world(rig, "bip01 tail", Vector3.UP, -.27 * turn)
	turn_world(rig, "bip01 tail1", Vector3.UP, .15 * sin(TAU * phase))
	turn_world(rig, "bip01 tail2", Vector3.UP, .11 * sin(TAU * phase - .35))
	anchor_hind_paws(rig, anchor)
