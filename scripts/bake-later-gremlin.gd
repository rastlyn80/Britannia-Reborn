# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-later-goblin.gd"

const GREMLIN_ACTIONS := {
	2: ["Death", 1.12], 3: ["Death2", 1.22], 4: ["GremlinSwipe", .69],
	5: ["GremlinLowStrike", .64], 10: ["GremlinStagger", .65],
	11: ["GremlinGuard", .87], 12: ["GremlinOverheadLunge", .85],
	15: ["GremlinDuck", .66], 19: ["Fly", .87], 23: ["GremlinLookBack", 1.04],
	25: ["ReadyStance", 1.49], 26: ["GremlinWarning", .98],
	27: ["GremlinBrace", 1.14], 28: ["GremlinReady", .81],
}

const GREMLIN_JOINTS := ["bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]


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
		model.scale *= Vector3(.48, .69, .55)
		var geometry := mesh.mesh.duplicate() as ArrayMesh
		var material := geometry.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_texture = gremlin_atlas(material.albedo_texture, style)
		material.roughness = .94
		geometry.surface_set_material(0, material)
		add_tail(geometry, mesh, rig)
		mesh.mesh = geometry
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for group: int in GREMLIN_ACTIONS:
			var entry: Array = GREMLIN_ACTIONS[group]
			var fit := fit_grounded(player, rig, [skin], entry[1], "__root", Joints + GREMLIN_JOINTS,
				pose_gremlin.bind(group))
			if group in [19, 25]:
				fit.loop_mode = Animation.LOOP_LINEAR
			if library.has_animation(entry[0]):
				library.remove_animation(entry[0])
			assert(library.add_animation(entry[0], fit) == OK)
		var pace := player.get_animation("Walk").duplicate(true) as Animation
		pace.length *= 1.14
		for track in pace.get_track_count():
			for key in range(pace.track_get_key_count(track) - 1, 0, -1):
				pace.track_set_key_time(track, key, pace.track_get_key_time(track, key) * 1.14)
		assert(library.add_animation("GremlinPeaceWalk", pace) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("724-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("GREMLIN FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func gremlin_atlas(texture: Texture2D, style: String) -> Texture2D:
	var atlas := texture.get_image()
	if atlas.is_compressed():
		assert(atlas.decompress() == OK)
	atlas.convert(Image.FORMAT_RGB8)
	for y in atlas.get_height():
		for x in atlas.get_width():
			var pixel := atlas.get_pixel(x, y)
			var uv := Vector2(float(x) / atlas.get_width(), float(y) / atlas.get_height())
			var value := pixel.get_luminance()
			var warm := smoothstep(-.08, .06, pixel.g - pixel.b)
			if style == "modern":
				var head := (1.0 - smoothstep(.28, .34, uv.x)) * (1.0 - smoothstep(.24, .36, uv.y))
				var chest := smoothstep(.35, .39, uv.x) * (1.0 - smoothstep(.79, .82, uv.x))
				chest *= 1.0 - smoothstep(.30, .43, uv.y)
				var limbs := maxf(smoothstep(.80, .85, uv.x), smoothstep(.61, .70, uv.y))
				warm *= maxf(maxf(head, limbs), .42 * chest)
			var slate := Color("#141920").lerp(Color("#576475"), smoothstep(.07, .9, value))
			var skin := Color("#302821").lerp(Color("#c9b299"), smoothstep(.00, .88, value))
			atlas.set_pixel(x, y, slate.lerp(skin, warm))
	atlas.generate_mipmaps()
	return ImageTexture.create_from_image(atlas)


func add_tail(geometry: ArrayMesh, mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var hip := rig.find_bone("bip01 pelvis")
	var binding := -1
	for index in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_bone(index) == hip or mesh.skin.get_bind_name(index) == "bip01 pelvis":
			binding = index
			break
	assert(binding >= 0)
	var center := mesh.to_local(rig.to_global(rig.get_bone_global_rest(hip).origin))
	var offsets := [Vector3(0, .12, -.07), Vector3(0, .24, -.15), Vector3(.02, .38, -.23),
		Vector3(.035, .52, -.29), Vector3(.025, .63, -.27), Vector3(.008, .70, -.23)]
	var radii := [.106, .092, .069, .044, .023, .003]
	var material := StandardMaterial3D.new()
	var pigment := Image.create_empty(16, 16, false, Image.FORMAT_RGB8)
	for y in pigment.get_height():
		for x in pigment.get_width():
			var shade := .43 + .27 * cos(float(x) * TAU / 16.0) + .08 * sin(float(y) * 2.7)
			pigment.set_pixel(x, y, Color("#252932").lerp(Color("#5d6776"), shade))
	pigment.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(pigment)
	material.roughness = .94
	var tail := SurfaceTool.new()
	tail.begin(Mesh.PRIMITIVE_TRIANGLES)
	tail.set_material(material)
	const Sides := 10
	for segment in offsets.size() - 1:
		for side in Sides:
			var a := Vector2i(segment, side)
			var b := Vector2i(segment, side + 1)
			var c := Vector2i(segment + 1, side + 1)
			var d := Vector2i(segment + 1, side)
			for corner: Vector2i in [a, b, c, a, c, d]:
				var angle := float(corner.y) * TAU / Sides
				var out := Vector3(cos(angle), 0.0, sin(angle))
				tail.set_uv(Vector2(float(corner.y) / Sides, float(corner.x) / (offsets.size() - 1)))
				tail.set_normal(out)
				tail.set_bones(PackedInt32Array([binding, 0, 0, 0]))
				tail.set_weights(PackedFloat32Array([1, 0, 0, 0]))
				tail.add_vertex(center + offsets[corner.x] + out * radii[corner.x])
	tail.commit(geometry)


func pose_gremlin(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := smoothstep(.06, .43, phase) * (1.0 - smoothstep(.57, .99, phase))
	if group in [2, 3]:
		var fall := smoothstep(.14, .86, phase)
		var brace := sin(PI * fall)
		turn_world(rig, "__root", Vector3.RIGHT, (1.49 if group == 2 else -1.53) * fall)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * .62 * fall)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -.31 * brace)
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, sign * .32 * brace)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, .68 * brace)
		return
	if group == 19:
		var cycle := sin(phase * TAU)
		turn_world(rig, "__root", Vector3.RIGHT, 1.34 + .085 * cycle)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -.55)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * (.69 + .39 * cycle))
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -.29 + .12 * sign * cycle)
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, .28 + .27 * sign * cycle)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, .72 - .28 * sign * cycle)
		return
	if group == 12:
		var cock := smoothstep(.07, .31, phase) * (1.0 - smoothstep(.38, .67, phase))
		var lunge := smoothstep(.32, .57, phase) * (1.0 - smoothstep(.70, .99, phase))
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, .35 * cock - .48 * lunge)
		turn_world(rig, "bip01 spine2", Vector3.UP, -.43 * cock + .41 * lunge)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.38 * cock + .62 * lunge)
		turn_world(rig, "bip01 r forearm", Vector3.UP, -.77 * cock + .29 * lunge)
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -.81 * lunge)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, .68 * lunge)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, .63 * lunge)
		return
	if group == 25:
		pulse = sin(phase * TAU)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.15 + .022 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, .061 * pulse)
		return
	pose_goblin(rig, phase, group)
	if group in [5, 11, 15, 27]:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.21 * pulse)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, .29 * pulse)
		turn_world(rig, "bip01 r calf", Vector3.RIGHT, .32 * pulse)
