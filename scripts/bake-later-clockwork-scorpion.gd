# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {
	"ClockworkBrace": [15, .70], "ClockworkScan": [23, 1.24], "ReadyStance": [25, 1.55],
	"ClockworkLift": [26, .82], "ClockworkTestClaw": [27, 1.10], "ClockworkArm": [28, .91],
	"ClockworkSettle": [2, .97], "ClockworkSpasm": [3, 1.23],
}
const Joints := ["bip01", "bip01 spine1", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm",
	"bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 tail1", "bip01 tail2",
	"bip01 tail3", "bip01 tail4"]

# The group 3 frames scatter the claws, tail and legs around the low chassis.
# Each region keeps its original skin until its joints separate.
const Pieces := {
	"bip01 l clavicle": [Vector3(.57, 0, -.30), Vector3(.22, .52, .50), .28, .31],
	"bip01 r clavicle": [Vector3(-.54, 0, -.49), Vector3(-.16, -.35, -.50), .23, .35],
	"bip01 tail": [Vector3(.38, 0, .72), Vector3(-1.92, .28, .25), .34, .27],
	"bone_hind07": [Vector3(-.61, 0, -.31), Vector3(.46, -.52, -.62), .25, .26],
	"bone_hind06": [Vector3(.55, 0, -.09), Vector3(.35, .63, .94), .19, .29],
	"bone_hind": [Vector3(-.48, 0, .09), Vector3(.69, .78, -.54), .18, .30],
	"bone_hind04": [Vector3(.65, 0, .17), Vector3(.42, -.12, .58), .21, .25],
	"bone_hind01": [Vector3(-.68, 0, .27), Vector3(.45, -.73, -.56), .22, .33],
	"bone_hind05": [Vector3(.38, 0, .42), Vector3(.51, .55, .61), .24, .27],
	"bip01 r thigh": [Vector3(-.43, 0, .64), Vector3(.28, -.49, -.54), .15, .32],
	"bip01 l thigh": [Vector3(.69, 0, .51), Vector3(.51, .44, .78), .25, .28],
}


