# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const FlightStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/daemon-wyvern/"
const DaemonClips := {23: "DaemonFoldedRise", 26: "DaemonTailWatch", 27: "DaemonWingRebuff", 28: "DaemonWingAlert"}
const WyvernClips := {12: "WyvernNeckThrust", 23: "WyvernWingRise", 26: "WyvernTailWatch",
	27: "WyvernWingsAndFangs", 28: "WyvernWingGuard"}
const DaemonLengths := {23: 1.18, 26: 1.02, 27: 1.06, 28: .78}
const WyvernLengths := {12: .88, 23: 1.16, 26: 1.03, 27: 1.08, 28: .79}
const DaemonJoints := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 tail", "bip01 tail1", "bip01 tail2",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"daemon l mainwing01", "daemon l mainwing02", "daemon l wing01",
	"daemon r mainwing01", "daemon r mainwing02", "daemon r wing01"]
const WyvernJoints := ["bip01", "bip01 spine1", "bip01 spine3", "bip01 neck", "bip01 neck1",
	"bip01 neck2", "bip01 neck3", "bip01 head", "bip01 ponytail1",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"box01", "box02", "box03", "box06", "box05", "box04"]

func run() -> void:
	for body: int in [9, 62]:
		var row := Registry.entry(body)
		for treatment: String in row.assets:
			if not bake_wings(body, treatment, row):
				quit(1)
				return
	quit()

func bake_wings(body: int, treatment: String, row: Dictionary) -> bool:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	assert(not skins.is_empty())
	var daemon := body == 9
	var clips := DaemonClips if daemon else WyvernClips
	var lengths := DaemonLengths if daemon else WyvernLengths
	var joints := DaemonJoints if daemon else WyvernJoints
	for group: int in clips:
		var fit := pose_daemon.bind(group) if daemon else pose_wyvern.bind(group)
		var motion := fit_grounded(player, rig, skins, lengths[group], "bip01", joints, fit, .008)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	var output := FlightStage + "%d-%s.scn" % [body, treatment]
	var saved := ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS)
	model.free()
	print("DAEMON AND WYVERN ENHANCED ", body, "/", treatment, ": ", clips.size(), " added actions")
	return saved == OK

func pose_daemon(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var open := 0.0
	var lift := 0.0
	var cast := 0.0
	var turn := 0.0
	var tail := 0.0
	match group:
		23:
			crouch = 1.0 - smoothstep(.13, .64, phase)
			open = smoothstep(.28, .72, phase)
			lift = envelope(phase, .15, .45, .62, .98)
			tail = .40 * (open - crouch)
		26:
			turn = .17 * sin(TAU * phase) * sin(PI * phase)
			tail = .36 * envelope(phase, .08, .33, .58, .98)
			lift = .21 * envelope(phase, .35, .63, .71, 1.0)
		27:
			crouch = .24 * envelope(phase, .04, .21, .38, .67)
			open = .94 * envelope(phase, .17, .54, .69, .98)
			cast = envelope(phase, .12, .47, .58, .92)
			turn = -.23 * cast
			tail = .36 * envelope(phase, .31, .61, .78, 1.0)
		28:
			open = .80 * smoothstep(.13, .71, phase)
			crouch = .35 * open
			cast = .43 * envelope(phase, .12, .43, .56, .88)
			tail = -.38 * open
	turn_world(rig, "bip01", Vector3.RIGHT, .46 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .42 * crouch - .15 * lift)
	turn_world(rig, "bip01 spine2", Vector3.UP, turn)
	turn_world(rig, "bip01 head", Vector3.UP, -.64 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.31 * crouch - .18 * cast)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .30 * crouch + .21 * tail)
	turn_world(rig, "bip01 tail1", Vector3.UP, tail)
	turn_world(rig, "bip01 tail2", Vector3.UP, .64 * tail)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var limb := "bip01 " + side
		var wing := "daemon " + side
		turn_world(rig, limb + " thigh", Vector3.RIGHT, -.71 * crouch)
		turn_world(rig, limb + " calf", Vector3.RIGHT, .54 * crouch)
		turn_world(rig, limb + " foot", Vector3.RIGHT, -.29 * crouch)
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, -.68 * crouch - (.87 if side == "r" else .46) * cast)
		turn_world(rig, limb + " forearm", Vector3.RIGHT, -.47 * crouch - .70 * cast)
		turn_world(rig, wing + " mainwing01", Vector3.FORWARD, sign * (.62 * open - .24 * crouch - .25 * lift))
		turn_world(rig, wing + " mainwing02", Vector3.UP, -sign * (.58 * open - .15 * crouch))
		turn_world(rig, wing + " wing01", Vector3.RIGHT, .18 * open - .15 * lift + .21 * crouch)

func pose_wyvern(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var wing := 0.0
	var neck := 0.0
	var bite := 0.0
	var tail := 0.0
	var curl := 0.0
	var guard := 0.0
	match group:
		12:
			guard = envelope(phase, .07, .27, .36, .61)
			bite = envelope(phase, .25, .45, .54, .82)
			neck = -.13 * guard + .31 * bite
			tail = -.58 * envelope(phase, .15, .43, .65, .97)
			wing = .19 * guard
		23:
			fold = 1.0 - smoothstep(.17, .73, phase)
			wing = .44 * smoothstep(.25, .84, phase)
			neck = .25 * fold - .11 * sin(PI * phase)
			curl = .33 * smoothstep(.57, .96, phase)
		26:
			tail = .38 * sin(TAU * phase) * sin(PI * phase)
			curl = -.30 * envelope(phase, .09, .35, .62, .90)
			neck = -.09 * envelope(phase, .30, .57, .70, 1.0)
			wing = .14 * sin(PI * phase)
		27:
			wing = .70 * envelope(phase, .04, .31, .52, .95)
			bite = envelope(phase, .28, .54, .67, .92)
			neck = -.20 * bite
			curl = .40 * sin(PI * phase)
		28:
			wing = .58 * smoothstep(.13, .52, phase) * (1.0 - .34 * smoothstep(.72, 1.0, phase))
			guard = .34 * smoothstep(.20, .70, phase)
			curl = .52 * guard
			neck = .22 * guard
	turn_world(rig, "bip01", Vector3.RIGHT, .055 * fold - .08 * guard)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .065 * fold - .13 * bite)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .085 * fold)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, neck)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .62 * neck)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .39 * neck)
	turn_world(rig, "bip01 neck3", Vector3.RIGHT, -.36 * neck + .32 * bite)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.21 * neck + .28 * bite)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .43 * bite)
	turn_world(rig, "bip01 tail", Vector3.UP, .47 * tail)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .38 * curl)
	turn_world(rig, "bip01 tail1", Vector3.UP, tail)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, .70 * curl)
	turn_world(rig, "bip01 tail2", Vector3.UP, .52 * tail)
	turn_world(rig, "bip01 tail3", Vector3.RIGHT, .74 * curl)
	turn_world(rig, "bip01 tail4", Vector3.RIGHT, .62 * curl)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var limb := "bip01 " + side
		var segments := ["box06", "box05", "box04"] if side == "l" else ["box01", "box02", "box03"]
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, -.43 * fold + .19 * guard)
		turn_world(rig, limb + " forearm", Vector3.RIGHT, .62 * fold - .13 * guard)
		turn_world(rig, segments[0], Vector3.FORWARD, -sign * (.42 * wing + .06 * fold))
		turn_world(rig, segments[1], Vector3.UP, sign * (.23 * wing + .48 * fold))
		turn_world(rig, segments[2], Vector3.FORWARD, -sign * (.32 * wing + .16 * fold))
