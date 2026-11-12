# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const OriginalHorse := preload("res://Presentation/SourceWarHorseVisual.gd")
const Stage := preload("res://Presentation/ItemStudio.gd")
const Frame := Vector2i(340, 220)
const Requests := {
	2: [3, 0], 3: [3, 1], 4: [0, 0], 10: [4, 0], 12: [11, 0], 15: [2, 0],
	26: [5, 0], 27: [5, 1], 28: [8, 0],
}


func _initialize() -> void:
	create_timer(105.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	OriginalHorse.configure_war_horses(true)
	assert(OriginalHorse.war_scenes.size() == 7)
	var viewport := SubViewport.new()
	viewport.size = Frame
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	Stage.studio_lights(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.55
	viewport.add_child(camera)
	camera.make_current()
	camera.look_at_from_position(Vector3(5.8, 2.05, 2.40), Vector3(0., 1.10, 0.))
	var folder := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		printerr("Provide an existing private output directory using --study.")
		quit(1)
		return
	var proof := {}
	var count := 0
	for body: int in [OriginalHorse.BritannianBody, OriginalHorse.PackBody]:
		var groups := [1, 2, 3, 4, 10, 12, 15, 22, 24, 25, 26, 27, 28]
		if body == OriginalHorse.BritannianBody:
			groups.erase(12)
		var sheet := Image.create(Frame.x * 3, Frame.y * groups.size(), false, Image.FORMAT_RGB8)
		var rows := {}
		for row in groups.size():
			var group: int = groups[row]
			var actor := OriginalHorse.create_war_horse(body) as OriginalHorse
			viewport.add_child(actor)
			actor.apply_identity(body, 0)
			actor.set_physics_process(false)
			actor.set_process(false)
			actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if Requests.has(group):
				var selector: Array = Requests[group]
				assert(actor.receive_enhanced_action({"protocol": "new", "body": body, "type": selector[0],
					"variation": selector[1]}, 0 if group == 26 else 0x40))
			else:
				actor.set_native_combat_flags(0x40 if group == 1 else 0)
				actor.play_gait(group in [22, 24], 5.4 if group == 24 else 1.8)
			assert(actor.current_clip == OriginalHorse.EnhancedClips.get(group, "Walk" if group == 22 else "Run"))
			actor.animator.advance(.16)
			var views := []
			for column in 3:
				var phase: float = [.05, .46, .94][column]
				actor.animator.seek(actor.animator.current_animation_length * phase, true)
				actor.skeleton.force_update_all_bone_transforms()
				for frame in 3:
					await RenderingServer.frame_post_draw
				var view := viewport.get_texture().get_image()
				assert(view != null and view.get_size() == Frame)
				view.convert(Image.FORMAT_RGB8)
				var pixels := foreground(view)
				assert(pixels > (340 if group in [2, 3] and column == 2 else 600),
					"body %d group %d phase %.2f has %d foreground samples" % [body, group, phase, pixels])
				var head := actor.skeleton.find_bone("bip01 head")
				var position := actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(head).origin)
				if group == 3 and column == 2:
					var root_joint := actor.skeleton.find_bone("bip01")
					var hip := actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(root_joint).origin)
					assert(absf(position.y - hip.y) < .50, "the turned corpse must rest on its flank")
				views.append({"phase": phase, "foreground": pixels, "head": position})
				sheet.blit_rect(view, Rect2i(Vector2i.ZERO, Frame), Vector2i(column * Frame.x, row * Frame.y))
			rows[group] = {"clip": actor.current_clip, "views": views}
			actor.free()
		var side: Vector3 = rows[2].views[2].head
		var back: Vector3 = rows[3].views[2].head
		assert(side.distance_to(back) > .45, "the rendered collapses need distinct endpoints")
		for group: int in ([4, 27] if body == OriginalHorse.BritannianBody else [4, 12, 27]):
			var views: Array = rows[group].views
			assert(views[1].head.y - views[0].head.y > .28, "the rendered rear must lift the skull")
		assert(sheet.save_png(folder.path_join("enhanced-horse-%d.png" % body)) == OK)
		proof[body] = {"groups": rows, "scene_sha256": FileAccess.get_sha256(OriginalHorse.Art + OriginalHorse.FormsByBody[body][0])}
		count += 3 * groups.size()
	var receipt := FileAccess.open(folder.path_join("enhanced-render-proof.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"views": count, "bodies": proof}, "  "))
	receipt.close()
	print("ORIGINAL WAR HORSE RENDER: ", count, " Forward+ views across every indexed group")
	quit()


func foreground(view: Image) -> int:
	var pixels := 0
	for y in range(0, Frame.y, 2):
		for x in range(0, Frame.x, 2):
			var value := view.get_pixel(x, y)
			if value.r + value.g + value.b > .39:
				pixels += 1
	return pixels
