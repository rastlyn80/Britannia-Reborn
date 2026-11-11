# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Articulates the Third Dawn cover triangles without changing their closed skinning.

const Torso := ["bip01 pelvis", "spine 02", "spine 01"]
const WingSections := [Vector3(.23, 1.87, -.04), Vector3(.41, 1.84, -.42),
	Vector3(.53, 1.75, -.91), Vector3(.52, 1.60, -1.43), Vector3(.42, 1.42, -1.88),
	Vector3(.35, 1.34, -2.12)]
const WingWidths := [.045, .27, .37, .32, .18, .008]

var rig: Skeleton3D
var body: MeshInstance3D
var skin: Skin
var cover: Array[Dictionary] = [{}, {}]
var membrane: Array[int] = []
var membrane_bind: Array[int] = []
var pivot: Array[Vector3] = []


func install(model: Node3D, skeleton: Skeleton3D) -> void:
	rig = skeleton
	body = model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = body.skin.duplicate() as Skin
	var torso_binds := {}
	for bind in skin.get_bind_count():
		var parent := skin.get_bind_bone(bind)
		var label := rig.get_bone_name(parent) if parent >= 0 else str(skin.get_bind_name(bind))
		if label in Torso:
			torso_binds[bind] = rig.find_bone(label)
	assert(Torso.all(func(label: String) -> bool: return rig.find_bone(label) in torso_binds.values()),
		"Source torso bind map is %s" % str(torso_binds))
	for side in [-1, 1]:
		var slot := int(side > 0)
		pivot.append(Vector3(side * .30, 2.04, .08))
		var joint_by_parent := {}
		for bind: int in torso_binds:
			var parent: int = torso_binds[bind]
			if not joint_by_parent.has(parent):
				joint_by_parent[parent] = add_bone("cover_%d_%d" % [slot, parent], parent, Transform3D.IDENTITY)
			var bone: int = joint_by_parent[parent]
			cover[slot][bind] = Vector2i(bone, skin.get_bind_count())
			# This child has its parent's exact rest and animated pose when closed.
			skin.add_bind(bone, skin.get_bind_pose(bind))
		var base := rig.find_bone(Torso[0])
		var hinge := Vector3(side * WingSections[0].x, WingSections[0].y, WingSections[0].z)
		var rest := rig.get_bone_global_rest(base).affine_inverse() * Transform3D(Basis.IDENTITY, rig.to_local(hinge))
		var wing := add_bone("hindwing_%d" % slot, base, rest)
		membrane.append(wing)
		membrane_bind.append(skin.get_bind_count())
		skin.add_bind(wing, rig.get_bone_global_rest(wing).affine_inverse())
	partition_covers(torso_binds)
	add_membranes()


func add_bone(label: String, parent: int, rest: Transform3D) -> int:
	var bone := rig.add_bone(label)
	rig.set_bone_parent(bone, parent)
	rig.set_bone_rest(bone, rest)
	rig.reset_bone_pose(bone)
	return bone


