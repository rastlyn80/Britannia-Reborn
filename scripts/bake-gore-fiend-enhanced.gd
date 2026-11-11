# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/gore-fiend-enhanced/"
const Body := 305
const Clips := {11: "GoreFiendLowFeint", 12: "GoreFiendRaisedClaws", 15: "GoreFiendCurlGuard",
	23: "GoreFiendUncoil", 25: "GoreFiendQuietHunch", 26: "GoreFiendScentDip",
	27: "GoreFiendNeckThreat", 28: "GoreFiendLowReach"}
const Durations := {11: .83, 12: .93, 15: .66, 23: 1.16, 25: 1.12, 26: .99, 27: .92, 28: .77}
const GoreJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3",
	"bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3", "bip01 neck4", "bip01 head",
	"bip01 bone jaw2", "bip01 bone ear1", "bip01 bone ear2", "bip01 bone ear3", "bip01 bone ear4",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	prepare_body(Body, Clips, Durations, GoreJoints, pose_gore, Destination, configure_motion)
	quit()


func configure_motion(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_gore(rig: Skeleton3D, phase: float, group: int) -> void:
	var curl := 0.0
	var bend := 0.0
	var raise := 0.0
	var twist := 0.0
	var reach := 0.0
	var spread := 0.0
	var jaw := 0.0
	match group:
		11:
			var feint := envelope(phase, .03, .35, .53, .95)
			bend = .45 * feint
			twist = .29 * feint
			reach = .29 * feint
		12:
			var display := envelope(phase, .07, .43, .62, .97)
			raise = .66 * display
			reach = .64 * display
			spread = .36 * display
			jaw = .36 * display
			twist = -.16 * display
		15:
			var guard := envelope(phase, .04, .31, .57, .96)
			curl = .40 * guard
			bend = .18 * guard
			raise = .13 * guard
			spread = .22 * guard
		23:
			curl = .83 * (1.0 - smoothstep(.19, .93, phase))
			bend = .23 * curl
			reach = .30 * envelope(phase, .38, .61, .75, .98)
			jaw = .17 * reach
		25:
			bend = .027 * sin(TAU * phase)
			twist = .029 * sin(TAU * phase)
			curl = .026 * (1.0 - cos(TAU * phase))
		26:
			var sniff := envelope(phase, .07, .34, .65, .97)
			bend = .31 * sniff
			twist = .27 * sin(TAU * phase) * sniff
			spread = .15 * sniff
		27:
			var threat := envelope(phase, .08, .39, .63, .98)
			raise = .47 * threat
			spread = .40 * threat
			jaw = .49 * threat
			reach = .23 * threat
		28:
			var guard := smoothstep(.11, .82, phase)
			curl = .23 * guard
			bend = .27 * guard
			reach = .46 * guard
			twist = -.21 * guard
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .14 * curl - .09 * raise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .28 * curl + .21 * bend - .18 * raise)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .20 * curl + .21 * bend - .20 * raise)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .37 * curl + .18 * bend - .21 * raise)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, -.13 * curl - .22 * raise)
	turn_world(rig, "bip01 neck3", Vector3.RIGHT, -.24 * curl - .19 * raise)
	turn_world(rig, "bip01 neck4", Vector3.RIGHT, -.20 * curl + .14 * bend)
	turn_world(rig, "bip01 neck3", Vector3.UP, .45 * twist)
	turn_world(rig, "bip01 head", Vector3.UP, .47 * twist)
	turn_world(rig, "bip01 bone jaw2", Vector3.RIGHT, jaw)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.69 * reach - .42 * raise + .20 * curl)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * .43 * spread)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.44 * reach + .29 * raise)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * .18 * spread)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.31 * curl)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .46 * curl)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.13 * curl)
	turn_world(rig, "bip01 bone ear1", Vector3.UP, -.20 * spread)
	turn_world(rig, "bip01 bone ear3", Vector3.UP, .20 * spread)
	turn_world(rig, "bip01 bone ear2", Vector3.RIGHT, -.14 * jaw)
	turn_world(rig, "bip01 bone ear4", Vector3.RIGHT, -.14 * jaw)
	anchor_hind_paws(rig, anchor)
