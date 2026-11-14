# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {2: ["Death", 1.05], 3: ["Death2", 1.17], 4: ["LavaElementalLunge", .71],
	5: ["LavaElementalRake", .80], 10: ["LavaElementalRecoil", .49], 11: ["LavaElementalWatch", .96],
	15: ["LavaElementalHunker", .66], 23: ["LavaElementalKindle", 1.23], 25: ["ReadyStance", 1.49],
	26: ["LavaElementalJawFan", .82], 27: ["LavaElementalSwell", 1.09], 28: ["LavaElementalRise", .90]}
const Joints := ["__root", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head", "bip01 ponytail1",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l thigh", "bip01 r thigh"]


func run() -> void:
	var row := Registry.entry(206)
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
		model.scale *= Vector3(.98, 1.40, 1.09)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var material := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_texture = magma(material.albedo_texture)
		material.roughness = .86
		geometry.surface_set_material(0, material)
		mesh.mesh = geometry
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for group: int in Clips:
			var data: Array = Clips[group]
			if library.has_animation(data[0]):
				library.remove_animation(data[0])
			var clip := fit_grounded(player, rig, [skin], data[1], "__root", Joints, pose_lava.bind(group))
			assert(library.add_animation(data[0], clip) == OK)
		assert(library.add_animation("LavaElementalPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("720-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("LAVA ELEMENTAL FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func magma(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 720
	noise.frequency = .070
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var shade := smoothstep(.10, .72, pixel.get_luminance())
			var stone := Color("#241914").lerp(Color("#8e4424"), shade)
			var distance := absf(noise.get_noise_2d(x, y))
			var heat := (1.0 - smoothstep(.015, .115, distance)) * (.37 + .63 * shade)
			image.set_pixel(x, y, stone.lerp(Color("#ff8b36"), heat * .74))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func pose_lava(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.08, .39, phase) * (1.0 - smoothstep(.56, .96, phase))
	var fall := smoothstep(.18, .90, phase) if group in [2, 3] else 0.0
	var sweep := pulse if group in [4, 5, 26, 27] else 0.0
	var recoil := pulse if group in [10, 15] else 0.0
	var rise := pulse if group in [23, 28] else 0.0
	var sway := sin(TAU * phase) * pulse
	turn_world(rig, "__root", Vector3.FORWARD, (-.22 if group == 2 else .68) * fall)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .27 * sweep + .14 * recoil - .25 * rise + .19 * fall)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .43 * sweep + .18 * recoil - .39 * rise)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.20 * sweep + .21 * fall)
	turn_world(rig, "bip01 head", Vector3.UP, (.57 if group in [5, 23] else .21) * sway)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .34 * sweep + .22 * rise)
	turn_world(rig, "bip01 tail1", Vector3.UP, .51 * sway + (.41 if group == 2 else -.48) * fall)
	turn_world(rig, "bip01 tail2", Vector3.UP, -.37 * sway + .28 * fall)
	for side: String in ["l", "r"]:
		var effort := sweep if side == "r" and group == 5 else .17 * sweep
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.55 * effort + .45 * fall)
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, .38 * fall)
