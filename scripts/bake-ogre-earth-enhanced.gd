# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ogre-earth/"
const OgreClips := {4: "OgreTurningSweep", 23: "OgreCrouchRise", 26: "OgreLookDown",
	27: "OgreBrowGuard", 28: "OgreReadyLean"}
const OgreLengths := {4: .90, 23: .70, 26: 1.10, 27: 1.05, 28: .68}
const EarthClips := {12: "EarthTwoHandSlam", 26: "EarthFistCheck", 27: "EarthHeavyGuard", 28: "EarthLowBrace"}
const EarthLengths := {12: .85, 26: 1.06, 27: .84, 28: .60}
const Legs := ["bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const Upper := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 l clavicle",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm"]

func run() -> void:
	prepare_body(1, OgreClips, OgreLengths, Upper + Legs + ["bip01 spine2", "bip01 head"], pose_ogre, Stage)
	prepare_body(14, EarthClips, EarthLengths, Upper + Legs, pose_earth, Stage)
	quit()

func pose_ogre(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var hip := joint_world(rig, RootJoint)
	var right_hand := joint_world(rig, "bip01 r hand")
	var left_hand := joint_world(rig, "bip01 l hand")
	var wind := 0.0
	var release := 0.0
	var crouch := 0.0
	var shoulder := 0.0
	var look := 0.0
	match group:
		4:
			wind = envelope(phase, .08, .28, .32, .49)
			release = envelope(phase, .29, .53, .63, .96)
			crouch = .65 * release
			shoulder = .52 * release - .61 * wind
			look = -.36 * shoulder
		23:
			crouch = 1.0 - smoothstep(.10, .80, phase)
			wind = .74 * crouch
			release = .27 * envelope(phase, .27, .53, .60, .99)
			look = .27 * crouch
		26:
			var survey := sin(TAU * phase) * sin(PI * phase)
			look = .20 * survey
			shoulder = .09 * survey
			crouch = .09 * sin(PI * phase)
		27:
			wind = envelope(phase, .10, .32, .35, .52)
			release = envelope(phase, .28, .50, .79, 1.0)
			shoulder = -.18 * wind + .43 * release
			crouch = .33 * release
			look = -.30 * release
		28:
			release = smoothstep(.09, .36, phase)
			shoulder = .29 * release
			crouch = .40 * release
	turn_world(rig, RootJoint, Vector3.UP, .14 * shoulder)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .30 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .33 * crouch - .14 * wind)
	turn_world(rig, "bip01 spine1", Vector3.UP, .68 * shoulder)
	turn_world(rig, "bip01 spine2", Vector3.FORWARD, -.23 * shoulder)
	turn_world(rig, "bip01 neck", Vector3.UP, look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.19 * crouch)
	pose_stance(rig, crouch, shoulder)
	if group != 26:
		var raise := Vector3(-.63, 1.50, .17)
		var follow := Vector3(.06, .42, 1.07)
		var left_reach := Vector3(1.11, .48, .26)
		match group:
			23:
				raise = Vector3(-.26, .20, .54)
				follow = Vector3(-.95, .43, .55)
				left_hand = left_hand.lerp(hip + Vector3(.30, .23, .50), wind)
			27:
				raise = Vector3(-.32, 1.24, .52)
				follow = Vector3(-.45, .80, .62)
				left_reach = Vector3(.99, .93, -.25)
			28:
				follow = Vector3(-.81, .42, .90)
				left_reach = Vector3(.85, .29, .83)
		fit_arm(rig, "r", right_hand.lerp(hip + raise, wind).lerp(hip + follow, release))
		fit_arm(rig, "l", left_hand.lerp(hip + left_reach, .73 * release))
	anchor_hind_paws(rig, anchor)

func pose_earth(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var hip := joint_world(rig, RootJoint)
	var right_hand := joint_world(rig, "bip01 r hand")
	var wind := 0.0
	var release := 0.0
	var crouch := 0.0
	var twist := 0.0
	match group:
		12:
			wind = envelope(phase, .02, .24, .32, .45)
			release = envelope(phase, .30, .46, .82, 1.0)
			crouch = .70 * release
		26:
			wind = .78 * envelope(phase, .02, .20, .87, 1.0)
			twist = -.21 * wind
		27:
			wind = .54 * envelope(phase, .01, .24, .77, .97)
			release = .41 * sin(PI * phase)
			crouch = .38 * release
			twist = .52 * wind
		28:
			release = .57 * smoothstep(.06, .35, phase)
			crouch = .67 * release
			twist = -.31 * release
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .39 * crouch - .22 * wind)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .41 * crouch - .11 * wind)
	turn_world(rig, "bip01 spine1", Vector3.UP, twist)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .20 * wind - .12 * release)
	pose_stance(rig, crouch, twist)
	var raised := Vector3(-.66, 1.64, .35) if group == 12 else Vector3(-.47, 1.15, .49)
	var lowered := Vector3(-.46, .23, 1.11) if group == 12 else Vector3(-.78, .46, .82)
	fit_arm(rig, "r", right_hand.lerp(hip + raised, wind).lerp(hip + lowered, release))
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -1.96 * wind - .68 * release if group == 12 else -.32 * release)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -.44 * wind + .29 * release)
	turn_world(rig, "bip01 l clavicle", Vector3.BACK, .21 * (wind + release))
	anchor_hind_paws(rig, anchor)

func pose_stance(rig: Skeleton3D, crouch: float, twist: float) -> void:
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.72 * crouch + .21 * twist * sign_x)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.19 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.47 * crouch)
