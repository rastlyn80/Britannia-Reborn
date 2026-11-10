# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Bake := preload("bake-efreet-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedEfreetVisual.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Phases := [.05, .24, .47, .76, 1.0]
const Size := 224


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	var backdrop := WorldEnvironment.new()
	backdrop.environment = Environment.new()
	backdrop.environment.background_mode = Environment.BG_COLOR
	backdrop.environment.background_color = Color("#2d353f")
	backdrop.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	backdrop.environment.ambient_light_color = Color("#e3eaf0")
	backdrop.environment.ambient_light_energy = .63
	root.add_child(backdrop)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -26, 0)
	key.light_energy = 1.75
	root.add_child(key)
	var view := SubViewport.new()
	view.size = Vector2i(Size, Size)
	view.world_3d = root.world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.72
	view.add_child(camera)
	camera.position = Vector3(1.42, 2.2, 3.25)
	camera.look_at(Vector3(0, .81, .09))
	camera.make_current()
	var row := Registry.entry(131).duplicate(true)
	row.assets = {"modern": Bake.Destination + "131-modern.scn"}
	var actor := Visual.new()
	actor.entry = row
	root.add_child(actor)
	actor.apply_identity(131, 0)
	actor.set_physics_process(false)
	actor.set_process(false)
	var props := actor.props
	var skin := actor.model.find_child("Body", true, false) as MeshInstance3D
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var result := Image.create(Size * Phases.size(), Size * Bake.Clips.size(), false, Image.FORMAT_RGB8)
	var heights := {}
	var minimum := Size * Size
	var line := 0
	for group: int in Bake.Clips:
		actor.current_clip = Bake.Clips[group]
		player.play(actor.current_clip, 0.0)
		player.advance(0.0)
		var sampled := []
		for index in Phases.size():
			var phase: float = Phases[index]
			player.seek(phase * player.current_animation_length, true)
			actor.skeleton.force_update_all_bone_transforms()
			var box := Geometry.deformed_bounds(skin, actor.skeleton)
			await RenderingServer.frame_post_draw
			var frame := view.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			var bounds := foreground(frame)
			assert(bounds.has_area() and bounds.position.x > 0 and bounds.position.y > 0
				and bounds.end.x < Size - 1 and bounds.end.y < Size - 1)
			var pixels := bounds.get_area()
			assert(pixels > (90 if group == 23 and phase < .33 else 4200))
			minimum = mini(minimum, pixels)
			result.blit_rect(frame, Rect2i(0, 0, Size, Size), Vector2i(index * Size, line * Size))
			sampled.append([box.position.y, props.lamp.visible, props.carpet.visible])
		heights[str(group)] = sampled
		line += 1
	assert(result.save_png(Bake.Destination + "efreet-props-review.png") == OK)
	var receipt := FileAccess.open(Bake.Destination + "efreet-prop-render-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	var owned := {}
	for file: String in ["SourceEnhancedEfreetVisual.gd", "EfreetEnhancedProps.gd", "efreet-carpet.gdshader", "efreet-smoke.gdshader"]:
		owned[file] = FileAccess.get_sha256(Bake.Destination + file)
	receipt.store_string(JSON.stringify({"poses": line * Phases.size(), "heights": heights,
		"minimum_foreground_box_pixels": minimum, "script_sha256": owned,
		"scene_sha256": FileAccess.get_sha256(row.assets.modern)}, "\t"))
	receipt.close()
	print("EFREET PROP REVIEW: ", line * Phases.size(), " views, minimum ", minimum, " pixels ", heights)
	quit()


func foreground(frame: Image) -> Rect2i:
	var background := frame.get_pixel(0, 0)
	var bounds := Rect2i()
	for y in Size:
		for x in Size:
			var color := frame.get_pixel(x, y)
			var difference := absf(color.r - background.r) + absf(color.g - background.g) + absf(color.b - background.b)
			if difference > .14:
				var point := Rect2i(x, y, 1, 1)
				bounds = bounds.merge(point) if bounds.has_area() else point
	return bounds
