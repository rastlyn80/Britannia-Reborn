# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {
	2: ["Death", 1.06], 3: ["Death2", 1.15], 4: ["GoblinStrike", .69], 5: ["GoblinBackhand", .81],
	10: ["GoblinRecoil", .48], 11: ["GoblinGuard", .86], 15: ["GoblinDuck", .59],
	23: ["GoblinLookBack", 1.22], 25: ["ReadyStance", 1.49], 26: ["GoblinWarning", .80],
	27: ["GoblinLowWatch", 1.10], 28: ["GoblinReady", .70],
}
const Joints := ["__root", "bip01", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l thigh", "bip01 r thigh", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand"]


func run() -> void:
	var row := Registry.entry(17)
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, style)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[style])
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		model.scale *= Vector3(.57, .73, .61)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var material := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_texture = goblin_atlas(material.albedo_texture)
		material.roughness = .91
		geometry.surface_set_material(0, material)
		add_ears(geometry, mesh, rig)
		mesh.mesh = geometry
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for group: int in Clips:
			var entry: Array = Clips[group]
			if library.has_animation(entry[0]):
				library.remove_animation(entry[0])
			assert(library.add_animation(entry[0], fit_grounded(player, rig, [skin], entry[1],
				"__root", Joints, pose_goblin.bind(group))) == OK)
		assert(library.add_animation("GoblinPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("723-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("GOBLIN FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func goblin_atlas(texture: Texture2D) -> Texture2D:
	var atlas := texture.get_image()
	if atlas.is_compressed():
		assert(atlas.decompress() == OK)
	atlas.convert(Image.FORMAT_RGB8)
	for y in atlas.get_height():
		for x in atlas.get_width():
			var pixel := atlas.get_pixel(x, y)
			var luminance := pixel.get_luminance()
			var skin := smoothstep(.01, .19, pixel.g - pixel.r)
			var olive := Color("#283324").lerp(Color("#9b9d70"), smoothstep(.11, .80, luminance))
			var brown := Color("#241c17").lerp(Color("#958366"), smoothstep(.14, .88, luminance))
			atlas.set_pixel(x, y, brown.lerp(olive, skin))
	atlas.generate_mipmaps()
	return ImageTexture.create_from_image(atlas)


func add_ears(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var head := rig.find_bone("bip01 head")
	var binding := -1
	for index in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(index) == head or mesh.skin.get_bind_name(index) == "bip01 head":
			binding = index
			break
	assert(binding >= 0)
	var center := mesh.to_local(rig.to_global(rig.get_bone_global_rest(head).origin))
	var material := StandardMaterial3D.new()
	var pigment := Image.create_empty(8, 8, false, Image.FORMAT_RGB8)
	for y in pigment.get_height():
		for x in pigment.get_width():
			pigment.set_pixel(x, y, Color("#536447").lerp(Color("#87906a"), (x + y) / 14.0))
	material.albedo_texture = ImageTexture.create_from_image(pigment)
	var ears := SurfaceTool.new()
	ears.begin(Mesh.PRIMITIVE_TRIANGLES)
	ears.set_material(material)
	var points := [Vector3(.075, -.07, .04), Vector3(.14, -.04, .014),
		Vector3(.265, .067, .118), Vector3(.093, .02, .11), Vector3(.138, -.036, .072)]
	for side: int in [-1, 1]:
		for face: Array in [[0, 4, 1], [1, 4, 2], [2, 4, 3], [3, 4, 0], [0, 1, 2], [2, 3, 0]]:
			if side < 0:
				face.reverse()
			for index: int in face:
				var point: Vector3 = points[index] * Vector3(side, 1, 1)
				ears.set_uv(Vector2(point.x * side * 3.1, point.z * 7.5))
				ears.set_bones(PackedInt32Array([binding, 0, 0, 0]))
				ears.set_weights(PackedFloat32Array([1, 0, 0, 0]))
				ears.add_vertex(center + point)
	ears.generate_normals()
	ears.commit(geometry)


func pose_goblin(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.09, .41, phase) * (1.0 - smoothstep(.57, .96, phase))
	var curl := smoothstep(.10, .87, phase) if group in [2, 3] else 0.0
	var swing := pulse if group in [4, 5] else 0.0
	var dip := pulse if group in [10, 15, 27] else 0.0
	var head_turn := .56 * pulse if group == 23 else .17 * pulse
	turn_world(rig, "__root", Vector3.FORWARD, (-1.22 if group == 2 else 1.36) * curl)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .29 * dip + .32 * curl + .20 * swing)
	turn_world(rig, "bip01 spine2", Vector3.UP, (.46 if group == 4 else -.48) * swing)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .17 * dip - .20 * swing)
	turn_world(rig, "bip01 head", Vector3.UP, head_turn)
	var warning := pulse if group in [11, 26, 28] else 0.0
	for side: String in ["l", "r"]:
		var effort := swing if side == "r" else swing * .20
		var sign := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.94 * effort - .28 * warning + .21 * curl)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.UP, sign * (.54 * effort + .31 * warning))
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, sign * .31 * dip - .36 * curl)
