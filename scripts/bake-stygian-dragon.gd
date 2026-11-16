# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Donor := 172
const Wings := [28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41]
const Face := [12, 13, 14, 15, 16, 17]
const Joints := [
	"bip01", "bip01 spine2", "bip01 neck", "bip01 neck2", "bip01 head", "box14",
	"box20", "box01", "dummy-l_wing", "dummy-r_wing", "bip01 tail1", "bip01 tail2",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l thigh", "bip01 r thigh",
]
const Fits := {
	"StygianRest": [1.65, 1], "Death": [1.9, 2], "Death2": [2.0, 3],
	"StygianRake": [.84, 4], "StygianLunge": [.96, 5], "StygianRecoil": [.58, 10],
	"StygianWingGuard": [1.1, 15], "StygianBreath": [1.48, 27], "StygianTailCheck": [1.08, 30],
	"TakeOff": [1.08, 28],
}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var folder := OS.get_environment("BR_STYGIAN_DRAGON_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	var row := Registry.entry(Donor)
	var proofs := {}
	for style: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, style)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[style])
		var actor := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var animator := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 57 and rig.get_bone_name(29) == "dummy-l_wing")
		var changed := 0
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				changed += refit(mesh, rig)
				skins.append(Ground.skin_points(mesh, rig))
		var library := animator.get_animation_library("")
		for label: String in Fits:
			var options: Array = Fits[label]
			var clip := fit_grounded(animator, rig, skins, options[0], "bip01", Joints, pose_stygian.bind(options[1]))
			if library.has_animation(label):
				library.remove_animation(label)
			assert(library.add_animation(label, clip) == OK)
		var walk := fold_gait(animator, rig, skins, "Walk")
		var run_clip := fold_gait(animator, rig, skins, "Run")
		for label: String in ["Idle", "Walk", "Run"]:
			library.remove_animation(label)
		assert(library.add_animation("Idle", library.get_animation("StygianRest")) == OK)
		assert(library.add_animation("ReadyStance", library.get_animation("StygianRest").duplicate(true)) == OK)
		assert(library.add_animation("Walk", walk) == OK)
		assert(library.add_animation("Run", run_clip) == OK)
		animator.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var path := folder.path_join("826-%s.scn" % style)
		assert(scene.pack(actor) == OK and ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		proofs[style] = {"donor": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(path),
			"vertices": changed, "bones": rig.get_bone_count(), "clips": animator.get_animation_list()}
		actor.free()
		print("STYGIAN FIT: ", style, " / ", changed, " skinned vertices")
	var file := FileAccess.open(folder.path_join("fitted-scenes.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(proofs, "\t"))
	file.close()
	quit()


func pose_stygian(rig: Skeleton3D, phase: float, group: int) -> void:
	var stride := sin(phase * TAU)
	var thrust := smoothstep(.16, .46, phase) * (1.0 - smoothstep(.54, .97, phase))
	var recoil := smoothstep(.02, .20, phase) * (1.0 - smoothstep(.24, .95, phase))
	if group in [2, 3]:
		var direction := 1.0 if group == 2 else -1.0
		var brace := smoothstep(.03, .24, phase) * (1.0 - smoothstep(.34, .65, phase))
		var topple := smoothstep(.28, .91, phase)
		turn_world(rig, "bip01", Vector3.FORWARD, direction * (1.02 if group == 2 else 1.37) * topple)
		turn_world(rig, "bip01", Vector3.RIGHT, (.20 if group == 2 else -.23) * topple)
		fold_wings(rig, .94 - .77 * brace, .28 * direction * (1.0 - topple))
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -.28 * brace + .51 * topple)
		turn_world(rig, "bip01 head", Vector3.UP, direction * .35 * topple)
		turn_world(rig, "bip01 tail1", Vector3.UP, direction * -.61 * topple)
		turn_world(rig, "bip01 tail2", Vector3.RIGHT, -.27 * topple)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.37 * topple)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, .43 * topple)
		return
	if group == 1:
		fold_wings(rig, .92 + .03 * stride)
		turn_world(rig, "bip01 neck2", Vector3.RIGHT, .032 * stride)
		turn_world(rig, "bip01 tail1", Vector3.UP, .034 * stride)
		return
	if group == 28:
		var push := smoothstep(.30, .65, phase)
		fold_wings(rig, .92 * (1.0 - push))
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.29 * push)
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -.33 * push)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -.33 * push)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, .32 * push)
		return
	fold_wings(rig, .92 - (.77 if group in [4, 15, 27] else .42) * thrust,
		.48 * thrust if group == 4 else -.21 * thrust)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .16 * thrust - .18 * recoil)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.45 * thrust + .35 * recoil if group == 10 else -.34 * thrust)
	turn_world(rig, "bip01 head", Vector3.UP, (.44 if group == 4 else -.12) * thrust)
	turn_world(rig, "box14", Vector3.RIGHT, (.43 if group == 27 else .25) * thrust)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.30 * thrust if group == 4 else .0)
	turn_world(rig, "bip01 tail1", Vector3.UP, (.73 if group == 30 else .11) * thrust)
	turn_world(rig, "bip01 tail2", Vector3.UP, (.48 if group == 30 else .08) * thrust)


