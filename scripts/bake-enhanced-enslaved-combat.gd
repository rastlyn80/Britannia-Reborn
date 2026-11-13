# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-gargoyle-quiet-fidget.gd"

const VariantFolder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/enslaved-gargoyle-variants/"
const FitNames := {4: "EnslavedGargoyleCrossingSwipe", 5: "EnslavedGargoyleFlyingKick",
	10: "EnslavedGargoyleChestRecoil", 11: "EnslavedGargoyleLowSearch", 15: "EnslavedGargoyleBackwardGuard",
	23: "EnslavedGargoyleCrouchRise", 28: "EnslavedGargoyleForwardBrace"}
const FitLengths := {4: .72, 5: .82, 10: .63, 11: 1.2, 15: .69, 23: .85, 28: .71}


func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VariantFolder)) == OK)
	for treatment: String in ["original", "rounded", "modern"]:
		var filename := "753-%s.scn" % treatment
		var source := "res://local-art/creatures/enhanced-creature-actions/" + filename
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
		var joints := UOP_BIPED + UOP_WINGS + ["bip01 pelvis", "bip01 l foot", "bip01 r foot"]
		for group: int in FitNames:
			var motion := fit_grounded(player, rig, skins, FitLengths[group], "bip01", joints,
				fit_enslaved.bind(group), .005)
			assert(library.add_animation(FitNames[group], motion) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, VariantFolder + filename, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ENSLAVED GARGOYLE FIT ", treatment, " ", FitNames.values())
	quit()


func fit_enslaved(rig: Skeleton3D, phase: float, group: int) -> void:
	var load_weight := smoothstep(.04, .24, phase) * (1.0 - smoothstep(.30, .52, phase))
	var throw_weight := smoothstep(.25, .50, phase) * (1.0 - smoothstep(.62, .95, phase))
	var drop := .50 * throw_weight
	var twist := -.42 * load_weight + .57 * throw_weight
	var left := Vector3(.32 + .22 * load_weight, .01 + .16 * throw_weight, .20 + .47 * throw_weight)
	var right := Vector3(-.31 - .33 * load_weight, .07 - .19 * throw_weight, .13 + .37 * throw_weight)
	if group == 5:
		twist = .36 * load_weight - .47 * throw_weight
		drop = .28 * throw_weight
		left.z += .14 * throw_weight
	elif group == 10:
		drop = -.38 * load_weight
		twist = .33 * load_weight
		left.y += .20 * load_weight
		right.y += .21 * load_weight
	elif group == 11:
		throw_weight = smoothstep(.05, .27, phase) * (1.0 - smoothstep(.70, .96, phase))
		drop = .94 * throw_weight
		twist = .20 * sin(TAU * phase) * throw_weight
		left += Vector3(0, -.32, .37) * throw_weight
		right += Vector3(0, -.35, .33) * throw_weight
	elif group == 15:
		load_weight = 1.0 - smoothstep(.17, .90, phase)
		drop = .46 * load_weight
		twist = .25 * load_weight
		left += Vector3(0, .21, .27) * load_weight
		right += Vector3(0, .13, .20) * load_weight
	elif group == 23:
		load_weight = 1.0 - smoothstep(.13, .84, phase)
		drop = .92 * load_weight
		twist = -.16 * load_weight
		left += Vector3(0, -.34, .23) * load_weight
		right += Vector3(0, -.39, .20) * load_weight
	elif group == 28:
		drop = .32 * throw_weight
		twist = .12 * load_weight
		right.z += .23 * throw_weight
	turn_world(rig, "bip01 pelvis", Vector3.UP, .35 * twist)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .35 * drop)
	turn_world(rig, "bip01 spine2", Vector3.UP, .78 * twist)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .42 * drop)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.18 * drop)
	turn_world(rig, UOP_WINGS[0], Vector3.BACK, -.28 * throw_weight)
	turn_world(rig, UOP_WINGS[1], Vector3.BACK, .29 * throw_weight)
	if group in [11, 23]:
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.45 * drop)
			turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .65 * drop)
			turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.20 * drop)
	if group == 5:
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -.82 * throw_weight)
		turn_world(rig, "bip01 r calf", Vector3.RIGHT, .45 * load_weight)
		turn_world(rig, "bip01 r foot", Vector3.RIGHT, -.23 * throw_weight)
	var chest := joint_world(rig, "bip01 spine2")
	var weight := maxf(load_weight, throw_weight)
	fit_arm(rig, "l", joint_world(rig, "bip01 l hand").lerp(chest + left, weight))
	fit_arm(rig, "r", joint_world(rig, "bip01 r hand").lerp(chest + right, weight))
