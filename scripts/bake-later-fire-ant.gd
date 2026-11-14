# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {1: ["FireAntIdle", 1.60], 2: ["Death", .89], 3: ["Death2", 1.05], 4: ["FireAntBite", .63],
	5: ["FireAntAbdomenStrike", .80], 10: ["FireAntRecoil", .45], 11: ["FireAntReadiness", .84],
	15: ["FireAntWithdraw", .59], 23: ["FireAntScan", 1.22], 25: ["ReadyStance", 1.40],
	26: ["FireAntAntennaFan", .84], 27: ["FireAntAbdomenPulse", 1.06], 28: ["FireAntRise", .85]}
const Joints := ["__root", "bip01", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 tail", "bip01 tail1", "antenna l", "antenna r", "mandible l", "mandible r",
	"legbone lf1", "legbone rf1", "legbone lr1", "legbone rr1", "bip01 l upperarm", "bip01 r upperarm"]


func run() -> void:
	var row := Registry.entry(781)
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
		model.scale *= Vector3(.67, .55, .70)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var material := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_texture = amber(material.albedo_texture)
		material.roughness = .82
		geometry.surface_set_material(0, material)
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
				"__root", Joints, pose_ant.bind(group))) == OK)
		assert(library.add_animation("FireAntPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		library.remove_animation("Idle")
		assert(library.add_animation("Idle", library.get_animation("FireAntIdle").duplicate(true)) == OK)
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("738-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("FIRE ANT FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func amber(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var shine := smoothstep(.08, .74, pixel.get_luminance())
			var pigment := Color("#2b190d").lerp(Color("#e5a03f"), shine)
			image.set_pixel(x, y, pigment.lerp(Color("#ffe0a3"), smoothstep(.67, .94, shine) * .45))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func pose_ant(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.05, .38, phase) * (1.0 - smoothstep(.56, .96, phase))
	var fall := smoothstep(.13, .90, phase) if group in [2, 3] else 0.0
	var jitter := sin(TAU * phase * 2.0) * pulse
	var bite := pulse if group == 4 else 0.0
	var sting := pulse if group in [5, 27] else 0.0
	var withdraw := pulse if group in [10, 15] else 0.0
	var antennae := pulse if group in [11, 23, 26, 28] else 0.0
	turn_world(rig, "__root", Vector3.FORWARD, (-.45 if group == 2 else 1.48) * fall)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.70 * (1.0 - fall) + .29 * bite - .28 * sting + .25 * fall)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .43 * bite + .34 * withdraw)
	turn_world(rig, "bip01 head", Vector3.UP, .47 * jitter if group == 23 else -.13 * antennae)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.22 - .62 * sting + .29 * fall)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.37 * sting - .17 * fall)
	for side: String in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		turn_world(rig, "mandible " + side, Vector3.UP, sign * (.46 * bite + .16 * jitter))
		turn_world(rig, "antenna " + side, Vector3.FORWARD, sign * (.58 * antennae + .39 * fall))
		turn_world(rig, "legbone " + side + "f1", Vector3.RIGHT, -.29 * bite + .49 * fall)
		turn_world(rig, "legbone " + side + "r1", Vector3.RIGHT, .22 * sting + .38 * fall)
