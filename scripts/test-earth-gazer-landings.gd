extends "res://../scripts/test-serpent-ogre-landings.gd"

const Motion := preload("res://../scripts/test-earth-gazer-imp-actions.gd")
const Earth := preload("res://Presentation/EarthAssemblyActionsVisual.gd")

func run() -> void:
	Registry.load_index()
	for body: int in [14, 22]:
		var row := Motion.trial_row(body)
		Registry.entries[body] = row
		for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, 0.11), Vector3(-0.12, 0.0, -0.10)]:
			await witness(body, tilt)
			if body == 14:
				await witness_assembly(row, tilt)
	check_no_floor(Registry.entry(14))
	print("EARTH AND GAZER: six decoded corpse handoffs, 246 terrain samples, three interruptible assembly cases and the no-floor fallback")
	quit()

func check_no_floor(row: Dictionary) -> void:
	var actor := Earth.new()
	actor.entry = row
	actor.position = Vector3(40.0, 0.0, 40.0)
	root.add_child(actor)
	actor.apply_identity(14, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	assert(actor.receive_action({"protocol": "classic", "action": 12}))
	var player := actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Assemble", 0.0)
	player.advance(0.0)
	player.seek(player.current_animation_length, true)
	assert(actor.assembly_shift.is_zero_approx() and actor.position == Vector3(40.0, 0.0, 40.0))
	actor.free()

func witness_assembly(row: Dictionary, tilt: Vector3) -> void:
	var ground := StaticBody3D.new()
	ground.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.10, 8.0)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -0.05
	ground.add_child(collider)
	root.add_child(ground)
	await physics_frame
	await physics_frame
	var actor := Earth.new()
	actor.entry = row
	root.add_child(actor)
	actor.apply_identity(14, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	assert(actor.receive_action({"protocol": "classic", "action": 12}) and not actor.contact.enabled)
	var player := actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Assemble", 0.0)
	player.advance(0.0)
	var skin := Ground.skin_points(actor.model.find_children("*", "MeshInstance3D", true, false)[0], actor.skeleton)
	var normal := ground.global_basis.y
	var start := Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform, Vector3.ZERO, normal)
	player.seek(player.current_animation_length, true)
	var final := Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform, Vector3.ZERO, normal)
	print("EARTH ASSEMBLY ", tilt, " first/final clearance ", [start, final], " model shift ", actor.assembly_shift)
	assert(start < -0.45 and final > -0.004 and actor.global_position.is_zero_approx())
	assert(actor.receive_action({"protocol": "classic", "action": 4}) and actor.assembly_shift.is_zero_approx())
	actor.free()
	ground.free()
