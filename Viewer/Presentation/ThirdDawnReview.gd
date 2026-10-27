extends SceneTree
## Private asset review in the actual client project. No network connection.

var bodies: Array[Node3D] = []
var camera: Camera3D
var target := Vector3(0, 1.25, 0)
var yaw := 0.22
var pitch := 0.12
var distance := 7.0
var orbit := false
var clips_paused := false
var capture_path := ""
var report_path := ""
var selected_clip := "Idle"
var frame := 0
var stage: Node3D
var human_review := false
var free_human_review := false
var free_equipment_review := false
var selected_view := "all"
var rear_view := false
var lighting := "studio"
var material_test_path := ""
var review_angle := "front"
var review_note: Label
var capture_phase := .23
var skin_choice := "young_lightskinned_male_diffuse2.png"
var motion_grid := false
var hair_choice := "short02"

class OrbitInput extends Node:
	var receiver: Callable
	func _unhandled_input(event: InputEvent) -> void:
		receiver.call(event)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--human": human_review = true
		if arg == "--motion-grid": motion_grid = true
		if arg == "--equipment":
			human_review = true
			free_human_review = true
			free_equipment_review = true
		if arg == "--free-human":
			human_review = true
			free_human_review = true
		if arg.begins_with("--angle="): review_angle = arg.substr(8)
		if arg.begins_with("--phase="): capture_phase = clampf(float(arg.substr(8)),0.0,1.0)
		if arg.begins_with("--skin="): skin_choice = arg.substr(7)
		if arg.begins_with("--hair="): hair_choice = arg.substr(7)
		if arg == "--rear": rear_view = true
		if arg.begins_with("--light="): lighting = arg.substr(8)
		if arg.begins_with("--material-test="): material_test_path = arg.substr(16)
		if arg.begins_with("--view="): selected_view = arg.substr(7)
		if arg.begins_with("--screenshot="): capture_path = arg.substr(13)
		if arg.begins_with("--report="): report_path = arg.substr(9)
		if arg.begins_with("--clip="): selected_clip = arg.substr(7)
	call_deferred("build")

