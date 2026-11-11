# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Crown := [
	[Vector3(-.13, .15, .04), Vector3(-.39, .84, .06), .17],
	[Vector3(.11, .16, .04), Vector3(.39, .83, .08), .19],
	[Vector3(.0, .21, -.09), Vector3(.03, .88, -.30), .25],
	[Vector3(-.15, .12, -.11), Vector3(-.62, .68, -.31), .21],
	[Vector3(.16, .13, -.12), Vector3(.65, .64, -.26), .24],
	[Vector3(-.17, .01, -.16), Vector3(-.67, .31, -.58), .19],
	[Vector3(.17, .01, -.16), Vector3(.66, .38, -.56), .18],
	[Vector3(.00, .12, -.22), Vector3(.06, .55, -.76), .20],
]
const Shoulders := [
	[Vector3(.08, .06, -.09), Vector3(.85, .44, -.18), .22],
	[Vector3(.03, .11, -.17), Vector3(.45, .73, -.43), .20],
	[Vector3(-.02, -.01, -.22), Vector3(.32, .18, -.86), .17],
]
const Spine := [
	[Vector3(.0, -.02, -.21), Vector3(.00, .43, -.90), .20],
	[Vector3(-.10, -.12, -.17), Vector3(-.44, .26, -.78), .15],
	[Vector3(.10, -.12, -.17), Vector3(.44, .22, -.80), .15],
]


static func shape(mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var donor := mesh.mesh
	assert(donor.get_surface_count() == 1)
	var arrays: Array = donor.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var stride := joints.size() / positions.size()
	assert(stride == 4 or stride == 8)
	var world_to_mesh := mesh.global_transform.affine_inverse()
	var centers := {}
	var bind_indices := {}
	for index in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(index)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(index))
		assert(bone >= 0)
		var name := rig.get_bone_name(bone)
		centers[name] = rig.to_global(rig.get_bone_global_rest(bone).origin)
		bind_indices[name] = index
	var bend := {"upperarm": "forearm", "forearm": "hand", "thigh": "calf", "calf": "foot", "hand": "finger1"}
	var thickening := {"upperarm": .47, "forearm": .48, "thigh": .40, "calf": .33, "hand": .17}
	var head: Vector3 = centers["bip_01 head"]
	var torso: Vector3 = centers["bip_01 spine1"]
	for i in positions.size():
		var point := mesh.to_global(positions[i])
		var offset := Vector3.ZERO
		var crown := 0.0
		for influence in stride:
			var slot := i * stride + influence
			var weight := weights[slot]
			if weight <= 0.00001:
				continue
			var bone := mesh.skin.get_bind_bone(joints[slot])
			if bone < 0:
				bone = rig.find_bone(mesh.skin.get_bind_name(joints[slot]))
			var label := rig.get_bone_name(bone)
			var leaf := label.get_slice(" ", 2)
			if bend.has(leaf):
				var other := "bip_01 %s %s" % [label.get_slice(" ", 1), bend[leaf]]
				var start: Vector3 = centers[label]
				var line: Vector3 = centers[other] - start
				var radial := (point - start).slide(line.normalized())
				offset += radial * float(thickening[leaf]) * weight
			elif label == "bip_01 head":
				var relative := point - head
				var trim := smoothstep(.16, .44, relative.y)
				var compact := Vector3(relative.x * .68, .15 + relative.y * .12, relative.z * .49)
				offset += relative.lerp(compact, trim) * weight - relative * weight
				crown = maxf(crown, trim * weight)
			elif label.begins_with("bip_01 spine") or label.ends_with(" clavicle"):
				var width := (point - torso).slide(Vector3.UP)
				offset += Vector3(width.x * .34, 0.0, width.z * .29) * weight
		positions[i] = world_to_mesh * (point + offset)
		if crown > .54:
			uvs[i] = uvs[i].lerp(Vector2(.438, .751), smoothstep(.54, .89, crown))
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var result := ArrayMesh.new()
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	result.surface_set_material(0, donor.surface_get_material(0))
	var tips := SurfaceTool.new()
	tips.begin(Mesh.PRIMITIVE_TRIANGLES)
	for definition: Array in Crown:
		spike(tips, world_to_mesh, head, definition, bind_indices["bip_01 head"])
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var bone := "bip_01 %s clavicle" % side
		var shoulder: Vector3 = centers["bip_01 %s upperarm" % side]
		for definition: Array in Shoulders:
			var mirrored := [definition[0] * Vector3(sign_x, 1, 1), definition[1] * Vector3(sign_x, 1, 1), definition[2]]
			spike(tips, world_to_mesh, shoulder, mirrored, bind_indices[bone])
	for definition: Array in Spine:
		spike(tips, world_to_mesh, centers["bip_01 spine3"], definition, bind_indices["bip_01 spine3"])
	tips.generate_normals()
	tips.set_material(bone_surface())
	var spikes := MeshInstance3D.new()
	spikes.name = "BruteSpines"
	spikes.mesh = tips.commit()
	spikes.skin = mesh.skin
	spikes.skeleton = mesh.skeleton
	spikes.transform = mesh.transform
	mesh.get_parent().add_child(spikes)
	spikes.owner = mesh.owner
	mesh.mesh = result


static func spike(surface: SurfaceTool, world_to_mesh: Transform3D, pivot: Vector3, definition: Array, bind: int) -> void:
	const Sides := 8
	var base: Vector3 = pivot + definition[0]
	var axis: Vector3 = definition[1].normalized()
	var length: float = definition[2]
	var u := Vector3.UP.cross(axis).normalized()
	var v := axis.cross(u).normalized()
	var radius := length * .29
	for i in Sides:
		var angle := TAU * i / Sides
		var next := TAU * (i + 1) / Sides
		var left := u * cos(angle) + v * sin(angle)
		var right := u * cos(next) + v * sin(next)
		var a := base + left * radius
		var b := base + right * radius
		var c := base + axis * length * .53 + left * radius * .54
		var d := base + axis * length * .53 + right * radius * .54
		var end := base + axis * length - Vector3.BACK * length * .09
		for point: Vector3 in [a, b, c, c, b, d, c, d, end]:
			surface.set_bones(PackedInt32Array([bind, 0, 0, 0]))
			surface.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			surface.set_uv(Vector2(float(i) / Sides, (point - base).dot(axis) / length))
			surface.add_vertex(world_to_mesh * point)


static func bone_surface() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var texels := Image.create_empty(8, 16, false, Image.FORMAT_RGBA8)
	for y in texels.get_height():
		var colour := Color("#625b42").lerp(Color("#c5b994"), smoothstep(0.0, 1.0, y / 15.0))
		for x in texels.get_width():
			var variation := sin(x * 3.9 + y * 1.9) * .025
			texels.set_pixel(x, y, colour.lightened(variation) if variation >= 0 else colour.darkened(-variation))
	texels.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(texels)
	material.roughness = .87
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
