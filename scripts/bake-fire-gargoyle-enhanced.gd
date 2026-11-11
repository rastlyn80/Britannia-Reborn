# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 130
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/fire-gargoyle-enhanced/"
const Clips := {4: "FireGargoyleOverheadRake", 5: "FireGargoyleSwoopingClaw",
	11: "FireGargoyleAshSearch", 31: "FireGargoyleFireBreath"}
const Durations := {4: .84, 5: .93, 11: 1.27, 31: 1.55}
const FireJoints := ["bip01 pelvis", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 l thigh",
	"bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot",
	"gargoyle l mainwing1", "gargoyle r mainwing1", "gargoyle l mainwing2", "gargoyle r mainwing2"]


func run() -> void:
	prepare_body(Body, Clips, Durations, FireJoints, pose_fire_gargoyle, Destination)
	quit()


func pose_fire_gargoyle(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := 0.0
	var reach := 0.0
	var crouch := 0.0
	var turn := 0.0
	var wing_fold := 0.0
	var lead := -1.0
	match group:
		4:
			rise = envelope(phase, .03, .28, .40, .62)
			reach = envelope(phase, .31, .56, .72, .98)
			crouch = .60 * reach
			turn = .39 * rise - .47 * reach
			wing_fold = .62 * (rise + .35 * reach)
		5:
			rise = .38 * envelope(phase, .02, .25, .42, .62)
			reach = envelope(phase, .29, .55, .73, .97)
			crouch = .72 * reach
			turn = -.26 * rise + .45 * reach
			wing_fold = .46 * reach
			lead = 1.0
		11:
			reach = .55 * envelope(phase, .12, .34, .55, .88)
			crouch = .90 * envelope(phase, .03, .34, .70, .99)
			turn = .18 * sin(TAU * phase) * crouch
			wing_fold = .51 * crouch
		31:
			rise = .45 * envelope(phase, .02, .32, .58, .78)
			reach = .87 * envelope(phase, .45, .76, .89, .99)
			crouch = .40 * reach
			wing_fold = .41 * (rise + reach)
	var feet := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.UP, .28 * turn)
	turn_world(rig, RootJoint, Vector3.RIGHT, .19 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .31 * crouch - .24 * rise)
	turn_world(rig, "bip01 spine2", Vector3.UP, .78 * turn)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .20 * reach - .26 * rise)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.20 * crouch + .27 * reach)
	turn_world(rig, "bip01 head", Vector3.UP, -.32 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.32 * reach)
	for side: String in ["l", "r"]:
		var direction := 1.0 if side == "l" else -1.0
		var active := 1.0 if is_equal_approx(direction, lead) or group == 31 else .39
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, direction * .14 * active * rise)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, direction * (.66 * active * rise + .31 * reach))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -active * (1.83 * rise + 1.08 * reach))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -active * (.68 * rise - .21 * reach))
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, direction * (.25 * reach - .18 * rise))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.59 * crouch - .23 * active * rise)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .82 * crouch + .38 * active * rise)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.21 * crouch)
		turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.RIGHT, -.29 * wing_fold)
		turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.BACK, -direction * .49 * wing_fold)
		turn_world(rig, "gargoyle %s mainwing2" % side, Vector3.UP, direction * .39 * wing_fold)
		if group == 4:
			var follow_through := envelope(phase, .29, .44, .58, .75)
			turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.BACK, direction * .16 * follow_through)
	anchor_hind_paws(rig, feet)