func build() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var input_sink := OrbitInput.new()
	input_sink.receiver = handle_input
	stage.add_child(input_sink)
	var entries := [
		{"body": "human", "x": -1.5, "label": "THIRD DAWN HUMAN / 1.8 m", "treatment": "original", "wardrobe": "base"},
		{"body": "ogre", "x": 1.0, "label": "THIRD DAWN OGRE / 2.8 m", "treatment": "original", "wardrobe": "base"}]
	if human_review:
		entries = [
			{"body": "human", "x": -3.2, "label": "ORIGINAL BASE", "treatment": "original", "wardrobe": "base"},
			{"body": "human", "x": -1.6, "label": "PREVIOUS ROUNDING", "treatment": "skin_v2", "wardrobe": "base", "localized": true},
			{"body": "human", "x": 0.0, "label": "CHEST + FACE REFINEMENT", "treatment": "skin_v2", "wardrobe": "base", "localized": true, "anatomy": true},
			{"body": "human", "x": 1.6, "label": "CHAIN SHIRT", "treatment": "skin_v2", "wardrobe": "shirt", "localized": true, "anatomy": true},
			{"body": "human", "x": 3.2, "label": "ROBE", "treatment": "skin_v2", "wardrobe": "robe", "localized": true, "anatomy": true}]
		target = Vector3(0, .95, 0)
		distance = 9.0
		yaw = PI if rear_view else 0.0
		pitch = .07
	if free_human_review:
		entries[1] = {"body":"human", "x":-1.6, "label":"OLD UO BODY", "treatment":"skin_v2", "wardrobe":"base", "anatomy":true}
		for i in [2,3,4]:
			entries[i]["body"] = "free-human"
			entries[i]["treatment"] = "original"
			entries[i]["label"] = "CC0 HUMAN BASE" if i == 2 else ("UO CHAIN SHIRT / REFITTED" if i == 3 else "UO ROBE / REFITTED")
	if free_equipment_review:
		entries = [{"body":"free-equipment", "x":-1.6, "label":"PREVIOUS SKIN", "treatment":"previous", "wardrobe":"previous"}]
		var captions := {"base":"NEW SKIN", "tunic":"MAIL TUNIC", "pants":"TROUSERS", "boots":"LEATHER BOOTS", "robe":"MONK ROBE", "hood":"HOOD", "viking":"TUNIC + TROUSERS + BOOTS", "monk":"ROBE + HOOD"}
		for slot in ["base", "tunic", "pants", "boots", "robe", "hood", "viking", "monk"]:
			entries.append({"body":"free-equipment", "x":0.0, "label":captions[slot], "treatment":"original", "wardrobe":slot})
		if motion_grid:
			entries.clear()
			for i in 8: entries.append({"body":"free-equipment", "x":0.0, "label":"STRIDE %d%%" % (i*12.5), "treatment":"original", "wardrobe":"monk"})
	for entry in entries:
		var actor := preload("res://Presentation/ThirdDawnBody.gd").new()
		actor.body = entry.body
		actor.treatment = entry.treatment
		actor.wardrobe = entry.wardrobe
		actor.refined = entry.get("refined", false)
		actor.localized = entry.get("localized", false)
		actor.anatomy = entry.get("anatomy", false)
		actor.skin_texture = skin_choice
		actor.hair_style = hair_choice
		actor.set_meta("review_x", entry.x)
		actor.position.x = entry.x
		stage.add_child(actor)
		bodies.append(actor)
		var label := Label3D.new()
		label.text = entry.label
		label.position = actor.position + Vector3(0, 0.07, 1.1)
		label.font_size = 26
		label.pixel_size = 0.0024
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stage.add_child(label)
		actor.set_meta("review_label", label)
	if not human_review:
		var current := preload("res://Presentation/Avatar.gd").new()
		current.position = Vector3(-3.1, 0, 0)
		stage.add_child(current)
		current.set_physics_process(false)
		var label := Label3D.new()
		label.text = "CURRENT AVATAR / REFERENCE"
		label.position = Vector3(-3.1, .07, 1.1)
		label.font_size = 23
		label.pixel_size = .0024
		stage.add_child(label)
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(12, 0.1, 9)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5b6264")
	mat.roughness = .95
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("26333e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bdcbd5")
	environment.environment.ambient_light_energy = .65
	if free_equipment_review:
		environment.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
		environment.environment.ambient_light_energy = .40
	if lighting == "outdoor":
		environment.environment.background_mode = Environment.BG_SKY
		environment.environment.sky = Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("6898c3")
		sky_material.sky_horizon_color = Color("c8d7df")
		environment.environment.sky.sky_material = sky_material
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.environment.ambient_light_energy = .55
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.05 if human_review else 1.8
	if lighting == "side": sun.rotation_degrees = Vector3(-22, -80, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	if rear_view:
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-35,155,0)
		fill.light_energy = .45
		stage.add_child(fill)
	camera = Camera3D.new()
	camera.fov = 45
	stage.add_child(camera)
	update_camera()
	var ui := VBoxContainer.new()
	ui.position = Vector2(24, 20)
	root.add_child(ui)
	var title := Label.new()
	title.text = "BRITANNIA REBORN / MALE BODY AND WARDROBE" if human_review else "BRITANNIA REBORN / THIRD DAWN IMPORT EXPERIMENT"
	if free_equipment_review: title.text = "BRITANNIA REBORN / FREE EQUIPMENT AND HUMAN MATERIAL REVIEW"
	ui.add_child(title)
	var note := Label.new()
	review_note = note
	note.text = "Private original assets • Alpha Build 35 • RMB orbit / wheel zoom\nNative rigs + original albedo • fitted scale • in-place animation • no live gameplay"
	if human_review: note.text = "Original UVs + native skeleton • Same skin material • left: previous rounding / right: chest + face refinement\nPrototype body-hiding masks • Idle / Walk / Run • RMB orbit / wheel zoom • private review"
	if free_human_review: note.text = "New CC0 MakeHuman base + original UO wearables refitted to the new skeleton\nLeft: old body / right: new base • native target animations • private clothing experiment"
	ui.add_child(note)
	var buttons := HBoxContainer.new()
	ui.add_child(buttons)
	for clip in ["Idle", "Walk", "Run"]:
		var button := Button.new()
		button.text = clip
		button.pressed.connect(func(): choose_clip(clip))
		buttons.add_child(button)
	var pause_button := Button.new()
	pause_button.text = "Pause / resume"
	pause_button.pressed.connect(func():
		clips_paused = not clips_paused
		for body in bodies: body.animator.speed_scale = 0.0 if clips_paused else 1.0)
	buttons.add_child(pause_button)
	if human_review:
		for view in (["Complete outfits", "All five pieces", "Skin comparison", "Head close-up", "Robe movement"] if free_equipment_review else ["All", "Base close-up", "Material close-up", "Head close-up", "Chest + face", "Clothing close-up"]):
			var button := Button.new()
			button.text = view
			button.pressed.connect(func():
				if free_equipment_review:
					apply_view("clothing" if view == "Complete outfits" else ("parts" if view == "All five pieces" else ("bust" if view == "Skin comparison" else ("robe" if view == "Robe movement" else "head"))))
					return
				apply_view("base" if view == "Base close-up" else ("materials" if view == "Material close-up" else ("head" if view == "Head close-up" else ("bust" if view == "Chest + face" else ("clothing" if view == "Clothing close-up" else "all"))))))
			buttons.add_child(button)
		var angles := HBoxContainer.new()
		ui.add_child(angles)
		for angle in ["Front", "Three-quarter", "Profile"]:
			var button := Button.new()
			button.text = angle
			button.pressed.connect(func(): apply_angle(angle.to_lower()))
			angles.add_child(button)
		if free_equipment_review:
			var appearance := HBoxContainer.new()
			ui.add_child(appearance)
			for choice in [["Light","young_lightskinned_male_diffuse2.png"],["Medium","young_lightskinned_male_diffuse3.png"],["Dark","young_darkskinned_male_diffuse.png"]]:
				var button := Button.new()
				button.text = choice[0] + " skin"
				button.pressed.connect(func():
					for actor in bodies: actor.set_natural_skin(choice[1]))
				appearance.add_child(button)
			for choice in [["Bald","bald"],["Short","short02"]]:
				var button := Button.new()
				button.text = choice[0]
				button.pressed.connect(func():
					for actor in bodies: actor.set_hair(choice[1]))
				appearance.add_child(button)
		apply_angle(review_angle)
		apply_view(selected_view)
		var skin_controls := HBoxContainer.new()
		skin_controls.visible = not free_human_review
		ui.add_child(skin_controls)
		for setting in ["Skin detail", "Skin sheen"]:
			var caption := Label.new()
			caption.text = setting
			skin_controls.add_child(caption)
			var slider := HSlider.new()
			slider.custom_minimum_size.x = 130
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = .01
			slider.value = .46 if setting == "Skin detail" else .49
			slider.value_changed.connect(func(value: float):
				for actor in bodies:
					if actor.treatment != "skin_v2": continue
					for mesh in actor.model.find_children("*", "MeshInstance3D", true, false):
						var material = mesh.material_override
						if material is ShaderMaterial:
							material.set_shader_parameter("normal_strength" if setting == "Skin detail" else "skin_roughness",
								value * .65 if setting == "Skin detail" else lerpf(.75, .40, value)))
			skin_controls.add_child(slider)
	choose_clip(selected_clip)
	if motion_grid: arrange_motion_grid()
	if not material_test_path.is_empty():
		await test_material()
		return
	if not report_path.is_empty():
		await process_frame
		await validate()
	if not capture_path.is_empty():
		for body in bodies:
			body.animator.speed_scale = 0.0
			body.animator.stop()
			body.animator.play(selected_clip, 0.0)
			body.animator.advance(0.0)
			body.animator.seek(body.animator.current_animation_length * (float(bodies.find(body))/8.0 if motion_grid else capture_phase), true)
			body.animator.pause()
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(capture_path)
		quit(result)

