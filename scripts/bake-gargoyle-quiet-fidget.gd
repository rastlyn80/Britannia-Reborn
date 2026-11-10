# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-preferred-uop-actions.gd"

const BODY := 753
const CLIP := "UopGargoyleQuietFidget"
const CANDIDATE := "res://../work/creatures/native-form-audit/enhanced-source-gaps/gargoyle-quiet-fidget-%s.scn"

func run() -> void:
	var row := Registry.entry(BODY)
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
		player.deterministic = true
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				skins.append(Ground.skin_points(mesh, rig))
		assert(not skins.is_empty())
		var clip := fit_grounded(player, rig, skins, 1.0, "bip01", UOP_BIPED + UOP_WINGS, quiet_pose)
		assert(library.add_animation(CLIP, clip) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, CANDIDATE % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("GARGOYLE QUIET FIDGET: ", treatment, " / group 26")
	quit()

func quiet_pose(rig: Skeleton3D, phase: float) -> void:
	# Group 26 keeps both feet registered while the left forearm crosses the chest.
	var gesture := smoothstep(.04, .33, phase) * (1.0 - smoothstep(.76, .98, phase))
	var breathing := sin(phase * TAU) * gesture
	turn_world(rig, "bip01 spine1", Vector3.UP, .12 * gesture)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .07 * gesture)
	turn_world(rig, UOP_WINGS[0], Vector3.UP, .06 * gesture)
	turn_world(rig, UOP_WINGS[1], Vector3.UP, -.04 * gesture)
	var chest := joint_world(rig, "bip01 spine2")
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	fit_arm(rig, "l", left.lerp(chest + Vector3(.23, -.08 + .04 * breathing, .25), gesture * .88))
	fit_arm(rig, "r", right.lerp(chest + Vector3(-.28, -.28, .22), gesture * .30))
