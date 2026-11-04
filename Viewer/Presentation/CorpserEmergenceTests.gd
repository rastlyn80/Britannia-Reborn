extends SceneTree

const Geometry = preload("res://Presentation/SkinGeometry.gd")

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var registry = preload("res://Presentation/CreatureRegistry.gd")
	var active := "--active" in OS.get_cmdline_user_args()
	var layered: bool = active and registry.entry(8).get("classic_gesture_batch") == "zombie_corpser_gargoyle_actions"
	if not layered:
		var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/corpser-emergence/candidate.json"))
		if active:
			assert(registry.entry(8) == candidate)
		else:
			registry.load_index()
			registry.entries[8] = candidate
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 0.2, 14)
	collider.shape = box
	collider.position.y = -0.1
	floor_body.add_child(collider)
	root.add_child(floor_body)
	for angle in [0.0, 0.10, -0.10]:
		floor_body.rotation.z = angle
		var actor := registry.create(8)
		root.add_child(actor)
		actor.apply_identity(8, 0x8035)
		assert(actor.receive_action({"protocol":"classic", "action":12}))
		actor.play("Emerge", 0.0)
		actor.animator.advance(0.0)
		var mesh := actor.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var levels: Array[float] = []
		for phase in [0.0, 0.25, 0.5, 0.75, 1.0]:
			actor.animator.seek(actor.animator.current_animation_length * phase, true)
			actor.animator.pause()
			for tick in 4:
				await physics_frame
			var bounds := Geometry.deformed_bounds(mesh, actor.skeleton)
			assert(bounds.position.is_finite() and actor.position.is_zero_approx())
			levels.append(bounds.end.y)
		assert(levels[0] < 0.02 and levels[-1] > 1.9)
		actor.play("Emerge", 0.0)
		actor.animator.seek(0.42,true)
		assert(actor.receive_action({"protocol":"classic", "action":5 if layered else 4}))
		for step in 16:
			actor.animator.advance(0.02)
		var time: float = actor.animator.current_animation_position
		var after := Geometry.deformed_bounds(mesh, actor.skeleton)
		actor.play("Attack", 0.0)
		actor.animator.seek(time,true)
		actor.skeleton.force_update_all_bone_transforms()
		var baseline := Geometry.deformed_bounds(mesh, actor.skeleton)
		print("ATTACK CROSSFADE ", angle, " ", after, " vs ", baseline)
		assert(actor.current_clip == "Attack" and after.is_equal_approx(baseline))
		print("CORPSER TERRAIN ", angle, ": ", levels, "; interrupt to Attack passed")
		actor.free()
	var corpse := preload("res://Presentation/CorpseModels.gd").build(8,0x8035)
	assert(corpse != null and corpse.get_meta("static_cadaver"))
	corpse.free()
	print("CORPSER EMERGENCE: 15 poses, three Attack interruptions and a static corpse")
	quit()