func choose_clip(clip: String) -> void:
	selected_clip = clip
	for body in bodies: body.set_clip(clip)

func arrange_motion_grid() -> void:
	var right := Vector3(cos(yaw),0,-sin(yaw))
	for i in bodies.size():
		var actor := bodies[i]
		actor.visible = true
		actor.position = right * ((float(i%4)-1.5)*1.6) + Vector3(0,2.25 if i<4 else 0.0,0)
		var label: Label3D = actor.get_meta("review_label")
		label.position = actor.position + Vector3(0,-.17,0)
		label.visible = true
	target = Vector3(0,2.60,0)
	pitch = 0.0
	distance = 8.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.65
	review_note.text = "Robe + hood / " + selected_clip + " / eight evenly spaced poses across the complete cycle\nContinuous legs retained • eight skirt controls • front/side/rear review"
	update_camera()

func update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)

func apply_view(view: String) -> void:
	if free_equipment_review:
		apply_equipment_view(view)
		return
	if free_human_review:
		review_note.text = "CC0 MakeHuman base + original UO3D garments refitted to its skeleton\n" + ("Base / refitted chain shirt / refitted robe • Idle / Walk / Run" if view == "clothing" else "Left: old UO body / right: free human base • same studio lighting")
	target = Vector3(-1.6 if view == "base" else (1.6 if view == "clothing" else 0.0), .95, 0)
	distance = 6.0 if view != "all" else 9.0
	if free_human_review and view == "clothing": distance = 4.0
	if view in ["materials", "head", "bust"]:
		target = Vector3(-.8, .95, 0)
		distance = 3.8
	if view == "head":
		target = Vector3(0, 1.63, 0)
		distance = 1.65
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if view in ["head", "bust"] else Camera3D.PROJECTION_PERSPECTIVE
	camera.size = .85 if view == "head" else 1.32
	if view == "bust":
		target = Vector3(0, 1.48, 0)
		distance = 2.5
	for i in bodies.size():
		bodies[i].position.x = (-.29 if i == 1 else .29) if view == "head" else ((-.43 if i == 1 else .43) if view == "bust" else float(bodies[i].get_meta("review_x")))
		bodies[i].get_meta("review_label").position.x = bodies[i].position.x
		var shown := view == "all" or (i <= 2 if view == "base" else (i in [1, 2] if view in ["materials", "head", "bust"] else i >= 2))
		bodies[i].visible = shown
		bodies[i].get_meta("review_label").visible = shown
	update_camera()

