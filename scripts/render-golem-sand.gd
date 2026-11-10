extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Golem := preload("bake-golem-enhanced.gd")
const Vortex := preload("bake-sand-vortex-enhanced.gd")
const IronVisual := preload("res://Presentation/SourceEnhancedIronGolemVisual.gd")
const SandVisual := preload("res://Presentation/SourceEnhancedSandVortexVisual.gd")
const Size := 192
const Phases := [.0, .24, .47, .76, 1.0]


func review_cast() -> Dictionary:
	return {752: Golem.Clips.values(), 790: Vortex.SandClips.values()}


func review_folder() -> String:
	return Golem.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	if body == 790:
		row.archive_grounded_gestures = Vortex.SandClips.values()
		return SandVisual.new()
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = Golem.Clips.values()
	return IronVisual.new()


func minimum_box(body: int, clip: String, index: int) -> int:
	return 8 if body == 158 and clip == "AcidElementalCondense" and index == 0 else 100


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#2d353f")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#e3eaf0")
	world.environment.ambient_light_energy = .55
	root.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -30, 0)
	key.light_energy = 1.8
	root.add_child(key)
	var views: Array[SubViewport] = []
	for angle: float in [.5, 1.57]:
		var view := SubViewport.new()
		view.size = Vector2i(Size, Size)
		view.world_3d = root.world_3d
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		view.add_child(camera)
		camera.make_current()
		views.append(view)
		camera.set_meta("angle", angle)
	var measurements := {}
	var cast := review_cast()
	var folder := review_folder()
	for body: int in cast:
		var entry := Registry.entry(body).duplicate(true)
		entry.assets = {"modern": folder + "%d-modern.scn" % body}
		Registry.entries[body] = entry
		var actor := review_actor(body)
		actor.entry = entry
		root.add_child(actor)
		actor.apply_identity(body, 0)
		actor.set_physics_process(false)
		actor.set_process(false)
		var clips := {}
		for clip: String in cast[body]:
			clips[clip] = true
		var player: AnimationPlayer = actor.animator
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var bounds := motion_bounds(actor, clips.keys())
		for view: SubViewport in views:
			var camera := view.get_camera_3d()
			var target := bounds.get_center()
			camera.position = target + Vector3.BACK.rotated(Vector3.UP, camera.get_meta("angle")) * 19 + Vector3.UP * 3.2
			camera.look_at(target)
			var horizontal := camera.global_basis.x.abs().dot(bounds.size)
			var vertical := camera.global_basis.y.abs().dot(bounds.size)
			camera.size = maxf(horizontal, vertical) * 1.10
		var atlas := Image.create(Size * 2 * Phases.size(), Size * clips.size(), false, Image.FORMAT_RGB8)
		var row := 0
		var lowest := Size * Size
		for clip: String in clips:
			player.stop()
			actor.current_clip = clip
			player.play(clip, 0.0)
			player.advance(0.0)
			for index in Phases.size():
				player.seek(player.current_animation_length * Phases[index], true)
				await RenderingServer.frame_post_draw
				for side in views.size():
					var frame := views[side].get_texture().get_image()
					assert(not frame.is_empty())
					frame.convert(Image.FORMAT_RGB8)
					var foreground := foreground_rect(frame)
					assert(foreground.position.x > 0 and foreground.position.y > 0
						and foreground.end.x < Size - 1 and foreground.end.y < Size - 1,
						"Crop clips body %d in %s, %s" % [body, clip, foreground])
					var pixels := (foreground.size.x + 1) * (foreground.size.y + 1)
					var minimum := minimum_box(body, clip, index)
					assert(pixels > minimum, "%d/%s phase %.2f view %d only drew %d box pixels" % [body, clip, Phases[index], side, pixels])
					lowest = mini(lowest, pixels)
					atlas.blit_rect(frame, Rect2i(0, 0, Size, Size), Vector2i((side * Phases.size() + index) * Size, row * Size))
			row += 1
		assert(atlas.save_png(entry.assets.modern.get_base_dir().path_join("%d-motion-review.png" % body)) == OK)
		measurements[str(body)] = {"poses": row * Phases.size() * views.size(), "minimum_foreground_box_pixels": lowest,
			"scene_sha256": FileAccess.get_sha256(entry.assets.modern), "clips": clips.keys()}
		actor.free()
		print("CREATURE MOTION MATERIAL RENDER ", body, ": ", measurements[str(body)])
	var receipt := FileAccess.open(folder + "motion-render-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(measurements, "\t"))
	receipt.close()
	quit()

func motion_bounds(actor: Node3D, clips: Array) -> AABB:
	var bounds := AABB()
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
	for clip: String in clips:
		actor.current_clip = clip
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		for phase: float in Phases:
			player.seek(player.current_animation_length * phase, true)
			rig.force_update_all_bone_transforms()
			for mesh: MeshInstance3D in meshes:
				if not mesh.is_visible_in_tree():
					continue
				var box := Geometry.deformed_bounds(mesh, rig) if mesh.skin != null else mesh.global_transform * mesh.get_aabb()
				assert(box.position.is_finite() and box.size.is_finite() and box.has_volume())
				bounds = bounds.merge(box) if bounds.has_volume() else box
	return bounds

func foreground_rect(frame: Image) -> Rect2i:
	var background := frame.get_pixel(0, 0)
	var bounds := Rect2i(-1, -1, 0, 0)
	for y in Size:
		for x in Size:
			var delta := frame.get_pixel(x, y) - background
			if maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) > .025:
				var pixel := Vector2i(x, y)
				if bounds.position.x < 0:
					bounds.position = pixel
				else:
					bounds = bounds.expand(pixel)
	return bounds
