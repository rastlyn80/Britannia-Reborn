# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CLIPS := {"2": "EnhancedHalberdCollapse", "4": "EnhancedHalberdSweep",
	"10": "EnhancedHalberdRecoil", "23": "EnhancedHalberdRise", "28": "EnhancedHalberdSpin"}
const Exact := preload("res://../scripts/test-quadruped-actions.gd")

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func run() -> void:
	var destination := OS.get_environment("BR_INDEXED_BAKE_DIRECTORY").path_join("animated-weapon-variants")
	assert(not OS.get_environment("BR_INDEXED_BAKE_DIRECTORY").is_empty())
	var fit_path := destination.path_join("fit.json")
	var receipt_path := destination.path_join("bake.json")
	var out := destination.path_join("692.scn")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fit_path))
	var fit: Dictionary = proof.groups
	var row := Registry.entry(692)
	var path: String = Registry.asset_path(row)
	var source_sha: String = row.asset_sha256.modern
	assert(FileAccess.get_sha256(path) == source_sha)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bone := rig.find_bone("weapon_halberd")
	assert(bone >= 0)
	var skin := Ground.skin_points(mesh, rig)
	var binding: int = skin.bones.find(bone)
	assert(binding >= 0)
	var bind: Transform3D = skin.bind_poses[binding]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.play("Idle", 0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var original := rig.get_bone_global_pose(bone)
	var rig_basis := rig.global_basis.orthonormalized()
	var local_axis := bind.basis * Vector3.UP
	var old_axis := (rig_basis * original.basis * local_axis).normalized()
	var first := vector(fit["4"].axis[0])
	var yaw := atan2(old_axis.x, old_axis.z) - atan2(first.x, first.z)
	var orient := Basis(Vector3.UP, yaw)
	var metres_per_pixel := mesh.get_aabb().size.y / 83.0
	var zero := vector(fit["4"].centers[0])
	var center_anchor := bind * (Vector3.UP * mesh.get_aabb().get_center().y)
	var old_center := original * center_anchor
	var clip_root := player.get_node(player.root_node).get_path_to(rig)
	var track_path := NodePath("%s:weapon_halberd" % clip_root)
	var max_adjustment := 0.0
	for group: String in CLIPS:
		var clip := Animation.new()
		var axes: Array = fit[group].axis
		var frames: Array = fit[group].centers
		var seconds_per_frame := 0.09
		clip.length = float(axes.size() - 1) * seconds_per_frame
		var translations := clip.add_track(Animation.TYPE_POSITION_3D)
		var rotations := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(translations, track_path)
		clip.track_set_path(rotations, track_path)
		var orientation := original.basis.get_rotation_quaternion()
		var previous := rig_basis.inverse() * old_axis
		var clip_adjustment := 0.0
		var raised_frames := 0
		for index in axes.size():
			var axis := (rig_basis.inverse() * orient * vector(axes[index])).normalized()
			orientation = (Quaternion(previous, axis) * orientation).normalized()
			previous = axis
			var center := old_center + rig_basis.inverse() * (orient * (vector(frames[index]) - zero)) * metres_per_pixel
			var pose := Transform3D(Basis(orientation), center - Basis(orientation) * center_anchor)
			rig.set_bone_global_pose(bone, pose)
			rig.force_update_all_bone_transforms()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			var target := .02
			var adjustment := maxf(0.0, target - gap)
			if group == "2":
				# The terminal sprite lies on the ground. Preserve the approach
				# separately from the residual height of this donor mesh.
				var phase := float(index) / (axes.size() - 1)
				adjustment -= maxf(0.0, gap - target) * smoothstep(.49, .85, phase)
			if absf(adjustment) > 0.0001:
				raised_frames += 1
			clip_adjustment = maxf(clip_adjustment, absf(adjustment))
			pose.origin += rig_basis.inverse() * Vector3.UP * adjustment
			rig.set_bone_global_pose(bone, pose)
			var time := float(index) * seconds_per_frame
			clip.position_track_insert_key(translations, time, rig.get_bone_pose_position(bone))
			clip.rotation_track_insert_key(rotations, time, rig.get_bone_pose_rotation(bone))
		assert(library.add_animation(CLIPS[group], clip) == OK)
		max_adjustment = maxf(max_adjustment, clip_adjustment)
		print("UOP HALBERD ", group, " ", CLIPS[group], " keys ", axes.size(), " orientation RMSE ", fit[group].pixel_rmse,
			" raised frames ", raised_frames, " max ", clip_adjustment, " m")
	assert(max_adjustment < 0.75, str(max_adjustment))
	Exact.check_earlier_keys(player, path)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, out, ResourceSaver.FLAG_COMPRESS) == OK)
	var receipt := FileAccess.open(receipt_path, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"source_asset": path, "source_sha256": source_sha,
		"scene_sha256": FileAccess.get_sha256(out), "fit_sha256": FileAccess.get_sha256(fit_path),
		"baker_sha256": FileAccess.get_sha256(get_script().resource_path), "maximum_lift": max_adjustment}))
	receipt.close()
	print("UOP HALBERD: five added clips, maximum physical clearance adjustment ", max_adjustment, " m")
	model.free()
	quit()
