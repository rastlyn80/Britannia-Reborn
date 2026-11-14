# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {2: ["Death", .96], 3: ["Death2", 1.13], 4: ["GuardianClaw", .64],
	5: ["GuardianWingSweep", .82], 10: ["GuardianRecoil", .48], 11: ["GuardianWard", .97],
	12: ["GuardianCast", 1.07], 15: ["GuardianFold", .62], 23: ["GuardianGatherRise", 1.28],
	25: ["ReadyStance", 1.52], 26: ["GuardianThreat", .82], 27: ["GuardianLookBack", 1.0],
	28: ["GuardianReady", .85]}
const Joints := ["__root", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "gargoyle l mainwing1", "gargoyle r mainwing1",
	"gargoyle l mainwing2", "gargoyle r mainwing2"]


func run() -> void:
	var row := Registry.entry(4)
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
		model.scale *= Vector3(.79, .93, .75)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var material := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_texture = ash_atlas(material.albedo_texture)
		material.roughness = .93
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
			assert(library.add_animation(data[0], fit_grounded(player, rig, [skin], data[1],
				"__root", Joints, pose_guardian.bind(group))) == OK)
		assert(library.add_animation("GuardianPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("722-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("UNDEAD GUARDIAN FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func ash_atlas(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var light := smoothstep(.09, .82, pixel.get_luminance())
			var ash := Color("#222833").lerp(Color("#afbac1"), light)
			var velvet := Color("#211e1b").lerp(Color("#7b7168"), light)
			image.set_pixel(x, y, ash.lerp(velvet, smoothstep(.015, .25, pixel.r - pixel.b)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func pose_guardian(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.09, .40, phase) * (1.0 - smoothstep(.54, .96, phase))
	var fall := smoothstep(.16, .89, phase) if group in [2, 3] else 0.0
	var cast := pulse if group in [11, 12, 26] else 0.0
	var attack := pulse if group in [4, 5] else 0.0
	var brace := pulse if group in [10, 15] else 0.0
	var rise := pulse if group in [23, 28] else 0.0
	var side := -1.0 if group == 2 else 1.0
	turn_world(rig, "__root", Vector3.FORWARD, side * 1.17 * fall)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .33 * brace + .37 * fall + .17 * attack - .22 * rise)
	turn_world(rig, "bip01 spine2", Vector3.UP, (.44 if group == 4 else -.57) * attack)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .33 * fall + .24 * brace)
	turn_world(rig, "bip01 head", Vector3.UP, (.59 if group == 27 else .12) * pulse)
	for arm: String in ["l", "r"]:
		var sign := 1.0 if arm == "l" else -1.0
		var lead := attack if arm == "r" else attack * .24
		turn_world(rig, "bip01 " + arm + " upperarm", Vector3.RIGHT, -.89 * lead - .70 * cast + .29 * fall)
		turn_world(rig, "bip01 " + arm + " forearm", Vector3.UP, sign * (.53 * lead + .37 * cast))
		turn_world(rig, "bip01 " + arm + " thigh", Vector3.RIGHT, sign * .33 * fall)
		turn_world(rig, "gargoyle " + arm + " mainwing1", Vector3.UP, sign * (.46 * fall - .64 * cast - .48 * attack))
		turn_world(rig, "gargoyle " + arm + " mainwing2", Vector3.FORWARD, sign * (.30 * brace + .67 * fall - .51 * rise))
