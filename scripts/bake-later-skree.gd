# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {
	2: ["Death", 1.04], 3: ["Death2", 1.14], 4: ["SkreeDive", .78], 5: ["SkreeRake", .72],
	10: ["SkreeRecoil", .50], 11: ["SkreeWingWatch", .98], 15: ["SkreeBrace", .62],
	23: ["SkreeCast", 1.24], 25: ["ReadyStance", 1.45], 26: ["SkreeThreat", .86],
	27: ["SkreeGlance", 1.20], 28: ["SkreeReady", .77], 21: ["AirDeath", 1.12],
}
const Joints := ["__root", "bip01", "bip01 neck", "bip01 neck2", "bip01 head", "bip01 ponytail1",
	"bip01 tail", "bip01 tail2", "bip01 tail4", "bip01 l thigh", "bip01 r thigh",
	"box01", "box02", "box03", "box06", "box05", "box04"]


func run() -> void:
	var row := Registry.entry(62)
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
		model.scale *= Vector3(.30, .32, .27)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var material := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_texture = green_atlas(material.albedo_texture)
		material.roughness = .84
		material.metallic = 0
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
				"__root", Joints, pose_skree.bind(group))) == OK)
		assert(library.add_animation("SkreePeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("733-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("SKREE FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func green_atlas(source: Texture2D) -> Texture2D:
	var image := source.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var texel := image.get_pixel(x, y)
			var luminance := texel.get_luminance()
			var green := Color("#132510").lerp(Color("#83a845"), smoothstep(.10, .79, luminance))
			var membrane := Color("#14251d").lerp(Color("#526f38"), smoothstep(.13, .84, luminance))
			var wing := smoothstep(.02, .23, texel.r - texel.g)
			image.set_pixel(x, y, green.lerp(membrane, wing))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func pose_skree(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.07, .41, phase) * (1.0 - smoothstep(.54, .96, phase))
	var is_fall := group in [2, 3, 21]
	var collapse := smoothstep(.10, .90, phase) if is_fall else 0.0
	var stroke := sin(phase * TAU) * pulse
	var flare := pulse if group in [4, 5, 11, 23, 26, 28] else 0.0
	var bracing := pulse if group in [10, 15, 27] else 0.0
	var fall_side := -.25 if group == 2 else .47
	turn_world(rig, "__root", Vector3.FORWARD, fall_side * collapse - .13 * stroke)
	if group == 21:
		turn_world(rig, "__root", Vector3.RIGHT, -.52 * sin(PI * phase))
	turn_world(rig, "bip01", Vector3.RIGHT, .24 * collapse + (.37 if group == 4 else -.17) * flare)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .28 * collapse + .32 * bracing - .24 * flare)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .37 * flare if group == 4 else -.17 * flare)
	turn_world(rig, "bip01 head", Vector3.UP, .50 * stroke if group in [23, 27] else .10 * stroke)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .18 * bracing + .12 * flare)
	turn_world(rig, "bip01 tail2", Vector3.UP, -.48 * collapse - .31 * stroke)
	turn_world(rig, "bip01 tail4", Vector3.RIGHT, .43 * collapse + .18 * flare)
	turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -.53 * pulse if group == 5 else .29 * collapse)
	turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -.23 * collapse)
	for chain: Array in [["box01", "box02", "box03", -1.0], ["box06", "box05", "box04", 1.0]]:
		var side: float = chain[3]
		var fold := (.46 if group == 2 else 1.04) * collapse
		turn_world(rig, chain[0], Vector3.FORWARD, side * (.17 * collapse + .48 * flare - .56 * bracing + .11 * stroke))
		turn_world(rig, chain[1], Vector3.UP, side * (fold - .42 * flare + .30 * bracing))
		turn_world(rig, chain[2], Vector3.FORWARD, side * (-.27 * collapse - .30 * flare + .25 * bracing))
