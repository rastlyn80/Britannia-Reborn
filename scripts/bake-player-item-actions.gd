# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Rigs := {
	1: [.77, 1.06, .59],
	33: [1.06, .82, .44],
	51: [.75, .68, .36],
	54: [.88, 1.15, .64],
}
const Joints := ["bip01 spine", "bip01 spine1", "bip01 head",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l upperarm", "bip01 l forearm", "__root"]


func run() -> void:
	var folder := OS.get_environment("BR_PLAYER_ITEM_OUTPUT")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("res://local-art/creatures/player-item-actions")
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	for body: int in Rigs:
		var row := Registry.entry(body)
		for style: String in ["original", "rounded", "modern"]:
			var source := Registry.asset_path(row, style)
			assert(FileAccess.get_sha256(source) == row.asset_sha256[style])
			var model := (load(source) as PackedScene).instantiate() as Node3D
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var skins: Array[Dictionary] = []
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin != null and mesh.visible:
					skins.append(Ground.skin_points(mesh, rig))
			assert(not skins.is_empty())
			save_clip(folder, body, style, "CreatureDaggerThrow", player, rig, skins, false)
			if body == 33:
				save_clip(folder, body, style, "CreatureBolaThrow", player, rig, skins, true)
			model.free()
	quit(0)


func save_clip(folder: String, body: int, style: String, name: String, player: AnimationPlayer,
		rig: Skeleton3D, skins: Array[Dictionary], bola: bool) -> void:
	var duration := .6 if bola else .66
	var animation := fit_grounded(player, rig, skins, duration, "__root", Joints, pose_throw.bind(body, bola))
	for index in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_path(index).get_subname_count() == 0:
			animation.remove_track(index)
	var target := folder.path_join("%d-%s-%s.res" % [body, style, name])
	assert(ResourceSaver.save(animation, target, ResourceSaver.FLAG_COMPRESS) == OK)
	print("PLAYER ITEM FIT: ", body, " ", style, " ", name, " ", FileAccess.get_sha256(target))


func pose_throw(rig: Skeleton3D, phase: float, body: int, bola: bool) -> void:
	var wind := smoothstep(.04, .31, phase) * (1.0 - smoothstep(.31, .52, phase))
	var push := smoothstep(.34, .57, phase) * (1.0 - smoothstep(.65, .97, phase))
	var release := smoothstep(.40, .55, phase) * (1.0 - smoothstep(.62, .82, phase))
	var arc := sin(TAU * phase * 1.4) * (wind + push) if bola else 0.0
	var gain: Array = Rigs[body]
	turn_world(rig, "bip01 spine", Vector3.UP, gain[2] * (-.72 * wind + .80 * push))
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.16 * wind + .25 * push)
	turn_world(rig, "bip01 head", Vector3.UP, .24 * wind - .25 * push)
	turn_world(rig, "bip01 r clavicle", Vector3.FORWARD, -.20 * wind + .12 * push)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, gain[0] * (.95 * wind - 1.34 * push))
	turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, -gain[1] * .63 * wind + .52 * arc)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -1.30 * wind + .52 * push)
	turn_world(rig, "bip01 r hand", Vector3.RIGHT, -.29 * wind + .49 * release)
	turn_world(rig, "bip01 r hand", Vector3.UP, .48 * arc)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.39 * wind + .25 * push)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -.20 * (wind + push))
