# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {
	2: ["Death", 1.18], 3: ["Death2", 1.05], 4: ["BouraHeadRam", .84], 5: ["BouraForelegKick", .73],
	10: ["BouraRecoil", .50], 15: ["BouraDuck", .66], 23: ["BouraShake", 1.26], 25: ["ReadyStance", 1.42],
	26: ["BouraWarning", .76], 27: ["BouraSniff", 1.12], 28: ["BouraSettle", .82],
}
const Joints := ["bip01", "bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head",
	"jawbone", "bip01 tail", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh"]


func run() -> void:
	var source := Registry.entry(248)
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
		model.scale *= Vector3(.70, .56, .79)
		var result := mesh.mesh.duplicate() as ArrayMesh
		for surface in result.get_surface_count():
			var base := result.surface_get_material(surface) as StandardMaterial3D
			result.surface_set_material(surface, mantle_material(base))
		add_horns(result, mesh, rig)
		add_back_plates(result, mesh, rig)
		mesh.mesh = result
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for group: int in Clips:
			var data: Array = Clips[group]
			if library.has_animation(data[0]):
				library.remove_animation(data[0])
			assert(library.add_animation(data[0], fit_grounded(player, rig, [skin], data[1], "__root",
				Joints, pose_boura.bind(group))) == OK)
		assert(library.add_animation("BouraPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var target := folder.path_join("715-%s.scn" % style)
		assert(ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("RUDDY BOURA FIT: ", style, ", source ", FileAccess.get_sha256(path), ", scene ", FileAccess.get_sha256(target))
	quit(0)


func mantle_material(source: StandardMaterial3D) -> StandardMaterial3D:
	var image := source.albedo_texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var colour := Color("#3a3224").lerp(Color("#bd9a58"), smoothstep(.08, .80, pixel.get_luminance()))
			var mix := .55 if pixel.r > pixel.g * 1.20 else .32
			image.set_pixel(x, y, pixel.lerp(colour, mix))
	image.generate_mipmaps()
	var material := source.duplicate() as StandardMaterial3D
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = .90
	return material


func add_horns(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var head := rig.find_bone("bip01 head")
	var binding := -1
	for index in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(index) == head or mesh.skin.get_bind_name(index) == "bip01 head":
			binding = index
			break
	assert(binding >= 0)
	var material := StandardMaterial3D.new()
	var atlas := Image.create_empty(32, 8, false, Image.FORMAT_RGB8)
	for y in atlas.get_height():
		for x in atlas.get_width():
			var phase := x / 31.0
			var band := .13 * (1.0 + sin(phase * TAU * 6.0))
			atlas.set_pixel(x, y, Color("#6f5540").lerp(Color("#d9c29b"), .60 + band))
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = .86
	var horns := SurfaceTool.new()
	horns.begin(Mesh.PRIMITIVE_TRIANGLES)
	horns.set_material(material)
	var anchor := mesh.to_local(rig.to_global(rig.get_bone_global_rest(head).origin))
	for side: float in [-1.0, 1.0]:
		var stem := anchor + Vector3(side * 1100.0, 390.0, 460.0)
		for ring in 14:
			for edge in 9:
				for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
						Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var phase := (ring + offset.x) / 14.0
					var angle := .10 + phase * 4.2
					var around := (edge + offset.y) * TAU / 9
					var radius := lerpf(435.0, 22.0, phase)
					var direction := Vector3(side * sin(angle), cos(angle), 0)
					var center := stem + Vector3(side * (.28 + sin(angle) * .71), -(.45 - phase) * 1.65,
						cos(angle) * .79) * 925.0
					var offset_direction := direction * sin(around) + Vector3.BACK * cos(around)
					horns.set_bones(PackedInt32Array([binding, 0, 0, 0]))
					horns.set_weights(PackedFloat32Array([1, 0, 0, 0]))
					horns.set_uv(Vector2(phase, (edge + offset.y) / 9.0))
					horns.add_vertex(center + offset_direction * radius)
	horns.generate_normals()
	horns.commit(geometry)


func add_back_plates(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	var texture := Image.create_empty(16, 8, false, Image.FORMAT_RGB8)
	for y in texture.get_height():
		for x in texture.get_width():
			texture.set_pixel(x, y, Color("#704d2e").lerp(Color("#ceb17c"), y / 7.0))
	material.albedo_texture = ImageTexture.create_from_image(texture)
	shell.set_material(material)
	var plates := [
		["bip01 spine1", Vector3(0, -800, 1120), 750.0, 835.0],
		["bip01 spine1", Vector3(0, 65, 1420), 820.0, 1130.0],
		["bip01 spine1", Vector3(0, 790, 1420), 780.0, 890.0],
		["bip01 spine", Vector3(0, -175, 1270), 720.0, 650.0],
		["bip01 spine", Vector3(0, 540, 1170), 640.0, 516.0],
		["bip01 pelvis", Vector3(0, 490, 1010), 540.0, 405.0],
		["bip01 tail", Vector3(0, -80, 640), 390.0, 300.0],
	]
	for record: Array in plates:
		var joint := rig.find_bone(record[0])
		var binding := -1
		for index in mesh.skin.get_bind_count():
			if mesh.skin.get_bind_bone(index) == joint or mesh.skin.get_bind_name(index) == record[0]:
				binding = index
				break
		assert(binding >= 0)
		var anchor: Vector3 = mesh.to_local(rig.to_global(rig.get_bone_global_rest(joint).origin)) + record[1]
		var width: float = record[2]
		var height: float = record[3]
		var points := [Vector3(-.30 * width, -.56 * width, 0), Vector3(.30 * width, -.56 * width, 0),
			Vector3(.23 * width, .53 * width, 0), Vector3(-.23 * width, .53 * width, 0),
			Vector3(0, .35 * width, height)]
		for face: int in 4:
			for index: int in [face, (face + 1) % 4, 4]:
				shell.set_bones(PackedInt32Array([binding, 0, 0, 0]))
				shell.set_weights(PackedFloat32Array([1, 0, 0, 0]))
				shell.set_uv(Vector2(.5 if index == 4 else float(index % 2), 1.0 if index == 4 else 0.0))
				shell.add_vertex(anchor + points[index])
	shell.generate_normals()
	shell.commit(geometry)


func pose_boura(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.10, .41, phase) * (1.0 - smoothstep(.53, .94, phase))
	var falling := group in [2, 3]
	var fall := smoothstep(.14, .89, phase) if falling else 0.0
	var turn := (.20 if group == 2 else -.99) * fall
	var neck := .39 if group in [4, 15, 27] else -.27
	var shove := pulse if group in [4, 5, 15] else 0.0
	var twitch := sin(phase * TAU * 2.0) * pulse
	turn_world(rig, "bip01", Vector3.FORWARD, turn)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .20 * shove + .21 * fall)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, neck * pulse + .43 * fall)
	turn_world(rig, "bip01 head", Vector3.UP, .40 * twitch if group in [23, 27] else .06 * pulse)
	turn_world(rig, "jawbone", Vector3.RIGHT, .29 * pulse if group in [4, 26] else .07 * fall)
	turn_world(rig, "bip01 tail", Vector3.UP, -.33 * fall + .23 * twitch)
	for side: String in ["l", "r"]:
		var kick := -.77 * pulse if side == "l" and group == 5 else .05 * shove
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, kick + .38 * fall)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -.58 * fall)
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, .27 * fall)
