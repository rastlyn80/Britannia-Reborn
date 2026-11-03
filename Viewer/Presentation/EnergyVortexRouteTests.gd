extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const BODY := 164

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/energy_vortex/preparation.json"))
	Registry.load_index()
	var expected: Dictionary = package.models[0].duplicate(true)
	expected.status = "validated"
	assert(Registry.supports_body(BODY) and Registry.entry(BODY) == expected)
	var avatar := Avatar.new()
	avatar.initial_body = BODY
	root.add_child(avatar)
	avatar.set_physics_process(false)
	var actor: Node3D = avatar.horse_visual
	assert(actor != null and actor.contact.feet.is_empty())
	actor.set_process(false)
	actor.set_physics_process(false)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.2, 2.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = 0.25
	root.add_child(ground)
	await physics_frame
	await physics_frame
	actor._physics_process(0.0)
	assert(is_equal_approx(actor.model.position.y, 0.35))
	ground.position.x = 10.0
	await physics_frame
	await physics_frame
	actor._physics_process(0.0)
	assert(is_zero_approx(actor.model.position.y))
	assert(avatar.transform.is_equal_approx(Transform3D.IDENTITY))
	ground.queue_free()
	for gait in [[false,0.0,"Idle"],[true,1.8,"Walk"],[true,5.5,"Run"]]:
		actor.play_gait(gait[0],gait[1])
		assert(actor.current_clip == gait[2])
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var serial := 0x1234
	var entity := {"serial":serial,"body":BODY,"hue":0}
	game.entities[serial] = entity
	var actions := {4:"Attack",10:"Hit",17:"Fidget",2:"Death"}
	for group: int in actions:
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(PackedByteArray([0,group,0,5,0,1,1,0,0]))
		game._handle(packet)
		assert(avatar.receive_native_action(game.last_mobile_actions[serial]))
		assert(actor.current_clip == actions[group])
	for hue in [0,53,0x8035]:
		entity.hue = hue
		avatar.apply_server_appearance(entity,[])
		assert(actor.native_body == BODY and actor.native_hue == hue)
		var meshes: Array[Node] = actor.model.find_children("*","MeshInstance3D",true,false)
		for mesh: MeshInstance3D in meshes:
			var material := mesh.get_active_material(0) as ShaderMaterial
			assert(material.get_shader_parameter("partial_hue") == ((hue & 0x8000) != 0))
		var corpse := Corpses.build(BODY,hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_children("*","AnimationPlayer",true,false).is_empty())
		assert(corpse.find_children("*","MeshInstance3D",true,false).size() == 3)
		corpse.free()
	await process_frame
	avatar.queue_free()
	game.queue_free()
	await process_frame
	print("energy_vortex passed three gaits, four decoded actions, finite support and three static corpse hues")
	quit()
