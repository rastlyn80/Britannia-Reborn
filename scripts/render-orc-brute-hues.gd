# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Corpse := preload("res://Presentation/CorpseModels.gd")
const Fit := preload("bake-orc-brute-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedOrcBruteVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const ImageSize := 384
const Hues := [0, 0x35, 0x8035]


func review_folder() -> String:
	return Fit.Destination + "silhouette/"


func run() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#2d353f")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#e3eaf0")
	world.environment.ambient_light_energy = .62
	root.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -28, 0)
	key.light_energy = 1.8
	root.add_child(key)
	var view := SubViewport.new()
	view.size = Vector2i(ImageSize, ImageSize)
	view.world_3d = root.world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	camera.make_current()
	var row := Registry.entry(189).duplicate(true)
	row.assets = {"modern": review_folder() + "189-modern.scn", "original": review_folder() + "189-original.scn"}
	row.archive_grounded_gestures = Fit.Clips.values()
	var actor := Visual.new()
	actor.entry = row
	root.add_child(actor)
	actor.apply_identity(189, 0)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.current_clip = "Death2"
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(actor.current_clip, 0.0)
	player.advance(.95)
	var bounds := Geometry.deformed_bounds(actor.model.find_child("Body", true, false), actor.skeleton)
	bounds = bounds.merge(Geometry.deformed_bounds(actor.model.find_child("BruteSpines", true, false), actor.skeleton))
	var target := bounds.get_center()
	camera.position = target + Vector3(.64, .55, 1.0).normalized() * 17.0
	camera.look_at(target)
	camera.size = maxf(camera.global_basis.x.abs().dot(bounds.size), camera.global_basis.y.abs().dot(bounds.size)) * 1.14
	var atlas := Image.create(ImageSize * Hues.size(), ImageSize * 2, false, Image.FORMAT_RGB8)
	var report := {}
	var neutral: Image
	for index in Hues.size():
		var hue: int = Hues[index]
		actor.set_hue(hue)
		actor.set_meta("corpse_body", 189)
		actor.set_meta("native_hue", hue)
		actor.set_meta("death_clip", actor.current_clip)
		await RenderingServer.frame_post_draw
		var moving := view.get_texture().get_image()
		moving.convert(Image.FORMAT_RGB8)
		var box := foreground_rect(moving)
		assert(box.size.x * box.size.y > 2400, "Orc Brute render bounds " + str(box))
		if index == 0:
			neutral = moving
		var difference := average_difference(moving, neutral, box)
		var corpse := Corpse.freeze(actor)
		assert(corpse != null and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		var space := actor.global_transform.affine_inverse() * actor.skeleton.global_transform
		var floor := Ground.minimum_plane_gap(actor.control_skin, actor.skeleton, space, Vector3.ZERO, Vector3.UP)
		corpse.transform = actor.transform * Transform3D(Basis.IDENTITY, Vector3.UP * floor)
		root.add_child(corpse)
		actor.hide()
		await RenderingServer.frame_post_draw
		var frozen := view.get_texture().get_image()
		frozen.convert(Image.FORMAT_RGB8)
		var freeze_difference := average_difference(frozen, moving, box)
		assert(freeze_difference < .02, "Orc Brute freeze mismatch %.5f" % freeze_difference)
		if hue == 0x35:
			assert(difference > .03, "Full dye difference %.6f" % difference)
		if hue == 0x8035:
			assert(difference > .0005 and difference < report["0035"].difference_from_neutral, "Partial dye difference %.6f" % difference)
		assert(corpse.find_child("BruteSpines", false, false) != null)
		atlas.blit_rect(moving, Rect2i(0, 0, ImageSize, ImageSize), Vector2i(index * ImageSize, 0))
		atlas.blit_rect(frozen, Rect2i(0, 0, ImageSize, ImageSize), Vector2i(index * ImageSize, ImageSize))
		report["%04x" % hue] = {"difference_from_neutral": difference, "freeze_difference": freeze_difference}
		corpse.free()
		actor.show()
	assert(atlas.save_png(review_folder() + "189-hue-review.png") == OK)
	var receipt := FileAccess.open(review_folder() + "hue-render-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"scene_sha256": FileAccess.get_sha256(row.assets.modern),
		"shader_sha256": FileAccess.get_sha256("res://Presentation/OstardSurface.gdshader"), "hues": report}, "\t"))
	receipt.close()
	print("ORC BRUTE HUE RENDER ", report)
	actor.free()
	quit()


func average_difference(a: Image, b: Image, box: Rect2i) -> float:
	var distance := 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var one := a.get_pixel(x, y)
			var two := b.get_pixel(x, y)
			distance += Vector3(one.r - two.r, one.g - two.g, one.b - two.b).length()
	return distance / float(box.size.x * box.size.y)
