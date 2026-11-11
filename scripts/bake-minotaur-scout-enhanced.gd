# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/minotaur-scout-enhanced/"
const Clips := {4: "ScoutDownwardClaw", 5: "ScoutTurningHook", 11: "ScoutHornDip",
	15: "ScoutRaisedGuard", 23: "ScoutCrouchingRise", 25: "ScoutQuietStand", 26: "ScoutLookDown",
	27: "ScoutOpenChallenge", 28: "ScoutLowCombatStance"}
const Durations := {4: .91, 5: .89, 11: .92, 15: .78, 23: 1.16, 25: 1.1, 26: .96, 27: .94, 28: .77}
const ScoutJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck",
	"bip01 head", "bip01 jaw", "bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm",
	"bip01 r upperarm", "bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l horselink",
	"bip01 r horselink", "bip01 l foot", "bip01 r foot", "bip01 tail", "bip01 tail1", "bip01 tail2"]


func run() -> void:
	prepare_body(281, Clips, Durations, ScoutJoints, pose_scout, Destination, configure_motion)
	quit()


func configure_motion(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_scout(rig: Skeleton3D, phase: float, group: int) -> void:
	var wind := 0.0
	var strike := 0.0
	var crouch := 0.0
	var guard := 0.0
	var spread := 0.0
	var twist := 0.0
	var look := 0.0
	var lead := 1.0
	match group:
		4:
			wind = .74 * envelope(phase, .05, .29, .40, .59)
			strike = .79 * envelope(phase, .28, .55, .71, .97)
			crouch = .41 * strike
			twist = .32 * wind - .29 * strike
		5:
			wind = .77 * envelope(phase, .07, .30, .48, .70)
			strike = .85 * envelope(phase, .32, .55, .73, .99)
			crouch = .30 * strike
			twist = -.43 * wind + .39 * strike
			lead = -1.0
		11:
			crouch = .58 * envelope(phase, .04, .35, .62, .98)
			wind = .29 * envelope(phase, .01, .19, .34, .55)
			look = .28 * crouch
			twist = -.24 * crouch
		15:
			guard = .76 * envelope(phase, .04, .38, .65, .96)
			crouch = .21 * guard
			spread = .29 * guard
		23:
			crouch = .85 * (1.0 - smoothstep(.10, .77, phase))
			spread = .61 * envelope(phase, .11, .52, .69, 1.0)
			guard = .27 * crouch
			look = .35 * crouch
		25:
			look = .025 * sin(TAU * phase)
			spread = .024 * (1.0 - cos(TAU * phase))
		26:
			var checking := envelope(phase, .06, .32, .66, .96)
			look = .32 * checking
			twist = -.29 * checking
			guard = .16 * checking
		27:
			spread = .91 * envelope(phase, .08, .38, .68, .97)
			guard = .32 * spread
			twist = .13 * sin(TAU * phase) * spread
		28:
			crouch = .48 * smoothstep(.11, .84, phase)
			guard = .43 * crouch
			look = .11 * crouch
	var feet := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.UP, .36 * twist)
	turn_world(rig, RootJoint, Vector3.RIGHT, .19 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .32 * crouch - .17 * guard)
	turn_world(rig, "bip01 spine2", Vector3.UP, .61 * twist)
	turn_world(rig, "bip01 head", Vector3.RIGHT, look - .28 * crouch - .16 * guard)
	turn_world(rig, "bip01 head", Vector3.UP, -.27 * twist)
	turn_world(rig, "bip01 jaw", Vector3.RIGHT, .22 * guard + .19 * spread)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var active := 1.0 if is_equal_approx(sign_x, lead) else .26
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, sign_x * .16 * spread)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK,
			sign_x * (.77 * spread + .28 * guard + .20 * active * wind))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT,
			-active * (.92 * wind + .64 * strike) - .66 * guard - .33 * crouch)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT,
			active * (.35 * strike - .44 * wind) - .47 * guard - .21 * crouch)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.22 * spread + .17 * guard))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.43 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .61 * crouch)
		turn_world(rig, "bip01 %s horselink" % side, Vector3.RIGHT, -.36 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .09 * crouch)
	turn_world(rig, "bip01 tail1", Vector3.UP, -.62 * twist + .16 * spread)
	turn_world(rig, "bip01 tail2", Vector3.BACK, .32 * twist)
	anchor_hind_paws(rig, feet)
