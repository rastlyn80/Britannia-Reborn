extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const Dust = preload("res://Presentation/SandVortexSurface.gdshader")
const BODY := 790
const PACKAGE := "res://local-art/creatures/sand_vortex/preparation.json"


func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	Registry.load_index()
	if "--prepared" in OS.get_cmdline_user_args():
		var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
		Registry.entries[BODY] = package.models[0]
	assert(Registry.supports_body(BODY))
	assert(Registry.entry(BODY).kind == "sand_vortex")
	var actor := Registry.create(BODY)
	root.add_child(actor)
	actor.set_physics_process(false)
	assert(actor.contact.feet.is_empty())
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var plane := BoxShape3D.new()
	plane.size = Vector3(4.0, 0.1, 4.0)
	collider.shape = plane
	collider.position.y = 0.25
	ground.add_child(collider)
	root.add_child(ground)
	await physics_frame
	await physics_frame
	actor._physics_process(0.0)
	assert(is_equal_approx(actor.model.position.y, 0.3))
	assert(actor.global_transform.is_equal_approx(Transform3D.IDENTITY))
	actor.position.x = 3.0
	actor._physics_process(0.0)
	assert(is_zero_approx(actor.model.position.y))
	assert(actor.global_position.is_equal_approx(Vector3(3.0, 0.0, 0.0)))
	for hue in [0, 53, 0x8035]:
		actor.apply_identity(BODY, hue)
		for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
			var material := mesh.get_active_material(0) as ShaderMaterial
			assert(material.shader == Dust)
			assert(material.get_shader_parameter("use_hue") == (hue != 0))
			assert(material.get_shader_parameter("partial_hue") == ((hue & 0x8000) != 0))
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
		for mesh: MeshInstance3D in corpse.find_children("*", "MeshInstance3D", true, false):
			assert((mesh.get_active_material(0) as ShaderMaterial).shader == Dust)
		corpse.free()
	for group in [4, 10, 17, 2]:
		assert(actor.receive_action({"protocol": "classic", "action": group}))
		assert(actor.current_clip == {4: "Attack", 10: "Hit", 17: "Fidget", 2: "Death"}[group])
	actor.free()
	ground.free()
	print("sand_vortex passed four classic actions, dust hues and persistent static corpse")
	quit()