func fold_wings(rig: Skeleton3D, fold: float, asymmetric := 0.0) -> void:
	for side: int in 2:
		var sign := 1.0 if side == 0 else -1.0
		var outer := "dummy-l_wing" if side == 0 else "dummy-r_wing"
		var root_joint := "box20" if side == 0 else "box01"
		var tip := "box24" if side == 0 else "box19"
		var tail := rig.to_global(rig.get_bone_global_pose(45).origin)
		var chest := rig.to_global(rig.get_bone_global_pose(7).origin)
		var rear := Vector3(tail.x - chest.x, 0.0, tail.z - chest.z).normalized()
		var right := rear.cross(Vector3.UP)
		if right.dot(Vector3.RIGHT) < 0.0:
			right = -right
		aim_wing(rig, root_joint, outer, rear * .92 + right * (sign * .36) + Vector3.UP * (.15 + sign * asymmetric), fold)
		aim_wing(rig, outer, tip, rear * .96 + right * (sign * .24) + Vector3.UP * (.10 + sign * asymmetric), fold)


func aim_wing(rig: Skeleton3D, joint: String, tip: String, direction: Vector3, amount: float) -> void:
	var joint_id := rig.find_bone(joint)
	var pose := rig.get_bone_global_pose(joint_id)
	var from := (rig.get_bone_global_pose(rig.find_bone(tip)).origin - pose.origin).normalized()
	var to := (rig.global_basis.inverse() * direction).normalized()
	var rotation := Quaternion.IDENTITY.slerp(Quaternion(from, to), amount)
	pose.basis = Basis(rotation) * pose.basis
	rig.set_bone_global_pose(joint_id, pose)
	rig.force_update_all_bone_transforms()


func fold_gait(animator: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], label: String) -> Animation:
	var clip := animator.get_animation(label).duplicate(true) as Animation
	var prefix := animator.get_node(animator.root_node).get_path_to(rig)
	var tracks := {}
	for name: String in ["box20", "box01", "dummy-l_wing", "dummy-r_wing"]:
		var path := NodePath("%s:%s" % [prefix, name])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
		tracks[rig.find_bone(name)] = track
	var root_joint := rig.find_bone("bip01")
	var root_path := NodePath("%s:bip01" % prefix)
	var position := clip.find_track(root_path, Animation.TYPE_POSITION_3D)
	if position < 0:
		position = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(position, root_path)
	for key in range(clip.track_get_key_count(position) - 1, -1, -1):
		clip.track_remove_key(position, key)
	animator.play(label, .0)
	animator.advance(.0)
	for frame: int in 41:
		var progress := float(frame) / 40.0
		var time := progress * clip.length
		animator.seek(time, true)
		rig.force_update_all_bone_transforms()
		fold_wings(rig, .96 + .02 * cos(progress * TAU))
		var gap := INF
		for skin: Dictionary in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		var hip := rig.get_bone_global_pose(root_joint)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (.004 - gap)
		rig.set_bone_global_pose(root_joint, hip)
		clip.position_track_insert_key(position, time, rig.get_bone_pose_position(root_joint))
		for joint: int in tracks:
			clip.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(joint))
	return clip


func refit(mesh: MeshInstance3D, rig: Skeleton3D) -> int:
	var input := mesh.mesh
	var output := ArrayMesh.new()
	var processed := 0
	for surface in input.get_surface_count():
		var arrays := input.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var stride := weights.size() / vertices.size()
		var colours := PackedColorArray()
		colours.resize(vertices.size())
		for i in vertices.size():
			var wing := 0.0
			var head := 0.0
			var tail := 0.0
			var horn := 0.0
			for slot in stride:
				var j := i * stride + slot
				var bind := mesh.skin.get_bind_bone(bones[j])
				if bind < 0:
					bind = rig.find_bone(mesh.skin.get_bind_name(bones[j]))
				if bind in Wings:
					wing += weights[j]
				elif bind in Face:
					head += weights[j]
					if bind >= 14:
						horn += weights[j]
				elif bind >= 42 and bind <= 45:
					tail += weights[j]
			var point := vertices[i]
			var stretch := Vector3(1.0 + wing * .19, 1.0 + wing * .17 + tail * .12, 1.0 + head * .15)
			vertices[i] = point * stretch
			normals[i] = (normals[i] / stretch).normalized()
			if not tangents.is_empty():
				var j := i * 4
				var tangent := Vector3(tangents[j], tangents[j + 1], tangents[j + 2]) * stretch
				tangent = (tangent - normals[i] * normals[i].dot(tangent)).normalized()
				tangents[j] = tangent.x
				tangents[j + 1] = tangent.y
				tangents[j + 2] = tangent.z
			var dark := Color(.35, .43, .47)
			var scarlet := Color(.83, .34, .24)
			var brass := Color(.89, .70, .35)
			colours[i] = dark.lerp(scarlet, smoothstep(.05, .90, wing)).lerp(brass, smoothstep(.12, .80, horn))
			processed += 1
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_COLOR] = colours
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
		output.add_surface_from_arrays(input.surface_get_primitive_type(surface), arrays, [], {}, flags)
		var material := input.surface_get_material(surface).duplicate() as StandardMaterial3D
		var atlas := material.albedo_texture.get_image()
		if atlas.is_compressed():
			assert(atlas.decompress() == OK)
		atlas.convert(Image.FORMAT_RGBA8)
		for y in atlas.get_height():
			for x in atlas.get_width():
				var pixel := atlas.get_pixel(x, y)
				var tone := .1 + pow(maxf(pixel.r, maxf(pixel.g, pixel.b)), .8) * .86
				atlas.set_pixel(x, y, Color(tone, tone, tone, pixel.a))
		atlas.generate_mipmaps()
		material.albedo_texture = ImageTexture.create_from_image(atlas)
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.albedo_color = Color.WHITE
		material.roughness = .79
		output.surface_set_material(surface, material)
	mesh.mesh = output
	return processed
