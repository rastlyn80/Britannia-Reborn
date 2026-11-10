# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Sides := 24
static var pool_geometry: ArrayMesh


static func build(model: Node3D, rig: Skeleton3D) -> MeshInstance3D:
	var skin := Skin.new()
	var sheet := SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	sheet.set_material(surface())
	bind_loft(sheet, skin, rig, "bip01 head", Vector3.ZERO, [
		[-.16, .035, .063, .084], [-.09, .028, .127, .145], [.005, .025, .172, .195],
		[.105, -.04, .159, .224], [.183, -.14, .111, .191], [.244, -.245, .054, .117],
		[.305, -.337, .012, .043], [.320, -.359, .002, .003],
	], Vector2(.57, 1.0), .06)
	bind_loft(sheet, skin, rig, "bip01 spine2", Vector3(0, 0, -.035), [
		[-.46, 0.0, .13, .115], [-.32, -.025, .23, .145], [-.12, -.035, .316, .187],
		[.065, -.046, .349, .204], [.19, -.04, .242, .145], [.23, -.024, .099, .068],
	], Vector2(.12, .58), .12)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		bind_loft(sheet, skin, rig, "bip01 %s thigh" % side, Vector3(sign_x * .113, 0, -.009), [
			[-.41, -.05, .009, .012], [-.32, -.039, .043, .042], [-.17, -.018, .094, .096],
			[.0, .021, .135, .123], [.14, .016, .104, .084], [.20, .008, .026, .028],
		], Vector2(.0, .48), .20)
		bind_loft(sheet, skin, rig, "bip01 neck", Vector3(sign_x * .100, 0, .140), [
			[-.38, .050 * sign_x, .009, .011], [-.26, .055, .028, .031],
			[-.12, .055, .057, .068], [.035, .0, .072, .085], [.11, -.038, .029, .039],
		], Vector2(.04, .48), .17)
	sheet.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "BloodSurgeCrest"
	mesh.mesh = sheet.commit()
	mesh.skin = skin
	mesh.skeleton = NodePath("..")
	rig.add_child(mesh)
	mesh.owner = model
	return mesh


static func bind_loft(sheet: SurfaceTool, skin: Skin, rig: Skeleton3D, name: String, offset: Vector3,
		rings: Array, band: Vector2, ripple: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var frame := rig.global_transform * rig.get_bone_global_pose(bone)
	var binding := skin.get_bind_count()
	skin.add_bind(bone, Transform3D.IDENTITY)
	loft(sheet, frame.affine_inverse(), frame.origin + offset, rings, band, ripple, binding)


static func loft(sheet: SurfaceTool, into_local: Transform3D, origin: Vector3, rings: Array,
		band: Vector2, ripple: float, binding: int) -> void:
	for ring in rings.size() - 1:
		var lower: Array = rings[ring]
		var upper: Array = rings[ring + 1]
		var v := lerpf(band.x, band.y, float(ring) / (rings.size() - 1))
		var next_v := lerpf(band.x, band.y, float(ring + 1) / (rings.size() - 1))
		for side in Sides:
			var u := float(side) / Sides
			var next_u := float(side + 1) / Sides
			var a := vertex(lower, u, ripple)
			var b := vertex(lower, next_u, ripple)
			var c := vertex(upper, u, ripple)
			var d := vertex(upper, next_u, ripple)
			for item: Array in [[a, u, v], [b, next_u, v], [c, u, next_v],
					[b, next_u, v], [d, next_u, next_v], [c, u, next_v]]:
				if binding >= 0:
					sheet.set_bones(PackedInt32Array([binding, 0, 0, 0]))
					sheet.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				sheet.set_uv(Vector2(item[1], item[2]))
				sheet.add_vertex(into_local * (origin + item[0]))


static func vertex(profile: Array, u: float, ripple: float) -> Vector3:
	var angle := TAU * u
	var relief := 1.0 + ripple * (.61 * sin(angle * 3.0 + .5) + .39 * cos(angle * 7.0 - 1.6))
	return Vector3(cos(angle) * float(profile[2]) * relief, float(profile[0]),
		float(profile[1]) + sin(angle) * float(profile[3]) * relief)


static func pool_mesh() -> MeshInstance3D:
	if pool_geometry == null:
		var sheet := SurfaceTool.new()
		sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
		sheet.set_material(surface())
		loft(sheet, Transform3D.IDENTITY, Vector3.ZERO, [
			[.004, 0.0, .42, .33], [.016, .014, .46, .36], [.033, .025, .38, .31],
			[.060, .046, .22, .18], [.084, .064, .002, .002],
		], Vector2(.04, .57), .29, -1)
		sheet.generate_normals()
		pool_geometry = sheet.commit()
	var pool := MeshInstance3D.new()
	pool.name = "BloodRisePool"
	pool.mesh = pool_geometry
	pool.visible = false
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# This transient effect is removed from the frozen corpse.
	pool.set_meta("source_death_flash", true)
	return pool


static func surface() -> StandardMaterial3D:
	var image := Image.create(96, 128, false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var u := float(x) / (image.get_width() - 1)
			var v := float(y) / (image.get_height() - 1)
			var furrow := .54 + .20 * sin(TAU * (u * 6.0 + v * .83)) + .15 * cos(TAU * (u * 11.0 - v * 1.51))
			var flowing := Color("#33070b").lerp(Color("#a72a25"), furrow)
			var crest := Color("#a73e33").lerp(Color("#ded0ba"), clampf(furrow + .28, 0.0, 1.0))
			image.set_pixel(x, y, flowing.lerp(crest, smoothstep(.60, .96, v)))
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .35
	return material
