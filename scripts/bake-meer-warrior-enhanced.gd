# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/meer-warrior-enhanced/"
const Clips := {4: "MeerWarriorSweepingJab", 5: "MeerWarriorRisingStrike", 6: "MeerWarriorPivotingBackhand",
	15: "MeerWarriorBracedGuard", 25: "MeerWarriorQuietStand", 26: "MeerWarriorHipCheck"}
const Durations := {4: .67, 5: .63, 6: .61, 15: .50, 25: .90, 26: .77}
const MeerJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm",
	"bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 l thigh", "bip01 r thigh", "bip01 l calf",
	"bip01 r calf", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	prepare_body(771, Clips, Durations, MeerJoints, pose_meer, Destination, configure_motion)
	quit()


func configure_motion(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_meer(rig: Skeleton3D, phase: float, group: int) -> void:
	var wind := 0.0
	var strike := 0.0
	var high := 0.0
	var guard := 0.0
	var stance := 0.0
	var hips := 0.0
	var glance := 0.0
	var lead := 1.0
	match group:
		4:
			wind = .89 * envelope(phase, .02, .24, .34, .61)
			strike = 1.0 * envelope(phase, .27, .58, .68, .99)
			stance = .52 * envelope(phase, .05, .35, .71, .99)
		5:
			wind = .36 * envelope(phase, .04, .20, .31, .51)
			strike = .74 * envelope(phase, .20, .45, .62, .98)
			high = .93 * strike
			stance = .61 * envelope(phase, .07, .34, .66, .98)
			lead = -1.0
		6:
			wind = .53 * envelope(phase, .04, .22, .39, .62)
			strike = .75 * envelope(phase, .20, .54, .66, .99)
			stance = .43 * envelope(phase, .06, .33, .68, .99)
			glance = .36 * strike
			lead = -1.0
		15:
			guard = .77 * envelope(phase, .05, .35, .61, .97)
			stance = .40 * guard
			glance = -.22 * guard
		25:
			hips = .018 * (1.0 - cos(TAU * phase))
			glance = .032 * sin(TAU * phase)
		26:
			hips = .80 * envelope(phase, .06, .33, .68, .96)
			glance = .40 * sin(TAU * phase) * hips
	var feet := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.UP, lead * (.30 * wind - .36 * strike))
	turn_world(rig, RootJoint, Vector3.RIGHT, .12 * stance - .06 * high)
	turn_world(rig, "bip01 spine2", Vector3.UP, lead * (.44 * wind - .56 * strike) + .13 * glance)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .20 * strike + .16 * guard - .18 * high)
	turn_world(rig, "bip01 head", Vector3.UP, glance + lead * (.18 * strike - .15 * wind))
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.11 * strike + .10 * high)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var weight := 1.0 if is_equal_approx(sign_x, lead) else .38
		var outward := .35 * wind + .33 * guard + .41 * hips
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * outward)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT,
			weight * (.60 * wind - .83 * strike - .85 * high) - .40 * guard + .31 * hips)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.61 * guard - .51 * hips + weight * (.21 * strike - .47 * wind))
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.19 * hips + .20 * guard))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.BACK, sign_x * .48 * stance)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -sign_x * lead * .49 * stance - .28 * guard)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .36 * stance + .36 * guard)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.23 * stance - .14 * guard)
	anchor_hind_paws(rig, feet)