func apply_equipment_view(view: String) -> void:
	var shown: Array = [1, 7, 8]
	target = Vector3(1.6, .95, 0)
	distance = 4.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if view == "robe":
		shown = [5,8]
		target = Vector3(.8,.95,0)
		distance = 3.8
	if view == "parts":
		shown = [2, 3, 4, 5, 6]
		target = Vector3(0, .95, 0)
		distance = 7.0
	if view in ["materials", "bust", "head"]:
		shown = [0, 1]
		target = Vector3(0, 1.63 if view == "head" else 1.48, 0)
		distance = 2.5
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = .85 if view == "head" else 1.32
	for i in bodies.size():
		var at := shown.find(i)
		bodies[i].visible = at >= 0
		if at >= 0:
			bodies[i].position.x = (float(at) - 2.0) * 1.6 if view == "parts" else float(at) * 1.6
			if view in ["materials", "bust", "head"]: bodies[i].position.x = (-.29 if at == 0 else .29) if view == "head" else (-.43 if at == 0 else .43)
		var label: Label3D = bodies[i].get_meta("review_label")
		label.visible = at >= 0 and view not in ["materials", "bust", "head"]
		label.position.x = bodies[i].position.x
	review_note.text = "Five CC0 replacements: mail tunic / trousers / boots / monk robe / hood\n" + ("Left: previous appearance • right: new skin texture, surface detail and shading" if view in ["materials", "bust", "head"] else "Matching character and animation • Idle / Walk / Run • five reusable clothing pieces")
	update_camera()

