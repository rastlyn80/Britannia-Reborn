# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Joints := ["hopper elytron left", "hopper elytron right", "hopper hindwing left", "hopper hindwing right"]
const Span := [0.0, .09, .20, .34, .49, .65, .79, .91, 1.0]
const Width := [.026, .075, .122, .156, .163, .143, .105, .055, .002]


func build(actor: Node3D, rig: Skeleton3D) -> MeshInstance3D:
	var skin := Skin.new()
	var mesh := ArrayMesh.new()
	var thorax := rig.find_bone("bip01 spine2")
	var anchor := rig.get_bone_global_pose(thorax)
	for membrane: int in 2:
		var sheet := SurfaceTool.new()
		sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
		sheet.set_material(wing_material(bool(membrane)))
		for side: int in 2:
			var sign_x := 1.0 if side == 0 else -1.0
			var bind := membrane * 2 + side
			var joint := rig.add_bone(Joints[bind])
			rig.set_bone_parent(joint, thorax)
			var world_root := rig.to_global(anchor.origin) + Vector3(sign_x * (.13 + .035 * membrane), .13 - .025 * membrane, .01)
			var world_axis := rig.global_basis.orthonormalized().inverse()
			var local := anchor.affine_inverse() * Transform3D(world_axis, rig.to_local(world_root))
			rig.set_bone_rest(joint, local)
			rig.reset_bone_pose(joint)
			skin.add_bind(joint, Transform3D.IDENTITY)
			var raw_scale := rig.global_basis.get_scale().y
			wing(sheet, bind, sign_x, raw_scale, bool(membrane))
		assert(sheet.commit(mesh) != null)
	var prop := MeshInstance3D.new()
	prop.name = "HopperWings"
	prop.mesh = mesh
	prop.skin = skin
	prop.skeleton = NodePath("..")
	rig.add_child(prop)
	prop.owner = actor
	return prop


func wing(sheet: SurfaceTool, bind: int, sign_x: float, scale: float, membrane: bool) -> void:
	for segment in Span.size() - 1:
		for lobe: int in [-1, 1]:
			var u := .5 + .5 * lobe
			var a := point(segment, 0.0, sign_x, membrane) / scale
			var b := point(segment, lobe, sign_x, membrane) / scale
			var c := point(segment + 1, 0.0, sign_x, membrane) / scale
			var d := point(segment + 1, lobe, sign_x, membrane) / scale
			var t := float(Span[segment])
			var next := float(Span[segment + 1])
			triangle(sheet, bind, a, c, d, Vector2(.5, t), Vector2(.5, next), Vector2(u, next))
			triangle(sheet, bind, a, d, b, Vector2(.5, t), Vector2(u, next), Vector2(u, t))


func point(segment: int, lobe: float, sign_x: float, membrane: bool) -> Vector3:
	var progress := float(Span[segment])
	var width := float(Width[segment]) * (1.12 if membrane else .75)
	var bow := sin(PI * progress)
	return Vector3(sign_x * (.13 * progress + lobe * width), .095 * bow * (1.0 - .66 * absf(lobe)),
		-progress * (1.20 if membrane else 1.08))


func triangle(sheet: SurfaceTool, bind: int, a: Vector3, b: Vector3, c: Vector3, a_uv: Vector2, b_uv: Vector2, c_uv: Vector2) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var positions := [a, b, c] if normal.y >= 0.0 else [a, c, b]
	var uvs := [a_uv, b_uv, c_uv] if normal.y >= 0.0 else [a_uv, c_uv, b_uv]
	for corner in 3:
		sheet.set_normal(normal if normal.y >= 0.0 else -normal)
		sheet.set_uv(uvs[corner])
		sheet.set_bones(PackedInt32Array([bind, 0, 0, 0]))
		sheet.set_weights(PackedFloat32Array([1, 0, 0, 0]))
		sheet.add_vertex(positions[corner])


func wing_material(membrane: bool) -> StandardMaterial3D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var distance := absf(x / 95.0 - .5) * 2.0
			var spine := 1.0 - smoothstep(.015, .09, distance)
			var t := y / 95.0
			var primary := pow(maxf(0.0, cos(TAU * (t * 7.0 - .9 * distance))), 16.0)
			var cross_vein := pow(maxf(0.0, cos(TAU * (t * 12.0 + 1.5 * distance))), 20.0)
			var vein := maxf(primary, .48 * cross_vein * smoothstep(.32, .83, distance))
			var deep := Color("#534437") if membrane else Color("#3a492c")
			var bright := Color("#cdb77d") if membrane else Color("#ae9c60")
			var colour := deep.lerp(bright, clampf(.18 + .44 * spine + .35 * vein + .15 * t, 0.0, 1.0))
			colour.a = .30 + .48 * maxf(vein, spine) + .12 * pow(distance, 4.0) if membrane else 1.0
			image.set_pixel(x, y, colour)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .44 if membrane else .55
	if membrane:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	return material
