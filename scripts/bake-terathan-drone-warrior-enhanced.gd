# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/terathan-drone-warrior/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Motions := {1: "LowWatch", 12: "RaisedPincers", 23: "Unfold", 27: "LowPincerBrace", 28: "ForwardAlert"}
const Durations := {1: 1.18, 12: .94, 23: 1.32, 27: .88, 28: .70}
const RightLegs := [["bone40", "bone38", "bone37"], ["bone_r", "bone08", "bone09"],
	["bone_r01", "bone12", "bone13"], ["bone_r02", "bone16", "bone15"]]
const LeftLegs := [["bone32", "bone34", "bone21"], ["bone_r04", "bone25", "bone26"],
	["bone_r05", "bone28", "bone24"], ["bone_r03", "bone31", "bone29"]]
const UpperBody := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bone_fangs_l", "bone_fang_r"]


static func clip_name(body: int, group: int) -> String:
	return ("TerathanWarrior" if body == 70 else "TerathanDrone") + Motions[group]


func run() -> void:
	for body: int in [70, 71]:
		var row := Registry.entry(body)
		for treatment: String in Profile.registered_assets(row):
			var source := Registry.asset_path(row, treatment)
			assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
			var actor := (load(source) as PackedScene).instantiate()
			root.add_child(actor)
			var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
			player.remove_animation_library("")
			player.add_animation_library("", library)
			var joints := UpperBody.duplicate()
			for leg: Array in LeftLegs + RightLegs:
				joints.append_array(leg)
			var skins: Array[Dictionary] = [Ground.skin_points(actor.find_child("Body", true, false), rig)]
			for group: int in Motions:
				var clip := fit_grounded(player, rig, skins, Durations[group], "bip01", joints, pose_terathan.bind(body, group), .006)
				assert(library.add_animation(clip_name(body, group), clip) == OK)
			verify_base_clips(player, source)
			player.stop()
			rig.reset_bone_poses()
			var packed := PackedScene.new()
			assert(packed.pack(actor) == OK)
			assert(ResourceSaver.save(packed, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
			actor.free()
			print("TERATHAN ", body, "/", treatment, ": five fitted motions and exact retained keys")
	quit()


func pulse(phase: float, start: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, end, phase))


func pose_terathan(rig: Skeleton3D, phase: float, body: int, group: int) -> void:
	var tuck := 0.0
	var pitch := 0.0
	var spread := 0.0
	var raised := 0.0
	var flick := 0.0
	var lean := 0.0
	var warrior := body == 70
	match group:
		1:
			pitch = .35 + .043 * sin(TAU * phase)
			lean = .20 + .07 * sin(TAU * phase)
			spread = .18
		12:
			raised = pulse(phase, .13, .38, .68, 1.0)
			pitch = .22 - .51 * raised
			flick = .23 * raised * sin(5.0 * PI * phase)
			spread = .20 * raised
		23:
			tuck = 1.0 - smoothstep(.11, .87, phase)
			raised = .68 * pulse(phase, .12, .42, .64, .91)
			pitch = .84 * tuck - .17 * raised
			spread = .16 * pulse(phase, .36, .73, .88, 1.0)
			lean = .17 * tuck
		27:
			pitch = .64 - .27 * smoothstep(.66, 1.0, phase)
			spread = .31
			raised = .45 + .12 * sin(TAU * phase)
			lean = -.27 * smoothstep(.62, 1.0, phase)
		28:
			pitch = .28 * smoothstep(.08, .55, phase)
			spread = .17 + .20 * smoothstep(.05, .69, phase)
			raised = .32 * pulse(phase, .11, .52, .73, 1.0)
			flick = .26 * sin(PI * phase)
			lean = -.17 * smoothstep(.11, .56, phase)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .78 * pitch)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .63 * pitch)
	turn_world(rig, "bip01 spine2", Vector3.UP, lean)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.19 * pitch)
	turn_world(rig, "bip01 head", Vector3.UP, .33 * lean)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .37 * tuck + .13 * pitch)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .48 * tuck - .17 * pitch)
	turn_world(rig, "bip01 tail2", Vector3.UP, -.21 * lean)
	turn_world(rig, "bone_fangs_l", Vector3.UP, .23 * raised)
	turn_world(rig, "bone_fang_r", Vector3.UP, -.23 * raised)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var guard := raised * (1.0 if warrior else .82)
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.FORWARD, -.13 * sign_x * guard)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -1.09 * guard + .27 * tuck + sign_x * flick)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.58 * guard - .54 * tuck))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.37 * guard - .68 * tuck)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.18 * guard - .25 * tuck))
		var legs := LeftLegs if side == "l" else RightLegs
		for index in legs.size():
			var leg: Array = legs[index]
			var spread_axis := .14 + .08 * index
			turn_world(rig, leg[0], Vector3.BACK, sign_x * (.82 * tuck - .18 * spread))
			turn_world(rig, leg[0], Vector3.UP, sign_x * (index - 1.5) * spread * spread_axis)
			turn_world(rig, leg[1], Vector3.BACK, sign_x * (-1.30 * tuck + .12 * spread))
			turn_world(rig, leg[2], Vector3.BACK, sign_x * (-.60 * tuck - .10 * spread))