func apply_angle(angle: String) -> void:
	review_angle = angle
	for body in bodies:
		body.rotation.y = PI / 2.0 if angle == "profile" else (PI / 4.0 if angle == "three-quarter" else 0.0)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbit = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				camera.size = clampf(camera.size + (-.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .1), .35, 3.5)
			else:
				distance = clampf(distance + (-.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .5), 3, 14)
			update_camera()
	if event is InputEventMouseMotion and orbit:
		yaw -= event.relative.x * .006
		pitch = clampf(pitch + event.relative.y * .006, -.05, 1.1)
		update_camera()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: quit()

func validate() -> void:
	var evidence: Array = []
	var failures: Array = []
	for body in bodies:
		var skeleton: Skeleton3D = body.model.find_children("*", "Skeleton3D", true, false)[0]
		var mesh: MeshInstance3D = body.model.find_children("*", "MeshInstance3D", true, false)[0]
		for candidate: MeshInstance3D in body.model.find_children("*", "MeshInstance3D", true, false):
			if candidate.mesh.surface_get_array_len(0) > mesh.mesh.surface_get_array_len(0): mesh = candidate
		var row := {"body": body.body, "treatment": body.treatment, "refined": body.refined, "localized": body.localized, "anatomy": body.anatomy, "wardrobe": body.wardrobe, "bones": skeleton.get_bone_count(), "equipment_count": body.equipment.size(), "clips": {}}
		var origin: Vector3 = body.position
		for clip in ["Idle", "Walk", "Run"]:
			body.animator.stop()
			body.animator.play(clip, 0.0)
			var poses: Array = []
			var bounds: Array = []
			for phase in [.1, .35, .65, .9]:
				body.animator.seek(body.animator.current_animation_length * phase, true)
				await process_frame
				await process_frame
				var pose: Array[Transform3D] = []
				for i in skeleton.get_bone_count(): pose.append(skeleton.get_bone_global_pose(i))
				poses.append(pose)
				var box := deformed_bounds(mesh, skeleton)
				for rendered: MeshInstance3D in body.model.find_children("*", "MeshInstance3D", true, false):
					if rendered.skin != null: box = box.merge(deformed_bounds(rendered, skeleton))
				bounds.append([box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z])
				if not box.position.is_finite() or not box.size.is_finite() or box.size.length() > 15 or box.size.length() < .1:
					failures.append(body.body + " invalid deformed bounds " + clip)
				var floor_height := box.position.y - body.global_position.y
				var bad_ground := absf(floor_height) > .035
				# The CC0 source run has a brief aerial phase; retain it while
				# rejecting penetration separately from its bounded flight height.
				if body.body in ["free-human", "free-equipment"] and clip == "Run": bad_ground = floor_height < -.015 or floor_height > .09
				if bad_ground:
					failures.append(body.body + " feet outside ground tolerance " + clip + " " + str(box.position.y))
				for garment: MeshInstance3D in body.equipment:
					var gear_box := deformed_bounds(garment, skeleton)
					if not gear_box.size.is_finite() or gear_box.size.length() > 4.0:
						failures.append(body.wardrobe + " exploded garment " + clip)
					if gear_box.position.y < -.08 or gear_box.end.y > 2.1:
						failures.append(body.wardrobe + " garment outside body height " + clip + " " + str(gear_box.position.y) + ".." + str(gear_box.end.y))
			var changes := false
			for i in skeleton.get_bone_count():
				if not poses[0][i].is_equal_approx(poses[1][i]): changes = true
			if not changes: failures.append(body.body + " frozen pose " + clip)
			if body.position != origin: failures.append(body.body + " animation moved entity root")
			row.clips[clip] = {"duration": body.animator.current_animation_length, "pose_changes": changes, "bounds": bounds, "root_stationary": body.position == origin}
		evidence.append(row)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"models": evidence, "failures": failures}, "\t"))
	file.close()
	print("Third Dawn engine validation: ", failures.size(), " failures; ", evidence.size(), " animated bodies")
	if not failures.is_empty():
		push_error(str(failures))
		quit(1)
		return
	choose_clip(selected_clip)
	if capture_path.is_empty(): quit(0)

