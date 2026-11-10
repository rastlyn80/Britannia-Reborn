# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/serpent-harpy/"
const SerpentClips := {4: "SerpentUncoilStrike", 23: "SerpentSurface", 26: "SerpentLowWatch",
	27: "SerpentRaisedCoil", 28: "SerpentCoilAlert"}
const SerpentLengths := {4: .72, 23: 1.15, 26: 1.1, 27: 1.0, 28: .72}
const Neck := ["bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3", "bip01 neck4", "bip01 head"]
const Tail := ["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]
const HarpyClips := {12: "HarpyDoubleWingbeat", 23: "HarpyGlideSettle", 26: "HarpyFoldedGlance",
	27: "HarpyBank", 28: "HarpySpreadAlert"}
const HarpyLengths := {12: .95, 23: 1.1, 26: 1.05, 27: 1.1, 28: .7}
const HarpyJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 head", "bip01 tail",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "harpy l elbowextension",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "harpy r elbowextension",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]

func run() -> void:
	prepare_body(21, SerpentClips, SerpentLengths, [RootJoint, "bip01 spine", "bip01 ponytail1"] + Neck + Tail,
		pose_serpent, Stage, settle_serpent_height)
	prepare_body(30, HarpyClips, HarpyLengths, HarpyJoints, pose_harpy, Stage, apply_harpy_lift)
	quit()

func pose_serpent(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	var coil := 0.0
	var extension := 0.0
	var head_up := 0.0
	var gaze := 0.0
	match group:
		4:
			extension = envelope(phase, .15, .34, .37, .54)
			coil = .64 * (1.0 - extension)
			head_up = .17 * (1.0 - extension)
			gaze = .14 * pulse
		23:
			extension = .66 - .28 * smoothstep(.35, .95, phase)
			head_up = .10 * smoothstep(.12, .97, phase)
			gaze = .15 * pulse
		26:
			extension = .41 + .12 * sin(TAU * phase)
			head_up = -.20 + .09 * pulse
			gaze = .12 * sin(TAU * phase)
		27:
			coil = .72 + .18 * pulse
			head_up = .58 + .11 * pulse
			gaze = -.15 * pulse
		28:
			coil = .83 * smoothstep(.10, .86, phase)
			extension = .52 * (1.0 - smoothstep(.10, .50, phase))
			head_up = .34 * smoothstep(.21, .89, phase)
	var forward := (joint_world(rig, Neck[-1]) - joint_world(rig, Neck[0])).slide(Vector3.UP).normalized()
	for i in Neck.size() - 1:
		var upper := rig.find_bone(Neck[i])
		var lower := rig.find_bone(Neck[i + 1])
		var side := lerpf(.27, -.24, float(i) / 4.0) * coil
		var flat := forward.rotated(Vector3.UP, side)
		var incline := head_up * lerpf(.38, 1.0, float(i) / 4.0)
		var origin := rig.get_bone_global_pose(upper).origin
		var end := rig.get_bone_global_pose(lower).origin
		var aim := (flat + Vector3.UP * incline).normalized()
		var target := origin + rig.global_basis.inverse() * aim * origin.distance_to(end)
		Arms.aim(rig, upper, lower, end.lerp(target, .90 * extension + .48 * coil))
		rig.force_update_all_bone_transforms()
	turn_world(rig, Neck[0], forward.cross(Vector3.UP), .32 * head_up)
	turn_world(rig, Neck[-1], Vector3.UP, gaze)
	turn_world(rig, "bip01 ponytail1", forward.cross(Vector3.UP), -.25 * extension - .08 * pulse)
	turn_world(rig, Tail[1], Vector3.UP, -.40 * coil + .24 * extension)
	turn_world(rig, Tail[2], Vector3.UP, -.32 * coil - .15 * gaze)
	turn_world(rig, Tail[3], Vector3.UP, -.41 * coil + .21 * extension)
	turn_world(rig, Tail[4], Vector3.UP, -.28 * coil + .32 * gaze)

func settle_serpent_height(motion: Animation, rig: Skeleton3D, group: int) -> void:
	if group == 23:
		# The source begins with the serpent beneath the surface and only a tip visible.
		offset_root(motion, rig, func(phase: float): return -.67 * (1.0 - smoothstep(.03, .85, phase)))

func pose_harpy(rig: Skeleton3D, phase: float, group: int) -> void:
	var spread := 0.0
	var flap := 0.0
	var bank := 0.0
	var tuck := 0.0
	var gaze := 0.0
	match group:
		12:
			spread = .70 + .27 * sin(PI * phase)
			flap = .83 * sin(2.0 * TAU * phase - 1.25)
			tuck = .49 * envelope(phase, .03, .27, .62, .92)
		23:
			spread = smoothstep(.0, .26, phase) * (.92 - .26 * smoothstep(.76, 1.0, phase))
			flap = .27 * sin(3.0 * PI * phase) * spread
			tuck = .34 * spread
		26:
			spread = -.33 + .07 * sin(PI * phase)
			gaze = .34 * sin(TAU * phase) * sin(PI * phase)
		27:
			spread = .91 - .24 * smoothstep(.74, 1.0, phase)
			bank = .36 * envelope(phase, .02, .33, .67, .99)
			flap = .22 * sin(TAU * phase)
			tuck = .43 * sin(PI * phase)
		28:
			spread = .81 * smoothstep(.05, .44, phase)
			flap = .33 * sin(PI * phase) * spread
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.FORWARD, bank)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .16 * tuck)
	turn_world(rig, "bip01 spine2", Vector3.BACK, -.18 * bank)
	turn_world(rig, "bip01 neck", Vector3.UP, .45 * gaze)
	turn_world(rig, "bip01 head", Vector3.UP, .55 * gaze)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.28 * tuck)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var wing := sign_x * (.96 * spread + flap)
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, .18 * wing)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, .82 * wing)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.UP, sign_x * .39 * spread)
		turn_world(rig, "harpy %s elbowextension" % side, Vector3.UP, sign_x * .33 * spread)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, -.40 * wing)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.48 * tuck)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .66 * tuck)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.23 * tuck)
	anchor_hind_paws(rig, anchor)

func apply_harpy_lift(motion: Animation, rig: Skeleton3D, group: int) -> void:
	var amount: float = {12: .47, 23: .39, 27: .34}.get(group, 0.0)
	if amount > 0.0:
		offset_root(motion, rig, func(phase: float): return amount * envelope(phase, .02, .31, .68, .99))

func offset_root(motion: Animation, rig: Skeleton3D, height: Callable) -> void:
	var root_bone := rig.find_bone(RootJoint)
	var parent := rig.get_bone_parent(root_bone)
	var up := (rig.global_basis * rig.get_bone_global_pose(parent).basis).inverse() * Vector3.UP
	for track in motion.get_track_count():
		if motion.track_get_type(track) != Animation.TYPE_POSITION_3D or not str(motion.track_get_path(track)).ends_with(":" + RootJoint):
			continue
		for key in motion.track_get_key_count(track):
			var phase := motion.track_get_key_time(track, key) / motion.length
			var prior: Vector3 = motion.track_get_key_value(track, key)
			motion.track_set_key_value(track, key, prior + up * float(height.call(phase)))
		return
	assert(false, "Fitted motion requires the pelvis translation channel")
