# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Rebuild the Enhanced silhouette on the original deforming Ice Elemental.

const Segments := 6
const BladeJoint := {"l": "ice crystal blade left", "r": "ice crystal blade right"}
var surface := SurfaceTool.new()
var skin := Skin.new()
var bindings := {}


func build(actor: Node3D, rig: Skeleton3D) -> MeshInstance3D:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(ice_material())
	var head := point(rig, "bip01 head")
	for index in 5:
		var x := float(index - 2)
		var root := head + Vector3(x * .048, .102, -.055 + .014 * absf(x))
		var peak := root + Vector3(x * .037, .29 - .044 * absf(x), -.14)
		shard(rig, "bip01 head", root, peak, .061 - .007 * absf(x), .78)
	var chest := point(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var shoulder_name := "bip01 %s upperarm" % side
		var shoulder := point(rig, shoulder_name)
		for index in 3:
			var root := shoulder + Vector3(.065 * sign_x, .025, .098 - .092 * index)
			var peak := root + Vector3(sign_x * (.20 + .062 * index), .18 + .055 * index, -.10)
			shard(rig, shoulder_name, root, peak, .106 - .013 * index, .74)
		var ribs := chest + Vector3(.072 * sign_x, -.16, .095)
		shard(rig, "bip01 spine2", ribs, ribs + Vector3(.18 * sign_x, .32, .015), .107, .45)
		var hand_name := "bip01 %s hand" % side
		var hand := point(rig, hand_name)
		var grip := point(rig, "cp_grasp_%shand" % side)
		var aim := (grip - hand).normalized()
		var blade_name: String = BladeJoint[side]
		var blade := rig.add_bone(blade_name)
		rig.set_bone_parent(blade, rig.find_bone(hand_name))
		rig.force_update_all_bone_transforms()
		var blade_root := hand - aim * .105
		var blade_tip := hand + aim * .61 + Vector3(.038 * sign_x, 0, .047)
		shard(rig, blade_name, blade_root, blade_tip, .125, .38)
		shard(rig, blade_name, hand + Vector3(.060 * sign_x, 0, .01),
			hand + aim * .42 + Vector3(.119 * sign_x, 0, .022), .076, .50)
		var shin_name := "bip01 %s calf" % side
		var shin := point(rig, shin_name)
		var ankle := point(rig, "bip01 %s foot" % side)
		var cuff := ankle.lerp(shin, .23) + Vector3(.032 * sign_x, 0, .056)
		shard(rig, shin_name, cuff, shin + Vector3(.15 * sign_x, .09, .09), .155, .79)
		shard(rig, shin_name, cuff + Vector3(.056 * sign_x, .052, -.012),
			shin.lerp(ankle, .25) + Vector3(.225 * sign_x, -.046, .11), .074, .62)
	var shell := MeshInstance3D.new()
	shell.name = "IceCrystalShell"
	shell.mesh = surface.commit()
	shell.skin = skin
	shell.skeleton = NodePath("..")
	rig.add_child(shell)
	shell.owner = actor
	return shell


static func local_tip(mesh: MeshInstance3D, rig: Skeleton3D, side: String) -> Vector3:
	var joint := rig.find_bone(BladeJoint[side])
	var arrays := mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var stride := weights.size() / points.size()
	var tip := Vector3.ZERO
	for index in points.size():
		if mesh.skin.get_bind_bone(weights[index * stride]) == joint and points[index].length_squared() > tip.length_squared():
			tip = points[index]
	assert(tip.length() > .35)
	return tip


func point(rig: Skeleton3D, name: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)


func shard(rig: Skeleton3D, name: String, start: Vector3, end: Vector3, width: float, thickness: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	if not bindings.has(bone):
		bindings[bone] = skin.get_bind_count()
		skin.add_bind(bone, Transform3D.IDENTITY)
	var bind: int = bindings[bone]
	var local := (rig.global_transform * rig.get_bone_global_pose(bone)).affine_inverse()
	var axis := (end - start).normalized()
	var across := axis.cross(Vector3.BACK).normalized()
	if across.is_zero_approx():
		across = Vector3.RIGHT
	var depth := axis.cross(across).normalized()
	var shoulder := start.lerp(end, .24)
	var rings: Array[Array] = []
	for center: Vector3 in [start, shoulder]:
		var ring: Array[Vector3] = []
		var scale := .65 if center == start else 1.0
		for edge in Segments:
			var angle := TAU * edge / Segments
			ring.append(local * (center + width * scale * (cos(angle) * across + sin(angle) * depth * thickness)))
		rings.append(ring)
	for edge in Segments:
		var next := (edge + 1) % Segments
		var a: Vector3 = rings[0][edge]
		var b: Vector3 = rings[0][next]
		var c: Vector3 = rings[1][edge]
		var d: Vector3 = rings[1][next]
		var tint := float(edge) / Segments
		facet(bind, a, b, local * start, tint, .0, .24, .0)
		facet(bind, a, c, d, tint, .0, .24, .24)
		facet(bind, a, d, b, tint, .0, .24, .0)
		facet(bind, c, local * end, d, tint, .24, 1.0, .24)


func facet(bind: int, a: Vector3, b: Vector3, c: Vector3, tint: float, u: float, v: float, w: float) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var points := [a, b, c]
	var uv := [u, v, w]
	for index in 3:
		surface.set_normal(normal)
		surface.set_uv(Vector2(tint + index * .016, uv[index]))
		surface.set_bones(PackedInt32Array([bind, 0, 0, 0]))
		surface.set_weights(PackedFloat32Array([1.0, 0, 0, 0]))
		surface.add_vertex(points[index])


func ice_material() -> StandardMaterial3D:
	var texture := Image.create(48, 48, false, Image.FORMAT_RGB8)
	for y in texture.get_height():
		for x in texture.get_width():
			var rise := float(y) / (texture.get_height() - 1)
			var facet_tone := .18 * sin(TAU * x / 17.0) + .07 * sin(TAU * (x + y * .42) / 7.0)
			var colour := Color("#3d8ca9").lerp(Color("#e6fbff"), clampf(.22 + .65 * rise + facet_tone, 0.0, 1.0))
			texture.set_pixel(x, y, colour)
	texture.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(texture)
	material.roughness = .28
	return material