func deformed_bounds(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	# CPU skinning also works with Godot's headless dummy renderer. Use the
	# imported Skin inverse bind matrices, not a synthetic bone-only box.
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin := mesh.skin
	var matrices: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(i))
		matrices.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i))
	var box := AABB()
	for i in vertices.size():
		var point := Vector3.ZERO
		for j in 4:
			point += (matrices[indices[i * 4 + j]] * vertices[i]) * weights[i * 4 + j]
		point = skeleton.to_global(point)
		if i == 0: box = AABB(point, Vector3.ZERO)
		else: box = box.expand(point)
	return box

func material_snapshot() -> Image:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.resize(320, 200, Image.INTERPOLATE_BILINEAR)
	return picture

func material_difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var left := a.get_pixel(x, y)
			var right := b.get_pixel(x, y)
			total += absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)
	return total / (float(a.get_width() * a.get_height()) * 3.0)

func test_material() -> void:
	var subject: Node3D = bodies[1] if free_equipment_review else bodies[2]
	subject.position = Vector3.ZERO
	for actor in bodies:
		actor.animator.stop()
		actor.animator.play("Idle", 0.0)
		actor.animator.advance(0.0)
		actor.animator.seek(actor.animator.current_animation_length * .23, true)
		actor.animator.pause()
		actor.visible = actor == subject
		actor.get_meta("review_label").visible = false
	target = Vector3(0, .95, 0)
	distance = 3.2
	update_camera()
	var mesh: MeshInstance3D = subject.model.find_children("*", "MeshInstance3D", true, false)[0]
	for candidate: MeshInstance3D in subject.model.find_children("*", "MeshInstance3D", true, false):
		if candidate.material_override is ShaderMaterial: mesh = candidate
	var mat: ShaderMaterial = mesh.material_override
	mat.set_shader_parameter("normal_strength", 0.0)
	var flat := await material_snapshot()
	mat.set_shader_parameter("normal_strength", 0.30)
	var detailed := await material_snapshot()
	mat.set_shader_parameter("skin_roughness", .40)
	var smooth_skin := await material_snapshot()
	mat.set_shader_parameter("skin_roughness", .78)
	var rough_skin := await material_snapshot()
	mat.set_shader_parameter("skin_roughness", .58)
	var sun: DirectionalLight3D = stage.find_children("*", "DirectionalLight3D", true, false)[0]
	sun.rotation_degrees = Vector3(-22, -80, 0)
	var sidelight := await material_snapshot()
	var metrics := {
		"normal_response": material_difference(flat, detailed),
		"roughness_response": material_difference(smooth_skin, rough_skin),
		"light_response": material_difference(detailed, sidelight),
		"renderer": RenderingServer.get_current_rendering_method(),
		"geometry": "CC0 MakeHuman base, same geometry and pose" if free_equipment_review else "localized head/joint rounding; original native rig",
		"root_stationary": subject.position == Vector3.ZERO
	}
	var failures: Array[String] = []
	for key in ["normal_response", "roughness_response", "light_response"]:
		if metrics[key] <= .000005: failures.append(key + " had no visible GPU response")
	if not metrics.root_stationary: failures.append("material changed actor root")
	metrics["failures"] = failures
	var output := FileAccess.open(material_test_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	output.close()
	print("SKIN MATERIAL GPU: ", metrics)
	quit(0 if failures.is_empty() else 1)
