# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Clips := {2: ["Death", .94], 3: ["Death2", 1.14], 4: ["KepetchLunge", .69],
	5: ["KepetchCoilSnap", .85], 10: ["KepetchRecoil", .51], 15: ["KepetchWithdraw", .64],
	23: ["KepetchWatchBack", 1.22], 25: ["ReadyStance", 1.40], 26: ["KepetchHiss", .83],
	27: ["KepetchLowWatch", 1.09], 28: ["KepetchUncoil", .87]}
const Joints := ["__root", "bip01 spine", "bip01 neck", "bip01 neck1", "bip01 neck2",
	"bip01 neck3", "bip01 neck4", "bip01 head", "bip01 tail", "bip01 tail2", "bip01 tail3"]


func run() -> void:
	var row := Registry.entry(21)
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
		model.scale *= Vector3(.68, 1.30, .64)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var base := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		base.albedo_texture = moss(base.albedo_texture)
		geometry.surface_set_material(0, base)
		add_crown(geometry, mesh, rig)
		mesh.mesh = geometry
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for group: int in Clips:
			var row_data: Array = Clips[group]
			var name: String = row_data[0]
			if library.has_animation(name):
				library.remove_animation(name)
			assert(library.add_animation(name, fit_grounded(player, rig, [skin], row_data[1],
				"__root", Joints, pose_kepetch.bind(group))) == OK)
		assert(library.add_animation("KepetchPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		var rest := library.get_animation("ReadyStance").duplicate(true) as Animation
		library.remove_animation("Idle")
		assert(library.add_animation("Idle", rest) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("726-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("KEPETCH FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func moss(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var texel := image.get_pixel(x, y)
			var pigment := Color("#153928").lerp(Color("#9c9f57"), smoothstep(.08, .82, texel.get_luminance()))
			image.set_pixel(x, y, pigment)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func add_crown(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var name := "bip01 head"
	var joint := rig.find_bone(name)
	var binding := -1
	for index in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(index) == joint or mesh.skin.get_bind_name(index) == name:
			binding = index
			break
	assert(binding >= 0)
	var center := mesh.to_local(rig.to_global(rig.get_bone_global_rest(joint).origin))
	var texture := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	for y in texture.get_height():
		for x in texture.get_width():
			texture.set_pixel(x, y, Color("#55693b").lerp(Color("#b9a879"), y / 3.0))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(texture)
	var crown := SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	crown.set_material(material)
	var points := [Vector3(.03, -.04, .005), Vector3(.05, .06, .002), Vector3(.065, .02, .069),
		Vector3(.19, .09, .17)]
	for side: int in [-1, 1]:
		for face: Array in [[0, 1, 3], [1, 2, 3], [2, 0, 3], [1, 0, 2]]:
			if side < 0:
				face.reverse()
			for index: int in face:
				crown.set_bones(PackedInt32Array([binding, 0, 0, 0]))
				crown.set_weights(PackedFloat32Array([1, 0, 0, 0]))
				crown.set_uv(Vector2(.5, 1.0 if index == 3 else 0.0))
				crown.add_vertex(center + points[index] * Vector3(side, 1, 1))
	crown.generate_normals()
	crown.commit(geometry)


func pose_kepetch(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.06, .40, phase) * (1.0 - smoothstep(.56, .96, phase))
	var collapse := smoothstep(.14, .87, phase) if group in [2, 3] else 0.0
	var rolling := (-.21 if group == 2 else .28) * collapse
	var extension := pulse if group in [4, 5] else 0.0
	var retraction := pulse if group in [10, 15, 27] else 0.0
	var rise := -0.52 * (1.0 - collapse) + .16 * extension - .09 * retraction
	turn_world(rig, "__root", Vector3.FORWARD, rolling)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, rise)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, rise * .77)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, rise * .66 + .52 * collapse)
	turn_world(rig, "bip01 neck3", Vector3.RIGHT, -.24 * extension - .27 * collapse)
	turn_world(rig, "bip01 neck4", Vector3.RIGHT, .44 * extension - .21 * retraction)
	turn_world(rig, "bip01 head", Vector3.UP, (.67 if group in [5, 23] else .20) * pulse)
	turn_world(rig, "bip01 tail2", Vector3.UP, -.49 * extension + (.48 if group == 2 else -.57) * collapse)
	turn_world(rig, "bip01 tail3", Vector3.UP, .39 * pulse if group in [5, 26] else -.13 * collapse)
