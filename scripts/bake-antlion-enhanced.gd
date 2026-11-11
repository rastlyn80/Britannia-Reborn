# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/antlion-enhanced/"
const Body := 787
const AntRoot := "bip 01"
const Clips := {1: "AntLionCombatWatch", 11: "AntLionPincerFeint", 12: "AntLionPincerCross",
	15: "AntLionWard", 23: "AntLionBurrowRise", 25: "AntLionQuietWatch",
	27: "AntLionHighClaws", 28: "AntLionSweep"}
const Durations := {1: 1.10, 11: .67, 12: .80, 15: .58, 23: 1.18, 25: 1.13, 27: .94, 28: .81}
const AntJoints := ["spine 01", "spine 02", "spine 03", "head", "tail 01", "tail 02",
	"antenna l 01", "antenna l 02", "antenna l 03", "antenna r 01", "antenna r 02", "antenna r 03",
	"large pincher l 01", "large pincher l 02", "large pincher r 01", "large pincher r 02",
	"smaller pincher l", "large pincher r",
	"front leg l 01", "front leg l 02", "front leg r 01", "front leg r 02"]


func run() -> void:
	var row := Registry.entry(Body)
	for treatment: String in row.assets:
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
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in Clips:
			var motion := fit_grounded(player, rig, skins, Durations[group], AntRoot, AntJoints, pose_antlion.bind(group), .004)
			if group in [1, 25]:
				motion.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [Body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ANTLION FIT ", treatment, ": eight motions")
	quit()


func pose_antlion(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var rear := 0.0
	var close := 0.0
	var open := 0.0
	var sweep := 0.0
	var inspect := 0.0
	match group:
		1:
			rear = .13 + .032 * sin(TAU * phase)
			open = .19 + .046 * (1.0 - cos(TAU * phase))
			inspect = .067 * sin(TAU * phase)
		11:
			var feint := envelope(phase, .03, .30, .52, .97)
			crouch = .23 * feint
			close = .29 * feint
			sweep = .28 * feint
		12:
			var cross := envelope(phase, .07, .46, .59, .95)
			close = .55 * cross
			rear = .27 * cross
			sweep = -.22 * cross
		15:
			var ward := envelope(phase, .03, .36, .56, .94)
			open = .53 * ward
			rear = .22 * ward
		23:
			crouch = .82 * (1.0 - smoothstep(.16, .92, phase))
			close = .38 * crouch
			rear = .31 * envelope(phase, .36, .62, .75, .98)
		25:
			crouch = .13 + .028 * (1.0 - cos(TAU * phase))
			inspect = .080 * sin(TAU * phase)
		27:
			var display := envelope(phase, .08, .37, .65, .98)
			rear = .51 * display
			open = .45 * display
			inspect = .12 * sin(TAU * phase) * display
		28:
			var gesture := envelope(phase, .09, .40, .67, .98)
			crouch = .35 * gesture
			sweep = .48 * gesture
			close = .14 * gesture
	turn_world(rig, "spine 01", Vector3.RIGHT, .22 * crouch - .22 * rear)
	turn_world(rig, "spine 02", Vector3.RIGHT, .15 * crouch - .20 * rear)
	turn_world(rig, "spine 03", Vector3.UP, .23 * sweep)
	turn_world(rig, "head", Vector3.RIGHT, -.20 * crouch + .14 * rear)
	turn_world(rig, "head", Vector3.UP, .21 * sweep + inspect)
	turn_world(rig, "tail 01", Vector3.RIGHT, -.32 * crouch + .25 * rear)
	turn_world(rig, "tail 02", Vector3.RIGHT, -.23 * crouch + .16 * rear)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var swing := sign_x * (.48 * open - .34 * close) + .46 * sweep
		turn_world(rig, "large pincher %s 01" % side, Vector3.UP, swing)
		turn_world(rig, "large pincher %s 01" % side, Vector3.RIGHT, -.38 * rear + .20 * crouch)
		turn_world(rig, "large pincher %s 02" % side, Vector3.UP, sign_x * (.25 * open - .31 * close))
		turn_world(rig, "large pincher %s 02" % side, Vector3.RIGHT, -.16 * rear + .18 * close)
		turn_world(rig, "antenna %s 01" % side, Vector3.BACK, sign_x * (.20 * open + .10 * close))
		turn_world(rig, "antenna %s 02" % side, Vector3.RIGHT, .33 * crouch - .20 * rear + inspect)
		turn_world(rig, "antenna %s 03" % side, Vector3.RIGHT, .17 * crouch - .13 * rear)
		turn_world(rig, "front leg %s 01" % side, Vector3.BACK, sign_x * (.14 * crouch - .17 * rear))
		turn_world(rig, "front leg %s 02" % side, Vector3.BACK, sign_x * (-.16 * crouch + .20 * rear))
	turn_world(rig, "smaller pincher l", Vector3.UP, -.28 * close + .18 * open)
	turn_world(rig, "large pincher r", Vector3.UP, .28 * close - .18 * open)
