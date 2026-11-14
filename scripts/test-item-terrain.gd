# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Actions := preload("res://Presentation/CreaturePlayerItemActions.gd")
const Normals := [Vector3.UP, Vector3(.16, 1, 0), Vector3(-.16, 1, 0), Vector3(0, 1, .16), Vector3(0, 1, -.16)]


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var poses := 0
	var maximum_penetration := 0.0
	for body: int in [1, 33, 51, 54]:
		for style: String in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = style
			root.add_child(actor)
			actor.apply_identity(body, 0)
			var rig: Skeleton3D = actor.skeleton
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var skins: Array[Dictionary] = []
			for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin != null and mesh.visible:
					skins.append(Ground.skin_points(mesh, rig))
			var clips := ["CreatureDaggerThrow", "CreatureBolaThrow"] if body == 33 else ["CreatureDaggerThrow"]
			for clip: String in clips:
				if not Actions.load_clip(actor, clip):
					printerr("Cannot load ", body, " ", style, " ", clip)
					quit(1)
					return
				for normal: Vector3 in Normals:
					var up := normal.normalized()
					var transform := Transform3D(Basis(Quaternion(Vector3.UP, up)), Vector3.ZERO) * rig.global_transform
					player.play(clip, 0.0)
					player.advance(0.0)
					for frame in 31:
						player.seek(player.current_animation_length * float(frame) / 30.0, true)
						rig.force_update_all_bone_transforms()
						var height := INF
						for skin: Dictionary in skins:
							height = minf(height, Ground.minimum_plane_gap(skin, rig, transform, Vector3.ZERO, up))
						if not is_finite(height) or height < -.008:
							printerr("Throw sinks into plane: ", body, " ", style, " ", clip, " ", frame, " ", height)
							quit(1)
							return
						maximum_penetration = maxf(maximum_penetration, -height)
						poses += 1
			actor.free()
	print("PLAYER ITEM TERRAIN: ", poses, " full-skin poses, maximum penetration ", maximum_penetration, " m")
	quit(0)
