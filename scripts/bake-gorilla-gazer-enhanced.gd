# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const NextStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/gorilla-gazer/"
const GorillaClips := {4: "GorillaOverheadDrop", 15: "GorillaForearmGuard", 25: "GorillaLowBreath",
	26: "GorillaLowWatch", 27: "GorillaChestBeat", 28: "GorillaArmsWarning"}
const GorillaLengths := {4: .94, 15: .62, 25: 1.05, 26: .87, 27: 1.22, 28: .78}
const GazerClips := {11: "GazerTentacleSurvey", 12: "GazerEyeFan", 15: "GazerTiltRecoil",
	23: "GazerUnfurl", 26: "GazerHoverScan", 27: "GazerOrbitFeint", 28: "GazerRaisedEyeAlert"}
const GazerLengths := {11: 1.08, 12: 1.0, 15: .59, 23: .94, 26: 1.03, 27: .91, 28: .63}
const GorillaJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3",
	"bip01 neck", "bip01 head", "bip01 l clavicle", "bip01 r clavicle",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot",
	"bip01 l finger1", "bip01 r finger1"]
const GazerJoints := ["bip01 pelvis", "bip01 spine", "bip01 neck", "bip01 head", "bone_brow",
	"bip01 ponytail1", "bip01 ponytail2", "bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm",
	"bip01 r upperarm", "bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]
const Eyes := ["gazers_gazer_eyebone1", "gazers_gazer_eyebone2", "gazers_gazer_eyebone3", "gazers_gazer_eyebone4"]

func run() -> void:
	var gorilla := Registry.entry(29).duplicate(true)
	if not gorilla.has("assets"):
		var assets := {}
		for treatment: String in gorilla.asset_sha256:
			assets[treatment] = Registry.asset_path(gorilla, treatment)
		gorilla.assets = assets
	Registry.entries[29] = gorilla
	prepare_body(29, GorillaClips, GorillaLengths, GorillaJoints, pose_gorilla, NextStage)
	prepare_body(22, GazerClips, GazerLengths, GazerJoints + Eyes, pose_gazer, NextStage, place_gazer_eyes)
	quit()

func pose_gorilla(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var hip := joint_world(rig, RootJoint)
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	var rear := 0.0
	var reach := 0.0
	var guard := 0.0
	var look := 0.0
	var impact := 0.0
	match group:
		4:
			rear = envelope(phase, .08, .31, .44, .70)
			impact = envelope(phase, .44, .61, .68, .97)
			reach = rear
		15:
			guard = envelope(phase, .03, .24, .70, .98)
			look = -.32 * guard
		25:
			look = .03 * sin(TAU * phase)
		26:
			look = .26 * sin(TAU * phase) * sin(PI * phase)
		27:
			rear = .91 * envelope(phase, .07, .30, .70, .93)
			reach = .45 * rear
		28:
			guard = .61 * smoothstep(.08, .84, phase)
			rear = .34 * guard
			look = .18 * guard
	turn_world(rig, RootJoint, Vector3.RIGHT, -.25 * rear + .14 * impact)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -.30 * rear + .13 * impact)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.40 * rear + .13 * impact)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.27 * rear)
	turn_world(rig, "bip01 spine3", Vector3.UP, -.37 * guard)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .32 * rear - .26 * impact)
	turn_world(rig, "bip01 head", Vector3.UP, look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.10 * sin(PI * phase))
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .19 * rear - .18 * impact)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.43 * rear + .27 * impact)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .24 * rear)
		turn_world(rig, "bip01 %s finger1" % side, Vector3.RIGHT, .52 * maxf(rear, guard))
	var right_target := right.lerp(hip + Vector3(-.49, 1.30, .23), reach)
	var left_target := left.lerp(hip + Vector3(.51, 1.30, .24), reach)
	if group == 27:
		var beats := sin((phase - .23) * TAU * 3.0)
		right_target = right_target.lerp(hip + Vector3(-.19, .89, .51), rear * maxf(beats, 0.0))
		left_target = left_target.lerp(hip + Vector3(.19, .90, .49), rear * maxf(-beats, 0.0))
	elif group == 15:
		right_target = right_target.lerp(hip + Vector3(-.40, .79, .64), guard)
	elif group == 28:
		right_target = right_target.lerp(hip + Vector3(-.67, .57, .85), guard)
		left_target = left_target.lerp(hip + Vector3(.64, .57, .80), guard)
	if group not in [25, 26]:
		fit_arm(rig, "r", right_target.lerp(hip + Vector3(-.53, .12, 1.00), impact))
		fit_arm(rig, "l", left_target.lerp(hip + Vector3(.56, .10, .94), impact))
	anchor_hind_paws(rig, anchor)