func run() -> void:
	var source := Registry.entry(48)
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style: String in ["original", "rounded", "modern"]:
		var path := Registry.asset_path(source, style)
		assert(FileAccess.get_sha256(path) == source.asset_sha256[style])
		var model := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		model.scale *= Vector3(.64, .76, .56)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		for surface in geometry.get_surface_count():
			var base := geometry.surface_get_material(surface) as StandardMaterial3D
			geometry.surface_set_material(surface, plated_material(base))
		mesh.mesh = geometry
		var pieces := split_shell(mesh, rig)
		geometry = mesh.mesh as ArrayMesh
		add_core(geometry, mesh, rig)
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for name: String in Clips:
			var record: Array = Clips[name]
			var motion := fit_grounded(player, rig, [skin], record[1], "__root", Joints, pose_clockwork.bind(record[0]))
			if name == "ClockworkSpasm":
				add_breakup(player, rig, motion, pieces)
			assert(library.add_animation(name, motion) == OK)
		for name: String in ["Death", "Death2"]:
			library.remove_animation(name)
			assert(library.add_animation(name, library.get_animation("ClockworkSettle" if name == "Death" else "ClockworkSpasm")) == OK)
		assert(library.add_animation("ClockworkPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("717-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("CLOCKWORK SCORPION FIT: ", style, ", hash ", FileAccess.get_sha256(target))
	quit(0)


func split_shell(mesh: MeshInstance3D, rig: Skeleton3D) -> Array[Dictionary]:
	var source := mesh.mesh as ArrayMesh
	var shell := ArrayMesh.new()
	var skin := mesh.skin.duplicate() as Skin
	mesh.skin = skin
	var bind_count := skin.get_bind_count()
	var source_bones := PackedInt32Array()
	var piece_for_bind := PackedInt32Array()
	var pivots := {}
	var pieces: Array[Dictionary] = []
	for name: String in Pieces:
		var pivot := rig.find_bone(name)
		assert(pivot >= 0, name)
		pivots[pivot] = pieces.size()
		pieces.append({"name": name, "pivot": pivot, "copies": {}, "bindings": {}, "source_skin": {"surfaces": []}})
	for bind in bind_count:
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(skin.get_bind_name(bind))
		assert(bone >= 0)
		source_bones.append(bone)
		while bone >= 0 and not pivots.has(bone):
			bone = rig.get_bone_parent(bone)
		piece_for_bind.append(int(pivots.get(bone, -1)))
	var bind_poses: Array[Transform3D] = []
	for bind in bind_count:
		bind_poses.append(skin.get_bind_pose(bind))
	for piece: Dictionary in pieces:
		piece.source_skin.bones = source_bones
		piece.source_skin.bind_poses = bind_poses
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		split_surface(arrays, pieces, piece_for_bind, source_bones, skin, rig)
		var flags := source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		shell.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		shell.surface_set_material(surface, source.surface_get_material(surface))
	for piece: Dictionary in pieces:
		assert(not piece.copies.is_empty(), piece.name)
	mesh.mesh = shell
	return pieces


func split_surface(arrays: Array, pieces: Array[Dictionary], piece_for_bind: PackedInt32Array,
		source_bones: PackedInt32Array, skin: Skin, rig: Skeleton3D) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bones.size() / vertices.size()
	assert(stride in [4, 8] and indices.size() % 3 == 0)
	var mapping := {}
	var claimed := {}
	var additions := PackedInt32Array()
	var samples: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		var sample := {"points": PackedVector3Array(), "bindings": PackedInt32Array(),
			"weights": PackedFloat32Array(), "stride": stride}
		piece.source_skin.surfaces.append(sample)
		samples.append(sample)
	for first in range(0, indices.size(), 3):
		var votes := {}
		for corner in 3:
			var start := indices[first + corner] * stride
			for influence in range(start, start + stride):
				if weights[influence] > 0.0:
					var region := piece_for_bind[bones[influence]]
					votes[region] = float(votes.get(region, 0.0)) + weights[influence]
		var region := -1
		var best := float(votes.get(-1, 0.0))
		for candidate: int in votes:
			if float(votes[candidate]) > best:
				region = candidate
				best = votes[candidate]
		for corner in range(first, first + 3):
			var vertex := indices[corner]
			var key := Vector2i(vertex, region)
			if not mapping.has(key):
				mapping[key] = vertex
				if claimed.has(vertex):
					mapping[key] = vertices.size() + additions.size()
					additions.append(vertex)
				claimed[vertex] = true
			indices[corner] = mapping[key]
	for channel in Mesh.ARRAY_INDEX:
		if arrays[channel] == null or arrays[channel].is_empty():
			continue
		var values = arrays[channel]
		var width: int = values.size() / vertices.size()
		for vertex in additions:
			values.append_array(values.slice(vertex * width, (vertex + 1) * width))
		arrays[channel] = values
	bones = arrays[Mesh.ARRAY_BONES]
	weights = arrays[Mesh.ARRAY_WEIGHTS]
	for key: Vector2i in mapping:
		if key.y < 0:
			continue
		var piece := pieces[key.y]
		var sample := samples[key.y]
		var first: int = int(mapping[key]) * stride
		sample.points.append(vertices[key.x])
		sample.bindings.append_array(bones.slice(first, first + stride))
		sample.weights.append_array(weights.slice(first, first + stride))
		for influence in range(first, first + stride):
			if weights[influence] > 0.0:
				bones[influence] = copy_bind(piece, bones[influence], source_bones, skin, rig)
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bones


func copy_bind(piece: Dictionary, bind: int, source_bones: PackedInt32Array, skin: Skin, rig: Skeleton3D) -> int:
	if not piece.bindings.has(bind):
		var original := source_bones[bind]
		if not piece.copies.has(original):
			var copy := rig.add_bone("fracture_%d_%d" % [piece.pivot, original])
			rig.set_bone_parent(copy, original)
			rig.set_bone_rest(copy, Transform3D.IDENTITY)
			rig.reset_bone_pose(copy)
			piece.copies[original] = copy
		piece.bindings[bind] = skin.get_bind_count()
		skin.add_bind(piece.copies[original], skin.get_bind_pose(bind))
	return piece.bindings[bind]


func add_breakup(player: AnimationPlayer, rig: Skeleton3D, motion: Animation, pieces: Array[Dictionary]) -> void:
	var root_node := player.get_node(player.root_node)
	var rig_path := root_node.get_path_to(rig)
	var root_track := motion.find_track(NodePath("%s:__root" % rig_path), Animation.TYPE_POSITION_3D)
	assert(root_track >= 0)
	var drop := rig.global_basis.inverse() * Vector3.DOWN * .29
	for key in motion.track_get_key_count(root_track):
		var phase := motion.track_get_key_time(root_track, key) / motion.length
		var position: Vector3 = motion.track_get_key_value(root_track, key)
		motion.track_set_key_value(root_track, key, position + drop * smoothstep(.34, .89, phase))
	var library := player.get_animation_library("")
	assert(library.add_animation("FractureBake", motion.duplicate(true)) == OK)
	for piece: Dictionary in pieces:
		var tracks := {}
		for original: int in piece.copies:
			var path := NodePath("%s:%s" % [rig_path, rig.get_bone_name(piece.copies[original])])
			var placement := motion.add_track(Animation.TYPE_POSITION_3D)
			var rotation := motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(placement, path)
			motion.track_set_path(rotation, path)
			tracks[original] = Vector2i(placement, rotation)
		piece.tracks = tracks
	player.play("FractureBake", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var time := phase * motion.length
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		for piece: Dictionary in pieces:
			var transform := piece_motion(rig, piece, phase)
			for original: int in piece.tracks:
				var source := rig.get_bone_global_pose(original)
				var local := source.affine_inverse() * transform * source
				var tracks: Vector2i = piece.tracks[original]
				motion.position_track_insert_key(tracks.x, time, local.origin)
				motion.rotation_track_insert_key(tracks.y, time, local.basis.get_rotation_quaternion())
	player.stop()
	player.assigned_animation = "Idle"
	library.remove_animation("FractureBake")
	print("CLOCKWORK SCORPION BREAKUP: ", pieces.size(), " animated shell pieces")


func piece_motion(rig: Skeleton3D, piece: Dictionary, phase: float) -> Transform3D:
	var design: Array = Pieces[piece.name]
	var progress := clampf((phase - float(design[3])) / (.89 - float(design[3])), 0.0, 1.0)
	if progress <= 0.0:
		return Transform3D.IDENTITY
	var spread := 1.0 - pow(1.0 - progress, 2.0)
	var basis := rig.global_basis.orthonormalized()
	var angles: Vector3 = design[1]
	var rotation := basis.inverse() * Basis.from_euler(angles * spread) * basis
	var pivot := rig.get_bone_global_pose(piece.pivot).origin
	var offset: Vector3 = design[0]
	var inverse := rig.global_basis.inverse()
	var transform := Transform3D(rotation, pivot - rotation * pivot + inverse * (offset * spread))
	var minimum := Ground.minimum_plane_gap(piece.source_skin, rig, rig.global_transform * transform, Vector3.ZERO, Vector3.UP)
	var bounce := sin(progress * PI) * float(design[2])
	transform.origin += inverse * Vector3.UP * ((.006 - minimum) * smoothstep(0.0, .72, progress) + bounce)
	return transform


func plated_material(source: StandardMaterial3D) -> StandardMaterial3D:
	var atlas := source.albedo_texture.get_image()
	if atlas.is_compressed():
		assert(atlas.decompress() == OK)
	atlas.convert(Image.FORMAT_RGB8)
	for y in atlas.get_height():
		for x in atlas.get_width():
			var texel := atlas.get_pixel(x, y)
			var light := texel.get_luminance()
			var dark := Color("#231f22")
			var bronze := Color("#b67749")
			var sheen := smoothstep(.11, .73, light)
			atlas.set_pixel(x, y, dark.lerp(bronze, sheen))
	atlas.generate_mipmaps()
	var material := source.duplicate() as StandardMaterial3D
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.metallic = .68
	material.roughness = .65
	return material


func add_core(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var joint := rig.find_bone("bip01 spine2")
	var binding := -1
	for index in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(index) == joint or mesh.skin.get_bind_name(index) == "bip01 spine2":
			binding = index
			break
	assert(binding >= 0)
	var spark := StandardMaterial3D.new()
	var color := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	for y in 4:
		for x in 4:
			color.set_pixel(x, y, Color("#b63308").lerp(Color("#ffaf30"), y / 3.0))
	spark.albedo_texture = ImageTexture.create_from_image(color)
	spark.emission_enabled = true
	spark.emission = Color("#ff6619")
	spark.emission_energy_multiplier = .75
	var dome := SphereMesh.new()
	dome.radius = .28
	dome.height = .48
	dome.radial_segments = 20
	dome.rings = 10
	var atlas := dome.surface_get_arrays(0)
	var points: PackedVector3Array = atlas[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = atlas[Mesh.ARRAY_NORMAL]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var anchor := mesh.to_local(rig.to_global(rig.get_bone_global_rest(joint).origin))
	for index in points.size():
		points[index] = anchor + Vector3(points[index].x, -points[index].z, points[index].y + .26)
		normals[index] = Vector3(normals[index].x, -normals[index].z, normals[index].y)
		bones.append_array(PackedInt32Array([binding, 0, 0, 0]))
		weights.append_array(PackedFloat32Array([1, 0, 0, 0]))
	atlas[Mesh.ARRAY_VERTEX] = points
	atlas[Mesh.ARRAY_NORMAL] = normals
	atlas[Mesh.ARRAY_TANGENT] = null
	atlas[Mesh.ARRAY_BONES] = bones
	atlas[Mesh.ARRAY_WEIGHTS] = weights
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, atlas)
	geometry.surface_set_material(geometry.get_surface_count() - 1, spark)


func pose_clockwork(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.11, .41, phase) * (1.0 - smoothstep(.57, .95, phase))
	var collapsing := group in [2, 3]
	var settle := smoothstep(.15, .86, phase) if collapsing else 0.0
	var spasm := sin(phase * TAU * 3.0) * pulse if group == 3 else 0.0
	turn_world(rig, "bip01", Vector3.FORWARD, (-.28 if group == 2 else .53) * settle + .13 * spasm)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .19 * settle + .11 * pulse)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.60 * settle + .33 * pulse)
	turn_world(rig, "bip01 tail2", Vector3.UP, .40 * settle + .31 * spasm)
	turn_world(rig, "bip01 tail3", Vector3.RIGHT, -.52 * settle - .55 * pulse if group in [2, 3, 23] else .26 * pulse)
	turn_world(rig, "bip01 tail4", Vector3.UP, .19 * settle - .29 * spasm)
	for side: String in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.UP, sign * (.50 * settle + .26 * pulse))
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -.53 * pulse if group == 26 or group == 27 and side == "r" else -.14 * pulse)
		turn_world(rig, "bip01 " + side + " hand", Vector3.FORWARD, sign * (.21 * spasm + .22 * settle))