func partition_covers(torso_binds: Dictionary) -> void:
	var material := body.mesh.surface_get_material(0)
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := weights.size() / vertices.size()
	assert(stride in [4, 8] and weights.size() == vertices.size() * stride and indices.size() % 3 == 0,
		"Source surface has %d vertices, %d weights and %d indices" % [vertices.size(), weights.size(), indices.size()])
	var abdomen_points := PackedVector3Array()
	var abdomen_normals := PackedVector3Array()
	var abdomen_uvs := PackedVector2Array()
	var abdomen_bones := PackedInt32Array()
	var abdomen_weights := PackedFloat32Array()
	var counts := Vector2i.ZERO
	var sides := PackedInt32Array()
	for first in range(0, indices.size(), 3):
		var middle := Vector3.ZERO
		var torso_weight := 0.0
		for corner in 3:
			var vertex := indices[first + corner]
			middle += body.to_global(vertices[vertex]) / 3.0
			for influence in stride:
				var at := vertex * stride + influence
				if torso_binds.has(bones[at]):
					torso_weight += weights[at] / 3.0
		var fits := torso_weight > .999 and middle.z <= .38 and middle.y >= maxf(1.05, 1.62 + .23 * middle.z)
		var side := int(middle.x >= 0.0) if fits else -1
		sides.append(side)
		if not fits:
			continue
		counts[side] += 1
		for corner in 3:
			var vertex := indices[first + corner]
			var offset := vertex * stride
			abdomen_bones.append_array(bones.slice(offset, offset + stride))
			abdomen_weights.append_array(weights.slice(offset, offset + stride))
			abdomen_uvs.append(uvs[vertex])
			abdomen_normals.append(normals[vertex])
			var p := body.to_global(vertices[vertex])
			p.x *= .97
			p.y -= .135 + .14 * (1.0 - smoothstep(.27, 1.32, absf(p.x)))
			abdomen_points.append(body.to_local(p))
	assert(counts.x > 0 and absi(counts.x - counts.y) <= maxi(2, counts.x / 30), "Unbalanced source cover partition %s" % counts)
	var mapping := split_seams(arrays, indices, sides, vertices.size())
	bones = arrays[Mesh.ARRAY_BONES]
	weights = arrays[Mesh.ARRAY_WEIGHTS]
	for key: Vector2i in mapping:
		if key.y < 0:
			continue
		for influence in stride:
			var at: int = mapping[key] * stride + influence
			if weights[at] > 0.0:
				assert(cover[key.y].has(bones[at]), "A selected cover corner has a non-torso influence")
				bones[at] = cover[key.y][bones[at]].y
	arrays[Mesh.ARRAY_BONES] = bones
	var rebased := ArrayMesh.new()
	var format := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
	rebased.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	rebased.surface_set_material(0, material)
	body.mesh = rebased
	body.skin = skin
	var abdomen_arrays := []
	abdomen_arrays.resize(Mesh.ARRAY_MAX)
	abdomen_arrays[Mesh.ARRAY_VERTEX] = abdomen_points
	abdomen_arrays[Mesh.ARRAY_NORMAL] = abdomen_normals
	abdomen_arrays[Mesh.ARRAY_TEX_UV] = abdomen_uvs
	abdomen_arrays[Mesh.ARRAY_BONES] = abdomen_bones
	abdomen_arrays[Mesh.ARRAY_WEIGHTS] = abdomen_weights
	var abdomen := ArrayMesh.new()
	abdomen.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, abdomen_arrays, [], {}, format)
	abdomen.surface_set_material(0, material)
	add_surface("UnderCarapace", abdomen)
	print("GIANT BEETLE COVERS ", counts, " existing triangles")


func split_seams(arrays: Array, indices: PackedInt32Array, sides: PackedInt32Array, vertex_count: int) -> Dictionary:
	var mapping := {}
	var claimed := {}
	var additions := PackedInt32Array()
	for corner in indices.size():
		var vertex := indices[corner]
		var key := Vector2i(vertex, sides[corner / 3])
		if not mapping.has(key):
			mapping[key] = vertex
			if claimed.has(vertex):
				mapping[key] = vertex_count + additions.size()
				additions.append(vertex)
			claimed[vertex] = true
		indices[corner] = mapping[key]
	for channel in Mesh.ARRAY_INDEX:
		if arrays[channel] == null or arrays[channel].is_empty():
			continue
		var values = arrays[channel]
		assert(values.size() % vertex_count == 0)
		var stride: int = values.size() / vertex_count
		for vertex in additions:
			values.append_array(values.slice(vertex * stride, (vertex + 1) * stride))
		arrays[channel] = values
	arrays[Mesh.ARRAY_INDEX] = indices
	return mapping