func pose_gazer(rig: Skeleton3D, phase: float, group: int) -> void:
	var scan := sin(TAU * phase)
	var recoil := 0.0
	var flare := 0.0
	var tucked := 0.0
	match group:
		11:
			flare = .42 * sin(PI * phase)
		12:
			flare = envelope(phase, .01, .26, .72, .99)
		15:
			recoil = envelope(phase, .03, .32, .55, .96)
			flare = .27 * recoil
		23:
			tucked = 1.0 - smoothstep(.04, .84, phase)
			flare = .48 * envelope(phase, .28, .70, .79, .99)
		26:
			scan *= .58
		27:
			recoil = .58 * envelope(phase, .07, .28, .61, .91)
			flare = .65 * sin(PI * phase)
		28:
			flare = .72 * smoothstep(.05, .70, phase)
			recoil = .24 * flare
	turn_world(rig, RootJoint, Vector3.RIGHT, -.50 * recoil + .17 * tucked)
	turn_world(rig, "bip01 spine", Vector3.BACK, .26 * scan * (recoil + .25))
	turn_world(rig, "bip01 neck", Vector3.UP, .19 * scan)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .24 * recoil - .14 * tucked)
	turn_world(rig, "bone_brow", Vector3.RIGHT, -.28 * flare + .12 * tucked)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .33 * tucked - .29 * flare)
	turn_world(rig, "bip01 ponytail2", Vector3.RIGHT, -.25 * tucked + .24 * flare)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (1.20 * flare - .54 * tucked))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.70 * tucked + .46 * flare)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, sign_x * .53 * (tucked + flare))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.BACK, sign_x * .41 * (flare - tucked))
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.49 * tucked + .35 * flare)
	for eye: String in Eyes:
		turn_world(rig, eye, Vector3.UP, .36 * scan)
		turn_world(rig, eye, Vector3.RIGHT, .29 * recoil - .24 * flare)

func place_gazer_eyes(clip: Animation, rig: Skeleton3D, group: int) -> void:
	var tracks := {}
	var living_head := rig.find_bone("bip01 head")
	for eye: String in Eyes:
		var path := NodePath()
		for channel in clip.get_track_count():
			var channel_path := clip.track_get_path(channel)
			if channel_path.get_subname_count() == 1 and channel_path.get_subname(0) == eye:
				path = channel_path
				break
		assert(not path.is_empty(), eye)
		var track := clip.find_track(path, Animation.TYPE_POSITION_3D)
		var joint := rig.find_bone(eye)
		assert(rig.get_bone_parent(joint) == living_head)
		var point := rig.get_bone_rest(joint).origin
		if track < 0:
			track = clip.add_track(Animation.TYPE_POSITION_3D)
			clip.track_set_path(track, path)
		else:
			point = clip.track_get_key_value(track, 0)
			clip.track_remove_key(track, 0)
		tracks[track] = point
	for frame in 81:
		var phase := float(frame) / 80.0
		var extension := 1.0
		match group:
			12:
				extension += .23 * envelope(phase, .02, .24, .72, .99)
			23:
				extension = lerpf(.16, 1.0, smoothstep(.05, .84, phase))
			27:
				extension += .11 * sin(PI * phase)
			28:
				extension += .15 * smoothstep(.10, .79, phase)
		for track: int in tracks:
			clip.position_track_insert_key(track, phase * clip.length, tracks[track] * extension)
	offset_root(clip, rig, func(phase: float):
		return lerpf(.36, .61, smoothstep(.08, .91, phase)) if group == 23 else .49 + .13 * sin(PI * phase))
