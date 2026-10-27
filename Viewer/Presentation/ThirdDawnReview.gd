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

class OrbitInput extends Node:
	var receiver: Callable
	func _unhandled_input(event: InputEvent) -> void:
		receiver.call(event)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
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
	for i in 2:
		var actor := preload("res://Presentation/ThirdDawnBody.gd").new()
		actor.body = "human" if i == 0 else "ogre"
		actor.position.x = -1.5 if i == 0 else 1.0
		stage.add_child(actor)
		bodies.append(actor)
		var label := Label3D.new()
		label.text = "THIRD DAWN HUMAN / 1.8 m" if i == 0 else "THIRD DAWN OGRE / 2.8 m"
		label.position = actor.position + Vector3(0, 0.07, 1.1)
		label.font_size = 26
		label.pixel_size = 0.0024
		stage.add_child(label)
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
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 45
	stage.add_child(camera)
	update_camera()
	var ui := VBoxContainer.new()
	ui.position = Vector2(24, 20)
	root.add_child(ui)
	var title := Label.new()
	title.text = "BRITANNIA REBORN / THIRD DAWN IMPORT EXPERIMENT"
	ui.add_child(title)
	var note := Label.new()
	note.text = "Private original assets • Alpha Build 35 • RMB orbit / wheel zoom\nNative rigs + original albedo • fitted scale • in-place animation • no live gameplay"
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
	choose_clip(selected_clip)
	if not report_path.is_empty():
		await process_frame
		await validate()
	if not capture_path.is_empty():
		for body in bodies:
			body.animator.stop()
			body.animator.play(selected_clip, 0.0)
			body.animator.advance(0.0)
			body.animator.seek(body.animator.current_animation_length * 0.23, true)
			body.animator.pause()
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(capture_path)
		quit(result)

func choose_clip(clip: String) -> void:
	selected_clip = clip
	for body in bodies: body.set_clip(clip)

func update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbit = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
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
		var row := {"body": body.body, "bones": skeleton.get_bone_count(), "clips": {}}
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
				bounds.append([box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z])
				if not box.position.is_finite() or not box.size.is_finite() or box.size.length() > 15 or box.size.length() < .1:
					failures.append(body.body + " invalid deformed bounds " + clip)
				if absf(box.position.y - body.global_position.y) > .035:
					failures.append(body.body + " feet outside ground tolerance " + clip + " " + str(box.position.y))
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