func add_surface(label: String, mesh: ArrayMesh) -> void:
	var surface := MeshInstance3D.new()
	surface.name = label
	surface.transform = body.transform
	surface.skeleton = body.skeleton
	surface.skin = skin
	surface.mesh = mesh
	body.get_parent().add_child(surface)
	surface.owner = body.owner


func add_membranes() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(wing_material())
	for side in [-1, 1]:
		var slot := int(side > 0)
		var bind := membrane_bind[slot]
		assert(skin.get_bind_bone(bind) == membrane[slot])
		for span in WingSections.size() - 1:
			for rib in 6:
				var a := Vector2(float(rib) / 6.0, float(span) / (WingSections.size() - 1))
				var b := Vector2(float(rib + 1) / 6.0, a.y)
				var c := Vector2(a.x, float(span + 1) / (WingSections.size() - 1))
				var d := Vector2(b.x, c.y)
				var corners := [a, b, d, a, d, c, a, d, b, a, c, d]
				for corner in corners.size():
					var uv: Vector2 = corners[corner]
					var section := span if uv.y == a.y else span + 1
					var p: Vector3 = WingSections[section]
					p.x = side * (p.x + (uv.x * 2.0 - 1.0) * WingWidths[section])
					p.y += .11 * sin(PI * uv.x) * sin(PI * uv.y)
					surface.set_bones(PackedInt32Array([bind, 0, 0, 0]))
					surface.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
					surface.set_smooth_group(slot * 2 + int(corner >= 6))
					surface.set_uv(uv)
					surface.add_vertex(body.to_local(p))
	surface.generate_normals()
	add_surface("HindwingMembranes", surface.commit())


func wing_material() -> StandardMaterial3D:
	var image := Image.create_empty(128, 128, true, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var along := float(y) / 127.0
			var across := float(x) / 127.0
			var radial := absf(sin((across + .14 * sin(PI * along)) * TAU * 2.0))
			var branches := absf(sin(TAU * (along * 6.0 + .7 * across + .2 * sin(TAU * across))))
			var vein := maxf(1.0 - smoothstep(.015, .13, radial), .52 * (1.0 - smoothstep(.02, .14, branches)))
			var colour := Color("b7bca3").lerp(Color("e1d4a8"), along).lerp(Color("7d795f"), vein * .73)
			image.set_pixel(x, y, colour)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = .66
	return material


func joints() -> Array[int]:
	var result: Array[int] = []
	for side in 2:
		for link: Vector2i in cover[side].values():
			if link.x not in result:
				result.append(link.x)
		result.append(membrane[side])
	return result


func spread(amount: float, phase: float) -> void:
	var base := rig.find_bone(Torso[0])
	var follow := rig.get_bone_global_pose(base) * rig.get_bone_global_rest(base).affine_inverse()
	for side in [-1, 1]:
		var slot := int(side > 0)
		var flutter := sin(TAU * phase * 4.0 + slot * .33)
		var cover_turn := Basis(Vector3.UP, -side * .26 * amount) * Basis(Vector3.RIGHT, (.89 + .035 * flutter) * amount)
		var wing_turn := Basis(Vector3.UP, -side * (1.07 + .12 * flutter) * amount) * Basis(Vector3.RIGHT, (.52 + .14 * flutter) * amount)
		var anchor := follow * rig.to_local(pivot[slot])
		var turn := rig.global_basis.inverse() * cover_turn * rig.global_basis
		var moved: Array[int] = []
		for link: Vector2i in cover[slot].values():
			if link.x in moved:
				continue
			moved.append(link.x)
			var parent := rig.get_bone_parent(link.x)
			rig.set_bone_global_pose(link.x, Transform3D(turn, anchor - turn * anchor) * rig.get_bone_global_pose(parent))
		var wing := membrane[slot]
		var pose := rig.get_bone_global_pose(wing)
		pose.basis = rig.global_basis.inverse() * wing_turn * rig.global_basis * pose.basis
		rig.set_bone_global_pose(wing, pose)
