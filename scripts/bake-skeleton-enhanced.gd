# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/skeleton-mongbat/"
const SkeletonClips := {4: "SkeletonCastingStep", 23: "SkeletonAssemble", 26: "SkeletonSkullCheck",
	27: "SkeletonLooseGuard", 28: "SkeletonReadyStagger"}
const SkeletonLengths := {4: .60, 23: 1.0, 26: .90, 27: .80, 28: .40}
const SkeletonJoints := ["bip01", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const JoinPhase := .60

func run() -> void:
	var row := Registry.entry(50)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
		for group: int in SkeletonClips:
			var motion := fit_grounded(player, rig, skins, SkeletonLengths[group], "bip01", SkeletonJoints,
				pose_skeleton.bind(group), .004)
			assert(library.add_animation(SkeletonClips[group], motion) == OK)
		var assembly := library.get_animation(SkeletonClips[23])
		player.play(SkeletonClips[23], 0.0)
		player.advance(0.0)
		player.seek(JoinPhase * assembly.length, true)
		rig.force_update_all_bone_transforms()
		var pieces := make_assembly(model, body, rig, player, assembly)
		assert(pieces == 15)
		verify_base_clips(player, source)
		player.stop()
		body.visible = true
		model.get_node("AssemblyPieces").visible = false
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var output := Folder + "50-%s.scn" % treatment
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("SKELETON ENHANCED ", treatment, ": ", pieces, " original pieces, five authored fits")
	quit()

func make_assembly(model: Node3D, body: MeshInstance3D, rig: Skeleton3D, player: AnimationPlayer,
		clip: Animation) -> int:
	assert(body.mesh.get_surface_count() == 1)
	var source := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var faces: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var components := split_components(vertices, faces)
	var layer := Node3D.new()
	layer.name = "AssemblyPieces"
	layer.visible = false
	model.add_child(layer)
	layer.owner = model
	var animation_root := player.get_node(player.root_node)
	add_visibility(clip, animation_root.get_path_to(layer), true, false)
	add_visibility(clip, animation_root.get_path_to(body), false, true)
	var source_material := body.mesh.surface_get_material(0)
	var poses := posed_vertices(source, body.skin, rig, model)
	var face_groups := group_faces(components, faces, vertices.size())
	for index in components.size():
		var piece := make_piece(index, face_groups[index], source, poses, source_material)
		layer.add_child(piece)
		piece.owner = model
		add_piece_motion(model, clip, animation_root.get_path_to(piece), piece, index)
	return components.size()

func posed_vertices(source: Array, skin: Skin, rig: Skeleton3D, model: Node3D) -> Dictionary:
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var joints: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var stride := joints.size() / vertices.size()
	var to_model := model.global_transform.affine_inverse() * rig.global_transform
	var binds: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var joint := skin.get_bind_bone(bind)
		if joint < 0:
			joint = rig.find_bone(skin.get_bind_name(bind))
		binds.append(to_model * rig.get_bone_global_pose(joint) * skin.get_bind_pose(bind))
	var positions := PackedVector3Array()
	var directions := PackedVector3Array()
	for index in vertices.size():
		var point := Vector3.ZERO
		var normal := Vector3.ZERO
		for influence in stride:
			var slot := index * stride + influence
			if weights[slot] > 0.0:
				var pose := binds[joints[slot]]
				point += (pose * vertices[index]) * weights[slot]
				normal += (pose.basis * normals[index]) * weights[slot]
		positions.append(point)
		directions.append(normal.normalized())
	return {"positions": positions, "directions": directions}

func group_faces(components: Array, faces: PackedInt32Array, size: int) -> Array:
	var groups := []
	var labels := PackedInt32Array()
	labels.resize(size)
	for group in components.size():
		groups.append(PackedInt32Array())
		for vertex: int in components[group]:
			labels[vertex] = group
	for triangle in range(0, faces.size(), 3):
		var group := labels[faces[triangle]]
		assert(labels[faces[triangle + 1]] == group and labels[faces[triangle + 2]] == group)
		for vertex in range(triangle, triangle + 3):
			groups[group].append(faces[vertex])
	return groups

func make_piece(index: int, faces: PackedInt32Array, source: Array, poses: Dictionary, material: Material) -> MeshInstance3D:
	var box := AABB(poses.positions[faces[0]], Vector3.ZERO)
	for vertex in faces:
		box = box.expand(poses.positions[vertex])
	var center := box.get_center()
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var texture_coordinates := PackedVector2Array()
	for vertex in faces:
		positions.append(poses.positions[vertex] - center)
		normals.append(poses.directions[vertex])
		texture_coordinates.append(source[Mesh.ARRAY_TEX_UV][vertex])
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = positions
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = texture_coordinates
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	mesh.surface_set_material(0, material)
	var part := MeshInstance3D.new()
	part.name = "Piece%02d" % index
	part.mesh = mesh
	part.position = center
	return part

func add_visibility(clip: Animation, path: NodePath, early: bool, late: bool) -> void:
	var channel := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(channel, NodePath("%s:visible" % path))
	clip.value_track_set_update_mode(channel, Animation.UPDATE_DISCRETE)
	clip.track_insert_key(channel, 0.0, early)
	clip.track_insert_key(channel, JoinPhase * clip.length, late)

func add_piece_motion(model: Node3D, clip: Animation, path: NodePath, piece: MeshInstance3D, index: int) -> void:
	var rotation := clip.add_track(Animation.TYPE_ROTATION_3D)
	var position := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(rotation, path)
	clip.track_set_path(position, path)
	var start_rotation := Quaternion(Vector3.UP, float(index) * 1.43) * Quaternion(Vector3.RIGHT, float(index % 4 - 2) * .53)
	var radial := float(index) * 2.3999632
	var scatter := Vector3(cos(radial), 0.0, sin(radial)) * (.20 + .51 * sqrt(float(index) / 14.0))
	var floor_gap := INF
	var positions: PackedVector3Array = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in positions:
		floor_gap = minf(floor_gap, (model.global_basis * (start_rotation * point)).y)
	scatter.y = .014 - floor_gap
	var gathered := piece.position
	var start := model.to_local(scatter)
	var lift := model.global_basis.inverse() * Vector3.UP
	for frame in 49:
		var phase := JoinPhase * frame / 48.0
		var catch := smoothstep(.20 + float(index % 4) * .025, JoinPhase, phase)
		var jump := sin(PI * catch) * (.07 + .018 * float(index % 4))
		var time := phase * clip.length
		clip.rotation_track_insert_key(rotation, time, start_rotation.slerp(Quaternion.IDENTITY, catch))
		clip.position_track_insert_key(position, time, start.lerp(gathered, catch) + lift * jump)
	if index not in [1, 5, 11]:
		var visibility := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(visibility, NodePath("%s:visible" % path))
		clip.value_track_set_update_mode(visibility, Animation.UPDATE_DISCRETE)
		clip.track_insert_key(visibility, 0.0, false)
		clip.track_insert_key(visibility, (.12 + .012 * float(index % 5)) * clip.length, true)

func pose_skeleton(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	match group:
		4:
			var reach := smoothstep(.04, .41, phase) * (1.0 - smoothstep(.50, .96, phase))
			turn_world(rig, "bip01 spine", Vector3.UP, .49 * pulse)
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, .38 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -2.15 * reach)
			turn_world(rig, "bip01 r forearm", Vector3.RIGHT, .86 * reach)
			turn_world(rig, "bip01 l upperarm", Vector3.BACK, .51 * pulse)
			turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -.65 * pulse)
			turn_world(rig, "bip01 l calf", Vector3.RIGHT, .82 * pulse)
		23:
			var kneel := 1.0 - smoothstep(.54, .99, phase)
			turn_world(rig, "bip01", Vector3.RIGHT, .46 * kneel)
			turn_world(rig, "bip01 spine", Vector3.RIGHT, .48 * kneel)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -.46 * kneel)
			for side: String in ["l", "r"]:
				turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.96 * kneel)
				turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.51 * kneel)
				turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.83 * kneel)
				turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.52 * kneel)
				turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.43 * kneel)
		26:
			var inspect := smoothstep(.06, .28, phase) * (1.0 - smoothstep(.77, .99, phase))
			turn_world(rig, "bip01 neck", Vector3.UP, -.32 * inspect)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -.16 * inspect)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -1.12 * inspect)
			turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -.78 * inspect)
		27:
			var tense := .40 + .52 * pulse
			turn_world(rig, "bip01 spine", Vector3.RIGHT, .43 * tense)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -.29 * tense)
			for side: String in ["l", "r"]:
				var sign_x := 1.0 if side == "l" else -1.0
				turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * 1.01 * tense)
				turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.72 * tense)
		28:
			var guard := smoothstep(.10, .88, phase)
			turn_world(rig, "bip01 spine", Vector3.RIGHT, .36 * guard)
			turn_world(rig, "bip01 spine1", Vector3.UP, -.27 * guard)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -.25 * guard)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.88 * guard)
			turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -.59 * guard)

static func split_components(vertices: PackedVector3Array, faces: PackedInt32Array) -> Array:
	var parents := PackedInt32Array()
	parents.resize(vertices.size())
	var locations := {}
	for vertex in vertices.size():
		parents[vertex] = vertex
		var cell := Vector3i((vertices[vertex] * 100000.0).round())
		if locations.has(cell):
			join(parents, vertex, locations[cell])
		else:
			locations[cell] = vertex
	for face in range(0, faces.size(), 3):
		join(parents, faces[face], faces[face + 1])
		join(parents, faces[face], faces[face + 2])
	var parts := {}
	for vertex in vertices.size():
		var label := leader(parents, vertex)
		if not parts.has(label):
			parts[label] = []
		parts[label].append(vertex)
	var components := parts.values()
	components.sort_custom(func(a: Array, b: Array): return a.size() > b.size())
	return components

static func join(parents: PackedInt32Array, a: int, b: int) -> void:
	parents[leader(parents, a)] = leader(parents, b)

static func leader(parents: PackedInt32Array, vertex: int) -> int:
	while parents[vertex] != vertex:
		parents[vertex] = parents[parents[vertex]]
		vertex = parents[vertex]
	return vertex
